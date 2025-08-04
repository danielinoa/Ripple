//
//  Created by Daniel Inoa on 8/3/25.
//

/// Maintains Ripple’s **dependency graph**: a bi-directional mapping
/// between every `Publisher` and the `Subscriber`s that currently rely on it.
///
/// The tracker’s responsibilities:
/// 1. **Linking** – When a publisher is *read*, ``link(_:)`` records an
///    edge from the *current* subscriber (at the top of
///    ``subscriberStack``) to that publisher.
/// 2. **Running** – ``runAndSubscribe(_:)`` executes a subscriber,
///    collects the fresh dependency set, and updates the graph
///    atomically.
/// 3. **Unlinking** – When a subscriber or publisher goes away (or when
///    a subscriber is about to re-run) the tracker removes the obsolete
///    edges so future mutations don’t reference stale objects.
///
/// > Note: `Tracker` is used exclusively from the **main actor** by
/// > design; no internal synchronisation is required.
final class Tracker {

    // MARK: Internal storage

    private typealias PublisherID   = ObjectIdentifier
    private typealias SubscriberID  = ObjectIdentifier

    /// Forward index: *publisher → subscribers*.
    private var subscribersByPublisherId: [PublisherID: Subscribers] = [:]

    /// Reverse index: *subscriber → publishers*.
    private var publisherIdsBySubscriberId: [SubscriberID: Set<PublisherID>] = [:]

    /// Nestable “who’s running” stack; enables correct linking when a
    /// subscriber triggers another subscriber (e.g., a computed
    /// value inside another computed value).
    private var subscriberStack: Stack<any Subscriber> = []

    // MARK: - Associations

    /// Adds an edge **publisher → current subscriber** if a tracking
    /// scope is active.
    ///
    /// Called from `Publisher` getters (`AtomObject.value`,
    /// `Derivation.value`) to record each read during a subscriber’s run.
    func link(_ publisher: Publisher) {
        guard let subscriber = subscriberStack.peek else { return }
        guard subscriber !== publisher else {
            fatalError("\(publisher) should not associate to itself")
        }
        subscribersByPublisherId[publisher.objectIdentifier, default: []].insert(subscriber)
        publisherIdsBySubscriberId[subscriber.objectIdentifier, default: []]
            .insert(publisher.objectIdentifier)
    }

    /// Executes `subscriber`, refreshes its dependency set, and updates
    /// both the forward and reverse indices.
    ///
    /// Steps:
    /// 1. Remove any **stale** edges from a previous run.
    /// 2. Push `subscriber` so nested reads link correctly.
    /// 3. Invoke `run()` (which performs the user work and reads
    ///    publishers, thereby calling ``link(_:)``).
    /// 4. Pop and sanity-check stack integrity.
    func runAndSubscribe(_ subscriber: any Subscriber) {
        // 1. Clear stale dependencies
        unsubscribeFromPublishers(subscriber)

        // 2–4. Execute with stack bookkeeping
        subscriberStack.push(subscriber)
        subscriber.run()
        let processed = subscriberStack.pop()

        if subscriber !== processed {
            fatalError("Expected \(subscriber) to be last in stack after being processed")
        }
    }

    /// Removes **all** edges originating from `subscriber`.
    ///
    /// Called when a subscriber is about to re-run or when it is
    /// de-initialised.
    func unsubscribeFromPublishers(_ subscriber: any Subscriber) {
        guard let publisherIds = publisherIdsBySubscriberId
                .removeValue(forKey: subscriber.objectIdentifier) else { return }

        for publisherId in publisherIds {
            subscribersByPublisherId[publisherId]?.remove(subscriber)
            if subscribersByPublisherId[publisherId]?.isEmpty == true {
                subscribersByPublisherId.removeValue(forKey: publisherId)
            }
        }
    }

    /// Removes **all** subscribers linked to `publisher`.
    ///
    /// Invoked from a publisher’s `deinit` so the graph never keeps a
    /// dangling reference.
    func unlinkAsPublisher(_ publisher: Publisher) {
        subscribersByPublisherId.removeValue(forKey: publisher.objectIdentifier)
    }

    /// Returns the list of subscribers currently dependent on `publisher`.
    func subscribers(of publisher: Publisher) -> [any Subscriber] {
        subscribersByPublisherId[publisher.objectIdentifier]?.subscribers ?? []
    }
}
