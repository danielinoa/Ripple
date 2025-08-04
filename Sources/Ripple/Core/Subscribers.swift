//
//  Created by Daniel Inoa on 8/4/25.
//

/// A lightweight, *weak* set of subscribers.
///
/// `Subscribers` stores each subscriber in a `WeakSubscriber` wrapper so
/// the runtime never keeps objects alive longer than necessary.
/// When the underlying subscriber de-allocates, the wrapper’s
/// `subscriber` property becomes `nil` and the next access automatically
/// filters it out.
///
/// The collection:
/// * guarantees *uniqueness* (`Set` semantics based on object identity);
/// * offers `insert`, `remove`, and `isEmpty`; and
/// * can be created with array-literal syntax for convenience:
///
/// ```swift
/// let list: Subscribers = [effect1, effect2]
/// ```
///
/// > **Note:** Ordering is currently undefined (`Set`); replace the
/// > storage with an ordered set if deterministic run order is desired.
struct Subscribers: ExpressibleByArrayLiteral {

    // MARK: - Storage

    /// The backing store – a set of weak boxes keyed by subscriber
    /// identity.
    private var storage: Set<WeakSubscriber> = []     // TODO: consider ordered set

    // MARK: - Public API

    /// A strong array of the *currently alive* subscribers.
    ///
    /// Dead entries are skipped.
    var subscribers: [any Subscriber] {
        Array(storage.compactMap(\.subscriber))
    }
    
    /// `true` when the set contains **no live subscribers**.
    var isEmpty: Bool { storage.isEmpty }

    // MARK: - ExpressibleByArrayLiteral

    init(arrayLiteral elements: Subscriber...) {
        storage = .init(elements.map { $0.weakBoxed() })
    }

    /// Inserts `subscriber` if it is not already present.
    mutating func insert(_ subscriber: any Subscriber) {
        storage.insert(subscriber.weakBoxed())
    }

    /// Removes `subscriber` and returns it, or `nil` if it was not found.
    @discardableResult
    mutating func remove<S: Subscriber>(_ subscriber: S) -> Subscriber? {
        storage.remove(subscriber.weakBoxed())?.subscriber
    }
}

/// A wrapper that holds a **weak** reference to a subscriber while
/// remaining hashable by its original object identity.
fileprivate final class WeakSubscriber: Hashable {

    /// The referenced subscriber, or `nil` if it has been deallocated.
    private(set) weak var subscriber: (any Subscriber)?

    /// Cached identifier for stable hashing after the subscriber deallocs.
    private let subscriberIdentifier: ObjectIdentifier

    init(_ subscriber: any Subscriber) {
        self.subscriber = subscriber
        self.subscriberIdentifier = subscriber.objectIdentifier
    }

    // MARK: Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(subscriberIdentifier)
    }

    static func == (lhs: WeakSubscriber, rhs: WeakSubscriber) -> Bool {
        lhs.subscriberIdentifier == rhs.subscriberIdentifier
    }
}

// MARK: - Helper for boxing

fileprivate extension Subscriber {
    /// Returns a new `WeakSubscriber` that wraps `self`.
    func weakBoxed() -> WeakSubscriber { .init(self) }
}
