--!strict

--@sec: Spek
--@ord: -1
--@doc: All-in-one module for testing and benchmarking.
--
-- ## Speks
--
-- A specification or **spek** is a module that defines requirements (tests) and
-- measurements (benchmarks). As a Roblox instance, a spek is any ModuleScript
-- whose Name has the `.spek` suffix.
--
-- The principle value returned by a module is a **plan**, or a function that
-- receives a [T][T] object. A table of plans can be returned instead. The full
-- definition for the returned value is as follows:
--
-- ```lua
-- type Spek = Plan | {[any]: Spek}
-- type Plan = (t: T) -> ()
-- ```
--
-- Each plan function specifies a discrete set of units that remain grouped
-- together and separated from other plans. For example, when specifying
-- benchmarks, measurements that belong to the same plan will be tabulated into
-- one table, and wont mix with measurements from other plans.
--
-- The following can be used as a template for writing a spek:
--
-- ```lua
-- -- Optional; used only to get exported types.
-- local Spek = require(game:FindFirstDescendant("Spek"))
-- -- Require dependencies as usual.
-- local Eieren = require(script.Parent.Eieren)
--
-- return function(t: Spek.T)
-- 	--TODO: Test Eieren module.
-- end
-- ```
local export = {}

-- Due to type limitations, pcall has a type signature that evaluates
-- incorrectly with functions that return no values. Casting such a function to
-- this allows the return types to work correctly. This can be removed once
-- pcall gets a better type signature.
type PCALLABLE = any

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--@sec: Path
--@ord: 30
--@def: type Path
--@doc: A unique symbol representing a path referring to a value within a result
-- tree. Converting to a string displays a formatted path.
local Path = {__index={}}

export type Path = {
	Base: (self: Path) -> any,
	Elements: (self: Path) -> {any},
}

type _Path = Path & {
	_elements: {any}, -- Actual elements of the path.
	_string: string,  -- Cached string.
}

