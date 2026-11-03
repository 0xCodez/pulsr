import SwiftUI
import Charts

struct TodayView: View {
    @Environment(MetricsStore.self) private var store
    @State private var showSettings = false

    var body: some View {
        let day = store.selected
        ScrollView {
            VStack(spacing: 16) {
                header
                if let day {
                    rings(day)
                    insight(day)
                    monitors(day)
                    SectionTitle(title: "My Day")
                    activities(day)
                    if store.isToday { tonight(day) }
                    weekChart
                    bodyAgeTeaser
                } else if store.isLoading {
                    ProgressView().padding(.top, 120)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.load() }
        .background { AuroraBackground(accent: Theme.recoveryColor(day?.recovery)) }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button { showSettings = true } label: {
                Text(store.profile.initials)
                    .font(.footnote.weight(.bold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Spacer()
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 6) {
                    Button { withAnimation { store.step(-1) } } label: { Image(systemName: "chevron.left").frame(width: 22, height: 22) }
                        .buttonStyle(.glass).buttonBorderShape(.circle)
                        .disabled(store.selectedIndex == 0)
                    Text(store.isToday ? "TODAY" : (store.selected?.date.dayLabel ?? ""))
                        .font(.subheadline.weight(.semibold))
                        .tracking(1.5)
                        .frame(minWidth: 110)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .glassEffect(.regular, in: .capsule)
                    Button { withAnimation { store.step(1) } } label: { Image(systemName: "chevron.right").frame(width: 22, height: 22) }
                        .buttonStyle(.glass).buttonBorderShape(.circle)
                        .disabled(store.isToday)
                }
            }
            Spacer()

            Image(systemName: store.source == .demo ? "sparkles.rectangle.stack" : "applewatch")
                .font(.title3)
                .frame(width: 40, height: 40)
                .glassEffect(.regular, in: .circle)
        }
        .padding(.top, 6)
    }

    // MARK: Rings

    private func rings(_ d: DayScores) -> some View {
        VStack(spacing: 0) {
            NavigationLink(value: Route.recovery) {
                VStack(spacing: 0) {
                    HaloOrb(palette: .recovery(d.recovery))
                        .frame(width: 212, height: 212)
                        .padding(.top, 22)
                        .padding(.bottom, 26)
                    BigNumber(text: d.recovery.map(\.percent) ?? "–", unit: d.recovery == nil ? nil : "%", size: 76)
                    Eyebrow(text: d.recovery == nil ? "Recovery · waiting for sleep" : "Recovery · \(Insights.headline(d).title)")
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
            }
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    NavigationLink(value: Route.sleep) {
                        MetricCapsule(progress: (d.sleepPerformance ?? 0) / 100, color: Theme.sleep[0],
                                      value: d.sleepPerformance.map { "\($0.percent)%" } ?? "–", title: "Sleep")
                    }
                    NavigationLink(value: Route.strain) {
                        MetricCapsule(progress: (d.strain ?? 0) / 21, color: Theme.strain[0], value: d.strain?.oneDecimal ?? "–", title: "Strain")
                    }
                }
            }
            .padding(.top, 20)
        }
        .buttonStyle(.plain)
    }

    // MARK: Cards

    private func insight(_ d: DayScores) -> some View {
        let text = Insights.headline(d)
        return GlassCard(tint: Theme.recoveryColor(d.recovery)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(text.title).font(.title3.weight(.semibold))
                    Spacer()
                    if d.isCalibrating {
                        Text("CALIBRATING").font(.caption2.weight(.bold)).tracking(1)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .glassEffect(.regular.tint(Theme.yellow.opacity(0.3)), in: .capsule)
                    }
                }
                Text(text.body).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func monitors(_ d: DayScores) -> some View {
        let health = HealthMonitor.metrics(for: d)
        let inRange = health.filter { $0.inRange == true }.count
        let healthStatus = HealthMonitor.status(for: health)
        let healthColor: Color = healthStatus == .withinRange ? Theme.green : healthStatus == .outOfRange ? Theme.yellow : .secondary
        let stress = d.latestStress
        return HStack(spacing: 12) {
            NavigationLink(value: Route.healthMonitor) {
                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Eyebrow(text: "Health Monitor"); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                        HStack(spacing: 10) {
                            Image(systemName: healthStatus == .withinRange ? "checkmark" : healthStatus == .outOfRange ? "exclamationmark" : "minus")
                                .font(.caption.weight(.bold))
                                .frame(width: 26, height: 26)
                                .background(healthColor.opacity(0.25), in: .rect(cornerRadius: 7))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(healthStatus.rawValue)
                                    .font(.caption.weight(.bold)).tracking(0.8)
                                    .foregroundStyle(healthColor)
                                Text("\(inRange)/\(health.count) metrics").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            NavigationLink(value: Route.stress) {
                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Eyebrow(text: "Stress"); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                        HStack(spacing: 10) {
                            Text(stress?.oneDecimal ?? "–")
                                .font(.callout.weight(.bold).monospacedDigit())
                                .frame(width: 34, height: 26)
                                .background(Theme.stressColor(stress ?? 0).opacity(0.25), in: .rect(cornerRadius: 7))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stress.map { StressLevel($0).rawValue.uppercased() } ?? "NO DATA")
                                    .font(.caption.weight(.bold)).tracking(0.8)
                                    .foregroundStyle(Theme.stressColor(stress ?? 0))
                                Text(d.stress.last?.date.shortTime ?? "—").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func activities(_ d: DayScores) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Activities")
                if let sleep = d.raw.sleep {
                    NavigationLink(value: Route.sleep) {
                        ActivityRow(symbol: "moon.fill", tint: Theme.sleep[0], badge: sleep.asleep.hoursMinutes, title: "Sleep",
                                    detail: "\(sleep.start.shortTime) – \(sleep.end.shortTime)")
                    }
                }
                ForEach(d.raw.workouts) { w in
                    NavigationLink(value: Route.strain) {
                        ActivityRow(symbol: w.symbol, tint: Theme.strain[0], badge: d.workoutStrain[w.id]?.oneDecimal ?? "–", title: w.name,
                                    detail: "\(w.start.shortTime) · \(Int(w.duration / 60)) min")
                    }
                }
                if d.raw.sleep == nil && d.raw.workouts.isEmpty {
                    Text("No activities recorded.").font(.callout).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func tonight(_ d: DayScores) -> some View {
        let need = ScoreEngine.sleepNeed(profile: store.profile, previousStrain: d.strain, recent: store.window(3))
        let bedtime = ScoreEngine.recommendedBedtime(days: store.days, need: need)
        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Tonight's Sleep")
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(bedtime?.shortTime ?? "–", systemImage: "moon.zzz")
                            .font(.system(.title, design: .rounded).weight(.semibold))
                        Text("RECOMMENDED BEDTIME").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(need.hoursMinutes)
                            .font(.system(.title, design: .rounded).weight(.semibold))
                        Text("SLEEP NEEDED").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(Theme.sleep[0])
                    }
                }
            }
        }
    }

    private var weekChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Strain & Recovery · 7 days")
                StrainRecoveryChart(days: store.window(7), compact: true).frame(height: 170)
            }
        }
    }

    @ViewBuilder private var bodyAgeTeaser: some View {
        if let age = store.bodyAge {
            NavigationLink(value: Route.bodyAge) {
                GlassCard(tint: Theme.green) {
                    HStack(spacing: 16) {
                        HaloOrb(palette: .recovery(80), energy: 0.2, speed: 0.45).frame(width: 56, height: 56).padding(4)
                        VStack(alignment: .leading, spacing: 4) {
                            Eyebrow(text: "Body Age")
                            BigNumber(text: age.bodyAge.oneDecimal, size: 28)
                            Text(age.difference <= 0 ? "\(abs(age.difference).oneDecimal) years younger" : "\(age.difference.oneDecimal) years older")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(age.difference <= 0 ? Theme.green : Theme.hurts)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("No data yet").font(.title3.weight(.semibold))
                Text(store.errorMessage ?? "Wear your Apple Watch through the day and to bed, then pull to refresh.")
                    .foregroundStyle(.secondary)
                Button("Use demo data") { store.source = .demo }.buttonStyle(.glass)
            }
        }
        .padding(.top, 60)
    }
}

// MARK: - Pieces

struct MetricCapsule: View {
    var progress: Double
    var color: Color
    var value: String
    var title: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Theme.track, lineWidth: 4)
                Circle().trim(from: 0, to: max(0.01, min(progress, 1)))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 19, weight: .medium)).monospacedDigit()
                Eyebrow(text: title)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
    }
}

