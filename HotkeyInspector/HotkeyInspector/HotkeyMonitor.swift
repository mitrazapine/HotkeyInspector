import AppKit
import ApplicationServices
import Carbon
import Combine

struct MonitorEntry: Identifiable {
    let id = UUID()
    let date: Date
    let applicationName: String
    let keyCode: Int
    let shortcut: String
}

@MainActor
final class HotkeyMonitor: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Монитор выключен"
    @Published private(set) var entries: [MonitorEntry] = []
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var healthTimer: Timer?

    func start() {
        guard !isRunning else { return }
        guard CGPreflightListenEventAccess() else {
            _ = CGRequestListenEventAccess()
            status = "Разрешите «Мониторинг ввода» для HotkeyInspector в настройках macOS и нажмите «Запустить» снова."
            return
        }
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            // The source is attached exclusively to the main run loop.
            MainActor.assumeIsolated {
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(context).takeUnretainedValue()
                monitor.receive(type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap,
                                            options: .listenOnly, eventsOfInterest: mask,
                                            callback: callback,
                                            userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            status = "Не удалось создать монитор. Проверьте «Мониторинг ввода» и перезапустите приложение."
            return
        }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            status = "Не удалось подключить монитор к циклу событий."
            return
        }
        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        isRunning = true
        checkHealth()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkHealth() }
        }
    }

    func stop(clearHistory: Bool = false) {
        healthTimer?.invalidate()
        healthTimer = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        tap = nil
        source = nil
        isRunning = false
        status = "Монитор выключен"
        if clearHistory { entries.removeAll() }
    }

    func clear() { entries.removeAll() }

    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func checkHealth() {
        guard isRunning else { return }
        guard CGPreflightListenEventAccess() else {
            stop(clearHistory: true)
            status = "Монитор остановлен: разрешение отозвано."
            return
        }
        status = IsSecureEventInputEnabled()
            ? "Защищённый ввод: события пропускаются"
            : "Наблюдение: ⌘ / ⌃ и F1–F20 • последние 100 событий в памяти"
    }

    private func receive(_ type: CGEventType, event: CGEvent) {
        guard isRunning else { return }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            stop()
            status = "macOS отключила монитор. Нажмите «Запустить», чтобы возобновить."
            return
        }
        guard type == .keyDown, !IsSecureEventInputEnabled() else { return }
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        // Discard before constructing a record. Never read Unicode from an event.
        guard MonitorPolicy.allows(keyCode: code, flags: flags, isRepeat: isRepeat) else { return }
        let shortcut = ShortcutModifiers.event(flags).symbols + KeyboardLayout.label(for: code)
        let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Не определено"
        entries.insert(MonitorEntry(date: Date(), applicationName: name, keyCode: code, shortcut: shortcut), at: 0)
        if entries.count > 100 { entries.removeLast(entries.count - 100) }
    }
}

@MainActor
enum KeyboardLayout {
    // Translate a physical key through the current layout, not the text of an
    // input event or any field. The physical key code is always shown as well.
    static func label(for code: Int) -> String {
        if let special = KeyNames.special[code] { return special }
        guard let input = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(input, kTISPropertyUnicodeKeyLayoutData) else {
            return "Код \(code)"
        }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return "Код \(code)" }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKey: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 8)
        let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0,
                                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                    &deadKey, characters.count, &length, &characters)
        guard status == noErr, length > 0 else { return "Код \(code)" }
        return KeyNames.character(String(utf16CodeUnits: characters, count: length))
    }
}
