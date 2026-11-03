import Foundation

@main
struct SuiteRunner {
    static func main() async throws {
        try await HistoryTests.phoneHistory()
        print("PASS: Phone HR history")
        try await HistoryTests.watchHistory()
        print("PASS: Watch HR history")
        try await HistoryTests.windowStability()
        print("PASS: Strain history stability")
        print("3 history regression checks passed")
    }
}
