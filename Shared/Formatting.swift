import Foundation

extension TimeInterval {
    /// "7:42" style hours:minutes.
    var hoursMinutes: String {
        let total = Int((self / 60).rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

extension Double {
    var oneDecimal: String { String(format: "%.1f", self) }
    var percent: String { "\(Int(rounded()))" }
}

extension Date {
    var dayLabel: String { formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased() }
    var shortTime: String { formatted(date: .omitted, time: .shortened) }
}
