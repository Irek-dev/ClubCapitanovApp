import Foundation

/// Режим технического подключения пользователя к смене.
///
/// Сейчас есть только рабочий iPad-режим: пользователь управляет сменой с общего
/// устройства точки.
enum ShiftConnectionMode: String, Codable, Sendable, CaseIterable {
    case ipadOperator
}
