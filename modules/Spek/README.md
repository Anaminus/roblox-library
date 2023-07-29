# Spek
[Spek]: #spek

All-in-one module for testing and benchmarking.

## Speks
A specification or **spek** is a module that defines requirements (tests) and
measurements (benchmarks). As a Roblox instance, a spek is any ModuleScript
whose Name has the `.spek` suffix.

The principle value returned by a module is a **definition**, or a function
that receives a [T][T] object. A table of definitions can be returned
instead. The full definition for the returned value is as follows:

```lua
type Spek = Definition | {[any]: Spek}
type Definition = (t: T) -> ()
```

Each definition function specifies a discrete set of units that remain
grouped together and separated from other definitions. For example, when
specifying benchmarks, measurements that belong to the same definition will
be tabulated into one table, and wont mix with measurements from other
definitions.

The following can be used as a template for writing a spek:

```lua
-- Optional; used only to get exported types.
local Spek = require(game:FindFirstDescendant("Spek"))
-- Require dependencies as usual.
local Eieren = require(script.Parent.Eieren)

return function(t: Spek.T)
	--TODO: Test Eieren module.
end
```

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Spek][Spek]
	1. [Spek.find][Spek.find]
	2. [Spek.runner][Spek.runner]
2. [T][T]
	1. [T.after_each][T.after_each]
	2. [T.before_each][T.before_each]
	3. [T.describe][T.describe]
	4. [T.expect][T.expect]
	5. [T.expect_error][T.expect_error]
	6. [T.it][T.it]
	7. [T.measure][T.measure]
	8. [T.operation][T.operation]
	9. [T.parameter][T.parameter]
	10. [T.report][T.report]
	11. [T.reset_timer][T.reset_timer]
	12. [T.start_timer][T.start_timer]
	13. [T.stop_timer][T.stop_timer]
3. [Runner][Runner]
	1. [Runner.Keys][Runner.Keys]
	2. [Runner.Metrics][Runner.Metrics]
	3. [Runner.ObserveMetric][Runner.ObserveMetric]
	4. [Runner.ObserveResult][Runner.ObserveResult]
	5. [Runner.Reset][Runner.Reset]
	6. [Runner.Run][Runner.Run]
	7. [Runner.Running][Runner.Running]
	8. [Runner.Start][Runner.Start]
	9. [Runner.Stop][Runner.Stop]
	10. [Runner.Value][Runner.Value]
	11. [Runner.Wait][Runner.Wait]
4. [Path][Path]
	1. [Path.Base][Path.Base]
	2. [Path.Elements][Path.Elements]

</td></tr></tbody>
</table>

## Spek.find
[Spek.find]: #spekfind
```
function Spek.find(root: Instance): {ModuleScript}
```

Locates speks under a given instance.

## Spek.runner
[Spek.runner]: #spekrunner
```
function Spek.runner(speks: {ModuleScript}): Runner
```

Creates a new [Runner][Runner].

# T
[T]: #t
```
type T
```

Contains functions used to define a spek.

These functions are not methods, so its safe to call them as-is. It is also
safe to store them in variables for convenience.

```lua
return function(t: Spek.T)
	local describe = t.describe
	describe "can be stored in a variable" (function()end)

	t.describe "or can be called as-is" (function()end)
end
```

## Test functions

Some functions are "Statements". A statement is a function that receives a
value of some specified type.

```lua
return function(t: Spek.T)
	-- A Statement<Closure>, so it is a function that receives a Closure.
	t.before_each(function()end)
end
```

Some functions are "Clauses". A Clause can be a regular Statement, or it can
be a function that receives a string. If the latter, it returns a Statement.
This enables several syntaxes for annotating a function with an optional
description:

```lua
return function(t: Spek.T)
	t.describe "clause with a description" (function()end)

	-- Clause without a description.
	t.describe(function()end)
end
```

A Closure is a function that is expected to receive no arguments and return
no values. Typically it uses upvalues to further define the spek within the
context of the outer function.

```lua
return function(t: Spek.T)
	t.describe "uses a closure" (function()
		t.it "further defines within this context" (function()end)
	end)
end
```

An Assertion is like a Closure, except that it is expected to return a value
to be asserted.

```lua
return function(t: Spek.T)
	t.it "makes an assertion" (function()
		t.assert "that pi is a number" (function()
			return type(math.pi) == "number"
		end)
	end)
end
```

Certain functions may only be called in certain contexts. For example,
[expect][T.expect] may only be called within an [it][T.it] closure. Each
description of a function lists where the function is allowed to be called.
Some functions are allowed to be called anywhere. The root definition
function behaves the same as [describe][T.describe].

## Benchmark functions

The [measure][T.measure] function defines a benchmark.

TODO: finish T docs

## T.after_each
[T.after_each]: #tafter_each
```
after_each: Statement<Closure>
```

**Within:** definition, [describe][T.describe]

Defines a function to call after each unit, scoped to the context.

## T.before_each
[T.before_each]: #tbefore_each
```
before_each: Statement<Closure>
```

**Within:** definition, [describe][T.describe]

Defines function to call before each unit, scoped to the context.

## T.describe
[T.describe]: #tdescribe
```
describe: Clause<Closure>
```

