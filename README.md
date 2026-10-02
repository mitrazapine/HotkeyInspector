<img src="HotkeyInspector/HotkeyInspector/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="96" alt="Hotkey Inspector">

# Hotkey Inspector

Сочетания клавиш приложений и системные назначения macOS в одном окне.

- Чтение меню приложений, поиск и копирование сочетаний.
- Системные назначения из сохранённых настроек macOS.
- Пассивный монитор Command/Control-сочетаний и F1–F20; до 100 событий в памяти.

Нужны **macOS 27+** и **Xcode 27+** для сборки. Доступ Accessibility нужен для меню, Input Monitoring — для монитора. Обычный текст и пароли не записываются. Список сочетаний может быть неполным; нажатие не подтверждает выполнение команды.

## Homebrew

Сборка текущей версии из исходников через собственный tap:

```sh
brew tap mitrazapine/hotkey-inspector https://github.com/mitrazapine/HotkeyInspector.git
brew install --HEAD mitrazapine/hotkey-inspector/hotkey-inspector
hotkey-inspector
```

Установка требует полного Xcode, одних Command Line Tools недостаточно. Приложение хранится в каталоге Homebrew; команда `hotkey-inspector` открывает его. Обновление: `brew upgrade --fetch-HEAD hotkey-inspector`.

## Разработка

Откройте `HotkeyInspector/HotkeyInspector.xcodeproj` в Xcode и нажмите ⌘R либо выполните:

```sh
./script/build_and_run.sh
sh Tests/run.sh
```

В Git хранятся исходники, проект Xcode, ресурсы, тесты и сценарии сборки. Готовые приложения и промежуточные файлы исключены через `.gitignore`.
