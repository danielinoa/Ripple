//
//  Created by Daniel Inoa on 8/4/25.
//

/// A convenience property-wrapper that stores an **AtomObject**.
///
/// Declare mutable reactive state with ordinary Swift syntax:
///
/// ```swift
/// @Atom var count = 0          // read & write like a normal property
/// @Atom var title = "Hello"
///
/// count += 1                   // writes notify all dependents
/// print($count)                // `$` yields the underlying ``AtomObject``
/// ```
///
/// ### Behaviour
/// * **Read** when the value is accessed while Ripple is collecting
///   dependencies (e.g. inside a  `Derived`  body or an `Effect`),
///   the runtime records that the current subscriber now depends on
///   this atom.
/// * **Write** assigning a **different** value triggers the runtime to
///   re-schedule every subscriber that previously read the atom.
/// * Equality gating uses `Equatable`; setting the **same** value is a
///   no-op, preventing redundant work.
///
/// ### Projection
/// `projectedValue` (`$count`) exposes the backing ``AtomObject`` whenever
/// you need lower-level access or wish to pass the node to an API that
/// operates on `Publisher`s directly.
///
/// ### Concurrency note
/// Ripple treats atoms as **main-actor confined** by convention.
/// Perform heavy work off-thread and commit the result back to the atom
/// on the main actor, e.g.:
///
/// ```swift
/// Task.detached {
///     let heavy = await expensiveCalculation()
///     await MainActor.run { count = heavy }
/// }
/// ```
///
@propertyWrapper
public struct Atom<T: Equatable> {

    /// The underlying node that participates in Ripple’s dependency graph.
    ///
    /// Access via the `$` syntax:
    ///
    /// ```swift
    /// let node = $count           // AtomObject<Int>
    /// print(node.value)
    /// ```
    public var projectedValue: AtomObject<T> { storage }

    /// The atom’s current value.
    ///
    /// Reading the value records a dependency for the current subscriber.
    /// Writing a **new** value schedules dependent subscribers to re-run.
    public var wrappedValue: T {
        get { storage.value }
        set { storage.value = newValue }
    }

    // MARK: - Private storage

    private var storage: AtomObject<T>

    /// Creates an atom initialised with `value`.
    public init(wrappedValue value: T) {
        storage = .init(value)
    }
}
