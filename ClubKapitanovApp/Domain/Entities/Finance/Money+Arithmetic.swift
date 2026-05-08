import Foundation

extension Money {
    nonisolated static func + (lhs: Money, rhs: Money) -> Money {
        Money(kopecks: lhs.kopecks + rhs.kopecks)
    }

    nonisolated static func += (lhs: inout Money, rhs: Money) {
        lhs = lhs + rhs
    }

    nonisolated static func sum<S: Sequence>(_ values: S) -> Money where S.Element == Money {
        values.reduce(.zero, +)
    }

    nonisolated func multiplied(by quantity: Int) -> Money {
        Money(kopecks: kopecks * quantity)
    }
}
