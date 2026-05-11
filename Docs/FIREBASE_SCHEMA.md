# Firebase schema draft

Цель схемы - фиксировать Firestore-структуру приложения. Auth/users уже работают через Firebase, остальной app flow может оставаться in-memory до отдельного подключения. Все идентификаторы хранятся как строки UUID. Все денежные значения хранятся в копейках как `Int`. Даты предполагаются как Firestore `Timestamp` через будущий Codable/Firestore encoder.

## users

Пользователи приложения.

- `id`
- `firstName`
- `lastName`
- `role`
- `accountStatus`
- `createdAt`
- `updatedAt`

## pinCodes

Индекс PIN-кодов для входа. В будущем лучше хранить не открытый PIN, а hash/secure token.

- `pinCode`
- `userID`
- `firstNameSnapshot`
- `lastNameSnapshot`
- `roleSnapshot`
- `accountStatusSnapshot`
- `updatedAt`

## points

Рабочие точки.

- `id`
- `name`
- `city`
- `address`
- `status`
- `createdAt`
- `updatedAt`

## points/{pointId}/rentalTypes

Каталог типов проката на точке.

- `id`
- `name`
- `shortCode`
- `priceKopecks`
- `durationMinutes`
- `payrollKopecks`
- `stockQuantity`
- `sortOrder`
- `createdAt`
- `updatedAt`

## points/{pointId}/souvenirs

Каталог сувениров и текущий учетный остаток.

- `id`
- `name`
- `priceKopecks`
- `stockQuantity`
- `sortOrder`
- `createdAt`
- `updatedAt`

## points/{pointId}/fineTemplates

Каталог шаблонов штрафов.

- `id`
- `name`
- `amountKopecks`
- `sortOrder`
- `createdAt`
- `updatedAt`

## points/{pointId}/batteryTypes

Типы батареек и текущий остаток.

- `id`
- `name`
- `stockQuantity`
- `sortOrder`
- `createdAt`
- `updatedAt`

## points/{pointId}/equipmentCounters

Учетные счетчики оборудования по типам.

- `id`
- `pointID`
- `rentalTypeID`
- `name`
- `code`
- `totalCount`
- `workingCount`
- `discardedCount`
- `isActive`
- `updatedAt`

## shiftReports

Главный документ закрытого отчета смены. Детальные операции лежат в подколлекциях.

- `id`
- `reportNumber`
- `shiftID`
- `pointID`
- `pointNameSnapshot`
- `shiftDate`
- `createdAt`
- `createdByUserID`
- `userNameSnapshot`
- `weatherNote`
- `totalRevenueKopecks`
- `rentalRevenueKopecks`
- `souvenirRevenueKopecks`
- `finesRevenueKopecks`
- `payrollTotalKopecks`
- `paymentRevenue`
- `rentalTripsCount`
- `souvenirItemsCount`
- `finesCount`
- `equipmentNotes`
- `batteryNotes`
- `notes`
- `textReport`
- `inventoryAppliedAt`

## shiftReports/{reportId}/rentalOrders

Исторические заказы проката.

- `id`
- `rentalTypeID`
- `rentalTypeNameSnapshot`
- `rentedAssetIDs`
- `rentedAssetNumbersSnapshot`
- `rentedItemsSnapshot`
- `createdAt`
- `startedAt`
- `expectedEndAt`
- `finishedAt`
- `canceledAt`
- `durationMinutes`
- `quantity`
- `rentalPeriodsCount`
- `billableTripsCount`
- `priceSnapshot`
- `payrollSnapshot`
- `paymentMethod`
- `status`
- `notes`

## shiftReports/{reportId}/rentalSummary

Сводка проката.

- `totalTripsCount`
- `revenueKopecks`
- `tripsByType`
- `tariffBreakdown`
- `payments`
- `chipRevenueKopecks`

## shiftReports/{reportId}/souvenirSales

Исторические продажи сувениров.

- `id`
- `productID`
- `souvenirNameSnapshot`
- `quantity`
- `priceSnapshot`
- `totalPriceKopecks`
- `soldAt`
- `soldByEmployeeID`
- `userNameSnapshot`
- `paymentMethod`
- `notes`

## shiftReports/{reportId}/souvenirSummary

Сводка сувенирки.

- `totalRevenueKopecks`
- `rows`

## shiftReports/{reportId}/fines

Исторические начисления штрафов.

- `id`
- `templateID`
- `fineNameSnapshot`
- `priceSnapshot`
- `createdAt`
- `createdByEmployeeID`
- `userNameSnapshot`
- `paymentMethod`
- `notes`

## shiftReports/{reportId}/fineSummary

Сводка штрафов.

- `totalCount`
- `totalAmountKopecks`
- `rows`

## shiftReports/{reportId}/payroll

Snapshot зарплатной сводки.

- `ratePerTripKopecks`
- `totalTripsCount`
- `totalFundKopecks`
- `totalAmountKopecks`
- `payrollSnapshot`

## shiftReports/{reportId}/equipmentSnapshot

Ручной snapshot оборудования при закрытии смены.

- `workingRows`
- `discardedRows`
- `notes`

## shiftReports/{reportId}/batterySnapshot

Ручной snapshot батареек при закрытии смены.

- `workingTotal`
- `workingRows`
- `discardedRows`
- `notes`
