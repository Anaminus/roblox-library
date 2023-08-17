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
-- type Input = Plan | ModuleScript | {[any]: Input}
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
	if #elements == 0 then
		s[1] = "(root)"
	end
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
	-- Optional function to call before resuming dependents.
	_beforeFinish: (wg: WaitGroup) -> ()?,

	Finish: (self: WaitGroup) -> (),
	--TODO: Add: <X...>(self: WaitGroup, func: (X...)->(), X...) -> (),
	Add: (self: WaitGroup, func: (...any)->(), ...any) -> (),
	AddThread: (self: WaitGroup, thread: thread) -> (),
	AddWaitGroup: (self: WaitGroup, wg: WaitGroup) -> (),
	Wait: (self: WaitGroup) -> (),
	Cancel: (self: WaitGroup) -> (),
}


-- Creates a new WaitGroup. Receives an optional function to run before each
-- time the WaitGroup finishes.
local function newWaitGroup(beforeFinish: (wg: WaitGroup)->()?): WaitGroup
	local self: WaitGroup = setmetatable({
		_dependencies = {},
		_dependents = {},
		_beforeFinish = beforeFinish,
	}, WaitGroup) :: any
	return table.freeze(self)
end

-- Called by a dependency to indicate that it is finished.
function WaitGroup.__index.Finish(self: WaitGroup)
	local thread = coroutine.running()
	if not self._dependencies[thread] then
		-- Ignore if thread is not a dependency.
		return
	end
	self._dependencies[thread] = nil
	if next(self._dependencies) then
		-- Still waiting on dependencies.
		return
	end
	if self._beforeFinish then
		self._beforeFinish(self)
	end
	for _, thread in self._dependents do
		task.defer(thread)
	end
	table.clear(self._dependents)
end

-- Adds a function call as a dependency thread to wait on.
function WaitGroup.__index.Add<X...>(self: WaitGroup, func: (X...)->(), ...: X...)
	local function doFunc<X...>(func: (X...)->(), ...: X...)
		local ok, err = pcall(func::PCALLABLE, ...)
		if not ok then
			error(string.format("waitgroup dependency errored: %s", err))
		end
		self:Finish()
	end
	local thread = task.defer(doFunc, func, ...)
	self._dependencies[thread] = true
end

-- Adds a thread as a dependency. The thread is expected to call Finish before
-- it dies.
function WaitGroup.__index.AddThread<X...>(self: WaitGroup, thread: thread)
	self._dependencies[thread] = true
end

-- Adds a WaitGroup as a dependency.
function WaitGroup.__index.AddWaitGroup<X...>(self: WaitGroup, wg: WaitGroup)
	local thread = task.defer(function()
		wg:Wait()
		self:Finish()
	end)
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

-- Creates a new ContextManager. Each argument is the name of a function
-- expected to be in object X. If an argument is a table, then it's fields are
-- mapped directly to X.
local function newContextManager<X>(...: string | {[any]:any}): ContextManager<X>
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
		if type(field) == "table" then
			for key, value in field do
				object[key] = value
			end
			continue
		end
		object[field] = function(...)
			local state = threadStates[coroutine.running()]
			if not state then
				-- Running thread is not present in context. The user must have
				-- called this function from a different thread.
				error(string.format("cannot call %s in new thread", field), 2)
			end
			local implementation = state.Object[field]
			if implementation == nil then
				-- Not implemented by this context.
				error(string.format("cannot call %q while %s", field, state.Verb), 2)
			end
			return implementation(...)
		end
	end
	-- Assume that given fields implement X.
	self.Object = table.freeze(object) :: any

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

--@sec: Config
--@ord: -3
--@def: type Config = {
-- 	Iterations: number?,
-- 	Duration: number?,
-- }
--@doc: Configures options for running a unit.
--
-- Field      | Type    | Description
-- -----------|---------|------------
-- Iterations | number? | Target iterations for each benchmark. If unspecified, or zero or less, Duration is used.
-- Duration   | number? | Target duration for each benchmark, in seconds. Defaults to 1.
--
export type Config = {
	Iterations: number?,
	Duration: number?,
}

-- Constructs an immutable Config.
local function newConfig(config: Config?): Config
	if type(config) == "table" then
		local cfg: Config = {}
		if type(config.Iterations) == "number" then
			cfg.Iterations = config.Iterations
		elseif config.Iterations ~= nil then
			error(string.format("Config.Iterations: number expected, got %s", typeof(config.Iterations)), 3)
		end
		if type(config.Duration) == "number" then
			cfg.Duration = config.Duration
		elseif config.Duration ~= nil then
			error(string.format("Config.Duration: number expected, got %s", typeof(config.Duration)), 3)
		end
		return table.freeze(cfg)
	elseif config == nil then
		return table.freeze{
			Iterations = nil,
			Duration = 1,
		}
	else
		error(string.format("Config expected, got %s", typeof(config)), 3)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--@sec: Result
