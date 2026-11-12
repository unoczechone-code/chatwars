# Битва за чат / Chat Wars

Оффлайн 2D-игра на Godot 4.7.2: фарфоровый робот очищает чат от спама.
Собирается в unsigned IPA на macOS CI и ставится через LiveContainer.

## Игра (MVP)

Один портретный забег на 180 секунд:

- **3 волны** по 60 секунд. Босс появляется на 120-й секунде.
- **Победа** — убить босса. **Поражение** — HP на нуле или истёк таймер.
- **Управление**: перетаскивание в нижней трети экрана. Автоатака бьёт ближайшую цель.
  Одна кнопка AoE с перезарядкой 6 секунд. Отдельная кнопка паузы.
- **Враги**: падающий, «ткач» (синусоида), «броневик» (медленный, прочный) + босс
  с двумя атаками.
- **6 улучшений** (урон, скорострельность, HP, скорость, радиус AoE, перезарядка):
  выбор 1 из 3 на 60-й и 120-й секунде, с ограничением по стекам.
- **Экраны**: Title, Game, UpgradePick, Result, Settings/Credits. Рестарт без перезапуска.
- **Сохранение**: рекорд, число побед, настройки, язык. Версионированный JSON,
  атомарная запись, восстановление после повреждённого файла.
- **Языки**: ru / en.

Все ассеты нарисованы кодом в этом проекте — сторонних материалов нет.

## Проверено

| Что | Как | Статус |
|---|---|---|
| Импорт проекта | `--headless --import` с нуля | чисто, 0 ошибок |
| Смоук-тест | `tests/smoke_test.gd` | все проверки |
| Геймплей | `tests/gameplay_test.gd` | 24/24 |
| Навигация по экранам | `tests/ui_flow_test.gd` | 19/19 |
| Полный забег 180 с | `tests/soak_test.gd` | лимиты держатся, утечек нет |
| PCK-подмена | `tests/test_swap_pck.py` | 18/18 |
| Установка на iPhone | iPhone 15 Pro, iOS 27.2, LiveContainer | работает |

## Не проверено

- Производительность (60 FPS) и потребление памяти на устройстве — не измерялись.
- Широкий playtest и баланс: стартовые числа в `game/scripts/balance.gd` не отлажены.
- Другие модели iPhone и версии iOS.

## Структура

```text
.github/workflows/ios.yml   CI: сборка unsigned IPA на macos-26
game/
  project.godot
  export_presets.cfg        iOS preset (project-only)
  scenes/                   title, game, upgrade_pick, result, settings
  scripts/                  game, run_state, balance, enemy, player, bullet,
                            hud, main, save_manager, экраны
  loc/strings.csv           ru/en (импортится в .translation)
  art/                      иконки приложения
tools/swap_pck.py           подмена PCK в IPA без перепаковки
tools/make_icons.py         генерация всех иконок iOS
tests/                      smoke, gameplay, ui_flow, soak, swap_pck
docs/                       TOOLCHAIN, BUILD, SIGNING, DEVICE_TESTS, QA, STATE
```

## Как повторить

```bash
GODOT=/c/Agent/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe

python -m unittest discover -s tests -p "test_*.py"
"$GODOT" --headless --path game --import
"$GODOT" --headless --path game --script ../tests/smoke_test.gd
"$GODOT" --headless --path game --script ../tests/gameplay_test.gd
"$GODOT" --headless --path game --script ../tests/ui_flow_test.gd
```

Пуш в `main` собирает `ChatWars-unsigned.ipa` на macOS.

## Установка

Артефакт **неподписан**. Импортируй его в LiveContainer / SideStore / AltStore —
они переподпишут своим сертификатом. Подробности в `docs/DEVICE_TESTS.md`.

## Лицензии

См. `CREDITS.md` и `licenses/`.
