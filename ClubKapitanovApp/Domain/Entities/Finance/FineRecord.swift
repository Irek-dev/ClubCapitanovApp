import Foundation

/// Факт начисленного штрафа внутри смены.
///
/// Это операционная запись, а не элемент каталога. Она сохраняет сумму, название,
/// время создания, автора и способ оплаты, чтобы закрытие смены могло собрать
/// исторический отчет без обращения к актуальному каталогу штрафов.
struct FineRecord: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор записи о штрафе в смене.
    let id: UUID
    /// Идентификатор шаблона штрафа, если он был выбран из каталога.
    let templateID: UUID?
    /// Название штрафа в том виде, в котором оно должно остаться в истории.
    let title: String
    /// Сумма штрафа для учета в смене.
    let amount: Money
    /// Время, когда штраф был зафиксирован в системе.
    let createdAt: Date
    /// Сотрудник, который создал запись о штрафе.
    let createdByEmployeeID: UUID
    /// Способ оплаты штрафа.
    let paymentMethod: PaymentMethod
    /// Дополнительная заметка по штрафу.
    let notes: String?

    init(
        id: UUID = UUID(),
        templateID: UUID? = nil,
        title: String,
        amount: Money,
        createdAt: Date,
        createdByEmployeeID: UUID,
        paymentMethod: PaymentMethod = .card,
        notes: String? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.title = title
        self.amount = amount
        self.createdAt = createdAt
        self.createdByEmployeeID = createdByEmployeeID
        self.paymentMethod = paymentMethod
        self.notes = notes
    }
}
