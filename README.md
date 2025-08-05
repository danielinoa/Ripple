
# Ripple

A tiny, dependency-tracked reactivity runtime for Swift.
Use `@Atom` for mutable state, `@Derived` for cached computations, and `Effect` for side-effects. Ripple automatically records **what you read** while code runs, and **re-runs** dependents when those values change—no manual wiring.

---

## Outline ▸ Quick links
- [Ripple](#ripple)
  - [Outline ▸ Quick links](#outline-quick-links)
  - [Features](#features)
  - [Installation](#installation)
    - [Swift Package Manager](#swift-package-manager)
  - [Quick start](#quick-start)
  - [Concepts](#concepts)
    - [`@Atom` — mutable, tracked state](#atom--mutable-tracked-state)
    - [`@Derived` — cached, re-evaluated value](#derived--cached-re-evaluated-value)
    - [`Effect` — side-effects that follow your data](#effect--side-effects-that-follow-your-data)
  - [Testing \& isolation](#testing--isolation)
  - [Threading model](#threading-model)
  - [Behavior details](#behavior-details)
  - [API surface (public types)](#api-surface-public-types)
  - [Examples](#examples)
    - [UIKit binding](#uikit-binding)
    - [Chained derived values](#chained-derived-values)
    - [Parallel-safe tests](#parallel-safe-tests)
  - [Notes \& roadmap](#notes--roadmap)
  - [License](#license)
- [MIT License](#mit-license)

---

## Features
* **Ergonomic API** — `@Atom var count = 0`, `@Derived var title = "Count: \(count)"`.
* **Fine-grained tracking** — only recompute what actually depends on what changed.
* **Memoized computed values** — `@Derived` caches and invalidates on upstream mutations.
* **Side effects** — `Effect { … }` runs once up-front and whenever its inputs change.
* **Test isolation** — `withIsolatedRuntime { … }` gives each test a fresh graph.
* **No macros, no Combine** — simple value semantics and identity-based graphs.

---

## Installation

### Swift Package Manager
Add the package in Xcode (**File → Add Packages…**) or declare it in `Package.swift`:

```swift
.package(url: "https://github.com/danielinoa/Ripple.git", from: "0.1.0"),
```

---

## Quick start

```swift
import Ripple

@Atom var count = 0
@Derived var title = "Count: \(count)"

let render = Effect {                // keep the Effect alive
    label.text = title               // auto-updates when count changes
}

count += 1                            // → title recomputes → effect runs
```

---

## Concepts

### `@Atom` — mutable, tracked state
```swift
@Atom var name = "Ripple"
name = "Ripple 2"           // notifies dependents if value actually changed
print($name)                // `$` exposes the AtomObject
```
* Reads link the current subscriber.
* Writes call `Runtime.didMutate` **only if the value changes** (`Equatable`).

### `@Derived` — cached, re-evaluated value
```swift
@Atom var x = 1
@Atom var y = 2
@Derived var sum = x + y     // cached until x or y mutates
```
If `T : Equatable`, Ripple skips propagation when the recomputed value equals the cached one.

### `Effect` — side-effects that follow your data
```swift
@Atom var count = 0
var bag: [Effect] = []

bag.append(Effect {
    label.text = "Count: \(count)"
})
```
Runs once on creation and after every relevant mutation.

---

## Testing & isolation

```swift
@Test
func example() {
    withIsolatedRuntime {
        @Atom var a = 1
        @Derived var doubled = a * 2
        #expect(doubled == 2)
    }
}
```
`withIsolatedRuntime` (sync & async overloads) swaps `Runtime.current` with a fresh graph for the duration of the task tree.

---

## Threading model
Ripple is designed to run on the **main actor**.

```swift
Task.detached {
    let heavy = await expensiveWork()
    await MainActor.run { count = heavy }
}
```

---

## Behavior details
| Item | Behaviour |
|------|-----------|
| **Atom writes** | Notify dependents only when `newValue != oldValue`. |
| **Derived cache** | Recompute on first read or after any dependency mutates. |
| **Derived equality** | If `T : Equatable`, skip propagation when value is unchanged. |
| **Effect lifetime** | Runs while at least one strong reference exists; unsubscribes on deinit. |

---

## API surface (public types)

```swift
protocol Publisher : AnyObject                // identity + helper
protocol Subscriber : AnyObject { func run() }

final class Runtime {
    static var current: Runtime
    func register(_ subscriber: Subscriber)
    func unregister(subscriber: Subscriber)
    func unregister(publisher: Publisher)
    func willRead(_ publisher: Publisher)
    func didMutate(_ publisher: Publisher)
}

final class AtomObject<T: Equatable> : Publisher {
    public var value: T
}
func atom<T: Equatable>(_ value: T) -> AtomObject<T>

@propertyWrapper struct Atom<T: Equatable> {
    var wrappedValue: T
    var projectedValue: AtomObject<T>
}

final class Derivation<T> : Publisher, Subscriber {
    var value: T                    // read-only
    func run()
}
func derive<T>(_ body: @escaping () -> T) -> Derivation<T>

@propertyWrapper struct Derived<T> {
    var wrappedValue: T
    var projectedValue: Derived<T>
}

final class Effect : Subscriber {
    init(_ body: @escaping () -> Void)
    func run()
}

// Test helpers
enum RippleContext { @TaskLocal static var runtimeOverride: Runtime? }
func withIsolatedRuntime<T>(_ body: () -> T) -> T
func withIsolatedRuntime<T>(_ body: () async throws -> T) async rethrows -> T
func withIsolatedRuntime<T>(using: Runtime, _ body: () -> T) -> T
```

---

## Examples

### UIKit binding
```swift
final class CounterVC: UIViewController {
    private var label: UILabel = .init()
    private var bag: [Effect] = []

    @Atom
    private var count = 0
    
    @Derived
    private var title = "Count: \(count)"

    override func viewDidLoad() {
        super.viewDidLoad()
        bag.append(Effect { self.label.text = self.title })
    }

    private func plus() { count += 1 }
}
```

### Chained derived values
```swift
@Atom var a = 1
@Derived var d1 = a * 2          // 2
@Derived var d2 = d1 + 3         // 5
@Derived var d3 = d2 * 4         // 20
let e = Effect { print(d3) }     // prints 20, then 36 when a = 3
```

### Parallel-safe tests
```swift
@Test
func isolatedGraphs() async {
  let r1: Int = await withIsolatedRuntime {
    @Atom var x = 1; @Atom var y = 2; @Derived var s = x + y; return s
  }
  let r2: Int = await withIsolatedRuntime {
    @Atom var x = 10; @Atom var y = 20; @Derived var s = x + y; return s
  }
  #expect(r1 == 3 && r2 == 30)
}
```

---

## Notes & roadmap
* **Scheduler** — future: coalesce burst mutations into a single run loop pass.
* **Deterministic order** — `Subscribers` currently uses an unordered `Set`.

---

## License

### MIT License

Copyright (c) 2025 Daniel Inoa

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

