import Foundation

enum SleepTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static func segment(_ stage: SleepStage, _ from: Double, _ to: Double) -> SleepSegment {
        SleepSegment(stage: stage, start: start.addingTimeInterval(from * 3600), end: start.addingTimeInterval(to * 3600))
    }

    static func duplicates() throws {
        let interval = segment(.core, 0, 8)
        let session = SleepSession(segments: [interval, interval])
        try expect(session.segments.count == 1 && session.asleep == 8 * 3600, "Duplicate samples count once")
        var raw = RawDay(date: start)
        raw.sleep = session
        let score = ScoreEngine.score([raw], profile: UserProfile())[0]
        try expect(score.sleepEfficiency == 1, "Efficiency cannot exceed 100%")
        try expect((score.sleepPerformance ?? 0) <= 100, "Performance cannot exceed 100%")
    }

    static func overlappingStages() throws {
        let input = [segment(.asleep, 0, 8), segment(.core, 0, 4), segment(.deep, 2, 3), segment(.rem, 4, 6), segment(.awake, 5, 5.5)]
        let session = SleepSession(segments: input)
        try expect(session.asleep == 7.5 * 3600, "Awake overrides generic and staged sleep")
        try expect(session.duration(of: .core) == 3 * 3600, "Specific stages override generic sleep")
        try expect(session.duration(of: .deep) == 3600, "Conflicting specific stages resolve deterministically")
        try expect(session.duration(of: .rem) == 1.5 * 3600, "Awake time is removed from REM")
        try expect(session == SleepSession(segments: input.reversed()), "Sample order does not affect normalization")
        try expect(session == SleepSession(segments: session.segments), "Normalization is idempotent")
        try expect(session.segments.map(\.duration).reduce(0, +) == session.inBed, "All stage durations partition the recorded window")
        for (a, b) in zip(session.segments, session.segments.dropFirst()) {
            try expect(a.end <= b.start, "Normalized segments never overlap")
        }
    }

    static func gapsAndInvalidIntervals() throws {
        let session = SleepSession(segments: [segment(.core, 0, 2), segment(.core, 3, 5), segment(.deep, 4, 4), segment(.rem, 6, 5)])
        try expect(session.asleep == 4 * 3600 && session.inBed == 5 * 3600, "Gaps do not become sleep; invalid intervals are discarded")
        try expect(SleepSession(segments: []).asleep == 0, "Empty sleep has zero duration")
        let adjacent = SleepSession(segments: [segment(.core, 0, 1), segment(.core, 1, 2)])
        try expect(adjacent.segments.count == 1, "Adjacent matching intervals merge")
    }
}
