import Foundation

/// Health Monitor: overnight vitals compared to your own normal range.
enum HealthMonitor {
    struct Metric: Identifiable {
        var id: String { name }
        var name: String
        var symbol: String
        var value: String
        var range: String
        var inRange: Bool? // nil = still learning a personal range
    }

    enum Status: String {
        case noData = "NO DATA", learning = "LEARNING", withinRange = "WITHIN RANGE", outOfRange = "OUT OF RANGE"
    }

    static func status(for metrics: [Metric]) -> Status {
        guard !metrics.isEmpty else { return .noData }
        if metrics.contains(where: { $0.inRange == false }) { return .outOfRange }
        if metrics.contains(where: { $0.inRange == nil }) { return .learning }
        return .withinRange
    }

    static func metrics(for d: DayScores) -> [Metric] {
        var out: [Metric] = []
        func add(_ name: String, _ symbol: String, _ value: Double?, _ base: Baseline?, _ format: (Double) -> String) {
            guard let value else { return }
            if let base, base.samples >= 7 {
                let lo = base.mean - 2 * base.sd, hi = base.mean + 2 * base.sd
                out.append(Metric(name: name, symbol: symbol, value: format(value), range: "\(format(lo))–\(format(hi))", inRange: (lo...hi).contains(value)))
            } else {
                out.append(Metric(name: name, symbol: symbol, value: format(value), range: "learning", inRange: nil))
            }
        }
        if let hrv = d.raw.hrv, let b = d.hrvBaseline {
            let lo = exp(b.mean - 2 * b.sd), hi = exp(b.mean + 2 * b.sd)
            out.append(Metric(name: "Heart Rate Variability", symbol: "waveform.path.ecg", value: "\(Int(hrv)) ms", range: b.samples >= 7 ? "\(Int(lo))–\(Int(hi))" : "learning", inRange: b.samples >= 7 ? (lo...hi).contains(hrv) : nil))
        }
        add("Resting Heart Rate", "heart", d.raw.restingHR, d.rhrBaseline) { "\(Int($0.rounded()))" }
        add("Respiratory Rate", "lungs", d.raw.respiratoryRate, d.respBaseline) { $0.oneDecimal }
        if let spo2 = d.raw.spo2 {
            out.append(Metric(name: "Blood Oxygen", symbol: "drop", value: "\(Int(spo2 * 100))%", range: "95–100%", inRange: (0.95...1).contains(spo2)))
        }
        if let temp = d.raw.wristTemperature {
            if let b = d.tempBaseline, b.samples >= 7 {
                let delta = temp - b.mean
                out.append(Metric(name: "Skin Temperature", symbol: "thermometer.medium", value: String(format: "%+.1f°", delta), range: "±0.5°", inRange: abs(delta) <= 0.5))
            } else {
                out.append(Metric(name: "Skin Temperature", symbol: "thermometer.medium", value: String(format: "%.1f°", temp), range: "learning", inRange: nil))
            }
        }
        return out
    }
}
