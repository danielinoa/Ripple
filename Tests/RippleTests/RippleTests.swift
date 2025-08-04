//
//  Created by Daniel Inoa on 8/1/25.
//

import Testing
@testable import Ripple

struct RippleTests {
    
    @Test
    func `test a simple derive`() {
        withIsolatedRuntime {
            @Atom var x = 1
            @Atom var y = 2
            @Derived var c1 = x + y
            #expect(c1 == 3)
        }
    }
    
    // Ensures: mutating a source re-runs dependents AND conditional links are re-collected
    // so the derived chain (c2 -> c1 -> [x,y]) stays correct after toggling `flag`.
    @Test
    func `test mutating dependency triggers reruns body and resets linking`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            @Atom var y = 2
            @Atom var flag = true
            @Derived var c1 = x + y
            @Derived var c2 = flag ? 0 : c1 + 1
            #expect(c2 == 0)
            
            flag = false
            #expect(c2 == 4)
            
            x = 10
            #expect(c1 == 12)
            #expect(c2 == 13)
        }
    }
    
    // Ensures: an Effect (watcher) runs once on definition and re-runs when any of its
    // tracked sources change.
    @Test
    func `test watcher`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            @Atom var y = 2
            var result: Int?
            let effect = Effect {
                result = x + y
            }
            #expect(result == 3)
            x = 2
            #expect(result == 4)
            _ = effect
        }
    }
    
    // Ensures: initial dependency collection captures *both* sources read inside the Effect.
    @Test
    func `test defining an effect with 2 signals`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            @Atom var y = 2
            var result: Int? = nil
            let effect = Effect { result = x + y }
            #expect(result == 3)
            _ = effect
        }
    }
    
    // Ensures: after the initial collection, mutating a tracked source triggers a re-run.
    @Test
    func `test defining an effect with 2 signals and a mutation`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            @Atom var y = 2
            var result: Int? = nil
            let effect = Effect { result = x + y }
            x = 10
            #expect(result == 12)
            _ = effect
        }
    }
    
    // Ensures: fan-out works; multiple Effects can subscribe to the same source and each re-run.
    // Order is not guaranteed (and not required) with the current scheduler).
    @Test
    func `test 2 effects that are dependent on the same signal`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            @Atom var y = 2
            @Atom var z = 3
            var result: Int? = nil
            let effect1 = Effect { result = x + y }
            #expect(result == 3)
            let effect2 = Effect { result = x + z }
            #expect(result == 4)
            x = 10
            #expect(result == 12 || result == 13)
            _ = (effect1, effect2)
        }
    }
    
    // Ensures: conditional dependencies “switch” correctly and old branch unsubscribes,
    // new branch subscribes, so stale sources don’t trigger.
    @Test
    func `test effect with conditional dependency`() async throws {
        withIsolatedRuntime {
            @Atom var a = 1
            @Atom var b = 2
            @Atom var flag = true
            var result: Int? = nil
            let effect = Effect {
                if flag {
                    result = a
                } else {
                    result = b
                }
            }
            
            #expect(result == 1)
            
            flag = false
            #expect(result == 2)
            
            _ = effect
        }
    }
    
    // Ensures: nested Effects attribute reads to the correct subscriber.
    // Outer depends on `a`; inner depends on `b`. Updating one should
    // only re-run the corresponding subscriber.
    @Test
    func `test nested effects`() async throws {
        withIsolatedRuntime {
            @Atom var a = 1
            @Atom var b = 10
            
            var outerRuns = 0
            var innerRuns = 0
            var inner: Effect? = nil
            
            let outer = Effect {
                _ = a
                outerRuns += 1
                
                if inner == nil {
                    inner = Effect {
                        _ = b
                        innerRuns += 1
                    }
                }
            }
            
            #expect(outerRuns == 1)
            #expect(innerRuns == 1)
            
            a = 2
            #expect(outerRuns == 2)
            #expect(innerRuns == 1)
            
            b = 11
            #expect(outerRuns == 2)
            #expect(innerRuns == 2)
            
            inner = nil
            b = 12
            #expect(innerRuns == 2)
            
            _ = outer
        }
    }
    
    // Ensures: Derived caches and recomputes on source change; reading it does not
    // cause extra recomputation by itself.
    @Test
    func `test computed`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            @Atom var y = 2
            @Derived var c: Int = x + y
            #expect(c == 3)
            x = 2
            #expect(c == 4)
        }
    }
    
    // Ensures: propagation through a chain of Derived values is correct (c2 depends on c1).
    @Test
    func `test nested computed`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            @Atom var y = 2
            @Derived var c1 = x + y
            #expect(c1 == 3)
            
            @Atom var z = 3
            @Derived var c2 = c1 + z
            #expect(c2 == 6)
            
            x = 2
            #expect(c2 == 7)
        }
    }
    
    // Ensures: same-value guard on State prevents redundant re-runs.
    @Test
    func `test same value assignment does not rerun`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            var runs = 0
            let effect = Effect { _ = x; runs += 1 }
            
            #expect(runs == 1)     // initial
            x = 1                  // same value
            #expect(runs == 1)     // no extra run
            x = 2
            #expect(runs == 2)     // changed → rerun
            _ = effect
        }
    }
    
    // Ensures: conditional dep switching drops the old branch so it no longer triggers re-runs.
    @Test
    func `test conditional deps unsubscribe previous branch`() async throws {
        withIsolatedRuntime {
            @Atom var a = 10
            @Atom var b = 20
            @Atom var flag = true
            
            var out = -1
            let effect = Effect {
                out = flag ? a : b
            }
            #expect(out == 10)
            
            flag = false
            #expect(out == 20)
            
            a = 11
            #expect(out == 20) // inactive dep should not trigger
            
            b = 21
            #expect(out == 21)
            _ = effect
        }
    }
    
    // Ensures: Derived computes once in init, does not notify on first compute,
    // and recomputes exactly once per relevant change thereafter.
    @Test
    func `test derived initial compute happens once and does not notify`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            @Atom var y = 2
            
            var computes = 0
            @Derived var c: Int = {
                computes += 1;
                return x + y
            }()
            
            #expect(c == 3)
            #expect(computes == 1) // initial compute in init
            
            var seen: Int?
            let effect = Effect { seen = c } // reading cached value; no extra compute
            #expect(seen == 3)
            #expect(computes == 1)
            
            x = 2
            #expect(seen == 4)
            #expect(computes == 2)
            _ = effect
        }
    }
    
    // Ensures: two Derived values fanning out from the same sources both update correctly.
    @Test
    func `test multiple deriveds from same sources both update`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            @Atom var y = 2
            
            @Derived var d1 = x + y   // 3
            @Derived var d2 = x * y   // 2
            
            #expect(d1 == 3)
            #expect(d2 == 2)
            
            x = 4
            #expect(d1 == 6)
            #expect(d2 == 8)
        }
    }
    
    // Ensures: chaining Deriveds produces one consistent update per change.
    @Test
    func `test derived chaining propagates once per change (functional)`() async throws {
        withIsolatedRuntime {
            @Atom var a = 1
            @Atom var b = 2
            @Derived var sum = a + b            // 3
            @Derived var double = sum * 2       // 6
            
            var observed = 0
            let effect = Effect { observed = double }
            
            #expect(observed == 6)
            a = 5
            #expect(observed == 14) // (5+2)*2
            _ = effect
        }
    }
    
    // Ensures: disposing a subscriber (Effect) removes edges so future mutations
    // neither crash nor call the deallocated subscriber.
    @Test
    func `test deallocation stops notifications`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            var runs = 0
            do {
                let effect = Effect { _ = x; runs += 1 }
                #expect(runs == 1)
                _ = effect
            } // effect deallocates here
            
            x = 2
            #expect(runs == 1) // no more notifications
        }
    }
    
    // Ensures: repeatedly toggling a condition re-links dependencies correctly each time.
    @Test
    func `test switching back and forth re-links correctly`() async throws {
        withIsolatedRuntime {
            @Atom var a = 1
            @Atom var b = 10
            @Atom var flag = true
            
            var seen = 0
            let effect = Effect {
                seen = flag ? a : b
            }
            #expect(seen == 1)
            
            flag = false
            #expect(seen == 10)
            b = 11
            #expect(seen == 11)
            
            flag = true
            #expect(seen == 1)
            a = 2
            #expect(seen == 2)
            
            b = 12 // inactive
            #expect(seen == 2)
            _ = effect
        }
    }
    
    // Ensures: an Effect can depend on both a Derived and a raw State simultaneously
    // and re-runs when either input changes.
    @Test
    func `test effect can depend on derived and raw state together`() async throws {
        withIsolatedRuntime {
            @Atom var a = 2
            @Atom var b = 3
            @Derived var sum = a + b  // 5
            
            var latest: Int = -1
            let effect = Effect {
                latest = sum * a
            }
            #expect(latest == 10)
            
            a = 4
            #expect(latest == 28) // (4+3) * 4
            
            b = 5
            #expect(latest == 36) // (4+5) * 4
            _ = effect
        }
    }
    
    // Ensures: retaining multiple effects keeps them alive; dropping references stops updates.
    @Test
    func `test effect lifetime retained vs dropped`() async throws {
        withIsolatedRuntime {
            @Atom var x = 1
            var bag: [Effect] = []
            
            var r1 = 0, r2 = 0
            bag.append(Effect { r1 = x })
            bag.append(Effect { r2 = x })
            
            #expect(r1 == 1 && r2 == 1)
            
            x = 2
            #expect(r1 == 2 && r2 == 2)
            
            // Drop one effect; only the retained one should continue updating.
            bag.removeLast()
            x = 3
            #expect(r1 == 3 && r2 == 2)
            _ = bag
        }
    }
    
    /// Ensures two isolated runtimes do **not** see each other’s mutations.
    @Test
    func `test isolated runtimes are independent`() async {
        // First runtime
        let r1Sum: Int = withIsolatedRuntime {
            @Atom var x = 1
            @Atom var y = 2
            @Derived var sum = x + y
            x = 10
            return sum          // 12
        }
        
        // Second runtime
        let r2Sum: Int = withIsolatedRuntime {
            @Atom var x = 1     // fresh atoms
            @Atom var y = 2
            @Derived var sum = x + y
            return sum          // 3
        }
        
        #expect(r1Sum == 12)
        #expect(r2Sum == 3)     // unaffected by r1’s mutation
    }
    
    /// Ensures a `Derived` whose result type is *not* `Equatable` propagates
    /// when an upstream atom changes.
    @Test
    func `test derived with non Equatable output propagates on upstream change`() {
        struct Box { let n: Int }       // not Equatable
        var computes = 0
        
        withIsolatedRuntime {
            @Atom var base = 1
            @Derived var box = { computes += 1; return Box(n: base) }()
            
            #expect(computes == 1)
            base = 2                    // different value -> mutation
            #expect(computes == 2)      // recomputed as expected
            _ = box
        }
    }
    
    
    /// Ensures a deep derived chain recomputes **once per upstream change**
    /// and yields a consistent final value.
    @Test
    func `test deep derived chain propagates once per change`() {
        withIsolatedRuntime {
            @Atom var a = 1
            @Derived var d1 = a * 2         // 2
            @Derived var d2 = d1 + 3        // 5
            @Derived var d3 = d2 * 4        // 20
            
            var runs = 0
            let effect = Effect { _ = d3; runs += 1 }
            #expect(runs == 1)
            
            a = 3                           // chain should update once
            #expect(d3 == ((3*2)+3)*4)      // 36
            #expect(runs == 2)
            
            _ = effect
        }
    }
}