struct RingTile: View {
    var progress: Double
    var colors: [Color]
    var value: String
    var unit: String?
    var title: String
    var marker: Double? = nil

    var body: some View {
        VStack(spacing: 10) {
            ScoreRing(progress: progress, colors: colors, lineWidth: 9, marker: marker) {
                BigNumber(text: value, unit: unit, size: 26)
            }
            .frame(width: 96, height: 96)
            HStack(spacing: 3) {
                Text(title.uppercased()).font(.caption.weight(.bold)).tracking(1.3)
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 26))
    }
}

struct ActivityRow: View {
    var symbol: String
    var tint: Color
    var badge: String
    var title: String
    var detail: String

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(badge).monospacedDigit()
            }
            .font(.callout.weight(.bold))
            .frame(width: 92, height: 40)
            .background(tint.opacity(0.35), in: .rect(cornerRadius: 12))
            Text(title.uppercased()).font(.subheadline.weight(.semibold)).tracking(1)
            Spacer()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(6)
        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 16))
    }
}

struct HealthMonitorView: View {
    @Environment(MetricsStore.self) private var store

    var body: some View {
        DetailScaffold(title: "Health Monitor", accent: Theme.green) {
            if let d = store.selected {
                let metrics = HealthMonitor.metrics(for: d)
                GlassCard {
                    VStack(spacing: 0) {
                        ForEach(metrics) { m in
                            HStack(spacing: 12) {
                                Image(systemName: m.symbol).frame(width: 26).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.name.uppercased()).font(.footnote.weight(.semibold)).tracking(1)
                                    Text("Your range \(m.range)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(m.value).font(.system(.title3, design: .rounded).weight(.semibold))
                                Image(systemName: m.inRange == nil ? "clock" : m.inRange == true ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(m.inRange == nil ? Color.secondary : m.inRange == true ? Theme.green : Theme.yellow)
                            }
                            .padding(.vertical, 12)
                            if m.id != metrics.last?.id { Divider().opacity(0.4) }
                        }
                        if metrics.isEmpty {
                            Text("No overnight measurements available. Check Health permissions and wear your watch to sleep.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                InsightCallout(text: "Ranges are your personal 30-day normal (±2 standard deviations). Several metrics out of range at once can be an early sign of illness, overtraining or poor sleep.")
            }
        }
    }
}
