import Foundation

enum HistoryTests {
    static func phoneHistory() async throws {
        let days = try await DemoSource().loadDays(count: 60)
        try expect(days.count == 60, "Phone loads 60 days")
        try expect(days.dropLast().allSatisfy { !$0.heartRate.isEmpty }, "Every completed day includes HR")
        let scores = ScoreEngine.score(days, profile: UserProfile())
        try expect(scores.prefix(46).allSatisfy { (($0.strain as Double?) ?? 0) > 0 }, "Older activity is scored")
    }

    static func watchHistory() async throws {
        let days = try await DemoSource().loadDays(count: 30)
        try expect(days.prefix(28).allSatisfy { !$0.heartRate.isEmpty }, "Watch loads HR before two days")
    }

    static func windowStability() async throws {
        let source = DemoSource()
        let short = ScoreEngine.score(try await source.loadDays(count: 30), profile: UserProfile())
        let long = ScoreEngine.score(try await source.loadDays(count: 60), profile: UserProfile())
        // Compare completed days, including ones outside the old detail window.
        for (a, b) in zip(short.dropLast(), long.suffix(30).dropLast()) {
            try expect(a.date == b.date, "Same completed date")
            try expect(a.strain == b.strain, "Strain is independent of history length")
            try expect(a.zoneMinutes == b.zoneMinutes, "Zones are independent of history length")
        }
    }
}
