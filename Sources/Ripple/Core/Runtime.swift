//
//  Created by Daniel Inoa on 7/31/25.
//

/// The central coordinator of Ripple’s dependency graph.
///
/// `Runtime` tracks every relationship between ``Publisher`` values and
/// ``Subscriber`` nodes:
/// 1. **Tracking** – During a subscriber’s `run()`, any `Publisher` read invokes
///    ``willRead(_:)`` so the runtime can record _who_ depends on _what_.
/// 2. **Mutation** – When a publisher’s value changes, its owner calls
///    ``didMutate(_:)``.
///    The runtime then looks up all dependent subscribers and schedules
///    them by calling ``Tracker/runAndSubscribe(_:)``.
/// 3. **Unlinking** – When a subscriber is de-initialized or a conditional
///    branch changes, the runtime removes obsolete edges via
///    ``unregister(subscriber:)`` or ``unregister(publisher:)``.
///
/// Tests can override `current` with a task-local value to obtain an
/// isolated graph while keeping production ergonomics.
///
/// ```swift
/// await withIsolatedRuntime {
///     // Runtime.current now refers to a fresh graph for this task tree
///     @Atom var a = 1
///     @Derived var sum = a + 1
///     #expect(sum == 2)
/// }
/// ```
///
/// - Note: `Runtime` is **main-actor-confin­ed** by convention; all public
///   methods must be called from the main actor to guarantee thread safety.
public final class Runtime {

    // MARK: Singleton / Override

    /// The process-wide singleton backing normal app execution.
    private static let shared: Runtime = .init()

    /// The runtime that should be used **right now**.
    ///
    /// * In production, this is the shared singleton.
    /// * In tests, `RippleContext.runtimeOverride` can temporarily replace
    ///   it, giving each test an isolated graph without changing API usage.
    static var current: Runtime { RippleContext.runtimeOverride ?? shared }

    // MARK: Private graph machinery

    private let tracker = Tracker()

    // MARK: - Subscriber Lifecycle

    /// Registers a new subscriber and performs an initial `run()`.
    ///
    /// Called from subscriber initializers (`Atom`, `Derived`, `Effect`)
    /// to capture the node’s initial dependency set.
    func register(_ subscriber: Subscriber) {
        tracker.runAndSubscribe(subscriber)
    }

    /// Removes all edges that point **to** the given subscriber.
    ///
    /// Called from the subscriber’s `deinit` to ensure no dangling callbacks
    /// occur after the object is released.
    func unregister(subscriber: Subscriber) {
        tracker.unsubscribeFromPublishers(subscriber)
    }

    // MARK: - Publisher Lifecycle

    /// Removes all edges that point **from** the given publisher.
    ///
    /// Used when a publisher is de-initialized or when a conditional branch
    /// drops it from the active dependency set.
    func unregister(publisher: Publisher) {
        tracker.unlinkAsPublisher(publisher)
    }

    /// Records that the current tracking scope **read** `publisher`.
    ///
    /// Called by `Publisher` getters (`Atom.value`, `Derived.value`) to
    /// build the dependency graph.
    func willRead(_ publisher: Publisher) {
        tracker.link(publisher)
    }

    /// Notifies the runtime that `publisher` has **mutated**.
    ///
    /// The runtime looks up every subscriber that previously read this
    /// publisher and schedules each one to re-run.
    ///
    /// - TODO: Introduce a scheduler to coalesce burst mutations and avoid
    ///   redundant work in tight update loops.
    func didMutate(_ publisher: Publisher) {
        let subscribers = tracker.subscribers(of: publisher)
        for sub in subscribers {
            tracker.runAndSubscribe(sub)
        }
    }
}

