import Foundation

/// Latest-wins mouse-event coalescer for slow links (e.g. the CH9329 serial controller): rapid
/// pointer moves collapse to only the most recent position so the link never falls behind
/// streaming a backlog. Pure, synchronous, and thread-safe (BC-1.06.008).
public final class MouseCoalescer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: MouseEvent?

    public init() {}

    /// Record the latest event, discarding any previously-pending one.
    public func store(_ event: MouseEvent) {
        lock.lock(); pending = event; lock.unlock()
    }

    /// Return and clear the most recent pending event, or `nil` if none is pending.
    public func drain() -> MouseEvent? {
        lock.lock(); defer { lock.unlock() }
        let e = pending; pending = nil; return e
    }
}
