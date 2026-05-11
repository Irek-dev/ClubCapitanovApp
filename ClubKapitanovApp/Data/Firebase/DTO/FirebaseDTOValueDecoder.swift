import FirebaseFirestore
import Foundation

nonisolated enum FirebaseDTOValueDecoder {
    static func string(_ value: Any?, field: String) throws -> String {
        guard let string = value as? String, !string.isEmpty else {
            throw FirebaseDTOValueDecoderError.invalidField(field: field, value: value)
        }

        return string
    }

    static func int(_ value: Any?, field: String) throws -> Int {
        if let int = value as? Int {
            return int
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        throw FirebaseDTOValueDecoderError.invalidField(field: field, value: value)
    }

    static func optionalDate(_ value: Any?, field: String) throws -> Date? {
        guard let value else {
            return nil
        }

        if let date = value as? Date {
            return date
        }

        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }

        throw FirebaseDTOValueDecoderError.invalidField(field: field, value: value)
    }
}

nonisolated enum FirebaseDTOValueDecoderError: LocalizedError {
    case invalidField(field: String, value: Any?)

    var errorDescription: String? {
        switch self {
        case let .invalidField(field, value):
            return "Invalid Firebase field '\(field)': \(String(describing: value))"
        }
    }
}
