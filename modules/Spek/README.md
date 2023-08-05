# Spek
[Spek]: #spek

All-in-one module for testing and benchmarking.

## Speks

A specification or **spek** is a module that defines requirements (tests) and
measurements (benchmarks). As a Roblox instance, a spek is any ModuleScript
whose Name has the `.spek` suffix.

The principle value returned by a module is a **plan**, or a function that
receives a [T][T] object. A table of plans can be returned instead.
ModuleScripts may also be returned, which will be required as speks. The full
definition for the returned value is as follows:

```lua
type Input = Plan | ModuleScript | {[any]: Input}
type Plan = (t: T) -> ()
```

Each plan function specifies a discrete set of units that remain grouped
together and separated from other plans. For example, when specifying
benchmarks, measurements that belong to the same plan will be tabulated into
one table, and wont mix with measurements from other plans.

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
2. [UnitConfig][UnitConfig]
3. [T][T]
	1. [T.TODO][T.TODO]
	2. [T.after_each][T.after_each]
	3. [T.before_each][T.before_each]
	4. [T.describe][T.describe]
	5. [T.expect][T.expect]
	6. [T.expect_error][T.expect_error]
	7. [T.it][T.it]
	8. [T.measure][T.measure]
	9. [T.operation][T.operation]
	10. [T.parameter][T.parameter]
	11. [T.report][T.report]
	12. [T.reset_timer][T.reset_timer]
	13. [T.start_timer][T.start_timer]
	14. [T.stop_timer][T.stop_timer]
4. [Runner][Runner]
	1. [Runner.All][Runner.All]
	2. [Runner.Metrics][Runner.Metrics]
	3. [Runner.ObserveMetric][Runner.ObserveMetric]
	4. [Runner.ObserveResult][Runner.ObserveResult]
	5. [Runner.Paths][Runner.Paths]
	6. [Runner.Reset][Runner.Reset]
	7. [Runner.Result][Runner.Result]
	8. [Runner.Root][Runner.Root]
	9. [Runner.Run][Runner.Run]
	10. [Runner.Running][Runner.Running]
	11. [Runner.Start][Runner.Start]
	12. [Runner.Stop][Runner.Stop]
	13. [Runner.Wait][Runner.Wait]
5. [Assertion][Assertion]
6. [Benchmark][Benchmark]
7. [BenchmarkClause][BenchmarkClause]
8. [Clause][Clause]
9. [Closure][Closure]
10. [Input][Input]
11. [MetricObserver][MetricObserver]
12. [Metrics][Metrics]
13. [Parameter][Parameter]
14. [ParameterClause][ParameterClause]
15. [Path][Path]
	1. [Path.Base][Path.Base]
	2. [Path.Elements][Path.Elements]
