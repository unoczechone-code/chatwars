# Битва за чат / Chat Wars

Минимальный оффлайн 2D-проект на Godot 4.7.2, собираемый в unsigned IPA на macOS CI.
Заготовка этапа A (технический spike): доказать «проект собирается → ставится → работает»
до написания игры.

## Что уже работает (проверено локально, Windows)

- Импорт проекта headless: без ошибок.
- Смоук-тест `tests/smoke_test.gd`: 17/17 проверок (счётчик, сохранение в `user://save.json`,
  восстановление после перезапуска, восстановление после повреждённого файла, локали ru/en,
  минимальный размер кнопки 44 px).
- Экспорт PCK: `--export-pack "iOS"` → exit 0.
- `tools/swap_pck.py`: 18 юнит-тестов, все проходят.

## Что НЕ проверено

- Полная iOS-сборка (на Windows нет export templates — собирается на CI).
- Установка и запуск на реальном iPhone — **не выполнялось**.
- Совместимость рендерера Compatibility на физическом устройстве.

## Структура

```text
.github/workflows/ios.yml   CI: сборка unsigned IPA на macos-26
game/                       проект Godot
  project.godot
  export_presets.cfg        iOS preset (project-only)
  scenes/main.tscn
  scripts/{main,save_manager}.gd
  loc/strings.csv           ru/en (импортится в .translation)
  art/icon.svg
tools/swap_pck.py           подмена PCK в IPA без перепаковки
tests/                      smoke_test.gd, test_swap_pck.py
docs/                       TOOLCHAIN, BUILD, SIGNING, DEVICE_TESTS, QA
```

## Как повторить сборку

См. `docs/BUILD.md`. Кратко:

```bash
python -m unittest discover -s tests -p "test_*.py"
"$GODOT" --headless --path game --import
"$GODOT" --headless --path game --script ../tests/smoke_test.gd
```

Пуш в `main` (или ручной запуск workflow) собирает `ChatWars-unsigned.ipa` на macOS.

## Установка

Артефакт **неподписан**. Его нужно импортировать в LiveContainer / SideStore / AltStore,
которые переподпишут его своим сертификатом. Инструкция — `docs/DEVICE_TESTS.md`.

## Лицензии

Собственные ассеты. См. `CREDITS.md` и `licenses/`.
