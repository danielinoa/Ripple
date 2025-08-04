//
//  Created by Daniel Inoa on 8/3/25.
//

/// A **side-effect** node.
///
/// An `Effect` executes its closure once *immediately* upon creation and
/// then every time any of the publishers it touched during the most-recent
/// run mutate.
///
/// Typical use cases include:
/// - Updating UIKit / SwiftUI views.
/// - Logging, analytics.
/// - Bridging Ripple state to external services.
///
/// ```swift
/// @Atom var count = 0
///
/// // Re-render a label whenever `count` changes
/// let render = Effect {
///     label.text = "Count: \(count)"
/// }
/// // keep `render` alive (e.g. store in a bag) for continuous updates
/// ```
///
/// ### Lifetime
/// Keep a strong reference to an `Effect` (e.g. store it in a collection
/// or as a property) for as long as you need the updates.
/// When the last reference is released, `deinit` automatically unregisters
/// the node so future mutations no longer trigger the closure.
///
/// ### Threading
/// `Effect` instances are expected to run on the **main actor**.
/// Perform heavy work in a detached task and commit results back on the
/// main actor if needed.
public final class Effect: Subscriber {

    // MARK: - Private state

    private let body: () -> Void

    // MARK: - Creation

    /// Creates an effect driven by `body`.
    ///
    /// The closure is executed once during initial registration and then
    /// re-executed after every relevant mutation.
    public init(_ body: @escaping () -> Void) {
        self.body = body
        Runtime.current.register(self)   // initial run + dependency capture
    }

    // MARK: - Subscriber

    /// Executes the effect’s closure.
    func run() {
        body()
    }

    // MARK: - Tear-down

    deinit {
        // Unlink from the graph on the main actor to avoid dangling edges.
        Task { @MainActor [weak self] in
            guard let self else { return }
            Runtime.current.unregister(subscriber: self)
        }
    }
}
