import Foundation

protocol HealthDataSource {
    func requestAuthorization() async throws
    /// Returns `count` days ending today, oldest first, including heart rate for every day.
    func loadDays(count: Int) async throws -> [RawDay]
    func profileHints() -> (age: Int?, sex: Sex?)
}
