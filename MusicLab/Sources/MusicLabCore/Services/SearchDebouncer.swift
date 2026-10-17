import Foundation

/// Cancels any pending work and runs the newest scheduled action after a delay.
///
/// Used to debounce keystroke-driven catalog search and to guarantee that only
/// the latest query's work executes, so stale results cannot overwrite newer ones.
public final class SearchDebouncer {
    private var currentTask: Task<Void, Never>?

    public init() {}

    /// Cancels in-flight work, then runs `work` after `delay` seconds
    /// (`delay` of 0 runs immediately). Cancelling the scheduled work (or
    /// scheduling again) leaves the previous closure unexecuted.
    ///
    /// `work` is `@Sendable` so it can be launched onto its own task. Callers
    /// isolated to a global actor should hop back into their isolation from
    /// within `work` (e.g. `await self.mainActorMethod()`).
    public func schedule(delay: Double, _ work: @escaping @Sendable () async -> Void) {
        cancel()
        currentTask = Task<Void, Never> {
            if delay > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    return // cancelled while waiting
                }
                if Task.isCancelled { return }
            }
            await work()
        }
    }

    /// Cancels pending/running work. Safe to call when idle.
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}