-- Creates a new path from the given elements.
local function newPath(...: any): Path
	local elements = table.freeze{...}
	local s = table.create(#elements)
	for i, element in elements do
		local str = tostring(element)
		if str:match("[%[%]]") then
			s[i] = string.format("[%q]", str)
		else
			s[i] = string.format("[%s]", str)
		end
	end
	local self: _Path = setmetatable({
		_elements = elements,
		_string = table.concat(s),
	}, Path) :: any
	return table.freeze(self)
end

function Path.__tostring(self: _Path): string
	return self._string
end

--@sec: Path.Base
--@def: function Path:Base(): any
--@doc: Returns the last element of the path.
function Path.__index.Base(self: _Path): any
	return self._elements[#self._elements]
end

--@sec: Path.Elements
--@def: function Path:Elements(): {any}
--@doc: Returns the path as a list of elements.
function Path.__index.Elements(self: _Path): {any}
	local elements = table.create(#self._elements)
	table.move(self._elements, 1, #self._elements, 1, elements)
	return elements
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Used to wait for multiple threads to finish.
local WaitGroup = {__index={}}

type WaitGroup = {
	-- Threads the group is waiting on.
	_dependencies: {[thread]: true?},
	-- Threads waiting on the group.
	_dependents: {thread},

	Add: <X...>(self: WaitGroup, func: (X...)->(), X...) -> (),
	Wait: (self: WaitGroup) -> (),
	Cancel: (self: WaitGroup) -> (),
}

local function newWaitGroup(): WaitGroup
	local self: WaitGroup = setmetatable({
		_dependencies = {},
		_dependents = {},
	}, WaitGroup) :: any
	return table.freeze(self)
end

-- Adds a function call that automatically finishes as a dependency thread to
-- wait on.
function WaitGroup.__index.Add<X...>(self: WaitGroup, func: (X...)->(), ...: X...)
	local function doFunc<X...>(func: (X...)->(), ...: X...)
		local ok, err = pcall(func::PCALLABLE, ...)
		if not ok then
			error(string.format("waitgroup dependency errored: %s", err))
		end

		self._dependencies[coroutine.running()] = nil
		if next(self._dependencies) then
			return
		end
		for _, thread in self._dependents do
			task.defer(thread)
		end
		table.clear(self._dependents)
	end
	local thread = task.defer(doFunc, func, ...)
	self._dependencies[thread] = true
end

-- Called by a dependent thread to block until the WaitGroup is done.
function WaitGroup.__index.Wait(self: WaitGroup)
	if not next(self._dependencies) then
		return
	end
	table.insert(self._dependents, coroutine.running())
	coroutine.yield()
end

-- Called by a dependent thread to cancel all dependency threads and resume all
-- dependent threads.
function WaitGroup.__index.Cancel(self: WaitGroup)
	for thread in self._dependencies do
		task.cancel(thread)
	end
	table.clear(self._dependencies)
	for _, thread in self._dependents do
		task.defer(thread)
	end
	table.clear(self._dependents)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Enables the creation of thread-scoped "contexts". An "object" contains a
-- number of predefined "context functions", which do different things depending
-- on the context.
--
-- The primary use is to have the object provide a number of upvalue functions
-- that receive closures. Such a closure is received in one context, then called
-- in another, while still using the same upvalue functions.
type ThreadContext<X> = {
	-- Sets the context for the running thread. *location* is a description
	-- indicating when or where a function is running (e.g. "within X", "during
	-- X", "while Xing"). *context* is called to populate the context with
	-- implementations for each predefined function.
	--
	-- *context* does not need to implement all functions. If an unimplemented
	-- function is called, an error will be thrown indicating that the function
	-- cannot be called in that context.
	--
	-- The user of a context is not expected to call these functions from
	-- different threads. An error will be thrown if a function is called from a
	-- thread not known by the ThreadContext.
	With: (
		self: ThreadContext<X>,
		location: string,
		context: (ThreadObject)->(),
		body: () -> ()
	) -> (),
	-- Returns the object containing the public-facing context functions.
	Object: X,
}

type ThreadObject = {[string]: any}

-- Creates a new ThreadContext. Each argument is the name of a function expected
-- to be in object X.
local function newThreadContext<X>(...: string): ThreadContext<X>
	local self = {}

	type ThreadState = {
		Location: string,
		Object: ThreadObject,
	}

	local threadStates: {[thread]: ThreadState} = setmetatable({}, {__mode="k"}) :: any

	local object: ThreadObject = {}
	for i = 1, select("#", ...) do
		local field = select(i, ...)
		object[field] = function(...)
			local state = threadStates[coroutine.running()]
			if not state then
				-- Running thread is not present in context. The user must have
				-- called this function from a different thread.
				error(string.format("cannot call %s in new thread", field), 2)
			end
			local implementation = state.Object[field]
			if not implementation then
				-- Not implemented by this context.
				error(string.format("cannot call %q %s", field, state.Location), 2)
			end
			return implementation(...)
		end
	end
	self.Object = object :: any

	function self.With(
		self: ThreadContext<X>,
		location: string,
		context: (ThreadObject) -> (),
		body: () -> ()
	)
		local t: ThreadObject = {}
		context(t)
		local state = {Location = location, Object = t}
		local thread = coroutine.running()
		threadStates[thread] = state
		local ok, err = pcall(body::PCALLABLE)
		threadStates[thread] = nil
		if not ok then
			error(string.format("body errored: %s", err))
		end
	end

	return table.freeze(self)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--@sec: UnitConfig
--@def: type UnitConfig = {
-- 	Iterations: number?,
-- 	Duration: number?,
-- }
--@doc: Configures options for running a unit.
--
-- Field      | Type    | Description
-- -----------|---------|------------
-- Iterations | number? | Target iterations for each benchmark. If unspecified, Duration is used.
-- Duration   | number? | Target duration for each benchmark, in seconds. Defaults to 1.
--
export type UnitConfig = {
	Iterations: number?,
	Duration: number?,
}

-- Constructs an immutable UnitConfig.
local function newUnitConfig(config: UnitConfig?): UnitConfig
	local config: UnitConfig = config or {}
	config.Iterations = config.Iterations or 1
	config.Duration = config.Duration or 1
	return table.freeze(config)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Represents the result of a unit. Converting to a string displays a formatted
-- result.
export type Result = {
	-- Indicates the type of result.
	Type: NodeType,
	-- The status of the unit; whether the unit succeeded or failed. For
	-- benchmarks, this will be false if the benchmark errored. For nodes and
	-- plans, represents the conjunction of the status of all sub-units.
	Okay: boolean,
	-- A message describing the reason for the status. Empty if the unit
	-- succeeded.
	Reason: string,
	-- An optional stack trace to supplement the Reason.
	Trace: string?,
}

-- Constructs a new immutable Result.
local function newResult(
	type: NodeType,
	okay: boolean,
	reason: string,
	trace: string?
): Result
	--TODO: Should be formattable.
	return table.freeze{
		Type = type,
		Okay = okay,
		Reason = reason,
		Trace = trace,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- The interface for running a testing unit and handling the result. A Node is
-- immutable, but contains a mutable Data field. However, if the node is created
-- as an error node, the Data will be immutable.
local Node = {__index={}}

type Node = {
	-- Type of the node.
	Type: NodeType,
	-- The tree the node belongs to.
	Tree: Tree,
	-- Path symbol that refers to this node.
	Path: Path,
	-- Parent node, or nil if root node.
	Parent: Node?,
	-- List of child nodes.
	Children: {Node},
	-- Mutable data. Immutable if the node was created as an error.
	Data: {
		-- Context associated with a plan.
		ThreadContext: ThreadContext<T>?,
		-- Deferred closure associated with the node.
		Closure: Closure?,
		--  Closures to run before Closure.
		Before: {Closure},
		--  Closures to run after Closure.
		After: {Closure},
		-- Specific or aggregate result of the node. If the node was created as
		-- an error, this will be filled in with the error.
		Result: Result?,
		-- Specific or aggregate measurements about the node.
		Metrics: Metrics,
		-- Number of times the unit ran.
		Iterations: number,
		-- Total duration of all iterations of the unit.
		Duration: number,
	},
	-- Marks data has having changed.
	Pending: {
		-- Corresponds to Data.Result.
		Result: boolean,
		-- Corresponds to Data.Metrics.
		Metrics: {[string]: true},
		-- Corresponds to Data.Iterations+Duration.
		Benchmark: boolean,
	},

	-- Updates data of the node. Returns false if the node is frozen.
	UpdateResult: (self: Node, result: Result?) -> boolean,
	UpdateMetric: (self: Node, value: number, unit: string) -> boolean,
	UpdateBenchmark: (self: Node, iterations: number, duration: number) -> boolean,

	-- Reconciles derivative results and metrics.
	ReconcileResults: (self: Node) -> (),
	ReconcileMetrics: (self: Node) -> (),

	-- Calls the given observers with the node's pending data.
	Inform: (
		self: Node,
		result: ResultObserver,
		metric: MetricObserver
	) -> (),
}

-- Indicates the type of Node.
type NodeType
	= "test"  -- A test unit.
	| "benchmark" -- A benchmark unit.
	| "node"  -- A general node aggregating a number of units.
	| "plan"   -- A discrete node representing a plan.

-- Metrics contains measurements made during a test or benchmark. It maps the
-- unit of a measurement to its value.
--
-- For a benchmark result, contains default and custom measurements reported
-- during the benchmark.
--
-- For a test result, contains basic measurements reported during the test.
--
-- For a node or plan result, contains aggregated measurements of all sub-units.
export type Metrics = {[string]: number}

local function newNode(tree: Tree, type: NodeType, parent: Node?, key: any): Node
	assert(key ~= nil, "key cannot be nil")
	local node: Node = setmetatable({
		Type = type,
		Tree = tree,
		Path = nil,
		Parent = parent,
		Children = {},
		Data = {
			ThreadContext = nil,
			Closure = nil,
			Before = {},
			After = {},
			Result = nil,
			Metrics = {},
			Iterations = 0,
			Duration = 0,
		},
		Pending = {
			Result = false,
			Metrics = {},
			Benchmark = false,
		},
	}, Node) :: any
	if parent == nil then
		node.Path = newPath(key)
		table.insert(tree.Roots, node)
	else
		local elements = parent.Path:Elements()
		table.insert(elements, key)
		node.Path = newPath(table.unpack(elements))
		table.insert(parent.Children, node)
	end
	tree.Nodes[node.Path] = node
	return table.freeze(node)
end

-- Returns true if *old* and *new* are different. If 8struct* is true, then
-- *old* and *new* are assumed to contain the same fields.
local function compareTables(struct: boolean, old: {[string]: any}, new: {[string]: any}): boolean
	for key, value in old do
		if new[key] ~= value then
			return true
		end
	end
	if struct then
		return false
	end
	for key, value in new do
		if old[key] ~= value then
			return true
		end
	end
	return false
end

-- Returns true if *old* and *new* are different.
local function compareResults(old: Result?, new: Result?): boolean
	if old == nil then
		if new == nil then
			return true
		else
			return false
		end
	else
		if new == nil then
			return false
		else
			return compareTables(true, old, new)
		end
	end
end

-- Sets the result of the node to *result*. Marks the result as pending, and
-- marks the tree as dirty. Returns false if the node is frozen.
function Node.__index.UpdateResult(self: Node, result: Result?): boolean
	if table.isfrozen(self.Data) then
		return false
	end
	if compareResults(self.Data.Result, result) then
		return true
	end
	self.Data.Result = result
	self.Pending.Result = true
	self.Tree:Dirty()
	return true
end

-- Sets a metric of the node. Marks the metric as pending, and marks the tree as
-- dirty. Returns false if the node is frozen.
function Node.__index.UpdateMetric(self: Node, value: number, unit: string): boolean
	if table.isfrozen(self.Data) then
		return false
	end
	if self.Data.Metrics[unit] == value then
		return true
	end
	self.Data.Metrics[unit] = value
	self.Pending.Metrics[unit] = true
	self.Tree:Dirty()
	return true
end

-- Sets the benchmark metrics of the node. Marks the metrics as pending, and
-- marks the tree as dirty. Returns false if the node is frozen.
function Node.__index.UpdateBenchmark(self: Node, iterations: number, duration: number): boolean
	if table.isfrozen(self.Data) then
		return false
	end
	if self.Data.Iterations == iterations
	and self.Data.Duration == duration then
		return true
	end
	self.Data.Iterations = iterations
	self.Data.Duration = duration
	self.Pending.Benchmark = true
	self.Tree:Dirty()
	return true
end

-- If the node has child nodes, the Result of the node will be set to the
-- aggregation of the children's results.
function Node.__index.ReconcileResults(self: Node)
	local pending = false
	for _, node in self.Children do
		if not node.Pending.Result then
			continue
		end
		node:ReconcileResults()
		pending = true
	end
	if not pending then
		return
	end
	--TODO: aggregate reason/trace.
	local okay = true
	for _, node in self.Children do
		if not node.Pending.Result then
			continue
		end
		local result = node.Data.Result
		if result then
			okay = okay and result.Okay
			if not okay then
				break
			end
		end
	end
	self:UpdateResult(newResult(self.Type, okay, "one or more results failed"))
end

-- If the node has child nodes, the Metrics of the node will be set to the
-- aggregation of the children's metrics.
function Node.__index.ReconcileMetrics(self: Node)
	local pending = false
	for _, node in self.Children do
		if not node.Pending.Benchmark
		and not next(node.Pending.Metrics) then
			continue
		end
		node:ReconcileMetrics()
		pending = true
	end
	if not pending then
		return
	end
	local iterations = 0
	local duration = 0
	for _, node in self.Children do
		if not node.Pending.Benchmark then
			continue
		end
		iterations += node.Data.Iterations
		duration += node.Data.Duration
	end
	self:UpdateBenchmark(iterations, duration)

	local metrics: Metrics = {}
	for _, node in self.Children do
		if not next(node.Pending.Metrics) then
			continue
		end
		for unit, value in node.Data.Metrics do
			if not node.Pending.Metrics[unit] then
				continue
			end
			if metrics[unit] then
				metrics[unit] += value
			else
				metrics[unit] = value
			end
		end
	end
	for unit, value in metrics do
		self:UpdateMetric(value, unit)
	end
end

-- Produces the actual value of a metric with a specific prefix.
local function calculateMetric(
	value: number,
	unit: string,
	iterations: number,
	duration: number
): number
	if string.match(unit, "/op$") then
		return value/iterations
	elseif string.match(unit, "/s$") then
		return value/duration
	elseif string.match(unit, "/ms$") then
		return value/duration*1000
	elseif string.match(unit, "/us$") then
		return value/duration*1000000
	else
		return value
	end
end

-- Calls *visit* for each metric in *node*. Values are the final calculated
-- value based on the unit. If not overridden, the "iterations" and "duration"
-- metrics are included from benchmark data.
local function buildMetrics(node: Node, visit: (unit: string, value: number)->())
	local iterations = node.Data.Iterations
	local duration = node.Data.Duration
	if not node.Data.Metrics["iterations"] then
		visit("iterations", iterations)
	end
	if not node.Data.Metrics["duration"] then
		visit("duration", duration)
	end
	for unit, value in node.Data.Metrics do
		visit(unit, calculateMetric(value, unit, iterations, duration))
	end
end


-- Calls the given observers with the node's pending data. Unmarks the data as
-- pending.
function Node.__index.Inform(self: Node, result: ResultObserver, metric: MetricObserver)
	for _, node in self.Children do
		node:Inform(result, metric)
	end
	if self.Pending.Result then
		result(self.Path, self.Data.Result)
		self.Pending.Result = false
	end
	if self.Pending.Benchmark or next(self.Pending.Metrics) then
		if self.Pending.Benchmark then
			if not self.Data.Metrics["iterations"] then
				self.Pending.Metrics["iterations"] = true
			end
			if not self.Data.Metrics["duration"] then
				self.Pending.Metrics["duration"] = true
			end
		end
		buildMetrics(self, function(unit: string, value: number)
			if self.Pending.Metrics[unit] then
				metric(self.Path, unit, value)
			end
		end)
		self.Pending.Benchmark = false
		table.clear(self.Pending.Metrics)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Represents a tree of Runner results and metrics.
local Tree = {__index={}}

type Tree = {
	-- Flat map of paths to nodes.
	Nodes: {[Path]: Node},
	-- Nodes that are at the root of the tree.
	Roots: {Node},
	-- Whether the tree contains nodes with pending data.
	IsDirty: boolean,

	-- Observes the results of nodes in the tree.
	ResultObserver: ResultObserver?,
	-- Observes the metrics of nodes in the tree.
	MetricObserver: MetricObserver?,

	-- Creates a new node.
	CreateNode: (self: Tree,
		type: NodeType,
		parent: Node?,
		key: any
	) -> Node,

	-- Creates a new node frozen with an error result.
	CreateErrorNode: (self: Tree,
		type: NodeType,
		parent: Node?,
		key: any,
		format: string,
		...any
	) -> Node,

	-- Mark tree as dirty. At a defer point, the tree will reconcile any dirty
	-- nodes.
	Dirty: (self: Tree) -> (),
	-- Update derivative data.
	ReconcileData: (self: Tree) -> (),
	-- Inform observers of changes.
	InformObservers: (self: Tree) -> (),
}

-- Creates a new Tree witht the given configuration.
local function newTree(): Tree
	local self: Tree = setmetatable({
		Nodes = {},
		Roots = {},
		IsDirty = false,
		ResultObserver = nil,
		MetricObserver = nil,
	}, Tree) :: any
	return self
end

-- Creates a new node refered to by *key* under *parent*, or root if *parent* is
-- nil.
function Tree.__index.CreateNode(self: Tree, type: NodeType, parent: Node?, key: any): Node
	return newNode(self, type, parent, key)
end

-- Creates a node as usual, but the result is filled in with an error, and the
-- node's data is frozen.
function Tree.__index.CreateErrorNode(
	self: Tree,
	type: NodeType,
	parent: Node?,
	key: any,
	format: string,
	...: any
): Node
	local node = self:CreateNode(type, parent, key)
	node:UpdateResult(newResult(type, false, string.format(format, ...)))
	table.freeze(node.Data)
	return node
end

-- If the tree is not dirty, marks the tree as dirty, and defers a task that
-- reconciles data and informs the configured observers of changed data.
function Tree.__index.Dirty(self: Tree)
	if self.IsDirty then
		return
	end
	self.IsDirty = true
	task.defer(function(self: Tree)
		self:ReconcileData()
		self:InformObservers()
		self.IsDirty = false
	end, self)
end

-- Reconciles derivative data.
function Tree.__index.ReconcileData(self: Tree)
	for _, node in self.Roots do
		node:ReconcileResults()
	end
	for _, node in self.Roots do
		node:ReconcileMetrics()
	end
end

-- Calls the Inform method of each root node with the configured observers.
function Tree.__index.InformObservers(self: Tree)
	local result = self.ResultObserver or function()end
	local metric = self.MetricObserver or function()end
	for _, node in self.Roots do
		node:Inform(result, metric)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--@sec: T
--@ord: 10
--@def: type T
--@doc: Contains functions used to define a spek.
--
-- These functions are not methods, so its safe to call them as-is. It is also
-- safe to store them in variables for convenience.
--
-- ```lua
-- return function(t: Spek.T)
-- 	local describe = t.describe
-- 	describe "can be stored in a variable" (function()end)
--
-- 	t.describe "or can be called as-is" (function()end)
-- end
-- ```
--
-- ## Test functions
--
-- Some functions are "Statements". A statement is a function that receives a
-- value of some specified type.
--
-- ```lua
-- return function(t: Spek.T)
-- 	-- A Statement<Closure>, so it is a function that receives a Closure.
-- 	t.before_each(function()end)
-- end
-- ```
--
-- Some functions are "Clauses". A Clause can be a regular Statement, or it can
-- be a function that receives a string. If the latter, it returns a Statement.
-- This enables several syntaxes for annotating a function with an optional
-- description:
--
-- ```lua
-- return function(t: Spek.T)
-- 	t.describe "clause with a description" (function()end)
--
-- 	-- Clause without a description.
-- 	t.describe(function()end)
-- end
-- ```
--
-- A Closure is a function that is expected to receive no arguments and return
-- no values. Typically it uses upvalues to further define the spek within the
-- context of the outer function.
--
-- ```lua
-- return function(t: Spek.T)
-- 	t.describe "uses a closure" (function()
-- 		t.it "further defines within this context" (function()end)
-- 	end)
-- end
-- ```
--
-- An Assertion is like a Closure, except that it is expected to return a value
-- to be asserted.
--
-- ```lua
-- return function(t: Spek.T)
-- 	t.it "makes an assertion" (function()
-- 		t.assert "that pi is a number" (function()
-- 			return type(math.pi) == "number"
-- 		end)
-- 	end)
-- end
-- ```
--
-- Certain functions may only be called in certain contexts. For example,
-- [expect][T.expect] may only be called within an [it][T.it] closure. Each
-- description of a function lists where the function is allowed to be called.
-- Some functions are allowed to be called anywhere. The root plan function
-- behaves the same as [describe][T.describe].
--
-- ## Benchmark functions
--
-- The [measure][T.measure] function defines a benchmark.
--
--TODO: finish T docs
export type T = {
	--@sec: T.describe
	--@def: describe: Clause<Closure>
	--@doc: **Within:** plan, [describe][T.describe]
	--
	-- Defines a new context for a test or benchmark.
	describe: Clause<Closure>,

	--@sec: T.before_each
	--@def: before_each: Statement<Closure>
	--@doc: **Within:** plan, [describe][T.describe]
	--
	-- Defines function to call before each unit, scoped to the context.
	before_each: Statement<Closure>,

	--@sec: T.after_each
	--@def: after_each: Statement<Closure>
	--@doc: **Within:** plan, [describe][T.describe]
	--
	-- Defines a function to call after each unit, scoped to the context.
	after_each: Statement<Closure>,

	--@sec: T.it
	--@def: it: Clause<Closure>
	--@doc: **Within:** plan, [describe][T.describe]
	--
	-- Defines a new test unit.
	it: Clause<Closure>,

	--@sec: T.expect
	--@def: expect: Clause<Assertion>
	--@doc: **Within:** [it][T.it]
	--
	-- Expects the result of an assertion to be truthy.
	expect: Clause<Assertion>,

	--@sec: T.expect_error
	--@def: expect_error: Clause<Closure>
	--@doc: **Within:** [it][T.it]
	--
	-- Expects the closure to throw an error.
	expect_error: Clause<Closure>,

	--@sec: T.parameter
	--@def: parameter: ParameterClause
	--@doc: **Within:** plan, [describe][T.describe]
	--
	-- Defines a parameter symbol that can be passed to [measure][T.measure].
	parameter: ParameterClause,

	--@sec: T.measure
	--@def: measure: BenchmarkClause
	--@doc: **Within:** plan, [describe][T.describe]
	--
	-- Defines a new benchmark unit.
	measure: BenchmarkClause,

	--@sec: T.operation
	--@def: operation: Clause<Closure>
	--@doc: **Within:** [measure][T.measure] (only once)
	--
	-- Defines the operation of a benchmark unit that is being measured. This
	-- operation is run repeatedly.
	operation: Statement<Closure>,

	--@sec: T.reset_timer
	--@def: reset_timer: () -> ()
	--@doc: **Within:** anything
	--
	-- Resets the unit's elapsed time and all metrics. Does not affect whether
	-- the timer is running.
	reset_timer: () -> (),

	--@sec: T.start_timer
	--@def: start_timer: () -> ()
	--@doc: **Within:** anything
	--
	-- Starts or resumes the unit timer.
	start_timer: () -> (),

	--@sec: T.stop_timer
	--@def: stop_timer: () -> ()
	--@doc: **Within:** anything
	--
	-- Stops the unit timer.
	stop_timer: () -> (),

	--@sec: T.report
	--@def: report: Clause<number>
	--@doc: **Within:** anything
	--
	-- Reports a user-defined metric. Any previously reported value will be
	-- overridden.
	--
	-- The description determines the unit of the reported value, which is
	-- user-defined. If the description has a specific suffix, the value is
	-- altered:
	--
	-- - `/op`: Value is divided by the number of operations performed by the
	--   unit (1 for tests, many for benchmarks).
	-- - `/us`: Value is divided by the number microseconds elapsed during the
	--   unit.
	-- - `/ms`: Value is divided by the number milliseconds elapsed during the
	--   unit.
	-- - `/s`: Value is divided by the number seconds elapsed during the
	--   unit.
	-- - (no suffix): Value is reported as-is.
	--
	-- **Examples:**
	--
	-- ```lua
	-- report "compares" (compares) -- Report value per unit.
	-- report "compares/op" (compares) -- Report value per operation.
	-- report "compares/s" (compares) -- Report value per second.
	-- ```
	report: Detailed<number>,
}

-- Receives a statement or string. When a string, it returns a function that
-- receives the statement, enabling the following syntax sugar:
--
-- ```lua
-- clause(statement)
-- clause "description" (statement)
-- ```
export type Clause<X> = Statement<X> & Detailed<X>
export type Statement<X> = (X) -> ()
export type Detailed<X> = (desc: any) -> Statement<X>

-- General function operating on upvalues.
export type Closure = () -> ()
-- Caller expects a result.
export type Assertion = () -> any

-- Variation of clause and statement for benchmarks, which receives a variable
-- number of specific parameter values.
export type BenchmarkClause = BenchmarkStatement & BenchmarkDetailed
export type BenchmarkStatement = (Benchmark, ...Parameter) -> ()
export type BenchmarkDetailed = (desc: any) -> BenchmarkStatement
export type Benchmark = (...any) -> ()

export type ParameterClause = (name: string) -> (...any) -> Parameter
export type Parameter = unknown

-- Returns a clause function that can be called in one of two ways:
--
--     clause (closure)
--     clause (description) (closure)
--
-- If called with the non-description form, the description will be nil. If
-- called with the description form, errors if nil is passed as the description.
local function newClause<X>(process: (description: any?, closure: X)->()): Clause<X>
	return function(description: any | X): any
		if description == nil then
			error("description cannot be nil", 2)
		elseif type(description) == "function" then
			process(nil, description)
			return
		else
			return function(closure: X)
				process(description, closure)
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Represents the state of a plan.
type PlanState = {
	Stack: {Node},
	CreateNode: (self: PlanState, node: NodeType, key: any?, closure: Closure?) -> (),
	PeekNode: (self: PlanState) -> Node,
	PopNode: (self: PlanState) -> Node,
}

local function newPlanState(tree: Tree): PlanState
	local self = {
		Stack = {},
	}

	-- Creates a new node as a child of the node at the top of the stack,
	-- referred to using *key*. If *key* is equal to *compare* then the node's
	-- child location is used instead. A Unit of type *type* is set to the
	-- node's data.
	function self.CreateNode(self: PlanState, node: NodeType, key: any?, closure: Closure?)
		local parent = self:PeekNode()
		if key == nil then
			-- Unlabeled statement. Use node's predicted location in
			-- parent.
			key = #parent.Children + 1
		end
		local node = tree:CreateNode(node, parent, key)
		node.Data.Closure = closure
		table.insert(self.Stack, node)
	end

	-- Returns the node at the top of the stack.
	function self.PeekNode(self: PlanState): Node
		return assert(self.Stack[#self.Stack], "empty stack")
	end

	-- Pop the top node from the stack.
	function self.PopNode(self: PlanState): Node
		return assert(table.remove(self.Stack), "empty stack")
	end

	return self
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--@sec: Runner
--@ord: 20
--@def: type Runner
--@doc: Used to run speks. The results are represented as a tree. Each node in
-- the tree has a key, and can be visited using a path.
--
-- Converting to a string displays formatted results of the last run. Metrics
-- are tabulated per plan.
--
-- Note that the runner requires spek modules as-is.
local Runner = {__index={}}

export type Runner = {
	Running: (self: Runner) -> boolean,
	Run: (self: Runner) -> (),
	Start: (self: Runner) -> (),
	Wait: (self: Runner) -> (),
	Stop: (self: Runner) -> (),
	Reset: (self: Runner) -> (),
	Keys: (self: Runner, path: Path?) -> {Path}?,
	Value: (self: Runner, path: Path) -> Result?,
	Metrics: (self: Runner, path: Path) -> Metrics?,
	ObserveResult: (self: Runner, observer: ResultObserver) -> ()->(),
	ObserveMetric: (self: Runner, observer: MetricObserver) -> ()->(),
}

type _Runner = Runner & {
	_active: WaitGroup?,
	_tree: Tree,
	_config: UnitConfig,
	_resultObservers: {[Unsubscribe]: ResultObserver},
	_metricObservers: {[Unsubscribe]: MetricObserver},
	_start: (self: _Runner) -> WaitGroup,
}

export type Spek = Plan | {[any]: Spek}
export type Plan = (t: T) -> ()

-- Sets a context for running a plan.
local function planContext(ctx: ThreadContext<T>, tree: Tree, parent: Node): (ThreadObject) -> ()
	local state = newPlanState(tree)

	-- Use parent node as the root context.
	table.insert(state.Stack, parent)

	return function(t: ThreadObject)
		t.describe = newClause(function(desc: any?, closure: Closure)
			-- Run closure using created node as context.
			state:CreateNode("node", "describe", desc)
			closure()
			state:PopNode()
		end)

		function t.before_each(closure: Closure)
			local node = state:PeekNode()
			table.insert(node.Data.Before, closure)
		end

		function t.after_each(closure: Closure)
			local node = state:PeekNode()
			table.insert(node.Data.After, closure)
		end

		t.it = newClause(function(desc: any?, closure: Closure)
			state:CreateNode("test", desc, closure)
			state:PopNode()
		end)

		function t.parameter<X>(name: string): (...X) -> Parameter
			if type(name) ~= "string" then
				error("parameter name must be a string", 2)
			end
			return function(...: X): Parameter
				return table.freeze{
					_name = name,
					_variations = table.freeze(table.pack(...)),
				}
			end
		end

		-- Visit each permutation of parameter variations.
		local function permuteParameters(
			params: {{_variations:{any}}},
			visit: (...any)->(),
			n: number?,
			...: any
		)
			local n = n or #params
			if n <= 0 then
				visit(...)
			else
				local param = params[n]
				for _, v in param._variations do
					permuteParameters(params, visit, n-1, v, ...)
				end
			end
		end

		-- Generates a benchmark unit for each permutation of the given parameters.
		-- If the given description cannot be formatted according to the given
		-- parameters, then only one benchmark is generated.
		local function generateBenchmarks(key: any, benchmark: Benchmark, ...: Parameter)
			-- List of first variation of each parameter.
			local firsts: {n: number, [number]: any} = table.pack(...)
			for i, param in ipairs(firsts) do
				firsts[i] = (param::any)._variations[1]
			end
			table.freeze(firsts)

			-- Verify that key can be used to format parameters.
			local ok = pcall(function(...: Parameter)
				string.format(key, table.unpack(firsts, 1, firsts.n))
			end, ...)

			if ok then
				local parameters = table.freeze(table.pack(...))
				permuteParameters(parameters::any, function(...)
					local formatted = string.format(key, ...)
					local values = table.freeze(table.pack(...))
					state:CreateNode("benchmark", formatted, function()
						benchmark(table.unpack(values, 1, values.n))
					end)
					state:PopNode()
				end)
			else
				-- Cannot produce variations of key. Generate only one benchmark
				-- using the first variation of each parameter.
				state:CreateNode("benchmark", key, function()
					benchmark(table.unpack(firsts, 1, firsts.n))
				end)
				state:PopNode()
			end
		end

		function t.measure<X...>(description: string | Benchmark, ...: Parameter): BenchmarkStatement?
			local function process(benchmark: Benchmark, ...: Parameter)
				assert(type(benchmark) == "function", "function expected")
				generateBenchmarks(description, benchmark, ...)
			end
			if type(description) == "string" then
				return process
			elseif description == nil then
				error("description cannot be nil", 2)
			else
				process(description, ...)
				return
			end
		end
	end
end

-- Processes the value returned by a module, recursively creating nodes
-- corresponding to the structure. If a value is of an unexpected type, the
-- corresponding node is filled with a failing result.
local function processPlan(tree: Tree, plan: Spek, parent: Node?, key: any)
	if type(plan) == "function" then
		local node = tree:CreateNode("plan", parent, key)
		local ctx = newThreadContext(
			"describe",
			"before_each",
			"after_each",

			"it",
			"expect",
			"expect_error",

			"parameter",
			"measure",
			"operation",

			"reset_timer",
			"start_timer",
			"stop_timer",
			"report"
		)
		node.Data.ThreadContext = ctx
		local context = planContext(ctx, tree, node)
		local ok, err
		ctx:With("while planning", context, function()
			-- Generate sub-tree by processing plan provided by plan.
			ok, err = pcall(plan::PCALLABLE, ctx.Object)
		end)
		if not ok then
			node:UpdateResult(newResult(node.Type, false, err))
			table.freeze(node.Data)
		end
	elseif type(plan) == "table" then
		local node = tree:CreateNode("plan", parent, key)
		for key, plan in plan do
			processPlan(tree, plan, node, key)
		end
	else
		tree:CreateErrorNode("plan", parent, key, "unexpected plan type %q", typeof(plan))
	end
end

-- Processes a single spek module. Creates a node mapped to the full name ofthe
-- module.
local function processSpek(tree: Tree, spek: ModuleScript)
	local key = spek:GetFullName()
	local ok, plan = pcall(require, spek)
	if not ok then
		tree:CreateErrorNode("plan", nil, key, plan)
		return
	end
	processPlan(tree, plan, nil, key)
end

--@sec: Spek.runner
--@def: function Spek.runner(speks: {ModuleScript}): Runner
--@doc: Creates a new [Runner][Runner].
function export.runner(speks: {ModuleScript}, config: UnitConfig?): Runner
	local tree = newTree()
	-- Build plan nodes by processing spek modules.
	for _, spek in speks do
		processSpek(tree, spek)
	end
	local self: _Runner = setmetatable({
		_active = nil,
		_tree = tree,
		_config = newUnitConfig(config),
		_resultObservers = {},
		_metricObservers = {},
	}, Runner) :: any
	tree.ResultObserver = function(path: Path, result: Result?)
		for _, observer in self._resultObservers do
			observer(path, result)
		end
	end
	tree.MetricObserver = function(path: Path, unit: string, value: number)
		for _, observer in self._metricObservers do
			observer(path, unit, value)
		end
	end
	return self
end

function Runner.__tostring(self: _Runner): string
	return "TODO: format Runner"
end

-- Accumulate all before and after functions to run around the test.
local function gatherEnvironment(node: Node?, befores: {Closure}, afters: {Closure})
	-- Only walk back to nearest plan node. plan will not contain other plans, so
	-- it wont ever stop too early.
	if node and node.Type ~= "plan" then
		gatherEnvironment(node.Parent, befores, afters)
		table.move(node.Data.Before, 1, #node.Data.Before, #befores+1, befores)
		table.move(node.Data.After, 1, #node.Data.After, #afters+1, afters)
	end
end

local function runUnit(node: Node, state: UnitState)
	local closure = assert(node.Data.Closure, "unit node must have closure")

	local befores, afters = {}, {}
	gatherEnvironment(node, befores, afters)

	local result: Result? = nil
	;(function()
		for _, before in befores do
			local ok, err = pcall(before::PCALLABLE)
			if not ok then
				--TODO: add context to error
				result = newResult(node.Type, false, err)
				-- Exit early; errors occurring before are considered fatal.
				return
			end
		end

		local ok, err = pcall(closure::PCALLABLE)
		if not ok then
			--TODO: add context to error

			-- Don't override existing result, which is likely the result of a
			-- failed expectation, and the error is the result of being in an
			-- unexpected state.
			if not result then
				result = newResult(node.Type, false, err)
			end
			-- Run afters even if test fails.
		end

		for _, after in afters do
			local ok, err = pcall(after::PCALLABLE)
			if not ok then
				--TODO: add context to error
				if not result then
					result = newResult(node.Type, false, err)
				end
				-- Override and exit early; errors occurring after are considered
				-- fatal and more significant, given that they are a problem with
				-- the plan itself.
				return
			end
		end
	end)()

	if result == nil then
		result = state.Result
	end
	if result == nil then
		result = newResult(node.Type, true, "")
	end
	node:UpdateResult(state.Result)
	node:UpdateBenchmark(state.Iterations, state.Duration)
	for unit, value in state.Metrics do
		node:UpdateMetric(value, unit)
	end
end

type UnitState = {
	Timing: boolean, -- Whether time measurement is active.
	Duration: number, -- Accumulated time measurement.
	StartTime: number, -- Last time the clock was updated.
	Result: Result?, -- Nil indicates okay, or no error.
	Iterations: number, -- Number of iterations of the unit.
	Metrics: Metrics, -- Reported metrics.
}

local function newUnitState(): UnitState
	return {
		Timing = false,
		Duration = 0,
		StartTime = 0,
		Result = nil,
		Iterations = 0,
		Metrics = {},
	}
end

local function runTest(node: Node, ctx: ThreadContext<T>)
	local state = newUnitState()
	state.Iterations = 1
	local function context(t: ThreadObject)
		t.expect = newClause(function(description: any?, assertion: Assertion)
			if state.Result then
				return
			end
			local ok, result = pcall(assertion)
			if ok then
				if result then
					-- Nil indicates okay result.
				elseif description == nil then
					state.Result = newResult(node.Type, false, "expectation failed")
				else
					local reason = string.format("expect %s", tostring(description))
					state.Result = newResult(node.Type, false, reason)
				end
			else
				state.Result = newResult(node.Type, ok, result)
			end
		end)

		t.expect_error = newClause(function(description: any?, closure: Closure)
			if pcall(closure) then
				local reason
				if description == nil then
					reason = "expect error"
				else
					reason = string.format("expect error %s", tostring(description))
				end
				state.Result = newResult(node.Type, false, reason)
			end
		end)

		function t.reset_timer()
			state.Duration = 0
			if state.Timing then
				state.StartTime = os.clock()
			end
		end

		function t.start_timer()
			if not state.Timing then
				state.Timing = true
				state.StartTime = os.clock()
			end
		end

		function t.stop_timer()
			if state.Timing then
				local c = os.clock()
				state.Duration += c - state.StartTime
				state.Timing = false
			end
		end

		function t.report(unit: string)
			assert(type(unit) == "string", "string expected")
			return function(value: number)
				assert(type(value) == "number", "number expected")
				state.Metrics[unit] = value
			end
		end
	end
	ctx:With("during test", context, function()
		runUnit(node, state)
	end)
end

local function runBenchmark(node: Node, config: UnitConfig, ctx: ThreadContext<T>)
	local state = newUnitState()
	local operated = false
	local function context(t: ThreadObject)
		function t.operation(closure: Closure)
			if operated then
				state.Result = newResult(node.Type, false, "multiple operations per measure")
				return
			end
			operated = true
			-- Do all work within pcall so that slow pcall is called once per
			-- benchmark instead of once per operation.
			local ok, err = pcall(function() --TODO: use xpcall to acquire trace
				--TODO: Script can be timed out by Studio.ScriptTimeoutLength.
				--If we're allowed to read settings(), insert yields required to
				--keep time just under configured timeout.
				--
				--If setting is zero or inaccessible, perform with default yield
				--frequency to give user chance to cancel out of a large target
				--duration.
				--
				--NOTE: With parallel runs, Actors require syncing each frame,
				--so durations have to be limited to framerate.
				local DEFAULT_DURATION = 1
				local targetN = config.Iterations or 0
				state.Duration = 0
				if targetN > 0 then
					-- Run configured number of iterations.
					for i = 1, targetN do
						state.Timing = true
						state.StartTime = os.clock()
						closure()
						local c = os.clock()
						state.Duration += c - state.StartTime
					end
					state.Timing = false
					state.Iterations = targetN
				else
					-- Run for configured duration.
					local targetD = config.Duration or DEFAULT_DURATION
					local start = os.clock()
					while os.clock()-start < targetD do
						state.Iterations += 1
						state.Timing = true
						state.StartTime = os.clock()
						closure()
						local c = os.clock()
						state.Duration += c - state.StartTime
					end
					state.Timing = false
				end
			end)
			if not ok then
				state.Result = newResult(node.Type, false, err)
			end
		end

		function t.reset_timer()
			state.Duration = 0
			if state.Timing then
				state.StartTime = os.clock()
			end
		end

		function t.start_timer()
			if not state.Timing then
				state.Timing = true
				state.StartTime = os.clock()
			end
		end

		function t.stop_timer()
			if state.Timing then
				local c = os.clock()
				state.Duration += c - state.StartTime
				state.Timing = false
			end
		end

		function t.report(unit: string)
			assert(type(unit) == "string", "string expected")
			return function(value: number)
				assert(type(value) == "number", "number expected")
				state.Metrics[unit] = value
			end
		end
	end
	ctx:With("during benchmark", context, function()
		runUnit(node, state)
	end)
end

function Runner.__index._start(self: _Runner): WaitGroup
	local wg = newWaitGroup()
	self._active = wg
	local function visit(node: Node, ctx: ThreadContext<T>?)
		if node.Type == "plan" then
			for _, child in node.Children do
				visit(child, node.Data.ThreadContext)
			end
		elseif node.Type == "node" then
			for _, child in node.Children do
				visit(child, ctx)
			end
		elseif node.Type == "test" then
			wg:Add(
				runTest,
				node,
				(assert(ctx, "missing thread context"))
			)
		elseif node.Type == "benchmark" then
			wg:Add(
				runBenchmark,
				node,
				self._config,
				(assert(ctx, "missing thread context"))
			)
		else
			error("unreachable")
		end
	end
	for _, node in self._tree.Roots do
		visit(node)
	end
	return wg
end

--@sec: Runner.Running
--@def: function Runner:Running(): boolean
--@doc: Returns whether the runner is currently active.
function Runner.__index.Running(self: _Runner): boolean
	return not not self._active
end

--@sec: Runner.Run
--@def: function Runner:Run()
--@doc: Runs the spek and waits for it to complete. Errors if the runner is
-- already active.
function Runner.__index.Run(self: _Runner)
	if self._active then
		error("runner is already active", 2)
	end
	self:_start():Wait()
end

--@sec: Runner.Start
--@def: function Runner:Start()
--@doc: Begins running spek without waiting for it to complete. Errors if the
-- runner is already active.
function Runner.__index.Start(self: _Runner)
	if self._active then
		error("runner is already active", 2)
	end
	self:_start()
end

--@sec: Runner.Wait
--@def: function Runner:Wait()
--@doc: Waits for the runner to complete. Does nothing if the runner is not
-- active.
function Runner.__index.Wait(self: _Runner)
	if self._active then
		self._active:Wait()
	end
end

--@sec: Runner.Stop
--@def: function Runner:Stop()
--@doc: Stops the runner, canceling all pending units. Does nothing if the
-- runner is not running.
function Runner.__index.Stop(self: _Runner)
	if self._active then
		self._active:Cancel()
	end
end

--@sec: Runner.Reset
--@def: function Runner:Reset()
--@doc: Clears all results.
function Runner.__index.Reset(self: _Runner)
	for _, node in self._tree.Nodes do
		if not table.isfrozen(node.Data) then
			node:UpdateResult(nil)
			for unit, value in node.Data.Metrics do
				node:UpdateMetric(value, unit)
			end
		end
	end
end

--@sec: Runner.Keys
--@def: function Runner:Keys()
--@doc: Returns keys that exist under *path* as a list of absolute paths. If
-- *path* is nil, the root keys are returned. Returns nil if *path* does not
-- exist.
function Runner.__index.Keys(self: _Runner, path: Path?): {Path}?
	if path then
		local node = self._tree.Nodes[path]
		if node then
			local keys = table.create(#node.Children)
			for _, node in node.Children do
				table.insert(keys, node.Path)
			end
			return keys
		end
		return nil
	end
	local keys = table.create(#self._tree.Roots)
	for _, node in self._tree.Roots do
		table.insert(keys, node.Path)
	end
	return keys
end

--@sec: Runner.Value
--@def: function Runner:Value()
--@doc: Returns the current result at *path*. Returns false if the result is not
-- yet ready. Returns nil if *path* does not exist or does not have a result.
function Runner.__index.Value(self: _Runner, path: Path): Result?
	local node = self._tree.Nodes[path]
	if not node then
		return nil
	end
	return node.Data.Result
end

--@sec: Runner.Metrics
--@def: function Runner:Metrics()
--@doc: Returns a snapshot of the metrics at *path*. Returns false if the result
-- is not yet ready. Returns nil if *path* does not exist or does not have a
-- result.
function Runner.__index.Metrics(self: _Runner, path: Path): Metrics?
	local node = self._tree.Nodes[path]
	if not node then
		return nil
	end
	local metrics = {}
	buildMetrics(node, function(unit: string, value: number)
		metrics[unit] = value
	end)
	return metrics
end

export type ResultObserver = (path: Path, result: Result?) -> ()
export type MetricObserver = (path: Path, unit: string, value: number) -> ()
export type Unsubscribe = () -> ()

--@sec: Runner.ObserveResult
--@def: function Runner:ObserveResult()
--@doc: Sets an observer to be called whenever a result changes. Returns a
-- function that removes the observer when called.
function Runner.__index.ObserveResult(self: _Runner, observer: ResultObserver): Unsubscribe
	local function unsubscribe()
		self._resultObservers[unsubscribe] = nil
	end
	self._resultObservers[unsubscribe] = observer
	for path, node in self._tree.Nodes do
		observer(path, node.Data.Result)
	end
	return unsubscribe
end

--@sec: Runner.ObserveMetric
--@def: function Runner:ObserveMetric()
--@doc: Sets an observer to be called whenever a single metric changes. Returns
-- a function that removes the observer when called.
function Runner.__index.ObserveMetric(self: _Runner, observer: MetricObserver): Unsubscribe
	local function unsubscribe()
		self._metricObservers[unsubscribe] = nil
	end
	self._metricObservers[unsubscribe] = observer
	for path, node in self._tree.Nodes do
		buildMetrics(node, function(unit: string, value: number)
			observer(node.Path, unit, value)
		end)
	end
	return unsubscribe
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--@sec: Spek.find
--@def: function Spek.find(root: Instance): {ModuleScript}
--@doc: Locates speks under a given instance.
function export.find(root: Instance): {ModuleScript}
	local speks: {ModuleScript} = {}
	for _, desc in root:GetDescendants() do
		if desc:IsA("ModuleScript") then
			if not desc.Name:match("^%.spek$") then
				continue
			end
			table.insert(speks, desc)
		end
	end
	return speks
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return table.freeze(export)
