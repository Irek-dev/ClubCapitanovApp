# ClubKapitanovApp

iPad-приложение для работы точки проката «Клуб Капитанов»: вход сотрудника,
выбор точки, открытие смены, операции проката/сувенирки/штрафов/батареек и
закрытие смены с сохранением отчета в Firebase.

## Архитектура

Проект написан на Swift + UIKit без storyboard. Модули собраны в VIP-стиле:

- `App` - запуск, `SceneDelegate`, DI-контейнер;
- `Core` - дизайн-система, форматтеры, UIKit helpers, сервисы;
- `Domain` - сущности, repository protocols, use cases;
- `Data/Firebase` - DTO, mappers и Firestore repositories;
- `Data/Repositories` и `Data/InMemory` - локальные in-memory реализации для состояния смены и разработки;
- `Features` - экраны login, выбор точки, открытие смены, workspace и админ-панель.

## Firebase

Firebase уже подключен через `FirebaseApp.configure()` в `AppDelegate`.
Основные коллекции:

- `users` - учетные записи сотрудников и администраторов;
- `pinCodes` - индекс PIN-кодов для входа;
- `points` - рабочие точки и их каталоги;
- `points/{pointId}/rentalTypes`, `souvenirs`, `fineTemplates`, `batteryTypes` - каталоги точки;
- `shiftReports` - закрытые отчеты смен с подколлекциями операций и сводок.

Полная структура описана в [Docs/FIREBASE_SCHEMA.md](Docs/FIREBASE_SCHEMA.md).
Запись отчетов описана в [Docs/FIREBASE_REPORT_WRITES.md](Docs/FIREBASE_REPORT_WRITES.md).

## Основной flow

```text
PIN login -> point selection -> open shift -> workspace -> close shift -> login
```

При открытии смены приложение загружает каталоги выбранной точки из Firebase и
держит текущую смену локально. При закрытии смены `FirestoreShiftReportRepository`
пишет snapshot-отчет в `shiftReports` и применяет изменения остатков сувенирки и
батареек в Firestore. Если отчет не сохранен, смена остается открытой.

## Админ-панель

Администратор входит через PIN и пароль администратора, выбирает точку и управляет:

- сотрудниками (`users` / `pinCodes`);
- сувениркой;
- штрафами;
- типами проката;
- батарейками.

Пустые списки показываются как empty state. Ошибки загрузки Firebase показываются
отдельно с возможностью повторить загрузку.

## Что осталось in-memory

In-memory слой остается для локального состояния активной смены, временного отчета,
dev/test fallback и безопасной разработки без полной миграции runtime-state в
Firebase. Основной Firebase-backed flow уже использует Firestore для пользователей,
точек, каталогов и закрытых отчетов.

## Запуск

1. Откройте `ClubKapitanovApp.xcodeproj` в Xcode.
2. Проверьте, что `GoogleService-Info.plist` добавлен в target приложения.
3. Выберите схему `ClubKapitanovApp` и iPad simulator/device.
4. Соберите и запустите проект.

Минимальная версия iOS: 16.0.

## Firebase prerequisites

Для работы нужен Firebase-проект с iOS app bundle id проекта, включенный Firestore
Database и правила доступа, разрешающие нужные операции чтения/записи для текущего
режима разработки. Файл должен называться строго `GoogleService-Info.plist`.
