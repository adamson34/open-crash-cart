import Foundation

/// Mouse-event coalescer for slow links (e.g. the CH9329 serial controller): rapid pointer moves
/// collapse to only the most recent position so the link never falls behind streaming a backlog.
/// Pure, synchronous, and thread-safe (BC-1.06.008).
///
/// Coalescing is limited to runs with the **same button state**: consecutive moves overwrite each
/// other, but any change in the pressed buttons is preserved as its own entry, so a press followed
/// by a release is never swallowed by a later move — that would drop a click on the target (C-8).
public final class MouseCoalescer: @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [MouseEvent] = []

    public init() {}

    /// Record an event. If it shares the pending tail's button state it overwrites it (a pure
    /// move); otherwise it is appended so the button transition survives.
    public func store(_ event: MouseEvent) {
        lock.lock(); defer { lock.unlock() }
        if let last = queue.last, last.buttons == event.buttons {
            queue[queue.count - 1] = event
        } else {
            queue.append(event)
        }
    }

    /// Return and remove the oldest pending event (FIFO), or `nil` if none is pending.
    public func drain() -> MouseEvent? {
        lock.lock(); defer { lock.unlock() }
        return queue.isEmpty ? nil : queue.removeFirst()
    }
}
