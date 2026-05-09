import Foundation

enum AppDateFormatter {
    static func dateTime(_ date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }

    static func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static let dateTimeFormatter = makeFormatter(format: "dd.MM.yyyy HH:mm")
    private static let dateFormatter = makeFormatter(format: "dd.MM.yyyy")
    private static let timeFormatter = makeFormatter(format: "HH:mm")

    private static func makeFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = format
        return formatter
    }
}