**Within:** definition, [describe][T.describe]

Defines a new context for a test or benchmark.

## T.expect
[T.expect]: #texpect
```
expect: Clause<Assertion>
```

**Within:** [it][T.it]

Expects the result of an assertion to be truthy.

## T.expect_error
[T.expect_error]: #texpect_error
```
expect_error: Clause<Closure>
```

**Within:** [it][T.it]

Expects the closure to throw an error.

## T.it
[T.it]: #tit
```
it: Clause<Closure>
```

**Within:** definition, [describe][T.describe]

Defines a new test unit.

## T.measure
[T.measure]: #tmeasure
```
measure: BenchmarkClause
```

**Within:** definition, [describe][T.describe]

Defines a new benchmark unit.

## T.operation
[T.operation]: #toperation
```
operation: Clause<Closure>
```

**Within:** [measure][T.measure] (only once)

Defines the operation of a benchmark unit that is being measured. This
operation is run repeatedly.

## T.parameter
[T.parameter]: #tparameter
```
parameter: ParameterClause
```

**Within:** definition, [describe][T.describe]

Defines a parameter symbol that can be passed to [measure][T.measure].

## T.report
[T.report]: #treport
```
report: Clause<number>
```

**Within:** anything

Reports a user-defined metric. Any previously reported value will be
overridden.

The description determines the unit of the reported value, which is
user-defined. If the description has a specific suffix, the value is
altered:

- `/op`: Value is divided by the number of operations performed by the
  unit (1 for tests, many for benchmarks).
- `/us`: Value is divided by the number microseconds elapsed during the
  unit.
- `/ms`: Value is divided by the number milliseconds elapsed during the
  unit.
- `/s`: Value is divided by the number seconds elapsed during the
  unit.
- (no suffix): Value is reported as-is.

**Examples:**

```lua
report "compares" (compares) -- Report value per unit.
report "compares/op" (compares) -- Report value per operation.
report "compares/s" (compares) -- Report value per second.
```

## T.reset_timer
[T.reset_timer]: #treset_timer
```
reset_timer: () -> ()
```

**Within:** anything

Resets the unit's elapsed time and all metrics. Does not affect whether
the timer is running.

## T.start_timer
[T.start_timer]: #tstart_timer
```
start_timer: () -> ()
```

**Within:** anything

Starts or resumes the unit timer.

## T.stop_timer
[T.stop_timer]: #tstop_timer
```
stop_timer: () -> ()
```

**Within:** anything

Stops the unit timer.

# Runner
[Runner]: #runner
```
type Runner
```

Used to run speks. The results are represented as a tree. Each node in
the tree has a key, and can be visited using a path.

Converting to a string displays formatted results of the last run. Metrics
are tabulated per definition.

Note that the runner requires spek modules as-is.

## Runner.Keys
[Runner.Keys]: #runnerkeys
```
function Runner:Keys()
```

Returns keys that exist under *path* as a list of absolute paths. If
*path* is nil, the root keys are returned. Returns nil if *path* does not
exist.

## Runner.Metrics
[Runner.Metrics]: #runnermetrics
```
function Runner:Metrics()
```

Returns a snapshot of the metrics at *path*. Returns false if the result
is not yet ready. Returns nil if *path* does not exist or does not have a
result.

## Runner.ObserveMetric
[Runner.ObserveMetric]: #runnerobservemetric
```
function Runner:ObserveMetric()
```

Sets an observer to be called whenever a single metric changes. Returns
a function that removes the observer when called.

## Runner.ObserveResult
[Runner.ObserveResult]: #runnerobserveresult
```
function Runner:ObserveResult()
```

Sets an observer to be called whenever a result changes. Returns a
function that removes the observer when called.

## Runner.Reset
[Runner.Reset]: #runnerreset
```
function Runner:Reset()
```

Clears all results.

## Runner.Run
[Runner.Run]: #runnerrun
```
function Runner:Run()
```

Runs the spek and waits for it to complete. Errors if the runner is
already active.

## Runner.Running
[Runner.Running]: #runnerrunning
```
function Runner:Running(): boolean
```

Returns whether the runner is currently active.

## Runner.Start
[Runner.Start]: #runnerstart
```
function Runner:Start()
```

Begins running spek without waiting for it to complete. Errors if the
runner is already active.

## Runner.Stop
[Runner.Stop]: #runnerstop
```
function Runner:Stop()
```

Stops the runner, canceling all pending units. Does nothing if the
runner is not running.

## Runner.Value
[Runner.Value]: #runnervalue
```
function Runner:Value()
```

Returns the current result at *path*. Returns false if the result is not
yet ready. Returns nil if *path* does not exist or does not have a result.

## Runner.Wait
[Runner.Wait]: #runnerwait
```
function Runner:Wait()
```

Waits for the runner to complete. Does nothing if the runner is not
active.

# Path
[Path]: #path
```
type Path
```

A unique symbol representing a path referring to a value within a result
tree. Converting to a string displays a formatted path.

## Path.Base
[Path.Base]: #pathbase
```
function Path:Base(): any
```

Returns the last element of the path.

## Path.Elements
[Path.Elements]: #pathelements
```
function Path:Elements(): {any}
```

Returns the path as a list of elements.