16. [Plan][Plan]
17. [Result][Result]
18. [ResultObserver][ResultObserver]
19. [ResultType][ResultType]
20. [Unsubscribe][Unsubscribe]

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
function Spek.runner(input: Input, config: UnitConfig?): Runner
```

Creates a new [Runner][Runner] that runs the given [Input][Input]. An
optional [UnitConfig][UnitConfig] configures how units are run.

# UnitConfig
[UnitConfig]: #unitconfig
```
type UnitConfig = {
	Iterations: number?,
	Duration: number?,
}
```

Configures options for running a unit.

Field      | Type    | Description
-----------|---------|------------
Iterations | number? | Target iterations for each benchmark. If unspecified, Duration is used.
Duration   | number? | Target duration for each benchmark, in seconds. Defaults to 1.

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

Certain functions may only be called within certain **contexts**. For
example, [expect][T.expect] may only be called while testing, so it should
only be called within an [it][T.it] closure. Each description of a function
lists which contexts the function is allowed to be called. Some functions are
allowed to be called anywhere.

The following contexts are available:

- **planning**: While processing the current [Plan][Plan].
- **testing**: While running a test.
- **benchmarking**: While running a benchmark.

## Benchmark functions

The [measure][T.measure] function defines a benchmark.

TODO: finish T docs

## T.TODO
[T.TODO]: #ttodo
```
TODO: (format: string?, ...any) -> ()
```

Produces an okay result, but with a reason indicating that the plan
or statement is not yet implemented. May optionally specify a formatted
message as the reason.

## T.after_each
[T.after_each]: #tafter_each
```
after_each: Statement<Closure>
```

**While:** planning

Defines a function to call after each unit within the scope. The closure
is called while testing or benchmarking.

## T.before_each
[T.before_each]: #tbefore_each
```
before_each: Statement<Closure>
```

**While:** planning

Defines function to call before each unit within the scope. The closure
is called while testing or benchmarking.

## T.describe
[T.describe]: #tdescribe
```
describe: Clause<Closure>
```

**While:** planning

Defines a new scope for a test or benchmark. The closure is called
immediately, while planning.

## T.expect
[T.expect]: #texpect
```
expect: Clause<Assertion>
```

**While:** testing

Expects the result of an assertion to be truthy. The closure is called
while testing.

## T.expect_error
[T.expect_error]: #texpect_error
```
expect_error: Clause<Closure>
```

**While:** testing

Expects the closure to throw an error. The closure is called while
testing.

## T.it
[T.it]: #tit
```
it: Clause<Closure>
```

**While:** planning

Defines a new test unit. The closure is called while testing.

## T.measure
[T.measure]: #tmeasure
```
measure: BenchmarkClause
```

**While:** planning

Defines a new benchmark unit. The closure is called while benchmarking.

## T.operation
[T.operation]: #toperation
```
operation: Clause<Closure>
```

**While:** benchmarking (only once)

Defines the operation of a benchmark unit that is being measured. This
operation is run repeatedly. The operation is called while benchmarking.
This function must only be called once per benchmark.

## T.parameter
[T.parameter]: #tparameter
```
parameter: ParameterClause
```

**While:** planning

Defines a parameter symbol that can be passed to [measure][T.measure].

## T.report
[T.report]: #treport
```
report: Detailed<number>
```

**While:** (doing anything)

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

**While:** (doing anything)

Resets the unit's elapsed time and all metrics. Does not affect whether
the timer is running.

## T.start_timer
[T.start_timer]: #tstart_timer
```
start_timer: () -> ()
```

**While:** (doing anything)

Starts or resumes the unit timer.

## T.stop_timer
[T.stop_timer]: #tstop_timer
```
stop_timer: () -> ()
```

**While:** (doing anything)

Stops the unit timer.

# Runner
[Runner]: #runner
```
type Runner
```

Used to run speks. The results are represented as a tree. Each node in
the tree has a key, and can be visited using a path.

Converting to a string displays formatted results of the last run. Metrics
are tabulated per plan.

Note that the runner requires spek modules as-is.

## Runner.All
[Runner.All]: #runnerall
```
function Runner:All(): {Path}
```

Returns a list of all paths in the runner. Paths are sorted by their
string representation.

## Runner.Metrics
[Runner.Metrics]: #runnermetrics
```
function Runner:Metrics(path: Path): Metrics?
```

Returns a snapshot of the [metrics][Metrics] at *path*. Returns nil if
*path* does not exist or does not have a result.

## Runner.ObserveMetric
[Runner.ObserveMetric]: #runnerobservemetric
```
function Runner:ObserveMetric(observer: MetricObserver): Unsubscribe
```

Sets an observer to be called whenever a single metric changes. Returns
a function that removes the observer when called.

## Runner.ObserveResult
[Runner.ObserveResult]: #runnerobserveresult
```
function Runner:ObserveResult(observer: ResultObserver): Unsubscribe
```

Sets an observer to be called whenever a result changes. Returns a
function that removes the observer when called.

## Runner.Paths
[Runner.Paths]: #runnerpaths
```
function Runner:Paths(path: Path): {Path}?
```

Returns paths of nodes that exist under the node of *path*. Returns nil
if *path* does not exist.

## Runner.Reset
[Runner.Reset]: #runnerreset
```
function Runner:Reset()
```

Clears all results.

## Runner.Result
[Runner.Result]: #runnerresult
```
function Runner:Result(path: Path): Result?
```

Returns the current [result][Result] at *path*. Returns nil if *path*
does not exist or does not have a result.

## Runner.Root
[Runner.Root]: #runnerroot
```
function Runner:Root(): Path
```

Returns the [Path][Path] of the root node. The path contains zero
elements.

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

## Runner.Wait
[Runner.Wait]: #runnerwait
```
function Runner:Wait()
```

Waits for the runner to complete. Does nothing if the runner is not
active.

# Assertion
[Assertion]: #assertion
```
type Assertion = () -> any
```

Like a [Closure][Closure], except the caller expects a truthy or falsy
result. If an optional second value is returned with a falsy result, then it
will be used as the reason.

# Benchmark
[Benchmark]: #benchmark
```
type Benchmark = (...any) -> ()
```

Like a [Closure][Closure], but receives values corresponding to the
[Parameters][Parameter] passed to [BenchmarkClause][BenchmarkClause].

# BenchmarkClause
[BenchmarkClause]: #benchmarkclause
```
type BenchmarkClause = BenchmarkStatement & BenchmarkDetailed
```

Variation of clause and statement for benchmarks, which receives a
[Benchmark][Benchmark] and a variable number of specific
[Parameter][Parameter] values.

```lua
clause(benchmark, ...Parameter)
clause "description" (benchmark, ...Parameter)
```

# Clause
[Clause]: #clause
```
type Clause<X> = Statement<X> & Detailed<X>
```

Receives X or a string. When a string, it returns a function that
receives X, enabling the following syntax sugar:

```lua
clause(x)
clause "description" (x)
```

# Closure
[Closure]: #closure
```
type Closure = () -> ()
```

A general function operating on upvalues.

# Input
[Input]: #input
```
type Input = Plan | ModuleScript | {[any]: Input}
```

Represents a [Plan][Plan], a valid spek ModuleScript, or a tree of such.
Inputs produce nodes within a [Runner][Runner]:

- A table produces a node for each entry.
- A spek produces a node for the spek.
- A plan does not produce a node, but its content usually does.
- Other values produce a node indicating an error.

# MetricObserver
[MetricObserver]: #metricobserver
```
type MetricObserver = (path: Path, unit: string, value: number) -> ()
```

Observes metric *unit* of *path*.

# Metrics
[Metrics]: #metrics
```
type Metrics = {[string]: number}
```

Metrics contains measurements made during a test or benchmark. It maps
the unit of a measurement to its value.

For a benchmark result, contains default and custom measurements reported
during the benchmark.

For a test result, contains basic measurements reported during the test.

For a node or plan result, contains aggregated measurements of all sub-units.

# Parameter
[Parameter]: #parameter
```
type Parameter = unknown
```

An opaque parameter to be passed to a
[BenchmarkClause][BenchmarkClause].

# ParameterClause
[ParameterClause]: #parameterclause
```
type ParameterClause = (name: string) -> (...any) -> Parameter
```

Creates an parameter to be passed to a benchmark statement. *name* is
the name of the parameter, which is not optional. Each value passed is a
"variation" of the parameter to be benchmarked individually.

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

# Plan
[Plan]: #plan
```
type Plan = (t: T) -> ()
```

Receives a [T][T] to plan a testing suite.

# Result
[Result]: #result
```
type Result = {
	Type: ResultType,
	Okay: boolean,
	Reason: string,
	Trace: string?,
}
```

Represents the result of a unit. Converting to a string displays a
formatted result.

Field  | Type                     | Description
-------|--------------------------|------------
Type   | [ResultType][ResultType] | Indicates the type of result.
Okay   | boolean                  | The status of the unit; whether the unit succeeded or failed. For benchmarks, this will be false if the benchmark errored. For nodes and plans, represents the conjunction of the status of all sub-units.
Reason | string                   | A message describing the reason for the status. Empty if the unit succeeded.
Trace  | string?                  | An optional stack trace to supplement the Reason.

# ResultObserver
[ResultObserver]: #resultobserver
```
type ResultObserver = (path: Path, result: Result?) -> ()
```

Observes the result of *path*.

# ResultType
[ResultType]: #resulttype
```
type ResultType = "node" | "plan" | "test" | "benchmark"
```

Indicates the type of a result tree node.

Value     | Description
----------|------------
node      | A general node aggregating a number of units.
plan      | A discrete node representing a plan.
test      | A test unit.
benchmark | A benchmark unit.

# Unsubscribe
[Unsubscribe]: #unsubscribe
```
type Unsubscribe = () -> ()
```

Causes the associated observer to stop observing when called.

