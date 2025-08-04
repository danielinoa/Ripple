//
//  Created by Daniel Inoa on 8/3/25.
//

/// A type that can be **observed** by Ripple’s runtime.
///
/// `Publisher` is adopted by value-holding nodes such as ``Atom`` and ``Derived``.
/// During an ``Effect`` runs the runtime
/// records every `Publisher` that is *read*.
/// When any of those publishers later **mutate**, the runtime re‐invokes the
/// dependent subscriber.
///
/// The protocol has no requirements; conformers simply need to be reference
/// types (`AnyObject`) so the runtime can identify them by object identity.
///
/// ### Conforming
/// Conform by adding `Publisher` to a `class` or `actor` declaration:
///
/// ```swift
/// @MainActor
/// final class Atom<T: Equatable>: Publisher { … }
/// ```
///
/// ### Identity
/// Every `Publisher` automatically exposes an ``objectIdentifier``
/// computed property, which Ripple uses as a stable graph key.
protocol Publisher: AnyObject {}

extension Publisher {
    /// A stable identifier for this publisher.
    ///
    /// Ripple uses the `ObjectIdentifier` as a key in its dependency graph.
    var objectIdentifier: ObjectIdentifier { ObjectIdentifier(self) }
}

