import SwiftUI
import Charts

// MARK: - Recovery

struct RecoveryDetailView: View {
    @Environment(MetricsStore.self) private var store

    var body: some View {
        DetailScaffold(title: store.isToday ? "Today" : store.selected?.date.dayLabel ?? "", accent: Theme.recoveryColor(store.selected?.recovery)) {
            if let d = store.selected {
                HeroRing(progress: (d.recovery ?? 0) / 100, colors: Theme.recoveryGradient(d.recovery),
                         value: d.recovery.map(\.percent) ?? "–", unit: d.recovery == nil ? nil : "%", caption: "Recovery")
                GlassCard {
                    VStack(spacing: 0) {
                        if let hrv = d.raw.hrv, let base = Insights.hrvBaselineValue(d) {
                            ContributorRow(symbol: "waveform.path.ecg", title: "Heart Rate Variability", value: "\(Int(hrv))",
                                           arrowUp: hrv >= base, trend: hrv >= base ? .better : .worse)
                            Divider().opacity(0.4)
                        }
                        if let rhr = d.raw.restingHR, let b = d.rhrBaseline {
                            ContributorRow(symbol: "heart", title: "Resting Heart Rate", value: "\(Int(rhr.rounded()))",
                                           arrowUp: rhr >= b.mean, trend: rhr <= b.mean ? .better : .worse)
                            Divider().opacity(0.4)
                        }
                        if let resp = d.raw.respiratoryRate, let b = d.respBaseline {
                            ContributorRow(symbol: "lungs", title: "Respiratory Rate", value: resp.oneDecimal,
                                           arrowUp: resp >= b.mean, trend: abs(b.z(resp)) < 1 ? .neutral : .worse)
                            Divider().opacity(0.4)
                        }
                        ContributorRow(symbol: "moon.zzz", title: "Sleep Performance", value: d.sleepPerformance.map { "\($0.percent)%" } ?? "–")
                        Text("▲▼ Today vs. prior 30 days")
                            .font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(.black.opacity(0.25), in: .rect(cornerRadius: 10))
                            .padding(.top, 6)
                    }
                }
                InsightCallout(text: recoveryExplanation(d))
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Recovery · 14 days")
                        Chart(store.window(14)) { day in
                            if let r = day.recovery {
                                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Recovery", r))
                                    .foregroundStyle(Theme.recoveryColor(r).gradient)
                                    .cornerRadius(5)
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                        .frame(height: 160)
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "HRV · 30 days")
                        TrendLine(points: store.window(30).compactMap { d in d.raw.hrv.map { TrendPoint(date: d.date, value: $0) } },
                                  baseline: Insights.hrvBaselineValue(d), color: Theme.green, unit: "ms")
                            .frame(height: 160)
                    }
                }
            }
        }
    }

    private func recoveryExplanation(_ d: DayScores) -> String {
        guard d.recovery != nil else { return "Recovery needs heart rate variability measured while you sleep. Wear your watch to bed tonight." }
        var parts: [String] = []
        if let change = Insights.hrvChange(d) {
            parts.append(abs(change) < 0.05 ? "Your HRV is typical" : change > 0 ? "Your HRV is elevated" : "Your HRV is suppressed")
        }
        if let rhr = d.raw.restingHR, let b = d.rhrBaseline {
            parts.append(abs(b.z(rhr)) < 1 ? "your RHR is typical" : rhr < b.mean ? "your RHR is lower than usual" : "your RHR is elevated")
        }
        if let p = d.sleepPerformance { parts.append(p >= 85 ? "sleep was optimal" : p >= 70 ? "sleep was sufficient" : "sleep fell short") }
        return parts.joined(separator: ", ").prefix(1).uppercased() + parts.joined(separator: ", ").dropFirst() + "."
    }
}

// MARK: - Sleep

struct SleepDetailView: View {
    @Environment(MetricsStore.self) private var store

