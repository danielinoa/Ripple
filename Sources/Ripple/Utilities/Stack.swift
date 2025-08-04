//
//  Created by Daniel Inoa on 8/3/25.
//

/// A simple **LIFO stack** value type that supports push, pop, and peek
/// operations.
///
/// ```swift
/// var stack: Stack<Int> = [1, 2, 3] // top-of-stack == 3
/// stack.push(4)                     // [1, 2, 3, 4]
/// let top = stack.pop()             // returns 4, stack is now [1, 2, 3]
/// print(stack.peek)                 // Optional(3)
/// ```
///
/// You can also create a stack from an existing array:
///
/// ```swift
/// let s = Stack([.north, .south, .east])
/// ```
struct Stack<Element>: ExpressibleByArrayLiteral {

    // MARK: - Storage

    private var elements: [Element] = []

    /// Creates a stack pre-populated with `elements`.
    init(_ elements: [Element]) {
        self.elements = elements
    }
    
    // MARK: - ExpressibleByArrayLiteral

    typealias ArrayLiteralElement = Element

    /// Creates a stack from an array literal.
    ///
    /// The last literal element becomes the **top** of the stack.
    init(arrayLiteral elements: Element...) {
        self.elements = elements
    }

    // MARK: - Mutating operations

    /// Pushes `newElement` onto the **top** of the stack.
    mutating func push(_ newElement: Element) {
        elements.append(newElement)
    }

    /// Removes and returns the **top** element.
    ///
    /// Returns `nil` if the stack is empty.
    mutating func pop() -> Element? {
        elements.popLast()
    }

    // MARK: - Inspection

    /// The element at the **top** of the stack without removing it, or
    /// `nil` if the stack is empty.
    var peek: Element? {
        elements.last
    }
}
