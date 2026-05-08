import Foundation

enum AppDateFormatter {
    static func dateTime(_ date: Date) -> String {
        string(from: date, format: "dd.MM.yyyy HH:mm")
    }

    static func time(_ date: Date) -> String {
        string(from: date, format: "HH:mm")
    }

    private static func string(from date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