    var body: some View {
        DetailScaffold(title: store.isToday ? "Today" : store.selected?.date.dayLabel ?? "", accent: Theme.sleep[1]) {
            if let d = store.selected {
                HeroRing(progress: (d.sleepPerformance ?? 0) / 100, colors: Theme.sleep,
                         value: d.sleepPerformance.map(\.percent) ?? "–", unit: d.sleepPerformance == nil ? nil : "%", caption: "Sleep Performance")
                GlassCard {
                    VStack(spacing: 0) {
                        row("clock", "Hours vs. Needed", d.hoursVsNeeded)
                        Divider().opacity(0.4)
                        row("calendar", "Sleep Consistency", d.sleepConsistency)
                        Divider().opacity(0.4)
                        row("bed.double", "Sleep Efficiency", d.sleepEfficiency)
                        Divider().opacity(0.4)
                        row("sparkles", "Restorative Sleep", d.raw.sleep?.restorativeShare.map { min(1, $0 / 0.45) }, display: d.raw.sleep?.restorativeShare)
                        HStack(spacing: 14) {
                            legend(Theme.hurts, "Poor"); legend(.white.opacity(0.7), "Sufficient"); legend(Theme.helps, "Optimal")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.black.opacity(0.25), in: .rect(cornerRadius: 10))
                        .padding(.top, 6)
                    }
                }
                InsightCallout(text: Insights.sleepSummary(d))
                if let sleep = d.raw.sleep {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Eyebrow(text: "Sleep Stages")
                                Spacer()
                                Text("\(sleep.start.shortTime) – \(sleep.end.shortTime)").font(.caption).foregroundStyle(.secondary)
                            }
                            Hypnogram(sleep: sleep).frame(height: 170)
                            HStack {
                                ForEach([SleepStage.awake, .rem, .core, .deep], id: \.self) { stage in
                                    VStack(spacing: 2) {
                                        Text((stage == .core ? sleep.duration(of: .core) + sleep.duration(of: .asleep) : sleep.duration(of: stage)).hoursMinutes)
                                            .font(.system(.callout, design: .rounded).weight(.semibold))
                                        Text(stage.title.uppercased()).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(stageColor(stage))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Hours slept vs. needed · 14 days")
                        Chart(store.window(14)) { day in
                            if let asleep = day.raw.sleep?.asleep {
                                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Hours", asleep / 3600))
                                    .foregroundStyle(LinearGradient(colors: Theme.sleep, startPoint: .bottom, endPoint: .top))
                                    .cornerRadius(5)
                            }
                            LineMark(x: .value("Day", day.date, unit: .day), y: .value("Need", day.sleepNeed / 3600))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        }
                        .chartXAxis { AxisMarks(values: .stride(by: .day, count: 2)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                        .frame(height: 160)
                    }
                }
            }
        }
    }

    private func row(_ symbol: String, _ title: String, _ value: Double?, display: Double? = nil) -> some View {
        let shown = display ?? value
        return ContributorRow(symbol: symbol, title: title, value: shown.map { "\(Int(($0 * 100).rounded()))%" } ?? "–", bar: value)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) { Capsule().fill(color).frame(width: 14, height: 4); Text(text).foregroundStyle(.secondary) }
    }
}

func stageColor(_ stage: SleepStage) -> Color {
    switch stage {
    case .awake: Color(hex: 0xFFB37A)
    case .rem: Color(hex: 0x5AD8FF)
    case .core, .asleep: Color(hex: 0x6E8BFF)
    case .deep: Color(hex: 0x8B5CFF)
    }
}

struct Hypnogram: View {
    var sleep: SleepSession
    var body: some View {
        Chart(sleep.segments) { seg in
            RectangleMark(xStart: .value("Start", seg.start), xEnd: .value("End", seg.end),
                          y: .value("Stage", seg.stage == .asleep ? SleepStage.core.title : seg.stage.title), height: .ratio(0.7))
                .foregroundStyle(stageColor(seg.stage).gradient)
                .cornerRadius(3)
        }
        .chartYScale(domain: [SleepStage.awake.title, SleepStage.rem.title, SleepStage.core.title, SleepStage.deep.title])
        .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 2)) { _ in AxisGridLine().foregroundStyle(.white.opacity(0.08)); AxisValueLabel(format: .dateTime.hour()) } }
    }
}

// MARK: - Strain

struct StrainDetailView: View {
    @Environment(MetricsStore.self) private var store

    var body: some View {
        DetailScaffold(title: store.isToday ? "Today" : store.selected?.date.dayLabel ?? "", accent: Theme.strain[1]) {
            if let d = store.selected {
                let target = ScoreEngine.strainTarget(recovery: d.recovery)
                HeroRing(progress: d.strain / 21, colors: Theme.strain, value: d.strain.oneDecimal, unit: nil, caption: "Day Strain",
                         marker: target.lowerBound / 21)
                Text("Target \(Int(target.lowerBound))–\(Int(target.upperBound)) based on your recovery")
                    .font(.caption).foregroundStyle(.secondary)
                GlassCard {
                    VStack(spacing: 0) {
                        ContributorRow(symbol: "heart", title: "Heart Rate Zones 1–3", value: (d.zoneMinutes[1...3].reduce(0, +) * 60).hoursMinutes)
                        Divider().opacity(0.4)
                        ContributorRow(symbol: "heart.fill", title: "Heart Rate Zones 4–5", value: (d.zoneMinutes[4...5].reduce(0, +) * 60).hoursMinutes)
                        Divider().opacity(0.4)
                        ContributorRow(symbol: "dumbbell", title: "Strength Activity Time", value: (d.strengthMinutes * 60).hoursMinutes)
                        Divider().opacity(0.4)
                        ContributorRow(symbol: "shoeprints.fill", title: "Steps", value: d.raw.steps.formatted(.number.precision(.fractionLength(0))))
                        Divider().opacity(0.4)
                        ContributorRow(symbol: "flame", title: "Active Calories", value: d.raw.activeEnergy.formatted(.number.precision(.fractionLength(0))))
                    }
                }
                InsightCallout(text: Insights.strainSummary(d))
                if !d.raw.heartRate.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Eyebrow(text: "Heart Rate")
                            HeartRateChart(points: d.raw.heartRate, workouts: d.raw.workouts, maxHR: store.profile.maxHeartRate)
                                .frame(height: 180)
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "Time in zones")
                            ForEach((1...5).reversed(), id: \.self) { z in
                                ZoneBar(zone: z, minutes: d.zoneMinutes[z], total: max(d.zoneMinutes[1...5].reduce(0, +), 1))
                            }
                        }
                    }
                }
                if !d.raw.workouts.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "Activities")
                            ForEach(d.raw.workouts) { w in
                                ActivityRow(symbol: w.symbol, tint: Theme.strain[0], badge: (d.workoutStrain[w.id] ?? 0).oneDecimal,
                                            title: w.name, detail: "\(w.start.shortTime) · \(Int(w.duration / 60)) min")
                            }
                        }
                    }
                }
            }
        }
    }
}

