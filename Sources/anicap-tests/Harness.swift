import Foundation

struct TestError: Error { let message: String }

enum Harness {
    static var passed = 0
    static var failed = 0
    static var failures: [String] = []

    @discardableResult
    static func check(_ cond: Bool, _ name: String,
                      file: String = #fileID, line: Int = #line) -> Bool {
        if cond { passed += 1; print("    PASS  \(name)") }
        else {
            failed += 1; failures.append("\(file):\(line)  \(name)")
            print("    FAIL  \(name)  [\(file):\(line)]")
        }
        return cond
    }

    static func eq<T: Equatable>(_ got: T, _ want: T, _ name: String,
                                 file: String = #fileID, line: Int = #line) {
        check(got == want, "\(name) — got \(got), want \(want)", file: file, line: line)
    }

    static func isNil<T>(_ v: T?, _ name: String, file: String = #fileID, line: Int = #line) {
        check(v == nil, "\(name) — want nil, got \(String(describing: v))", file: file, line: line)
    }

    static func notNil<T>(_ v: T?, _ name: String, file: String = #fileID, line: Int = #line) -> T? {
        if v == nil { check(false, "\(name) — want non-nil", file: file, line: line) }
        return v
    }

    static func unwrap<T>(_ v: T?, _ name: String, file: String = #fileID, line: Int = #line) throws -> T {
        guard let v else {
            check(false, "\(name) — want non-nil", file: file, line: line)
            throw TestError(message: "unwrap failed: \(name)")
        }
        return v
    }

    static func assertThrows<T>(_ body: () throws -> T, _ name: String,
                                _ match: (Error) -> Bool = { _ in true },
                                file: String = #fileID, line: Int = #line) {
        do { _ = try body(); check(false, "\(name) — expected throw, none happened", file: file, line: line) }
        catch let e { check(match(e), "\(name) — threw \(e)", file: file, line: line) }
    }

    static func summary() -> Bool {
        print("---- \(passed) passed, \(failed) failed ----")
        for f in failures { print("  FAILED  \(f)") }
        return failed == 0
    }
}
