import AppKit
import ApplicationServices
import Combine

@MainActor
final class InspectorModel: ObservableObject {
    @Published var applications: [ApplicationInfo] = []
    @Published var activeApplicationName = "Не определено"
    @Published var selectedPID: Int32? {
        didSet {
            guard selectedPID != oldValue else { return }
            clearScan()
            if hasAccessibility { scan() }
        }
    }
    @Published var hasAccessibility = false
    @Published var isScanning = false
    @Published var result: MenuScanResult?
    @Published var errorMessage: String?
    @Published var search = ""
    @Published var enabledOnly = false
    @Published var conflictsOnly = false

    private var lastExternalPID: Int32?
    private var observers: [NSObjectProtocol] = []
    private var scanTask: Task<MenuScanResult, Error>?
    private var scanGeneration = UUID()
    private var permissionTimer: Timer?

    var applicationPath: String { Bundle.main.bundleURL.path }

    var selectedApplication: ApplicationInfo? { applications.first { $0.id == selectedPID } }
    var conflictIDs: Set<String> { Hotkey.conflictingIDs(in: result?.hotkeys ?? []) }
    var visibleHotkeys: [Hotkey] {
        let conflicts = conflictIDs
        return (result?.hotkeys ?? []).filter { item in
            (!enabledOnly || item.isEnabled == true) &&
            (!conflictsOnly || conflicts.contains(item.id)) &&
            (search.isEmpty || [item.action, item.path, item.combination.display, item.application.name]
                .contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }

    func start() {
        guard observers.isEmpty else { return }
        refreshApplications()
        updateActiveApplication()
        selectedPID = lastExternalPID ?? applications.first?.id
        refreshPermission()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshApplications()
                    self?.updateActiveApplication()
                    self?.refreshPermission()
                }
            })
        }
        // TCC changes do not have a public notification. Checking trust is
        // inexpensive and must not repeatedly prompt the user.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermission() }
        }
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
        clearScan()
    }

    func refreshApplications() {
        applications = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .map { ApplicationInfo(id: $0.processIdentifier, name: $0.localizedName ?? "Без имени",
                                   bundleIdentifier: $0.bundleIdentifier) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if let selectedPID, !applications.contains(where: { $0.id == selectedPID }) {
            self.selectedPID = nil
            errorMessage = "Выбранное приложение завершилось. Выберите другое."
        }
    }

    private func updateActiveApplication() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        activeApplicationName = app.localizedName ?? "Без имени"
        if app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            lastExternalPID = app.processIdentifier
        }
    }

    func selectLastActive() {
        refreshApplications()
        updateActiveApplication()
        if let lastExternalPID, applications.contains(where: { $0.id == lastExternalPID }) {
            selectedPID = lastExternalPID
        }
    }

    func refreshPermission() {
        let trusted = AXIsProcessTrusted()
        guard trusted != hasAccessibility else { return }
        hasAccessibility = trusted
        if trusted { scan() } else { clearScan() }
    }

    func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        refreshPermission()
    }

    func revealApplication() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func clearScan() {
        scanGeneration = UUID()
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        result = nil
        errorMessage = nil
    }

    func scan() {
        guard AXIsProcessTrusted() else {
            hasAccessibility = false
            clearScan()
            return
        }
        guard let application = selectedApplication else { return }
        clearScan()
        let generation = scanGeneration
        isScanning = true
        let task = Task.detached(priority: .userInitiated) {
            try MenuReader.scan(application)
        }
        scanTask = task
        Task { [weak self] in
            do {
                let newResult = try await task.value
                guard let self, self.scanGeneration == generation else { return }
                self.result = newResult
                self.isScanning = false
                self.scanTask = nil
            } catch {
                guard let self, self.scanGeneration == generation else { return }
                self.errorMessage = error.localizedDescription
                self.isScanning = false
                self.scanTask = nil
            }
        }
    }
}
