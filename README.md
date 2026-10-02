<img src="HotkeyInspector/HotkeyInspector/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="96" alt="Hotkey Inspector">

# Hotkey Inspector

Помогает разобраться в сочетаниях клавиш на Mac: найти нужную команду в меню приложения и посмотреть, какие сочетания заданы в настройках macOS.

- Ищите команды по названию и копируйте их сочетания.
- Смотрите системные сочетания, включая свои переназначения.
- Включайте монитор, чтобы увидеть нажатые Command/Control-сочетания и F1–F20. Последние 100 событий остаются только в памяти.

Нужны **macOS 27+** и **Xcode 27+** для сборки. Доступ Accessibility нужен для меню, Input Monitoring — для монитора. Обычный текст и пароли не записываются. Список сочетаний может быть неполным; нажатие не подтверждает выполнение команды.

## Homebrew

Сборка текущей версии из исходников через собственный tap:

```sh
brew tap mitrazapine/hotkey-inspector https://github.com/mitrazapine/HotkeyInspector.git
brew install --cask mitrazapine/hotkey-inspector/hotkey-inspector
open /Applications/HotkeyInspector.app
```

Homebrew собирает приложение локально и устанавливает его в `/Applications`. Обновление: `brew upgrade --cask --greedy hotkey-inspector`.

## Разработка

Откройте `HotkeyInspector/HotkeyInspector.xcodeproj` в Xcode и нажмите ⌘R либо выполните:

```sh
bash script/build_and_run.sh
sh Tests/run.sh
```

