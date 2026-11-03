import Foundation

struct CheckFailure: Error, CustomStringConvertible {
    var description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String,
            file: StaticString = #filePath, line: UInt = #line) throws {
    if !condition() { throw CheckFailure(description: "\(file):\(line): \(message)") }
}