let zoneColors: [Color] = [.gray, Color(hex: 0x8FA3B8), Color(hex: 0x2FD4FF), Color(hex: 0x2EF2A0), Color(hex: 0xFFB340), Color(hex: 0xFF5A6E)]

struct ZoneBar: View {
    var zone: Int
    var minutes: Double
    var total: Double
    var body: some View {
        HStack(spacing: 10) {
            Text("Z\(zone)").font(.caption.weight(.bold)).frame(width: 24, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.06))
                    Capsule().fill(zoneColors[zone].gradient).frame(width: max(4, geo.size.width * minutes / total))
                }
            }
            .frame(height: 10)
            Text((minutes * 60).hoursMinutes).font(.caption.monospacedDigit()).frame(width: 44, alignment: .trailing)
        }
    }
}

struct HeartRateChart: View {
    var points: [HeartRatePoint]
    var workouts: [WorkoutSummary]
    var maxHR: Double

    var body: some View {
        Chart {
            ForEach(workouts) { w in
                RectangleMark(xStart: .value("Start", w.start), xEnd: .value("End", w.end))
                    .foregroundStyle(Theme.strain[0].opacity(0.12))
            }
            ForEach(points, id: \.date) { p in
                LineMark(x: .value("Time", p.date), y: .value("BPM", p.bpm))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 1.6))
                    .foregroundStyle(LinearGradient(colors: [zoneColors[2], zoneColors[3], zoneColors[4], zoneColors[5]], startPoint: .bottom, endPoint: .top))
            }
        }
        .chartYScale(domain: 40...maxHR)
        .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 4)) { _ in AxisGridLine().foregroundStyle(.white.opacity(0.08)); AxisValueLabel(format: .dateTime.hour()) } }
    }
}

/// Simple line with an optional dashed baseline.
struct TrendPoint: Identifiable {
    var id: Date { date }
    var date: Date
    var value: Double
}

struct TrendLine: View {
    var points: [TrendPoint]
    var baseline: Double?
    var color: Color
    var unit: String

    var body: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(x: .value("Day", p.date, unit: .day), y: .value(unit, p.value))
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Day", p.date, unit: .day), y: .value(unit, p.value))
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.2))
            }
            if let baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
    }
}

/// Strain (blue, 0–21) and Recovery (zone-colored, 0–100 %) on one chart.
struct StrainRecoveryChart: View {
    var days: [DayScores]
    var compact = false

    var body: some View {
        Chart {
            ForEach(days) { d in
                LineMark(x: .value("Day", d.date, unit: .day), y: .value("Strain", d.strain), series: .value("Series", "Strain"))
                    .foregroundStyle(Theme.strain[0])
                    .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("Day", d.date, unit: .day), y: .value("Strain", d.strain))
                    .foregroundStyle(Theme.strain[0])
                    .symbolSize(compact ? 30 : 50)
                    .annotation(position: .bottom, spacing: 4) {
                        if !compact { Text(d.strain.oneDecimal).font(.caption2.weight(.bold)).foregroundStyle(Theme.strain[0]) }
                    }
            }
            ForEach(days.filter { $0.recovery != nil }) { d in
                let r = d.recovery ?? 0
                LineMark(x: .value("Day", d.date, unit: .day), y: .value("Recovery", r / 100 * 21), series: .value("Series", "Recovery"))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                PointMark(x: .value("Day", d.date, unit: .day), y: .value("Recovery", r / 100 * 21))
                    .foregroundStyle(Theme.recoveryColor(r))
                    .symbolSize(compact ? 30 : 50)
                    .annotation(position: .top, spacing: 4) {
                        Text("\(r.percent)%").font(.caption2.weight(.bold)).foregroundStyle(Theme.recoveryColor(r))
                    }
            }
        }
        .chartYScale(domain: 0...23)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 7, 14, 21]) { _ in
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel().foregroundStyle(Theme.strain[0])
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: days.count > 10 ? 5 : 1)) { _ in
                AxisValueLabel(format: days.count > 10 ? .dateTime.month(.abbreviated).day() : .dateTime.weekday(.abbreviated))
            }
        }
    }
}
