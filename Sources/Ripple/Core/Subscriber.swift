//
//  Created by Daniel Inoa on 8/3/25.
//

/// A type that Ripple’s runtime can **execute** when one of its
/// dependencies changes.
///
/// Conforming types implement ``run()`` to perform work:
/// * **`Derived`** recomputes its cached value.
/// * **`Effect`** executes a side-effecting closure.
///
/// The protocol is reference-type-only (`AnyObject`) so that each
/// subscriber can be identified by identity.
///
/// ### Conforming
/// ```swift
/// @MainActor
/// final class Effect: Subscriber {
///     private let body: () -> Void
///     init(_ body: @escaping () -> Void) { self.body = body }
///     func run() { body() }
/// }
/// ```
///
/// ### Interaction with the runtime
/// When a tracked publisher mutates, the runtime calls `run()` on every
/// dependent `Subscriber`. Implementations should perform their work
/// **synchronously** and **without awaiting** to keep Ripple’s update graph
/// deterministic.
protocol Subscriber: AnyObject {

    /// Perform the subscriber’s work.
    ///
    /// Called by Ripple’s runtime after any of the subscriber’s tracked
    /// publishers mutate. Implementations must not `await` or perform
    /// lengthy blocking operations; spawn a task if heavy work is needed
    /// and commit results back on the main actor.
    func run()
}

extension Subscriber {

    /// A stable identifier for this subscriber.
    ///
    /// Ripple uses the `ObjectIdentifier` to store subscribers in its
    /// dependency graph.
    var objectIdentifier: ObjectIdentifier { ObjectIdentifier(self) }
}
