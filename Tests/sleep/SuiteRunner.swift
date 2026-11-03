import Foundation

@main
struct SuiteRunner {
    static func main() async throws {
        try SleepTests.duplicates()
        print("PASS: Duplicate sleep samples")
        try SleepTests.overlappingStages()
        print("PASS: Overlapping sleep stages")
        try SleepTests.gapsAndInvalidIntervals()
        print("PASS: Sleep gaps and invalid intervals")
        print("3 sleep regression checks passed")
    }
}
