//
//  Created by Daniel Inoa on 8/3/25.
//

/// A **mutable value** that participates in Ripple’s dependency-tracking graph.
///
/// `AtomObject` is the fundamental “signal” type:
/// * Reading ``value`` *links* the current subscriber to this atom.
/// * Writing a **different** value *invalidates* every dependent subscriber, causing each to re-run.
///
/// Create atoms with the convenience function ``atom(_:)`` or via the
/// ``@Atom`` property wrapper for the most ergonomic syntax.
///
/// ```swift
/// @Atom var count = 0                 // property-wrapper form
/// let temperature = atom(72)          // factory form
/// ```
///
/// > Tip: `AtomObject` is confined to the **main actor** by convention.
/// > Heavy work should occur off-thread and commit back via
/// > `await MainActor.run { atom.value = newValue }`.
public final class AtomObject<T: Equatable>: Publisher {

    // MARK: - Storage

    private var storage: T

    /// The atom’s current value.
    ///
    /// - Accessing `value` records a “read” so the runtime can establish a
    ///   dependency edge from the *current* subscriber to this atom.
    /// - Setting `value` to a **new** value (as determined by `==`) records
    ///   a mutation and schedules every dependent subscriber to re-run.
    public var value: T {
        get {
            Runtime.current.willRead(self)
            return storage
        }
        set {
            guard newValue != storage else { return }
            storage = newValue
            Runtime.current.didMutate(self)
        }
    }

    /// Creates an atom pre-populated with `value`.
    ///
    /// Use the free function ``atom(_:)`` instead for cleaner call-sites
    /// unless you need explicit type inference.
    public init(_ value: T) {
        self.storage = value
    }

    // MARK: - Graph clean-up

    deinit {
        // Hop to the main actor to unlink this publisher safely.
        Task { @MainActor [weak self] in
            guard let self else { return }
            Runtime.current.unregister(publisher: self)
        }
    }
}

/// Creates a new ``AtomObject`` that stores `value`.
///
/// Preferred over calling `AtomObject`’s initializer directly.
///
/// ```swift
/// let score = atom(0)
/// score.value += 1
/// ```
public func atom<T: Equatable>(_ value: T) -> AtomObject<T> {
    .init(value)
}
