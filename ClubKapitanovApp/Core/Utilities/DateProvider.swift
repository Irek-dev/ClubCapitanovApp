import Foundation

/// Источник текущего времени для слоев, где дата влияет на бизнес-результат или отчет.
///
/// Через протокол время можно подменить в тестах и не прятать `Date()` внутри
/// Interactor или presentation-фабрик.
protocol DateProviding {
    var now: Date { get }
}

struct SystemDateProvider: DateProviding {
    var now: Date {
        Date()
    }
}
