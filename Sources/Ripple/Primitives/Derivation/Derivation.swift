//
//  Created by Daniel Inoa on 8/3/25.
//

/// A **cached, read-only value** that is *derived* from one or more
/// publishers.
///
/// `Derivation` combines the roles of a
/// - ``Publisher`` – other subscribers may read `value` and link
///   themselves to this node, and
/// - ``Subscriber`` – it recomputes itself whenever one of its own
///   dependencies mutates.
///
/// The value is produced by `body` and **memoised**; Ripple re-evaluates
/// the closure only when a dependency change invalidates the cache.
///
/// ### Life-cycle
/// * **Init** – registers the instance with ``Runtime`` but does **not**
///   execute `body`.  The first call to `run()` (performed automatically
///   when the runtime schedules the node) fills the cache.
/// * **Run** – assigns the newly computed value to `value`, which
///   triggers `didMutate` and propagates change to dependents.
/// * **Deinit** – unregisters the node as both subscriber and publisher.
///
/// ### Equality optimisation
/// When `T` conforms to `Equatable`, Ripple skips propagation if
/// `newValue == cache`, reducing redundant work across the graph.
///
/// ### Threading
/// By convention `Derivation` is accessed on the **main actor**; keep the
/// closure quick, perform heavy work off-thread and commit the result back
/// through an `Atom`.
public final class Derivation<T>: Publisher, Subscriber {

    // MARK: - Private state

    private var cache: T!              // valid after first run()
    private let body: () -> T
    private let tracker = Runtime.current   // cache the runtime for speed

    // MARK: - Public interface

    /// The most recently computed value.
    ///
    /// Reading the property records a dependency.
    /// Writing occurs **only** inside `run()`; external callers cannot
    /// mutate derived state directly.
    private(set) public var value: T {
        get {
            tracker.willRead(self)
            precondition(cache != nil, "Derived read before first run()")
            return cache
        }
        set {
            if Self.isEquatable {
                let changed = (cache == nil) || !Self.areEqual(newValue, cache)
                if changed {
                    cache = newValue
                    tracker.didMutate(self)
                }
            } else {
                cache = newValue
                tracker.didMutate(self)
            }
        }
    }

    // MARK: - Creation

    /// Creates a derived node whose value is produced by `body`.
    ///
    /// Use the factory ``derive(_:)`` or the ``@Derived`` wrapper for
    /// cleaner call-sites.
    init(_ body: @escaping () -> T) {
        self.body = body
        tracker.register(self)       // initial dependency collection happens on first run()
    }

    // MARK: - Subscriber

    /// Recomputes the cached value by executing `body`.
    func run() {
        value = body()
    }

    // MARK: - Tear-down

    deinit {
        Task { @MainActor [weak self] in
            guard let self else { return }
            tracker.unregister(subscriber: self)
            tracker.unregister(publisher: self)
        }
    }
}

// MARK: - Equality specialisation

private extension Derivation {
    static var isEquatable: Bool { false }
    static func areEqual(_ old: T, _ new: T) -> Bool { false }
}

private extension Derivation where T: Equatable {
    static var isEquatable: Bool { true }
    static func areEqual(_ old: T, _ new: T) -> Bool { old == new }
}

// MARK: - Convenience factory

/// Creates a *derived* value that automatically tracks the publishers
/// it touches and recomputes whenever any of them mutate.
///
/// ```swift
/// let total = derive { price.value * quantity.value }
/// print(total.value)
/// ```
public func derive<T>(_ body: @escaping () -> T) -> Derivation<T> {
    Derivation(body)
}
