//
//  Created by Daniel Inoa on 8/4/25.
//

/// Thread-local container for Ripple’s *temporary* runtime override.
///
/// Most application code uses ``Runtime/current`` which resolves to the
/// process-wide singleton.  Tests and advanced scenarios can call
/// ``withIsolatedRuntime(_: )`` to execute code against a **fresh graph**
/// by storing a custom value in this `TaskLocal`.
public enum RippleContext {

    /// A per-task override for the runtime in use.
    ///
    /// * `nil` (default) → ``Runtime`` falls back to its shared singleton.
    /// * non-`nil`       → All calls to `Runtime.current` within the task
    ///   hierarchy return the provided instance.
    @TaskLocal static var runtimeOverride: Runtime?
}

/// Executes `body` on a **fresh, task-local runtime**, returning its result.
///
/// Use this in **unit tests** or ad-hoc sandboxes to ensure complete
/// isolation from the application’s singleton graph:
///
/// ```swift
/// await withIsolatedRuntime {
///     @Atom var x = 1
///     @Derived var doubled = x * 2
///     #expect(doubled == 2)
/// }
/// ```
///
/// - Remark: Child tasks created with `Task { … }` inherit the override.
///   Detached tasks (`Task.detached { … }`) do *not*; bind the value
///   manually inside the detached task if needed.
public func withIsolatedRuntime<T>(_ body: () -> T) -> T {
    let runtime = Runtime()
    return RippleContext.$runtimeOverride.withValue(runtime) { body() }
}

/// Async variant of ``withIsolatedRuntime(_:)``.
///
/// Suspends and resumes on the same task-local runtime so all awaits
/// remain inside the isolated graph.
public func withIsolatedRuntime<T>(_ body: () async throws -> T) async rethrows -> T {
    let runtime = Runtime()
    return try await RippleContext.$runtimeOverride.withValue(runtime) {
        try await body()
    }
}

/// Executes `body` using the **provided** runtime instance.
///
/// Handy when you want multiple named graphs in the same test or need
/// to share a runtime between several helper calls.
///
/// ```swift
/// let graph = Runtime()
/// withIsolatedRuntime(using: graph) { … }
/// withIsolatedRuntime(using: graph) { … } // same graph
/// ```
public func withIsolatedRuntime<T>(using runtime: Runtime, _ body: () -> T) -> T {
    RippleContext.$runtimeOverride.withValue(runtime) { body() }
}
