import Foundation
import Testing
@testable import RuuviService

struct NativeConcurrencyTests {
    enum Failure: Error, Equatable { case expected }

    @Test func boundedMapPreservesInputOrderAndConcurrencyLimit() async throws {
        let tracker = ConcurrencyTracker()
        let values = try await ruuviConcurrentMap(Array(0..<12), limit: 3) { value async throws(Failure) in
            await tracker.start()
            try? await Task.sleep(for: .milliseconds(12 - value))
            await tracker.finish()
            return value * 2
        }
        #expect(values == Array(0..<12).map { $0 * 2 })
        #expect(await tracker.maximum <= 3)
        #expect(await tracker.active == 0)
        #expect(await tracker.finished == 12)
    }

    @Test func boundedMapJoinsWorkBeforeReturningFailure() async {
        let tracker = ConcurrencyTracker()
        do {
            _ = try await ruuviConcurrentMap(Array(0..<6), limit: 2) { value async throws(Failure) in
                await tracker.start()
                await Task.yield()
                await tracker.finish()
                if value == 1 { throw .expected }
                return value
            }
            Issue.record("Expected failure")
        } catch { #expect(error == .expected) }
        #expect(await tracker.active == 0)
        #expect(await tracker.finished == 6)
    }

    @Test func emptyMapNeverCallsOperation() async throws {
        let values: [Int] = try await ruuviConcurrentMap([]) { (_: Int) async throws(Failure) in
            Issue.record("Empty input invoked operation")
            return 0
        }
        #expect(values.isEmpty)
    }

    @Test func nonPositiveConcurrencyLimitStillCompletes() async throws {
        let tracker = ConcurrencyTracker()
        _ = try await ruuviConcurrentMap([1, 2, 3], limit: 0) { value async throws(Failure) in
            await tracker.start()
            await Task.yield()
            await tracker.finish()
            return value
        }
        #expect(await tracker.maximum == 1)
    }

    @Test func serialWorkKeepsSubmissionOrderWithoutBlockingOtherKeys() async {
        let store = RuuviTaskStore()
        let gate = AsyncStream<Void>.makeStream()
        let events = AsyncStream<Int>.makeStream()
        defer { gate.continuation.finish(); events.continuation.finish() }
        store.run(seriallyFor: "first") {
            events.continuation.yield(-1)
            for await _ in gate.stream { break }
            events.continuation.yield(0)
        }
        for value in 1...20 {
            store.run(seriallyFor: "first") { events.continuation.yield(value) }
        }
        store.run(seriallyFor: "second") { events.continuation.yield(-2) }
        var iterator = events.stream.makeAsyncIterator()
        let initial = [await iterator.next(), await iterator.next()]
        #expect(Set(initial.compactMap { $0 }) == Set([-1, -2]))
        gate.continuation.finish()
        var actual = [Int]()
        for _ in 0...20 { if let value = await iterator.next() { actual.append(value) } }
        #expect(actual == Array(0...20))
    }

    @Test func cancellingOwnedWorkReachesOperation() async {
        let store = RuuviTaskStore()
        let started = AsyncStream<Void>.makeStream()
        let finished = AsyncStream<Bool>.makeStream()
        store.run {
            started.continuation.yield(())
            do { try await Task.sleep(for: .seconds(30)) } catch { finished.continuation.yield(Task.isCancelled) }
            finished.continuation.finish()
        }
        for await _ in started.stream { break }
        store.cancelAll()
        for await cancelled in finished.stream { #expect(cancelled) }
        store.cancelAll()  // Repeated cancellation is safe.
    }
}

private actor ConcurrencyTracker {
    var active = 0
    var maximum = 0
    var finished = 0
    func start() { active += 1; maximum = max(maximum, active) }
    func finish() { active -= 1; finished += 1 }
}
