import Foundation

/// Состояние смены.
///
/// В домене оставлены только реальные бизнес-состояния. Черновик не используется,
/// потому что MVP открывает смену сразу и закрывает ее итоговым действием.
enum ShiftStatus: String, Codable, Sendable, CaseIterable {
    case open
    case closed
}
