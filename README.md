# ClubKapitanovApp

Внутреннее iPad-приложение для работы точки проката «Клуб Капитанов».

## Что делает приложение

- вход сотрудника по PIN;
- выбор рабочей точки;
- открытие смены на iPad;
- добавление сотрудников в смену;
- оформление проката, штрафов и продаж сувенирки;
- просмотр временного отчета;
- закрытие смены с сохранением итогового snapshot-отчета.

## Архитектура

Проект написан на UIKit без storyboard. Код разделен на слои:

- `App` — запуск приложения, `SceneDelegate`, DI-контейнер;
- `Core` — дизайн-система, форматтеры, UIKit helpers;
- `Domain` — сущности, repository protocols и use cases;
- `Data` — in-memory repositories и стартовые fixtures;
- `Features` — пользовательские сценарии в VIP-структуре.

Данные сейчас хранятся in-memory. Repository protocols уже отделены от реализаций, чтобы позже заменить storage без переписывания UI.

## Основной flow

```text
PIN login -> point selection -> open shift -> workspace -> close shift -> login
```

## Сборка

Откройте `ClubKapitanovApp.xcodeproj` в Xcode, выберите схему `ClubKapitanovApp` и iPad simulator/device.

Минимальная версия iOS: 16.0.
