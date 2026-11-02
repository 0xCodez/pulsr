import SwiftUI

@main
struct LumenApp: App {
    @State private var store = MetricsStore()
    @State private var journal = JournalStore()
    @State private var coach = Coach()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(journal)
                .environment(coach)
                .preferredColorScheme(.dark)
                .task { if store.hasOnboarded { await store.load() } }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, store.hasOnboarded { Task { await store.load() } }
                }
        }
    }
}

enum Route: Hashable {
    case recovery, sleep, strain, stress, bodyAge, healthMonitor, journalInsights
}

struct RootView: View {
    @Environment(MetricsStore.self) private var store

    var body: some View {
        if store.hasOnboarded {
            TabView {
                Tab("Today", systemImage: "circle.circle") { NavigationStack { TodayView().routes() } }
                Tab("Trends", systemImage: "chart.xyaxis.line") { NavigationStack { TrendsView().routes() } }
                Tab("Journal", systemImage: "book.closed") { NavigationStack { JournalView().routes() } }
                Tab("Coach", systemImage: "sparkles") { NavigationStack { CoachView() } }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tint(.white)
        } else {
            OnboardingView()
        }
    }
}

extension View {
    func routes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .recovery: RecoveryDetailView()
            case .sleep: SleepDetailView()
            case .strain: StrainDetailView()
            case .stress: StressView()
            case .bodyAge: BodyAgeView()
            case .healthMonitor: HealthMonitorView()
            case .journalInsights: JournalInsightsView()
            }
        }
    }
}
