import Foundation

/// A tiny dependency-free test harness. XCTest/swift-testing aren't available with the
/// Command Line Tools toolchain, so tests run as a plain executable (`swift run occ-tests`)
/// that works locally and in CI. Exits non-zero on any failure.
final class Harness {
    private(set) var passed = 0
    private(set) var failed = 0

    func section(_ name: String) {
        print("\n▸ \(name)")
    }

    func expect(_ condition: Bool, _ message: String) {
        if condition {
            passed += 1
            print("  ✓ \(message)")
        } else {
            failed += 1
            print("  ✗ \(message)")
        }
    }

    func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
        if actual == expected {
            passed += 1
            print("  ✓ \(message)")
        } else {
            failed += 1
            print("  ✗ \(message)  [got \(actual), want \(expected)]")
        }
    }

    func finish() -> Never {
        let total = passed + failed
        print("\n" + (failed == 0
            ? "ALL PASSED ✓  (\(total) checks)"
            : "\(failed) FAILED ✗  (\(passed)/\(total) passed)"))
        exit(failed == 0 ? 0 : 1)
    }
}
