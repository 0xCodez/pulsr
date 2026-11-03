import Foundation

enum MissingDataTests {
    static func days(_ count: Int, configure: (inout RawDay) -> Void = { _ in }) -> [RawDay] {
        let start = Calendar.current.startOfDay(for: Date())
        return (0..<count).map { offset in
            var raw = RawDay(date: Calendar.current.date(byAdding: .day, value: offset, to: start)!)
            configure(&raw)
            return raw
        }
    }

    static func emptyHistory() throws {
        let scores = ScoreEngine.score(days(30), profile: UserProfile())
        try expect(scores.allSatisfy { $0.strain == nil }, "Missing HR is not zero strain")
        try expect(ScoreEngine.bodyAge(days: scores, profile: UserProfile()) == nil, "Empty calendar rows do not produce body age")
        try expect(Insights.coachContext(days: scores, bodyAge: nil, profile: UserProfile()).contains("unavailable"), "Coach receives missing strain explicitly")
    }

    static func measuredZero() throws {
        let raw = days(7) { raw in
            raw.steps = 0
            raw.heartRate = [HeartRatePoint(date: raw.date, bpm: 60)]
        }
        let scores = ScoreEngine.score(raw, profile: UserProfile())
        try expect(scores.allSatisfy { $0.strain == 0 }, "Measured rest remains zero strain")
        let age = ScoreEngine.bodyAge(days: scores, profile: UserProfile())
        try expect(age?.factors.contains { $0.name == "Daily Steps" } == true, "Measured zero steps are included")
        try expect(age?.factors.contains { $0.name == "Zone 2–3 per week" } == true, "Measured resting HR has zero activity")
    }

    static func measuredWeek() throws {
        let short = ScoreEngine.score(days(6) { $0.restingHR = 60 }, profile: UserProfile())
        try expect(ScoreEngine.bodyAge(days: short, profile: UserProfile()) == nil, "Six measured days are insufficient")
        let raw = days(30) { $0.hrv = 45 }
        let scores = ScoreEngine.score(raw, profile: UserProfile())
        let age = ScoreEngine.bodyAge(days: scores, profile: UserProfile())
        try expect(age != nil, "A measured HRV history can produce an estimate")
        try expect(age?.factors.contains { $0.name == "Daily Steps" || $0.name == "Zone 2–3 per week" } == false, "Missing activity factors are omitted")
        let vo2Only = ScoreEngine.score(days(30) { $0.vo2Max = 45 }, profile: UserProfile())
        try expect(ScoreEngine.bodyAge(days: vo2Only, profile: UserProfile()) == nil, "A carried-forward VO2 value is not a measured week")
    }

    static func activityDenominator() throws {
        var raw = days(30)
        for i in 0..<7 {
            raw[i].heartRate = (0..<60).map { HeartRatePoint(date: raw[i].date.addingTimeInterval(Double($0) * 60), bpm: 140) }
        }
        let scores = ScoreEngine.score(raw, profile: UserProfile())
        let full = ScoreEngine.bodyAge(days: scores, profile: UserProfile())
        let week = ScoreEngine.bodyAge(days: Array(scores.prefix(7)), profile: UserProfile())
        try expect(full == week, "Unmeasured days do not dilute activity or change body age")
    }

    static func workoutAvailability() throws {
        let date = Date()
        let workout = WorkoutSummary(name: "Strength", symbol: "", start: date, end: date.addingTimeInterval(3600), isStrength: true)
        let missing = ScoreEngine.strain(heartRate: [], restingHR: 60, profile: UserProfile(), workouts: [workout])
        try expect(missing.strain == nil && missing.perWorkout[workout.id] == nil, "Unmeasured workout is unavailable")
        let rest = ScoreEngine.strain(heartRate: [HeartRatePoint(date: date, bpm: 60)], restingHR: 60, profile: UserProfile(), workouts: [workout])
        try expect(rest.strain == 0 && rest.perWorkout[workout.id] == 0, "Measured low-load workout is zero")
    }

    static func healthStates() throws {
        let empty = ScoreEngine.score(days(1), profile: UserProfile())[0]
        try expect(HealthMonitor.status(for: HealthMonitor.metrics(for: empty)) == .noData, "No vitals cannot be within range")
        let learning = ScoreEngine.score(days(1) { $0.restingHR = 60; $0.wristTemperature = 35 }, profile: UserProfile())[0]
        try expect(HealthMonitor.status(for: HealthMonitor.metrics(for: learning)) == .learning, "Unlearned baselines cannot be within range")
        let learned = ScoreEngine.score(days(8) { $0.restingHR = 60 }, profile: UserProfile()).last!
        try expect(HealthMonitor.status(for: HealthMonitor.metrics(for: learned)) == .withinRange, "A measured normal vital can be within range")
        var lowOxygen = learned
        lowOxygen.raw.spo2 = 0.94
        try expect(HealthMonitor.status(for: HealthMonitor.metrics(for: lowOxygen)) == .outOfRange, "Oxygen classification matches the displayed 95–100% range")
    }
}
