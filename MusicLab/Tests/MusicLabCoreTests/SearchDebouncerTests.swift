import XCTest
import Foundation
@testable import MusicLabCore

final class SearchDebouncerTests: XCTestCase {

    /// Thread-safe sink for work closures scheduled onto Task contexts.
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var _values: [String] = []
        func record(_ v: String) {
            lock.lock()
            _values.append(v)
            lock.unlock()
        }
        var values: [String] {
            lock.lock()
            defer { lock.unlock() }
            return _values
        }
    }

    private func sleepMs(_ ms: UInt64) async {
        try? await Task.sleep(nanoseconds: ms * 1_000_000)
    }

    private func waitUntil(_ condition: @autoclosure () -> Bool,
                           timeoutMs: UInt64 = 3000) async -> Bool {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            if condition() { return true }
            await sleepMs(20)
        }
        return condition()
    }

    func testImmediateScheduleRuns() async {
        let d = SearchDebouncer()
        let rec = Recorder()
        d.schedule(delay: 0) { rec.record("immediate") }
        let ok = await waitUntil(rec.values.count == 1)
        XCTAssertTrue(ok, "immediate work should run")
        XCTAssertEqual(rec.values, ["immediate"])
    }

    func testDelayDefersExecutionUntilElapse() async {
        let d = SearchDebouncer()
        let rec = Recorder()
        d.schedule(delay: 0.4) { rec.record("delayed") }
        await sleepMs(200)
        XCTAssertTrue(rec.values.isEmpty, "work must not run before the delay elapses")
        let ok = await waitUntil(rec.values.count == 1, timeoutMs: 2000)
        XCTAssertTrue(ok, "work should run after the delay")
        XCTAssertEqual(rec.values, ["delayed"])
    }

    func testCancelPreventsExecution() async {
        let d = SearchDebouncer()
        let rec = Recorder()
        d.schedule(delay: 0.2) { rec.record("cancelled") }
        d.cancel()
        await sleepMs(500)
        XCTAssertTrue(rec.values.isEmpty, "cancelled work must never run")
    }

    func testCancelIsIdempotentWhenIdle() async {
        let d = SearchDebouncer()
        d.cancel()
        d.cancel()
        let rec = Recorder()
        d.schedule(delay: 0) { rec.record("after-idle-cancel") }
        let ok = await waitUntil(rec.values.count == 1)
        XCTAssertTrue(ok, "debouncer must still work after cancelling while idle")
    }

    func testNewerScheduleCancelsOlder() async {
        let d = SearchDebouncer()
        let rec = Recorder()
        // Schedule A with a longer delay, then immediately supersede with B.
        d.schedule(delay: 0.6) { rec.record("A") }
        d.schedule(delay: 0.1) { rec.record("B") }

        let bRan = await waitUntil(rec.values.contains("B"), timeoutMs: 2000)
        XCTAssertTrue(bRan, "the newest scheduled work should run")

        // Give A's original (now-cancelled) window a chance to fire; it must not.
        await sleepMs(700)
        XCTAssertEqual(rec.values, ["B"], "the superseded schedule must not run")
    }
}
