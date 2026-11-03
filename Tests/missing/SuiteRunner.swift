import Foundation

@main
struct SuiteRunner {
    static func main() async throws {
        try MissingDataTests.emptyHistory()
        print("PASS: Empty health history")
        try MissingDataTests.measuredZero()
        print("PASS: Measured zeros")
        try MissingDataTests.measuredWeek()
        print("PASS: Measured week requirement")
        try MissingDataTests.activityDenominator()
        print("PASS: Activity coverage denominator")
        try MissingDataTests.workoutAvailability()
        print("PASS: Workout availability")
        try MissingDataTests.healthStates()
        print("PASS: Health monitor states")
        print("6 missing regression checks passed")
    }
}