--@def: type Result = {
-- 	Type: ResultType,
-- 	Status: boolean?,
-- 	Reason: string,
-- 	Trace: string?,
-- }
--@doc: Represents the result of a unit. Converting to a string displays a
-- formatted result.
--
-- The **Type** field is a [ResultType][ResultType] that indicates the type of
-- result.
--
-- The **Status** field indicates whether the unit succeeded or failed. A nil
-- status indicates that the result is pending. For benchmarks, it will be false
-- if the benchmark errored. For nodes and plans, represents the conjunction of
-- the status of all sub-units. If any sub-unit has a pending result, then the
-- status will also be pending.
--
-- The **Reason** field is a message describing the reason for the status.
-- Usually empty if the unit succeeded.
--
-- The **Trace** field is an optional stack trace to supplement the Reason.
export type Result = {
	Type: ResultType,
	Status: boolean?,
	Reason: string,
	Trace: string?,
}

-- Constructs a new immutable Result.
local function newResult(
	type: ResultType,
	status: boolean?,
	reason: string,
	trace: string?
): Result
	--TODO: Should be formattable.
	return table.freeze{
		Type = type,
		Status = status,
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
		-- By default, siblings nodes are run serially. If true, this node
		-- should be run concurrently in separate thread.
		Concurrent: boolean?,
		-- If true, this node should be among the only nodes run.
		Only: boolean?,
		-- If true, this node should not run.
		Skip: boolean?,
		-- Deferred closure associated with the node.
		Closure: Closure?,
		--  Closures to run before Closure.
		Before: {Closure},
		--  Closures to run after Closure.
		After: {Closure},
		-- Specific or aggregate result of the node. If the node was created as
		-- an error, this will be filled in with the error.
		Result: Result,
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

	-- Whether the node type indicates a leaf node.
	IsLeaf: (self: Node) -> boolean,

	-- Updates data of the node. Returns false if the node is frozen.
	UpdateResult: (self: Node, result: Result) -> boolean,
	UpdateMetric: (self: Node, unit: string, value: number) -> boolean,
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
--@def: type ResultType = "node" | "plan" | "test" | "benchmark"
--@doc: Indicates the type of a result tree node.
--
-- Value     | Description
-- ----------|------------
-- node      | A general node aggregating a number of units.
-- plan      | A discrete node representing a plan.
-- test      | A test unit.
-- benchmark | A benchmark unit.
--
export type ResultType
	= "node"
	| "plan"
	| "test"
	| "benchmark"

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
-- *key*. If *parent* is nil, the node assumed to be the root of *tree*.
local function newNode(tree: Tree, type: ResultType, parent: Node?, key: any): Node
	local node: Node = setmetatable({
		Type = type,
		Tree = tree,
		Path = nil,
		Parent = parent,
		Children = {},
		Data = {
			ContextManager = nil,
			Concurrent = false,
			Only = false,
			Skip = false,
			Closure = nil,
			Before = {},
			After = {},
			Result = newResult(type, nil, ""),
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
		-- Root node.
		node.Path = newPath()
		tree.Root = node
		tree.Nodes[node.Path] = node
	elseif parent ~= nil then
		assert(key ~= nil, "key cannot be nil")
		local elements = parent.Path:Elements()
		table.insert(elements, key)
		node.Path = newPath(table.unpack(elements))
		table.insert(parent.Children, node)
		tree.Nodes[node.Path] = node
	end
	return table.freeze(node)
end

-- Returns whether Type indicates a leaf node.
function Node.__index.IsLeaf(self: Node): boolean
	return self.Type == "test" or self.Type == "benchmark"
end

-- Returns true if *old* and *new* are equivalent.
local function tablesEqual(old: {[string]: any}, new: {[string]: any}): boolean
	for key, value in old do
		if new[key] ~= value then
			return false
		end
	end
	for key, value in new do
		if old[key] ~= value then
			return false
		end
	end
	return true
end

-- Sets the result of the node to *result*. Marks the result as pending, and
-- marks the tree as dirty. Returns whether the data changed.
function Node.__index.UpdateResult(self: Node, result: Result): boolean
	if table.isfrozen(self.Data) then
		return false
	end
	if tablesEqual(self.Data.Result, result) then
		return false
	end
	self.Data.Result = result
	self.Pending.Result = true
	self.Tree:Dirty()
	return true
end

-- Sets a metric of the node. Marks the metric as pending, and marks the tree as
-- dirty. Returns whether the data changed.
function Node.__index.UpdateMetric(self: Node, unit: string, value: number): boolean
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
-- aggregation of the children's results. Returns whether there were changes.
function Node.__index.ReconcileResults(self: Node): boolean
	if #self.Children == 0 then
		if self:IsLeaf() then
			-- Return whether leaf node has pending result.
			return self.Pending.Result
		end
		-- Non-leaf node with no children; aggregate as okay.
		return self:UpdateResult(newResult(self.Type, true, ""))
	end
	-- Reconcile children.
	local changed = false
	for _, node in self.Children do
		changed = node:ReconcileResults() or changed
	end
	if not changed then
		-- No changes, no need to process.
		return false
	end
	--TODO: aggregate reason/trace.
	local status: boolean? = true
	for _, node in self.Children do
		-- Have result status as first operand to ensure that nil status is
		-- propagated as nil.
		status = node.Data.Result.Status and status
		if not status then
			break
		end
	end
	local result
	if status == false then
		result = newResult(self.Type, false, "one or more results failed")
	else
		result = newResult(self.Type, status, "")
	end
	return self:UpdateResult(result)
end

-- If the node has child nodes, the Metrics of the node will be set to the
-- aggregation of the children's metrics.
function Node.__index.ReconcileMetrics(self: Node): boolean
	if #self.Children == 0 then
		-- Return whether leaf node has pending metrics.
		return self.Pending.Benchmark or next(self.Pending.Metrics) ~= nil
	end
	-- Reconcile children.
	local changed = false
	for _, node in self.Children do
		changed = node:ReconcileMetrics() or changed
	end
	if not changed then
		-- No changes, no need to process.
		return false
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
		changed = self:UpdateMetric(unit, value) or changed
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
	-- Encapsulates active state of a Runner.
	Active: {_active: WaitGroup?},
	-- Flat map of paths to nodes.
	Nodes: {[Path]: Node},
	-- The implicit root node.
	Root: Node,

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


	-- Active deferred maintenance thread. Indicates that the tree contains
	-- pending data.
	MaintenanceThread: thread?,
	-- Reconciles any dirty nodes.
	Maintenance: (self: Tree) -> (),
	-- Mark tree as dirty. At a defer point, the tree will perform maintenance.
	Dirty: (self: Tree) -> (),
	-- Update derivative data.
	ReconcileData: (self: Tree) -> (),
	-- Inform observers of changes.
	InformObservers: (self: Tree) -> (),
	-- Resets node results to pending.
	Reset: (self: Tree) -> (),
}

-- Creates a new Tree witht the given configuration.
local function newTree(): Tree
	local self: Tree = setmetatable({
		Active = nil,
		Nodes = {},
		Root = nil,
		ResultObserver = nil,
		MetricObserver = nil,
		MaintenanceThread = nil,
	}, Tree) :: any
	newNode(self, "node", nil)
	return self
end

-- Creates a new node refered to by *key* under *parent*, or root if *parent* is
-- nil.
function Tree.__index.CreateNode(self: Tree, type: ResultType, parent: Node?, key: any): Node
	if parent == nil then
		return newNode(self, type, self.Root, key)
	else
		return newNode(self, type, parent, key)
	end
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

-- Reconciles data and informs the configured observers of changed data.
function Tree.__index.Maintenance(self: Tree)
	self:ReconcileData()
	self:InformObservers()
	self.MaintenanceThread = nil
end

-- If the tree is not dirty, marks the tree as dirty, and defers a task that
-- performs maintenance.
function Tree.__index.Dirty(self: Tree)
	if self.MaintenanceThread then
		return
	end
	local thread = task.defer(function(self: Tree)
		self:Maintenance()
		if self.Active._active then
			self.Active._active:Finish()
		end
	end, self)
	self.MaintenanceThread = thread
	if self.Active._active then
		self.Active._active:AddThread(thread)
	end
end

-- Reconciles derivative data.
function Tree.__index.ReconcileData(self: Tree)
	self.Root:ReconcileResults()
	self.Root:ReconcileMetrics()
end

-- Calls the Inform method of each root node with the configured observers.
function Tree.__index.InformObservers(self: Tree)
	local result = self.ResultObserver or function()end
	local metric = self.MetricObserver or function()end
	self.Root:Inform(result, metric)
end

-- Resets node results to pending. If any maintenance is needed, it is performed
-- immediately.
function Tree.__index.Reset(self: Tree)
	for _, node in self.Nodes do
		if not table.isfrozen(node.Data) then
			node:UpdateResult(newResult(node.Type, nil, ""))
			for unit, value in node.Data.Metrics do
				node:UpdateMetric(unit, value)
			end
		end
	end
	-- Skip any deferred maintenance.
	if self.MaintenanceThread then
		task.cancel(self.MaintenanceThread)
	end
	self:Maintenance()
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
-- ## Statement functions
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
-- lists which contexts the function is allowed to be called.
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
-- ## Units
--
-- While planning, certain functions will produce a **unit**.
--
-- - The [it][T.it] function produces a test unit.
-- - The [measure][T.measure] function produces a benchmark unit.
-- - The [describe][T.describe] function produces an aggregate unit. This runs
--   each sub-unit it contains.
--
-- By default, aggregate units run their sub-units serially. This means that, in
-- turn, all units run serially. This is to ensure that upvalues aren't accessed
-- by more than one unit at the same time.
--
-- The above functions allow the "concurrently" flag to be specified. Doing so
-- will cause the unit to run concurrently with sibling units. This allows a
-- series of independent units to run at the same time rather than sequentially,
-- but care must be taken to ensure that no upvalues are shared with other
-- concurrent units.
--
-- An aggregate unit will wait for all sub-units to complete, whether they're
-- serial or concurrent.
--
-- ```lua
-- return function(t: Spek.T)
-- 	-- This context will run concurrently, but its contents still run serially.
-- 	t.describe "unit that takes 6 seconds to complete" (concurrently) (function()
-- 		t.it "takes 1 second to complete" (function()
-- 			task.wait(1)
-- 			t.assert(function()
-- 				return true
-- 			end)
-- 		end)
-- 		t.it "takes 2 seconds to complete" (function()
-- 			task.wait(2)
-- 			t.assert(function()
-- 				return true
-- 			end)
-- 		end)
-- 		t.it "takes 3 seconds to complete" (function()
-- 			task.wait(3)
-- 			t.assert(function()
-- 				return true
-- 			end)
-- 		end)
-- 	end)
-- 	-- This context will run serially, though it has no serial siblings.
-- 	t.describe "unit that takes 3 seconds to complete" (function()
-- 		t.it "takes 1 second to complete" (concurrently) (function()
-- 			task.wait(1)
-- 			t.assert(function()
-- 				return true
-- 			end)
-- 		end)
-- 		t.it "takes 2 seconds to complete" (concurrently) (function()
-- 			task.wait(2)
-- 			t.assert(function()
-- 				return true
-- 			end)
-- 		end)
-- 		t.it "takes 3 seconds to complete" (concurrently) (function()
-- 			task.wait(3)
-- 			t.assert(function()
-- 				return true
-- 			end)
-- 		end)
-- 	end)
-- end
-- ```
export type T = {
	--@sec: T.concurrently
	--@def: concurrently: Flag
	--@doc: When passed to a [FlagClause][FlagClause], causes the created unit
	-- to run concurrently with sibling units.
	concurrently: Flag,
	--@sec: T.only
	--@def: only: Flag
	--@doc: When passed to a [FlagClause][FlagClause], causes the created unit
	-- to be among the only units that run.
	only: Flag,
	--@sec: T.skip
	--@def: skip: Flag
	--@doc: When passed to a [FlagClause][FlagClause], causes the created unit
	-- to be skipped.
	skip: Flag,

	--@sec: T.describe
	--@def: describe: FlagClause<Closure>
	--@doc: **While:** planning
	--
	-- Defines a new scope for a test or benchmark. The closure is called
	-- immediately, while planning.
	describe: FlagClause<Closure>,

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
	--@def: it: FlagClause<Closure>
	--@doc: **While:** planning
	--
	-- Defines a new test unit. The closure is called while testing.
	it: FlagClause<Closure>,

	--@sec: T.expect
	--@def: expect: Clause<Assertion>
	--@doc: **While:** testing
	--
	-- Expects the result of an assertion to be truthy. The closure is called
	-- while testing. This function cannot be called within another expect
	-- function.
	expect: Clause<Assertion>,

	--@sec: T.expect_error
	--@def: expect_error: Clause<Closure>
	--@doc: **While:** testing
	--
	-- Expects the closure to throw an error. The closure is called while
	-- testing. This function cannot be called within another expect function.
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
	--@doc: **While:** testing, benchmarking
	--
	-- Resets the unit's elapsed time and all metrics. Does not affect whether
	-- the timer is running.
	reset_timer: () -> (),

	--@sec: T.start_timer
	--@def: start_timer: () -> ()
	--@doc: **While:** testing, benchmarking
	--
	-- Starts or resumes the unit timer.
	start_timer: () -> (),

	--@sec: T.stop_timer
	--@def: stop_timer: () -> ()
	--@doc: **While:** testing, benchmarking
	--
	-- Stops the unit timer.
	stop_timer: () -> (),

	--@sec: T.report
	--@def: report: Detailed<number>
	--@doc: **While:** planning, testing, benchmarking
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

	--@sec: T.TODO
	--@def: TODO: (format: string?, ...any) -> ()
	--@doc: Produces an okay result, but with a reason indicating that the plan
	-- or statement is not yet implemented. May optionally specify a formatted
	-- message as the reason.
	TODO: (format: string?, ...any) -> (),
}

--@sec: Clause
--@def: type Clause<X> = Statement<X> & Detailed<X>
--@doc: Returns a chain of functions based on received argument type, enabling
-- the following syntax sugars:
--
-- ```lua
-- clause(a)                -- statement
-- clause (description) (x) -- detailed
-- ```
--
-- The statement form is used when the function receives a function. The
-- detailed form is used otherwise. The function cannot receive nil.
export type Clause<X> = Statement<X> & Detailed<X>
export type Statement<X> = (X) -> ()
export type Detailed<X> = (description: string) -> Statement<X>

--@sec: FlagClause
--@def: type FlagClause<X> = Statement<X> & FlagDetailed<X> & Flagged<X>
--@doc: Returns a chain of functions based on received argument type, enabling
-- the following syntax sugars:
--
-- ```lua
-- clause(x)                           -- statement
-- clause (flags...) (x)               -- flagged
-- clause (description) (x)            -- detailed
-- clause (description) (flags...) (x) -- detailed flagged
-- ```
--
-- The statement form is used when the function receives a function. The flagged
-- form is used when the function receives a flag. The function cannot receive
-- nil. Otherwise, the detailed form is used when the second function receives a
-- function. The detailed flagged form is used when the second function receives
-- a flag.
export type FlagClause<X> = Statement<X> & FlagDetailed<X> & Flagged<X>
export type FlagDetailed<X> = (description: string) -> (Statement<X> & Flagged<X>)
export type Flagged<X> = (...Flag) -> Statement<X>

--@sec: Flag
--@def: type Flag = {type: "flag"}
--@doc: Refers to one of a specific set of values. These values are passed
-- through a [T][T] to be used by a [FlagClause][FlagClause].
--
-- - concurrent: Causes a unit to run concurrently.
-- - only: Causes a unit to be among the only units that run.
-- - skip: Causes a unit to be skipped.
export type Flag = {type: "flag"}

--@sec: Closure
--@def: type Closure = () -> ()
--@doc: A general function operating on upvalues.
export type Closure = () -> ()

--@sec: Assertion
--@def: type Assertion = () -> any
--@doc: Like a [Closure][Closure], except the caller expects a truthy or falsy
-- result. If an optional second value is returned with a falsy result, then it
-- will be used as the reason.
export type Assertion = () -> (any, any?)

--@sec: BenchmarkClause
--@def: type BenchmarkClause = BenchmarkStatement & BenchmarkDetailed & BenchmarkFlagged
--@doc: Variation of [FlagClause][FlagClause] for benchmarks, which receives a
-- [Benchmark][Benchmark] and a variable number of specific
-- [Parameter][Parameter] values.
--
-- ```lua
-- clause(benchmark, ...Parameter)
-- clause (flags...) (benchmark, ...Parameter)
-- clause (description) (benchmark, ...Parameter)
-- clause (description) (flags...) (benchmark, ...Parameter)
-- ```
export type BenchmarkClause = BenchmarkStatement & BenchmarkDetailed & BenchmarkFlagged
export type BenchmarkStatement = (Benchmark, ...Parameter) -> ()
export type BenchmarkDetailed = (description: string) -> (BenchmarkStatement & BenchmarkFlagged)
export type BenchmarkFlagged = (...Flag) -> BenchmarkStatement

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

-- Contains flags that have been set on a clause.
type Flags = {
	Concurrent: boolean,
	Only: boolean,
	Skip: boolean,
}

-- Constants representing flags passed to a FlagClause.
local CONCURRENT: Flag = table.freeze{type="flag", kind="concurrently"} :: any
local ONLY: Flag = table.freeze{type="flag", kind="only"} :: any
local SKIP: Flag = table.freeze{type="flag", kind="skip"} :: any

-- Returns whether a value is a valid flag.
local function isFlag(flag: any): boolean
	return flag == CONCURRENT
	or flag == ONLY
	or flag == SKIP
end

-- Converts a list of arguments into a Flags.
local function parseFlags(...: unknown): Flags
	local flags = {
		Concurrent = false,
		Only = false,
		Skip = false,
	}
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		if arg == CONCURRENT then
			flags.Concurrent = true
		elseif arg == ONLY then
			flags.Only = true
		elseif arg == SKIP then
			flags.Skip = true
		else
			error("unknown flag", 3)
		end
	end
	return table.freeze(flags)
end

-- Sets flags on the given node.
local function setFlags(node: Node, flags: Flags)
	if table.isfrozen(node.Data) then
		return
	end
	node.Data.Concurrent = flags.Concurrent
	node.Data.Only = flags.Only
	node.Data.Skip = flags.Skip
end

-- Returns a FlagClause function, where flags can optionally be passed after the
-- description.
--
--     clause (closure)
--     clause (description) (closure)
--     clause (flags...) (closure)
--     clause (description) (flags...) (closure)
--
-- If called with the non-description form, the description will be nil. If
-- called with the description form, errors if nil is passed as the description.
local function newFlagClause<X>(process: (description: any?, flags: Flags, closure: X)->()): FlagClause<X>
	return function(...: any): any
		if ... == nil then
			error("description cannot be nil", 2)
		elseif type(...) == "function" then
			-- clause (closure)
			local closure = ...
			process(nil, parseFlags(), closure)
			return
		elseif isFlag(...) then
			-- clause (flags...) (closure)
			local flags = parseFlags(...)
			return function(closure: X)
				process(nil, flags, closure)
			end
		else
			-- clause (description) ...
			local description = ...
			return function(...: any): Statement<X>?
				if type(...) == "function" then
					-- clause (description) (closure)
					local closure = ... :: X
					process(description, parseFlags(), closure)
					return
				elseif isFlag(...) then
					-- clause (description) (flags...) (closure)
					local flags = parseFlags(...)
					return function(closure: X)
						process(description, flags, closure)
					end
				else
					error("closure must be a function", 2)
				end
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
	CreateNode: (self: PlanState, node: ResultType, key: any?, flags: Flags, closure: Closure?) -> (),
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

	function self.CreateNode(self: PlanState, node: ResultType, key: any?, flags: Flags, closure: Closure?)
		local parent = self:PeekNode()
		if key == nil then
			-- Unlabeled statement. Use node's predicted location in
			-- parent.
			key = #parent.Children + 1
		end
		local node = tree:CreateNode(node, parent, key)
		node.Data.Closure = closure
		setFlags(node, flags)
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
	Root: (self: Runner) -> Path,
	All: (self: Runner) -> {Path},
	Paths: ((self: Runner, path: Path) -> {Path}?),
	Result: (self: Runner, path: Path) -> Result?,
	Metrics: (self: Runner, path: Path) -> Metrics?,
	ObserveResult: (self: Runner, observer: ResultObserver) -> ()->(),
	ObserveMetric: (self: Runner, observer: MetricObserver) -> ()->(),
}

type _Runner = Runner & {
	_active: WaitGroup?,
	_tree: Tree,
	_config: Config,
	_resultObservers: {[Unsubscribe]: ResultObserver},
	_metricObservers: {[Unsubscribe]: MetricObserver},
	_start: (self: _Runner) -> WaitGroup,
}

--@sec: Input
--@def: type Input = Plan | ModuleScript | {[any]: Input}
--@doc: Represents a [Plan][Plan], a valid spek ModuleScript, or a tree of such.
-- Inputs produce nodes within a [Runner][Runner]:
--
-- - A table produces a node for each entry.
-- - A spek produces a node for the spek.
-- - A plan does not produce a node, but its content usually does.
-- - Other values produce a node indicating an error.
export type Input = Plan | ModuleScript | {[any]: Input}
--TODO: Unioned table of union is not analyzed correctly (roblox/luau#664). To
--workaround, cast tables to whatever input types they include.

--@sec: Plan
--@def: type Plan = (t: T) -> ()
--@doc: Receives a [T][T] to plan a testing suite.
export type Plan = (t: T) -> ()

-- If a statement description is a string, returns it prefixed with *prefix*.
-- Otherwise, returns it unchanged.
local function wrapDesc<T>(prefix: string, desc: T): T
	if type(desc) == "string" then
		desc = prefix .. " " .. desc
	end
	return desc
end

-- Sets a context for running a plan.
local function planContext(ctxm: ContextManager<T>, tree: Tree, parent: Node): (ContextObject) -> ()
	local state = newPlanState(tree)

	-- Use parent node as the root context.
	table.insert(state.Stack, parent)

	return function(t: ContextObject)
		t.describe = newFlagClause(function(desc: any?, flags: Flags, closure: Closure)
			-- Run closure using created node as context.
			state:CreateNode("node", desc, flags)
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

		t.it = newFlagClause(function(desc: any?, flags: Flags, closure: Closure)
			state:CreateNode("test", desc, flags, closure)
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
		local function generateBenchmarks(key: any, flags: Flags, benchmark: Benchmark, ...: Parameter)
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
					state:CreateNode("benchmark", formatted, flags, function()
						benchmark(table.unpack(values, 1, values.n))
					end)
					state:PopNode()
				end)
			else
				-- Cannot produce variations of key. Generate only one benchmark
				-- using the first variation of each parameter.
				state:CreateNode("benchmark", key, flags, function()
					benchmark(table.unpack(firsts, 1, firsts.n))
				end)
				state:PopNode()
			end
		end

		function t.measure<X...>(...: any): BenchmarkStatement?
			if ... == nil then
				error("description cannot be nil", 2)
			elseif type(...) == "function" then
				-- clause (benchmark, parameters...)
				local benchmark = ...
				generateBenchmarks(nil, parseFlags(), benchmark, select(2, ...))
				return
			elseif isFlag(...) then
				-- clause (flags...) (benchmark, parameters...)
				local flags = parseFlags(...)
				return function(benchmark: Benchmark, ...: Parameter)
					generateBenchmarks(nil, flags, benchmark, ...)
				end
			else
				-- clause (description) ...
				local description = ...
				return function(...: any)
					if type(...) == "function" then
						-- clause (description) (benchmark, parameters...)
						local benchmark = ...
						generateBenchmarks(description, parseFlags(), benchmark, select(2, ...))
					elseif isFlag(...) then
						-- clause (description) (flags...) (benchmark, parameters...)
						local flags = parseFlags(...)
						return function(benchmark: Benchmark, ...: Parameter)
							assert(type(benchmark) == "function", "function expected")
							generateBenchmarks(description, flags, benchmark, ...)
						end
					else
						error("closure must be a function", 2)
					end
				end
			end
		end

		function t.report(unit: string)
			assert(type(unit) == "string", "string expected")
			return function(value: number)
				assert(type(value) == "number", "number expected")
				local node = state:PeekNode()
				node:UpdateMetric(unit, value)
			end
		end

		function t.TODO(format: string?, ...: any)
			local todo
			if format == nil then
				todo = "TODO: not implemented"
			else
				todo = string.format("TODO: "..format, ...)
			end
			local node = state:PeekNode()
			node:UpdateResult(newResult(node.Type, true, todo))
			table.freeze(node.Data)
		end
	end
end

-- Creates nodes under *parent* according to *input*.
local function processInput(tree: Tree, parent: Node, input: Input)
	if type(input) == "function" then
		-- Assumed to be a plan function.
		local ctxm = newContextManager(
			{
				concurrently = CONCURRENT,
				only = ONLY,
				skip = SKIP,
			},

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
			"report",

			"TODO"
		)
		-- A plan does not produce a node, because there's no reasonable key to
		-- use for it. Instead, the parent node is used. A consequence is that
		-- any input that contains a plan must produce a node in order for the
		-- plan to have something to operate on.
		parent.Data.ContextManager = ctxm
		local context = planContext(ctxm, tree, parent)
		local ok, err
		ctxm:While("planning", context, function()
			-- Generate sub-tree by processing plan provided by plan.
			ok, err = pcall(input::PCALLABLE, ctxm.Object)
		end)
		if not ok then
			-- Create single node representing the error.
			tree:CreateErrorNode("plan", parent, "error while planning", err)
			return
		end
		if #parent.Children == 0 then
			-- Plan must produce structure.
			tree:CreateErrorNode("plan", parent, "error while planning", "plan produced empty structure")
			return
		end
	elseif typeof(input) == "Instance" then
		-- A spek always creates a node.
		local key = input.Name
		if not input:IsA("ModuleScript") then
			tree:CreateErrorNode("node", parent, key, "unexpected spek class %q", input.ClassName)
			return
		end
		if not input.Name:match("%.spek$") then
			tree:CreateErrorNode("node", parent, key, "spek Name must have \".spek\" suffix")
			return
		end

		local node = tree:CreateNode("node", parent, key)
		local ok, inner = pcall(require, input)
		if not ok then
			tree:CreateErrorNode("plan", parent, key, inner)
			return
		end
		processInput(tree, node, inner)
	elseif type(input) == "table" then
		-- Each element of a table produces a node.
		for key, inner in input do
			local node = tree:CreateNode("node", parent, key)
			processInput(tree, node, inner)
		end
	else
		-- Anything else produces an error node.
		tree:CreateErrorNode("node", parent,
			"error traversing inputs",
			"unexpected input type %q", typeof(input)
		)
	end
end

--@sec: Spek.runner
--@def: function Spek.runner(input: Input, config: Config?): Runner
--@doc: Creates a new [Runner][Runner] that runs the given [Input][Input]. An
-- optional [Config][Config] configures how units are run.
function export.runner(input: Input?, config: Config?): Runner
	local tree = newTree()
	local self: _Runner = setmetatable({
		_active = nil,
		_tree = tree,
		_config = newConfig(config),
		_resultObservers = {},
		_metricObservers = {},
	}, Runner) :: any
	tree.Active = self
	if input ~= nil then
		processInput(tree, tree.Root, input)
	end
	tree.ResultObserver = function(path: Path, result: Result)
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

-- Walks a tree to produce formatted results.
local function walkTree(parent: Node, visit: ({node:Node,name:string})->(), level: string?)
	local sorted: {any} = table.clone(parent.Children)
	for i, node in sorted do
		sorted[i] = {
			name = tostring(node.Path:Base()),
			node = node,
		}
	end
	table.sort(sorted, function(a, b)
		return a.name < b.name
	end)
	for i, node in sorted do
		local last = i == #sorted
		local this = last and "└───" or "├───"
		node.name = if level then level .. this .. node.name else node.name
		visit(node)
		walkTree(node.node, visit, if level then level .. (last and "    " or "│   ") else "")
	end
end

-- A readable representation of the runner's results.
function Runner.__tostring(self: _Runner): string
	local nodes = {}
	local max = 0
	walkTree(self._tree.Root, function(node: {node:Node,name:string})
		table.insert(nodes, node)
		local l = utf8.len(node.name) or #node.name
		if l > max then
			max = l
		end
	end)
	local out = {""}
	for _, node in nodes do
		local result = node.node.Data.Result
		local status = result.Status
		local reason = result.Reason
		table.insert(out,
			node.name
			.. " "
			.. string.rep("…", max-(utf8.len(node.name) or #node.name))
			.. " | "
			.. (if status then " ok " elseif status == nil then "pend" else "FAIL")
			.. " | "
			.. reason
		)
	end
	return table.concat(out, "\n")
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
		node:UpdateResult(newResult(node.Type, true, ""))
	else
		node:UpdateResult(result)
	end
	node:UpdateBenchmark(state.Iterations, state.Duration)
	for unit, value in state.Metrics do
		node:UpdateMetric(unit, value)
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
	local expecting = false
	local function context(t: ContextObject)
		t.expect = newClause(function(description: any?, assertion: Assertion)
			if expecting then
				state.Result = newResult(node.Type, false, "cannot expect within expect")
				return
			end
			expecting = true
			if state.Result then
				expecting = false
				return
			end
			local ok, result, reason = pcall(assertion)
			if state.Result then
				-- In case of inner expect.
				expecting = false
				return
			end
			if ok then
				if result then
					-- Nil indicates okay result.
				elseif reason ~= nil then
					state.Result = newResult(node.Type, false, tostring(reason))
				elseif description ~= nil then
					state.Result = newResult(node.Type, false, wrapDesc("expect", description))
				else
					state.Result = newResult(node.Type, false, "expectation failed")
				end
			else
				state.Result = newResult(node.Type, ok, result)
			end
			expecting = false
		end)

		t.expect_error = newClause(function(description: any?, closure: Closure)
			if expecting then
				state.Result = newResult(node.Type, false, "cannot expect within expect")
				return
			end
			expecting = true
			local ok = pcall(closure)
			if state.Result then
				-- In case of inner expect.
				expecting = false
				return
			end
			if ok then
				local reason
				if description == nil then
					reason = "expect error"
				else
					reason = wrapDesc("expect error", description)
				end
				state.Result = newResult(node.Type, false, reason)
			end
			expecting = false
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

		function t.TODO(format: string?, ...: any)
			local todo
			if format == nil then
				todo = "TODO: not implemented"
			else
				todo = string.format("TODO: "..format, ...)
			end
			state.Result = newResult(node.Type, true, todo)
		end
	end
	ctxm:While("testing", context, function()
		runUnit(node, state)
	end)
end

-- Runs the closure of *node* as a benchmark unit using *ctxm* to provide
-- context.
local function runBenchmark(node: Node, ctxm: ContextManager<T>, config: Config)
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

		function t.TODO(format: string?, ...: any)
			local todo
			if format == nil then
				todo = "TODO: not implemented"
			else
				todo = string.format("TODO: "..format, ...)
			end
			state.Result = newResult(node.Type, true, todo)
		end
	end
	ctxm:While("benchmarking", context, function()
		runUnit(node, state)
	end)
end

-- Runs each unit in *node*. *outer* is an outer WaitGroup to which an inner
-- WaitGroup may be added. *ctxm* is passed down to children nodes. If
-- *onlyMode* is true, then leaf units do not run by default.
local function runUnits(self: _Runner, node: Node, outer: WaitGroup, onlyMode: boolean, ctxm: ContextManager<T>?)
	if node.Data.Skip then
		return
	end

	-- Whether to skip leaf unit. Also used for branch units: if branch unit has
	-- Only flag set while onlyMode is on, then it will run as though onlyMode
	-- is off, causing all descendant leaf units to run. Otherwise, it will run
	-- while passing state of onlyMode.
	local skip = onlyMode and not node.Data.Only

	-- Leaf units can be called directly. We may be inside a serial unit, where
	-- an error in one unit would prevent subsequent units from running, but the
	-- only potential errors are non-userspace.
	if node.Type == "test" then
		if skip then
			return
		end
		runTest(node, (assert(ctxm, "missing thread context")))
		return
	elseif node.Type == "benchmark" then
		if skip then
			return
		end
		runBenchmark(node, (assert(ctxm, "missing thread context")), self._config)
		return
	end

	-- Branch unit.

	-- Pass context manager to children, if available.
	if node.Data.ContextManager and ctxm then
		error("nested context managers")
	end
	ctxm = node.Data.ContextManager or ctxm

	-- Divide children into serial and concurrent units.
	local serial = {}
	local concurrent = {}
	for _, child in node.Children do
		if child.Data.Concurrent then
			table.insert(concurrent, child)
		else
			table.insert(serial, child)
		end
	end

	-- Represents lifetime of children units.
	local inner = newWaitGroup()

	-- Add serial units as one dependency.
	inner:Add(function(serial: {Node}, ctxm: ContextManager<T>?)
		for _, child in serial do
			runUnits(self, child, inner, skip, ctxm)
		end
	end, serial, ctxm)

	-- Add each concurrent unit individually.
	for _, child in concurrent do
		inner:Add(runUnits, self, child, inner, skip, ctxm)
	end

	-- Add inner as dependency of outer.
	outer:AddWaitGroup(inner)
end

-- Begins a new run, visiting each node and running its unit.
function Runner.__index._start(self: _Runner): WaitGroup
	self._tree:Reset()

	-- Represents lifetime of entire run.
	local wg = newWaitGroup(function(wg)
		if self._active == wg then
			self._active = nil
		end
	end)
	self._active = wg
	if self._tree.MaintenanceThread then
		wg:AddThread(self._tree.MaintenanceThread)
	end

	-- Determine whether there are any nodes that have Only flag set.
	local only = false
	for _, node in self._tree.Nodes do
		if node:IsLeaf() then
			only = only or (not not node.Data.Only and not node.Data.Skip)
		end
	end

	runUnits(self, self._tree.Root, wg, only)

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
	self._tree:Reset()
end

--@sec: Runner.Root
--@def: function Runner:Root(): Path
--@doc: Returns the [Path][Path] of the root node. The path contains zero
-- elements.
function Runner.__index.Root(self: _Runner): Path
	return self._tree.Root.Path
end

--@sec: Runner.All
--@def: function Runner:All(): {Path}
--@doc: Returns a list of all paths in the runner. Paths are sorted by their
-- string representation.
function Runner.__index.All(self: _Runner): {Path}
	local paths = {}
	for path in self._tree.Nodes do
		table.insert(paths, path)
	end
	table.sort(paths, function(a: any, b: any): boolean
		return a._string < b._string
	end)
	return paths
end

--@sec: Runner.Paths
--@def: function Runner:Paths(path: Path): {Path}?
--@doc: Returns paths of nodes that exist under the node of *path*. Returns nil
-- if *path* does not exist.
function Runner.__index.Paths(self: _Runner, path: Path?): {Path}?
	assert(path, "path expected")
	local node = self._tree.Nodes[path]
	if node then
		local paths = table.create(#node.Children)
		for _, child in node.Children do
			table.insert(paths, child.Path)
		end
		return paths
	end
	return nil
end

--@sec: Runner.Result
--@def: function Runner:Result(path: Path): Result?
--@doc: Returns the current [result][Result] at *path*. Returns nil if *path*
-- does not exist or does not have a result.
function Runner.__index.Result(self: _Runner, path: Path): Result?
	local node = self._tree.Nodes[path]
	if not node then
		return nil
	end
	return node.Data.Result
end

--@sec: Runner.Metrics
--@def: function Runner:Metrics(path: Path): Metrics?
--@doc: Returns a snapshot of the [metrics][Metrics] at *path*. Returns nil if
-- *path* does not exist or does not have a result.
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
--@def: type ResultObserver = (path: Path, result: Result) -> ()
--@doc: Observes the result of *path*.
export type ResultObserver = (path: Path, result: Result) -> ()

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
			if not desc.Name:match("%.spek$") then
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
