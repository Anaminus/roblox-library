--!strict

--@sec: Spek
--@ord: -10
--@doc: All-in-one module for testing and benchmarking.
--
-- ## Speks
--
-- A specification or **spek** is a module that defines requirements (tests) and
-- measurements (benchmarks). As a Roblox instance, a spek is any ModuleScript
-- whose Name has the `.spek` suffix.
--
-- The principle value returned by a module is a **plan**, or a function that
-- receives a [T][T] object. A table of plans can be returned instead.
-- ModuleScripts may also be returned, which will be required as speks. The full
-- definition for the returned value is as follows:
--
-- ```lua
-- type Plans = Plan | ModuleScript | {[any]: Plans}
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

-- Creates a new WaitGroup.
local function newWaitGroup(): WaitGroup
	local self: WaitGroup = setmetatable({
		_dependencies = {},
		_dependents = {},
	}, WaitGroup) :: any
	return table.freeze(self)
end

-- Adds a function call as a dependency thread to wait on.
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
type ContextManager<X> = {
	-- Sets the context for the running thread for the duration of the call to
	-- *body*, then calls *body*. *verb* is a description indicating what is
	-- happening while function is running (e.g. while "executing"). *context*
	-- is called to populate the context with implementations for each
	-- predefined function.
	--
	-- *context* does not need to implement all functions. If an unimplemented
	-- function is called, an error will be thrown indicating that the function
	-- cannot be called in that context.
	--
	-- The user of a context is not expected to call these functions from
	-- different threads. An error will be thrown if a function is called from a
	-- thread not known by the ContextManager.
	While: (
		self: ContextManager<X>,
		verb: string,
		context: (ContextObject)->(),
		body: () -> ()
	) -> (),
	-- Returns the object containing the public-facing context functions.
	Object: X,
}

type ContextObject = {[string]: any}

-- Creates a new ContextManager. Each argument is the name of a function expected
-- to be in object X.
local function newContextManager<X>(...: string): ContextManager<X>
	local self = {}

	type ThreadState = {
		Verb: string,
		Object: ContextObject,
	}

	-- Must cast as any because type T is not implemented by T+metatable.
	local threadStates: {[thread]: ThreadState} = setmetatable({}, {__mode="k"}) :: any

	local object: ContextObject = {}
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
				error(string.format("cannot call %q while %s", field, state.Verb), 2)
			end
			return implementation(...)
		end
	end
	-- Assume that given fields implement X.
	self.Object = object :: any

	function self.While(
		self: ContextManager<X>,
		verb: string,
		context: (ContextObject) -> (),
		body: () -> ()
	)
		local t: ContextObject = {}
		context(t)
		local state = {Verb = verb, Object = t}
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
--@ord: -3
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

--@sec: Result
--@def: type Result = {
-- 	Type: ResultType,
-- 	Okay: boolean,
-- 	Reason: string,
-- 	Trace: string?,
-- }
--@doc: Represents the result of a unit. Converting to a string displays a
-- formatted result.
--
-- Field  | Type                     | Description
-- -------|--------------------------|------------
-- Type   | [ResultType][ResultType] | Indicates the type of result.
-- Okay   | boolean                  | The status of the unit; whether the unit succeeded or failed. For benchmarks, this will be false if the benchmark errored. For nodes and plans, represents the conjunction of the status of all sub-units.
-- Reason | string                   | A message describing the reason for the status. Empty if the unit succeeded.
-- Trace  | string?                  | An optional stack trace to supplement the Reason.
export type Result = {
	Type: ResultType,
	Okay: boolean,
	Reason: string,
	Trace: string?,
}

-- Constructs a new immutable Result.
local function newResult(
	type: ResultType,
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
	Type: ResultType,
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
		ContextManager: ContextManager<T>?,
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
	ReconcileResults: (self: Node) -> boolean,
	ReconcileMetrics: (self: Node) -> boolean,

	-- Calls the given observers with the node's pending data.
	Inform: (
		self: Node,
		result: ResultObserver,
		metric: MetricObserver
	) -> (),
}

--@sec: ResultType
--@def: type ResultType = "test" | "benchmark" | "node" | "plan"
--@doc: Indicates the type of a result tree node.
--
-- Value     | Description
-- ----------|------------
-- test      | A test unit.
-- benchmark | A benchmark unit.
-- node      | A general node aggregating a number of units.
-- plan      | A discrete node representing a plan.
--
export type ResultType
	= "test"
	| "benchmark"
	| "node"
	| "plan"

--@sec: Metrics
--@def: type Metrics = {[string]: number}
--@doc: Metrics contains measurements made during a test or benchmark. It maps
-- the unit of a measurement to its value.
--
-- For a benchmark result, contains default and custom measurements reported
-- during the benchmark.
--
-- For a test result, contains basic measurements reported during the test.
--
-- For a node or plan result, contains aggregated measurements of all sub-units.
export type Metrics = {[string]: number}

-- Creates under *tree* a new Node of type *type*, parented to *parent* under
-- *key*. If *parent* is nil, the node is added to the root of *tree*.
local function newNode(tree: Tree, type: ResultType, parent: Node?, key: any): Node
	assert(key ~= nil, "key cannot be nil")
	local node: Node = setmetatable({
		Type = type,
		Tree = tree,
		Path = nil,
		Parent = parent,
		Children = {},
		Data = {
			ContextManager = nil,
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
-- marks the tree as dirty. Returns whether the data changed.
function Node.__index.UpdateResult(self: Node, result: Result?): boolean
	if table.isfrozen(self.Data) then
		return false
	end
	if compareResults(self.Data.Result, result) then
		return false
	end
	self.Data.Result = result
	self.Pending.Result = true
	self.Tree:Dirty()
	return true
end

-- Sets a metric of the node. Marks the metric as pending, and marks the tree as
-- dirty. Returns whether the data changed.
function Node.__index.UpdateMetric(self: Node, value: number, unit: string): boolean
	if table.isfrozen(self.Data) then
		return false
	end
	if self.Data.Metrics[unit] == value then
		return false
	end
	self.Data.Metrics[unit] = value
	self.Pending.Metrics[unit] = true
	self.Tree:Dirty()
	return true
end

-- Sets the benchmark metrics of the node. Marks the metrics as pending, and
-- marks the tree as dirty. Returns whether the data changed.
function Node.__index.UpdateBenchmark(self: Node, iterations: number, duration: number): boolean
	if table.isfrozen(self.Data) then
		return false
	end
	if self.Data.Iterations == iterations
	and self.Data.Duration == duration then
		return false
	end
	self.Data.Iterations = iterations
	self.Data.Duration = duration
	self.Pending.Benchmark = true
	self.Tree:Dirty()
	return true
end

-- If the node has child nodes, the Result of the node will be set to the
-- aggregation of the children's results.
function Node.__index.ReconcileResults(self: Node): boolean
	if #self.Children > 0 then
		local changed = false
		for _, node in self.Children do
			changed = node:ReconcileResults() or changed
		end
		if not changed then
			return false
		end
	elseif self.Pending.Result then
		return true
	end
	--TODO: aggregate reason/trace.
	local okay = true
	for _, node in self.Children do
		local result = node.Data.Result
		if result then
			okay = okay and result.Okay
			if not okay then
				break
			end
		end
	end
	local result
	if okay then
		result = newResult(self.Type, true, "")
	else
		result = newResult(self.Type, false, "one or more results failed")
	end
	return self:UpdateResult(result)
end

-- If the node has child nodes, the Metrics of the node will be set to the
-- aggregation of the children's metrics.
function Node.__index.ReconcileMetrics(self: Node): boolean
	if #self.Children > 0 then
		local changed = false
		for _, node in self.Children do
			changed = node:ReconcileMetrics() or changed
		end
		if not changed then
			return false
		end
	elseif self.Pending.Benchmark or next(self.Pending.Metrics) ~= nil then
		return true
	end
	local iterations = 0
	local duration = 0
	for _, node in self.Children do
		iterations += node.Data.Iterations
		duration += node.Data.Duration
	end
	local changed = self:UpdateBenchmark(iterations, duration)

	local metrics: Metrics = {}
	for _, node in self.Children do
		for unit, value in node.Data.Metrics do
			if metrics[unit] then
				metrics[unit] += value
			else
				metrics[unit] = value
			end
		end
	end
	for unit, value in metrics do
		changed = self:UpdateMetric(value, unit) or changed
	end
	return changed
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
		type: ResultType,
		parent: Node?,
		key: any
	) -> Node,

	-- Creates a new node frozen with an error result.
	CreateErrorNode: (self: Tree,
		type: ResultType,
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
function Tree.__index.CreateNode(self: Tree, type: ResultType, parent: Node?, key: any): Node
	return newNode(self, type, parent, key)
end

-- Creates a node as usual, but the result is filled in with an error, and the
-- node's data is frozen.
function Tree.__index.CreateErrorNode(
	self: Tree,
	type: ResultType,
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
--@ord: -2
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
-- Certain functions may only be called within certain **contexts**. For
-- example, [expect][T.expect] may only be called while testing, so it should
-- only be called within an [it][T.it] closure. Each description of a function
-- lists which contexts the function is allowed to be called. Some functions are
-- allowed to be called anywhere.
--
-- The following contexts are available:
--
-- - **planning**: While processing the current [Plan][Plan].
-- - **testing**: While running a test.
-- - **benchmarking**: While running a benchmark.
--
-- ## Benchmark functions
--
-- The [measure][T.measure] function defines a benchmark.
--
--TODO: finish T docs
export type T = {
	--@sec: T.describe
	--@def: describe: Clause<Closure>
	--@doc: **While:** planning
	--
	-- Defines a new scope for a test or benchmark. The closure is called
	-- immediately, while planning.
	describe: Clause<Closure>,

	--@sec: T.before_each
	--@def: before_each: Statement<Closure>
	--@doc: **While:** planning
	--
	-- Defines function to call before each unit within the scope. The closure
	-- is called while testing or benchmarking.
	before_each: Statement<Closure>,

	--@sec: T.after_each
	--@def: after_each: Statement<Closure>
	--@doc: **While:** planning
	--
	-- Defines a function to call after each unit within the scope. The closure
	-- is called while testing or benchmarking.
	after_each: Statement<Closure>,

	--@sec: T.it
	--@def: it: Clause<Closure>
	--@doc: **While:** planning
	--
	-- Defines a new test unit. The closure is called while testing.
	it: Clause<Closure>,

	--@sec: T.expect
	--@def: expect: Clause<Assertion>
	--@doc: **While:** testing
	--
	-- Expects the result of an assertion to be truthy. The closure is called
	-- while testing.
	expect: Clause<Assertion>,

	--@sec: T.expect_error
	--@def: expect_error: Clause<Closure>
	--@doc: **While:** testing
	--
	-- Expects the closure to throw an error. The closure is called while
	-- testing.
	expect_error: Clause<Closure>,

	--@sec: T.parameter
	--@def: parameter: ParameterClause
	--@doc: **While:** planning
	--
	-- Defines a parameter symbol that can be passed to [measure][T.measure].
	parameter: ParameterClause,

	--@sec: T.measure
	--@def: measure: BenchmarkClause
	--@doc: **While:** planning
	--
	-- Defines a new benchmark unit. The closure is called while benchmarking.
	measure: BenchmarkClause,

	--@sec: T.operation
	--@def: operation: Clause<Closure>
	--@doc: **While:** benchmarking (only once)
	--
	-- Defines the operation of a benchmark unit that is being measured. This
	-- operation is run repeatedly. The operation is called while benchmarking.
	-- This function must only be called once per benchmark.
	operation: Clause<Closure>,

	--@sec: T.reset_timer
	--@def: reset_timer: () -> ()
	--@doc: **While:** (doing anything)
	--
	-- Resets the unit's elapsed time and all metrics. Does not affect whether
	-- the timer is running.
	reset_timer: () -> (),

	--@sec: T.start_timer
	--@def: start_timer: () -> ()
	--@doc: **While:** (doing anything)
	--
	-- Starts or resumes the unit timer.
	start_timer: () -> (),

	--@sec: T.stop_timer
	--@def: stop_timer: () -> ()
	--@doc: **While:** (doing anything)
	--
	-- Stops the unit timer.
	stop_timer: () -> (),

	--@sec: T.report
	--@def: report: Detailed<number>
	--@doc: **While:** (doing anything)
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

--@sec: Clause
--@def: type Clause<X> = Statement<X> & Detailed<X>
--@doc: Receives X or a string. When a string, it returns a function that
-- receives X, enabling the following syntax sugar:
--
-- ```lua
-- clause(x)
-- clause "description" (x)
-- ```
export type Clause<X> = Statement<X> & Detailed<X>
export type Statement<X> = (X) -> ()
export type Detailed<X> = (description: any) -> Statement<X>

--@sec: Closure
--@def: type Closure = () -> ()
--@doc: A general function operating on upvalues.
export type Closure = () -> ()

--@sec: Assertion
--@def: type Assertion = () -> any
--@doc: Like a [Closure][Closure], except the caller expects a result.
export type Assertion = () -> any

--@sec: BenchmarkClause
--@def: type BenchmarkClause = BenchmarkStatement & BenchmarkDetailed
--@doc: Variation of clause and statement for benchmarks, which receives a
-- [Benchmark][Benchmark] and a variable number of specific
-- [Parameter][Parameter] values.
--
-- ```lua
-- clause(benchmark, ...Parameter)
-- clause "description" (benchmark, ...Parameter)
-- ```
export type BenchmarkClause = BenchmarkStatement & BenchmarkDetailed
export type BenchmarkStatement = (Benchmark, ...Parameter) -> ()
export type BenchmarkDetailed = (description: any) -> BenchmarkStatement

--@sec: Benchmark
--@def: type Benchmark = (...any) -> ()
--@doc: Like a [Closure][Closure], but receives values corresponding to the
-- [Parameters][Parameter] passed to [BenchmarkClause][BenchmarkClause].
export type Benchmark = (...any) -> ()

--@sec: ParameterClause
--@def: type ParameterClause = (name: string) -> (...any) -> Parameter
--@doc: Creates an parameter to be passed to a benchmark statement. *name* is
-- the name of the parameter, which is not optional. Each value passed is a
-- "variation" of the parameter to be benchmarked individually.
export type ParameterClause = (name: string) -> (...any) -> Parameter

--@sec: Parameter
--@def: type Parameter = unknown
--@doc: An opaque parameter to be passed to a
-- [BenchmarkClause][BenchmarkClause].
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

-- Represents the state of a plan. A plan may contain nested scopes, so the
-- plan's state is stacked-based.
type PlanState = {
	-- Stack of nodes.
	Stack: {Node},
	-- Creates a new node as a child of the node at the top of the stack,
	-- referred to using *key*. If *key* is equal to *compare* then the node's
	-- child location is used instead. A Unit of type *type* is set to the
	-- node's data.
	CreateNode: (self: PlanState, node: ResultType, key: any?, closure: Closure?) -> (),
	-- Returns the node at the top of the stack.
	PeekNode: (self: PlanState) -> Node,
	-- Pop the top node from the stack.
	PopNode: (self: PlanState) -> Node,
}

-- Creates a new PlanState.
local function newPlanState(tree: Tree): PlanState
	local self = {
		Stack = {},
	}

	function self.CreateNode(self: PlanState, node: ResultType, key: any?, closure: Closure?)
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

	function self.PeekNode(self: PlanState): Node
		return assert(self.Stack[#self.Stack], "empty stack")
	end

	function self.PopNode(self: PlanState): Node
		return assert(table.remove(self.Stack), "empty stack")
	end

	return self
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--@sec: Runner
--@ord: -1
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

--@sec: Plans
--@def: type Plans = Plan | ModuleScript | {[any]: Plans}
--@doc: Represents a [Plan][Plan], a spek ModuleScript, or a tree of such. Other
-- values cause an error, including ModuleScripts that do not qualify as speks.
export type Plans = Plan | {[any]: Plans}

--@sec: Plan
--@def: type Plan = (t: T) -> ()
--@doc: Receives a [T][T] to plan a testing suite.
export type Plan = (t: T) -> ()

-- Sets a context for running a plan.
local function planContext(ctxm: ContextManager<T>, tree: Tree, parent: Node): (ContextObject) -> ()
	local state = newPlanState(tree)

	-- Use parent node as the root context.
	table.insert(state.Stack, parent)

	return function(t: ContextObject)
		t.describe = newClause(function(desc: any?, closure: Closure)
			-- Run closure using created node as context.
			state:CreateNode("node", desc)
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
-- corresponding node is filled with a failing result. If a table is received
-- without a key, then its contents are added to the parent node.
local function processPlans(tree: Tree, plan: Plans, parent: Node?, key: any)
	if type(plan) == "function" then
		if key == nil then
			-- Better than nothing.
			key = debug.info(plan, "n")
			if key == "" then
				key = plan
			end
		end
		local node = tree:CreateNode("plan", parent, key)
		local ctxm = newContextManager(
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
		node.Data.ContextManager = ctxm
		local context = planContext(ctxm, tree, node)
		local ok, err
		ctxm:While("planning", context, function()
			-- Generate sub-tree by processing plan provided by plan.
			ok, err = pcall(plan::PCALLABLE, ctxm.Object)
		end)
		if not ok then
			node:UpdateResult(newResult(node.Type, false, err))
			table.freeze(node.Data)
		end
	elseif typeof(plan) == "Instance" then
		if plan:IsA("ModuleScript") and plan.Name:match("%.spek$") then
			-- Collapses into parent.
			if key == nil then
				-- Fallback to full name.
				key = plan:GetFullName()
			end
			local ok, plan = pcall(require, plan)
			if not ok then
				tree:CreateErrorNode("plan", parent, key, plan)
				return
			end
			processPlans(tree, plan, parent, key)
			return
		end
		tree:CreateErrorNode("plan", parent, key, "unexpected plan type %q", plan.ClassName)
	elseif type(plan) == "table" then
		if key == nil then
			-- Collapse into parent.
			for k, plan in plan do
				processPlans(tree, plan, parent, k)
			end
			return
		end
		local node = tree:CreateNode("node", parent, key)
		for k, plan in plan do
			processPlans(tree, plan, node, k)
		end
	else
		tree:CreateErrorNode("plan", parent, key, "unexpected plan type %q", typeof(plan))
	end
end

--@sec: Spek.runner
--@def: function Spek.runner(speks: Plans, config: UnitConfig?): Runner
--@doc: Creates a new [Runner][Runner] that runs the given [Plans][Plans]. An
-- optional [UnitConfig][UnitConfig] configures how units are run.
function export.runner(speks: Plans, config: UnitConfig?): Runner
	local tree = newTree()
	-- Build plan nodes by processing spek modules.
	processPlans(tree, speks)
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

-- A readable representation of the runner's results.
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

-- Runs the closure of *node*, which is assumed to operate on *state*.
-- Afterwards, propagates the data in *state* to the node.
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
	node:UpdateResult(result)
	node:UpdateBenchmark(state.Iterations, state.Duration)
	for unit, value in state.Metrics do
		node:UpdateMetric(value, unit)
	end
end

-- Contains the state of a running unit.
type UnitState = {
	Timing: boolean, -- Whether time measurement is active.
	Duration: number, -- Accumulated time measurement.
	StartTime: number, -- Last time the clock was updated.
	Result: Result?, -- Nil indicates okay, or no error.
	Iterations: number, -- Number of iterations of the unit.
	Metrics: Metrics, -- Reported metrics.
}

-- Creates a new UnitState.
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

-- Runs the closure of *node* as a test unit using *ctxm* to provide context.
local function runTest(node: Node, ctxm: ContextManager<T>)
	local state = newUnitState()
	state.Iterations = 1
	local function context(t: ContextObject)
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
	ctxm:While("testing", context, function()
		runUnit(node, state)
	end)
end

-- Runs the closure of *node* as a benchmark unit using *ctxm* to provide
-- context.
local function runBenchmark(node: Node, config: UnitConfig, ctxm: ContextManager<T>)
	local state = newUnitState()
	local operated = false
	local function context(t: ContextObject)
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
	ctxm:While("benchmarking", context, function()
		runUnit(node, state)
	end)
end

-- Begins a new run, visiting each node and running its unit.
function Runner.__index._start(self: _Runner): WaitGroup
	local wg = newWaitGroup()
	self._active = wg
	local function visit(node: Node, ctxm: ContextManager<T>?)
		if node.Type == "plan" then
			for _, child in node.Children do
				visit(child, node.Data.ContextManager)
			end
		elseif node.Type == "node" then
			for _, child in node.Children do
				visit(child, ctxm)
			end
		elseif node.Type == "test" then
			wg:Add(
				runTest,
				node,
				(assert(ctxm, "missing thread context"))
			)
		elseif node.Type == "benchmark" then
			wg:Add(
				runBenchmark,
				node,
				self._config,
				(assert(ctxm, "missing thread context"))
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
--@def: function Runner:Keys(path: Path?): {Path}?
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
--@def: function Runner:Value(path: Path): Result?
--@doc: Returns the current [result][Result] at *path*. Returns false if the
-- result is not yet ready. Returns nil if *path* does not exist or does not
-- have a result.
function Runner.__index.Value(self: _Runner, path: Path): Result?
	local node = self._tree.Nodes[path]
	if not node then
		return nil
	end
	return node.Data.Result
end

--@sec: Runner.Metrics
--@def: function Runner:Metrics(path: Path): Metrics?
--@doc: Returns a snapshot of the [metrics][Metrics] at *path*. Returns false if
-- the result is not yet ready. Returns nil if *path* does not exist or does not
-- have a result.
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

--@sec: ResultObserver
--@def: type ResultObserver = (path: Path, result: Result?) -> ()
--@doc: Observes the result of *path*.
export type ResultObserver = (path: Path, result: Result?) -> ()

--@sec: MetricObserver
--@def: type MetricObserver = (path: Path, unit: string, value: number) -> ()
--@doc: Observes metric *unit* of *path*.
export type MetricObserver = (path: Path, unit: string, value: number) -> ()

--@sec: Unsubscribe
--@def: type Unsubscribe = () -> ()
--@doc: Causes the associated observer to stop observing when called.
export type Unsubscribe = () -> ()

--@sec: Runner.ObserveResult
--@def: function Runner:ObserveResult(observer: ResultObserver): Unsubscribe
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
--@def: function Runner:ObserveMetric(observer: MetricObserver): Unsubscribe
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
