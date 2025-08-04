//
//  Created by Daniel Inoa on 8/4/25.
//

/// Wrap any expression in `@Derived` to obtain a cached, auto-updating
/// value.
///
/// ```swift
/// @Atom var x = 1
/// @Atom var y = 2
///
/// @Derived var sum = x + y
/// print(sum)            // 3
///
/// x = 10
/// print(sum)            // 12 (re-evaluated automatically)
/// ```
@propertyWrapper
public struct Derived<T> {

    /// The underlying ``Derivation`` node (`$property` gives you direct access).
    public var projectedValue: Self { self }

    /// The current cached value.
    public var wrappedValue: T { derivation.value }

    // MARK: - Private storage

    private var derivation: Derivation<T>

    /// Wraps `value` (captured as an autoclosure) in a derived node.
    public init(wrappedValue value: @escaping @autoclosure () -> T) {
        derivation = Derivation(value)
    }
}
