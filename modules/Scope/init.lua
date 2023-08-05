--@sec: Scope
--@ord: -1
--@doc: The Scope module provides a means for scoping values, conveying
-- lifetime, and managing [tasks][Task].
--
-- Values set on a scope cascade downward to descendant scopes. Values can also
-- be subscribed to for observing changes.
--
-- The Scope class implements scoped values and provides lifetime management.
--
-- A Scope is not reusable. After the scope has been destroyed, all methods
-- become **inert**; any behavior becomes a no-op, and any returned objects are
-- also inert.
local export = {}

export type Scope = {
	Context: (self: Scope) -> Context,
	Set: (self: Scope, key: any, value: any) -> (),
	Destroy: (self: Scope) -> (),
	Wrap: (self: Scope) -> (()->()),
	Derive: (self: Scope) -> Scope,
	Get: (self: Scope, key: any) -> any,
	Subscribe: (self: Scope, key: any, sub: Subscription) -> Unsubscriber,
	Alive: (self: Scope) -> boolean,
}

export type Context = {
	Derive: (self: Context) -> Scope,
	Get: (self: Context, key: any) -> any,
	Subscribe: (self: Context, key: any, sub: Subscription) -> Unsubscriber,
	Alive: (self: Context) -> boolean,
	Assign: (self: Context, name: any, task: Task?) -> (),
	AssignEach: (self: Context, ...Task) -> (),
	Connect: <T...>(self: Context, name: any?, signal: RBXScriptSignal<T...>, listener: (T...) -> ()) -> (),
	Clean: (self: Context, ...any) -> (),
	Unassign: (self: Context, name: any) -> Task?,
}

--@sec: Subscription
--@def: type Subscription = (value: any) -> ()
--@doc: Passed to [Subscribe][Context.Subscribe] to observe a scoped value.
--
-- **Examples:**
--
-- ```lua
-- local function subscription(value: any)
-- 	print("changed", value)
-- end
-- context:Subscribe("Foobar", subscription)
-- ```
export type Subscription = (value: any) -> ()

--@sec: Unsubscriber
--@def: type Unsubscriber = () -> ()
--@doc: Unsubscribes a [subscription][Context.Subscribe] when called.
--
-- **Examples:**
--
-- ```lua
-- local unsubscriber = context:Subscribe("Foobar", function subscription(value: any)
-- 	print("changed", value)
-- end)
-- unsubscriber()
-- ```
export type Unsubscriber = () -> ()

--@sec: Task
--@def: type Task = any
--@doc: A **task** is any value that encapsulates the finalization of some
-- procedure or state. "Cleaning" a task invokes it, causing the procedure or
-- state to be finalized.
--
-- All tasks must conform to the following contract when cleaning:
--
-- - A task must not produce an error.
-- - A task must not yield.
-- - A task must be idempotent. That is, it must finalize only once; cleaning an
--   already cleaned task should be a no-op.
-- - A task must not cause the production of more tasks.
--
-- When cleaning, certain known types are handled in specific ways. The
-- following types are known:
--
-- - `function`: The function is called.
-- - `thread`: The thread is canceled with `task.cancel`.
-- - `RBXScriptConnection`: The Disconnect method is called.
-- - `Instance`: The Destroy method is called.
-- - `table` without metatable: The value of each entry is cleaned. This applies
--   recursively, and such tables are cleaned only once. The table is cleared
--   unless it is frozen.
-- - `table` with metatable and Destroy function: Destroy is called as a method.
--
-- Other types are merely held onto until cleaned.
--
-- Any manner of finalization can be supported by wrapping it in a function.
--
-- **Examples:**
--
-- ```lua
-- -- Destroys the instance.
-- Scope.clean(Instance.new("Part"))
-- ```
export type Task = any

-- Tracks a scoped value and its subscriptions.
type _State = {
	-- The current value.
	_value: any,
	-- Subscriptions observing the value. Using Unsubscriber as the key ensures
	-- that it is unique while also being a key that the Unsubscriber can refer
	-- to in order to unsubscribe. Noe that, because a map is used,
	-- subscriptions are unordered.
	_subscriptions: {[Unsubscriber]: Subscription},
}

-- Implementation of Scope.
type _Scope = Scope & {
	-- Map of keys to values.
	_states: {[any]: _State},
	-- List of contexts attached to the scope. Used by Destroy to destroy
	-- contexts.
	_contexts: {Context},
	-- Set of child scopes. Used by Destroy to destroy all child scopes. Also
	-- used by Subscribe to find subscriptions inheriting a value. A map is used
	-- so that a child destroying itself can easily detach itself from the
	-- parent.
	_children: {[Scope]: true},
	-- The parent scope. Used by Get to look for inherited values, and to detach
	-- from the parent when destroying.
	_parent: _Scope?,
	-- Scope's own personal context. Used by Subscribe to automatically assign
	-- the resulting Unsubscriber. Created lazily.
	_context: Context?,
}

-- Implementation of Context.
type _Context = Context & {
	-- The associated scope.
	_scope: Scope?,
	-- Map of named tasks.
	_namedTasks: {[any]: Task},
	-- List of unnamed tasks.
	_unnamedTasks: {Task},
}

local task_cancel = task.cancel

-- Cleans *task*. *refs* is used to keep track of tables that have already been
-- traversed.
local function clean(task: Task, refs: {[any]:true}?)
	if not task then
		return
	end
	if type(task) == "function" then
		task()
	elseif type(task) == "thread" then
		task_cancel(task)
	elseif typeof(task) == "RBXScriptConnection" then
		task:Disconnect()
	elseif typeof(task) == "Instance" then
		task:Destroy()
	elseif type(task) == "table" then
		if getmetatable(task) == nil then
			if refs then
				if refs[task] then
					return
				end
				refs[task] = true
			else
				refs = {[task]=true}
			end
			for k, v in task do
				clean(v, refs)
			end
			if not table.isfrozen(task) then
				table.clear(task)
			end
		elseif type(task.Destroy) == "function" then
			task:Destroy()
		end
	end
end

local Scope = {__index={}}

--@sec: Context
--@def: type Context
--@doc: Encapsulates certain behaviors of a [Scope][Scope] and provides task
-- management.
--
-- Only readable behaviors of the scope can be accessed from the context. While
-- writable behaviors like [Set][Scope.Set] and [Destroy][Scope.Destroy] aren't
-- available, [Derive][Context.Derive] can be used to create a complete child
-- scope.
local Context = {__index={}}

-- Returns a new Scope. If *alive* is false, then an inert Scope is returned.
local function newScope(alive: boolean, parent: _Scope?)
	local self = setmetatable({
		_alive = {alive=alive},
		_states = {},
		_contexts = {},
		_children = {},
		_parent = nil,
		_context = nil,
	}, Scope)

	if alive and parent then
		self._parent = parent
		parent._children[self] = true
	end

	return table.freeze(self)
end

-- Returns a new Context derived from *scope*. If *scope* is nil, then an inert
-- Context is returned.
local function newContext(scope: _Scope?): Context
	local self = setmetatable({
		_scope = scope,
		_namedTasks = {},
		_unnamedTasks = {},
	}, Context)

	if scope then
		table.insert(scope._contexts, self)
	end

	return self
end

--@sec: Scope.Context
--@def: function Scope:Context(): Context
--@doc: Returns a new [Context][Context] attached to the lifetime of the scope.
--
-- Returns an inert context if the scope is dead.
--
-- **Examples:**
--
-- ```lua
-- local context = scope:Context()
-- ```
function Scope.__index:Context(): Context
	if not self._alive.alive then
		return newContext()
	end
	return newContext(self)
end

-- Recursively updates inheriting subscriptions to *key* with *value*.
local function updateSubscriptions(scope: _Scope, key: any, value: any)
	local state = scope._states[key]
	if state then
		if state._value ~= nil then
			-- Shadowed.
			return
		end
		for _, sub in state._subscriptions do
			task.defer(sub, value)
		end
	end
	for child in scope._children do
		updateSubscriptions(child, key, value)
	end
end

--@sec: Scope.Set
--@def: function Scope:Set(key: any, value: any)
--@doc: Sets a value visible to the scope and its descendants. Setting a value
-- flows downward to child scopes, but not upward to parent scopes.
--
-- When setting, any subscriptions to *key* are called with *value*. Descendant
-- scopes are traversed recursively and their subscriptions called as well. A
-- descendant that overrides *key* with a non-nil value is not traversed.
--
-- Does nothing if the scope is dead.
--
-- **Examples:**
--
-- Keys can be set to values. The key does not need to be a string.
--
-- ```lua
-- scope:Set("theme", Theme.new("Light"))
-- ```
--
-- Setting to nil unsets the key. If the scope has an ancestor with the same
-- key, the scope will get the value from there instead.
--
-- ```lua
-- local parentScope = Scope.new()
-- local lightTheme = Theme.new("Light")
-- parentScope:Set("theme", lightTheme)
--
-- local childScope = parentScope:Derive()
-- -- Value is inherited from parent scope.
-- print(childTheme:Get("theme")) --> Light
--
-- local darkTheme = Theme.new("Dark")
-- childScope:Set("theme", darkTheme)
-- -- Value is shadowed in child scope.
-- print(childTheme:Get("theme")) --> Dark
--
-- childScope:Set("theme", nil)
-- -- Value is unset, returning to the inherited value.
-- print(childTheme:Get("theme")) --> Light
-- ```
function Scope.__index:Set(key: any, value: any)
	local state = self._states[key]
	if not state then
		state = {
			_value = nil,
			_subscriptions = {},
		}
		self._states[key] = state
	end
	state._value = value
	for _, sub in state._subscriptions do
		task.defer(sub, value)
	end
	if value == nil and next(state._subscriptions) == nil then
		-- Clean up empty value state.
		self._states[key] = nil
	end
	for child in self._children do
		updateSubscriptions(child, key, value)
	end
end

--@sec: Scope.Destroy
--@def: function Scope:Destroy()
--@doc: Signals the end of the scope's lifetime. All descendant scopes are
-- destroyed, all subscriptions are unsubscribed, and tasks assigned to
-- associated contexts are cleaned. The scope, descendants, and contexts become
-- inert.
--
-- Does nothing if the scope is dead.
--
-- **Examples:**
--
-- ```lua
-- scope:Destroy()
-- ```
function Scope.__index:Destroy()
	if not self._alive.alive then
		return
	end
	self._alive.alive = false

	if self._parent then
		self._parent._children[self] = nil
	end
	for child in self._children do
		child:Destroy()
	end

	for key, state in self._states do
		state._value = nil
		for unsub, sub in state._subscriptions do
			task.defer(sub, nil)
			state._subscriptions[unsub] = nil
		end
		self._states[key] = nil
	end

	for _, context in self._contexts do
		if self._scope then
			self._scope = nil
			clean(self._namedTasks)
			clean(self._unnamedTasks)
		end
	end
end

--@sec: Scope.Wrap
--@def: function Scope:Wrap(): ()->()
--@doc: Encapsulates the scope by returning a function that destroys the scope
-- when called.
--
-- Returns an inert function if the scope is dead.
--
-- **Examples:**
--
-- ```lua
-- local task = scope:Wrap()
-- ```
function Scope.__index:Wrap(): (()->())
	if not self._alive.alive then
		return function()end
	end
	return function()
		self:Destroy()
	end
end

--@sec: Scope.Derive
--@def: function Scope:Derive(): Scope
--@doc: Creates a child scope. See [Context.Derive][Context.Derive].
--
-- **Examples:**
--
-- ```lua
-- local childScope = parentScope:Derive()
-- ```
function Scope.__index:Derive(): Scope
	if not self._alive.alive then
		return newScope(false)
	end
	return newScope(true, self)
end

--@sec: Scope.Get
--@def: function Scope:Get(key: any): any
--@doc: Gets a scoped value. See [Context.Get][Context.Get].
--
-- **Examples:**
--
-- ```lua
-- scope:Set("theme", Theme.new("Dark"))
-- print(scope:Get("theme")) --> Dark
-- ```
function Scope.__index:Get(key: any): any
	local scope = self
	while scope and scope._alive.alive do
		local state = scope._states[key]
		if state then
			return state._value
		end
		scope = scope._parent
	end
	return nil
end

--@sec: Scope.Subscribe
--@def: function Scope:Subscribe(key: any, sub: Subscription): Unsubscriber
--@doc: Subscribes to a value. See [Context.Subscribe][Context.Subscribe].
--
-- **Examples:**
--
-- ```lua
-- -- Subscription is called immediately.
-- scope:Subscribe("theme", function(theme)
--	print("updated theme to", theme)
-- end)
-- --> updated theme to nil
--
-- -- Setting value observes the change.
-- scope:Set("theme", Theme.new("Light"))
-- --> updated theme to Light
--
-- -- Unsetting value still observes the change.
-- scope:Set("theme", nil)
-- --> updated theme to nil
-- ```
function Scope.__index:Subscribe(key: any, sub: Subscription): Unsubscriber
	if not self._alive.alive then
		return function()end
	end
	local context = self._context
	if not context then
		self._context = newContext(self)
	end
	return self:Subscribe(key, sub)
end

--@sec: Scope.Alive
--@def: function Scope:Alive(): boolean
--@doc: Returns false after the scope has been destroyed, and true otherwise.
--
-- **Examples:**
--
-- ```lua
-- local scope = Scope.new()
-- print(scope:Alive()) --> true
-- scope:Destroy()
-- print(scope:Alive()) --> false
-- ```
function Scope.__index:Alive(): boolean
	return not not self._alive.alive
end

--@sec: Context.Context
--@def: function Context:Context(): Context
--@doc: Returns a new [Context][Context] attached to the lifetime of the
-- context's scope.
--
-- Returns an inert context if the context is dead.
--
-- **Examples:**
--
-- ```lua
-- local otherContext = context:Context()
-- ```
function Context.__index:Context(): Context
	return newContext(self._scope)
end

--@sec: Context.Derive
--@def: function Context:Derive(): Scope
--@doc: Creates a child [Scope][Scope] whose lifetime is attached to the
-- context's associated scope.
--
-- Returns an inert scope if the context is dead.
--
-- **Examples:**
--
-- ```lua
-- local childScope = parentContext:Derive()
-- ```
function Context.__index:Derive(): Scope
	if not self._scope then
		return newScope(false)
	end
	return newScope(true, self._scope)
end

--@sec: Context.Get
--@def: function Context:Get(key: any): any
--@doc: Returns the value currently assigned to *key* from the associated scope.
-- If the value is nil, then Get will attempt to retrieve recursively from
-- ancestor scopes, if available.
--
-- Returns nil if the context is dead.
--
-- **Examples:**
--
-- ```lua
-- context:Set("theme", Theme.new("Dark"))
-- print(context:Get("theme")) --> Dark
-- ```
function Context.__index:Get(key: any): any
	if not self._scope then
		return nil
	end
	return self._scope:Get(key)
end

--@sec: Context.Subscribe
--@def: function Context:Subscribe(key: any, sub: Subscription): Unsubscriber
--@doc: Subscribes to *key* from the associated scope, calling *sub* initially
-- and when the value assigned to *key* changes. Returns a function that
-- unsubscribes when called.
--
-- The returned [Unsubscriber][Unsubscriber] is automatically assigned to the
-- context, so it does not need to be handled manually. It is assigned using
-- itself as the name, so it can be unassigned by passing it to
-- [Unassign][Context.Unassign].
--
-- While the value of *key* is nil, the subscription will observe changes to the
-- nearest existing *key* from ancestor scopes.
--
-- Does nothing and returns an inert function if the context is dead.
--
-- **Examples:**
--
-- ```lua
-- -- Subscription is called immediately.
-- context:Subscribe("theme", function(theme)
-- 	print("updated theme to", theme)
-- end)
-- --> updated theme to nil
--
-- -- Setting value observes the change.
-- context:Set("theme", Theme.new("Light"))
-- --> updated theme to Light
--
-- -- Unsetting value still observes the change.
-- context:Set("theme", nil)
-- --> updated theme to nil
-- ```
--
-- The unsubscriber is automatically assigned to the context under itself.
--
-- ```lua
-- local unsub = context:Subscribe("theme", function(value)
-- 	print("updated theme to", theme)
-- end)
--
-- -- Unassign from the context so that we can handle it ourselves.
-- context:Unassign(unsub)
--
-- -- Assignment to itself looks like this.
-- context:Assign(unsub, unsub)
-- ```
function Context.__index:Subscribe(key: any, sub: Subscription): Unsubscriber
	local scope = self._scope
	if not scope then
		return function()end
	end
	local state = scope._states[key]
	if not state then
		state = {
			_value = nil,
			_subscriptions = {},
		}
		scope._states[key] = state
	end
	local function unsub()
		if not state._subscriptions[unsub] then
			return
		end
		state._subscriptions[unsub] = nil
		if state._value == nil and next(state._subscriptions) == nil then
			-- Clean up empty value state.
			scope._states[key] = nil
		end
	end
	state._subscriptions[unsub] = sub
	-- Ensure the task is managed by assigning it to the context. Using unsub as
	-- the name ensures that the name is unique while also giving the user the
	-- option to unassign it.
	if self._namedTasks[unsub] then
		error("panic: unsubscriber is not unique")
	end
	self._namedTasks[unsub] = unsub
	return unsub
end

--@sec: Context.Alive
--@def: function Context:Alive(): boolean
--@doc: Returns false after the context has been destroyed, and true otherwise.
-- A context is destroyed when its associated [Scope][Scope] is destroyed.
--
-- **Examples:**
--
-- ```lua
-- if context:Alive() then
-- 	context:Connect("heartbeat", RunService.Heartbeat:Connect(function(dt)
-- 		print("delta time", dt)
-- 	end))
-- end
-- ```
function Context.__index:Alive(): boolean
	return not not self._scope
end

--@sec: Context.Assign
--@def: function Context:Assign(name: any, task: Task?)
--@doc: Performs an action depending on the type of *task*. If *task* is nil,
-- then the task assigned as *name* is cleaned, if present. Otherwise, *task* is
-- assigned to the context as *name*. If a different task (according to
-- rawequal) is already assigned as *name*, then it is cleaned.
--
-- If the context is dead, *task* is cleaned immediately.
--
-- **Examples:**
--
-- A task can be assigned under a referable name. The name does not have to be a
-- string.
--
-- ```lua
-- context:Assign("part", Instance.new("Part"))
-- ```
--
-- Setting an assigned task to nil unassigns it from the context and cleans it.
--
-- ```lua
-- context:Assign("part", nil) -- Remove task and clean it.
-- ```
--
-- Assigning a task with a name that is already assigned cleans the previous
-- task first.
--
-- ```lua
-- context:Assign("part", Instance.new("Part"))
-- context:Assign("part", Instance.new("WedgePart"))
-- ```
function Context.__index:Assign(name: any, task: Task?)
	if not self._scope then
		clean(task)
		return
	end
	if task then
		local prev = self._namedTasks[name]
		if not rawequal(prev, task) then
			self._namedTasks[name] = task
			if prev then
				clean(prev)
			end
		end
	else
		local prev = self._namedTasks[name]
		self._namedTasks[name] = nil
		clean(prev)
	end
end

--@sec: Context.AssignEach
--@def: function Context:AssignEach(...: Task)
--@doc: Assigns each given argument as an unnamed task.
--
-- If the context is dead, the each task is cleaned immediately.
--
-- **Examples:**
--
-- ```lua
-- context:AssignEach(Instance.new("Part"), Instance.new("Model"))
-- context:AssignEach(Instance.new("Frame"), Instance.new("TextButton"))
-- ```
function Context.__index:AssignEach(...: Task)
	if not self._scope then
		for i = 1, select("#", ...) do
			local task = select(i, ...)
			clean(task)
		end
		return
	end
	for i = 1, select("#", ...) do
		local task = select(i, ...)
		if task then
			table.insert(self._unnamedTasks, task)
		end
	end
end

--@sec: Context.Connect
--@def: function Context:Connect<T...>(name: any?, signal: RBXScriptSignal<T...>, listener: (T...) -> ())
--@doc: Connects *listener* to *signal*, then assigns the resulting connection
-- to the context as *name*. If *name* is nil, then the connection is assigned
-- as an unnamed task instead. Does nothing if the context is dead.
--
-- Connect is the preferred method when using contexts to manage signals,
-- primarily to resolve problems concerning the assignment to a dead context:
--
-- - Slightly more efficient than regular assignment, since the connection of
--   the signal is never made.
-- - Certain signals can have side-effects when connecting, so avoiding the
--   connection entirely is more correct.
--
-- **Examples:**
--
-- ```lua
-- context:Connect("heartbeat", RunService.Heartbeat, function(dt)
-- 	print("delta time", dt)
-- end)
-- ```
function Context.__index:Connect<T...>(
	name: any?,
	signal: RBXScriptSignal<T...>,
	listener: (T...) -> ()
)
	if not self._scope then
		return
	end
	local connection = signal:Connect(listener)
	if name == nil then
		table.insert(self._unnamedTasks, connection)
	else
		self:Assign(name, connection)
	end
end

--@sec: Context.Clean
--@def: function Context:Clean(...: any)
--@doc: Receives a number of names, and cleans the task assigned to the context
-- for each name. Does nothing if the context is dead, and does nothing for
-- names that have no assigned task.
--
-- **Examples:**
--
-- ```lua
-- context:Clean("heartbeat", "part")
-- ```
function Context.__index:Clean(...: any)
	if not self._scope then
		return
	end
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		local task = self._namedTasks[name]
		self._namedTasks[name] = nil
		clean(task)
	end
end

--@sec: Context.Unassign
--@def: function Context:Unassign(name: any): Task?
--@doc: Removes the task assigned to the context as *name*, returning the task
-- without cleaning it. Returns nil if no task is assigned as *name*, or if the
-- context is dead.
--
-- **Examples:**
--
-- ```lua
-- context:Assign("part", Instance.new("Part"))
-- local part = context:Unassign("part")
-- ```
function Context.__index:Unassign(name: any): Task?
	if not self._scope then
		return nil
	end
	local task = self._namedTasks[name]
	self._namedTasks[name] = nil
	return task
end

--@sec: Scope.new
--@ord: -1
--@def: function Scope.new(): Scope
--@doc: Returns a new instance of the Scope class.
--
-- **Examples:**
--
-- ```lua
-- local scope = Scope.new()
-- ```
function export.new(): Scope
	return newScope(true)
end

--@sec: Scope.clean
--@ord: -2
--@def: function Scope.clean(...: Task)
--@doc: Cleans each argument. Does nothing for arguments that are not known
-- [Task][Task] types.
--
-- **Examples:**
--
-- ```lua
-- Scope.clean(Instance.new("Part"))
-- ```
function export.clean(...: Task)
	for i = 1, select("#", ...) do
		local task = select(i, ...)
		clean(task)
	end
end

--@sec: Scope.wrap
--@ord: -2
--@def: function Scope.wrap(...: Task): () -> ()
--@doc: Encapsulates the given tasks in a function that cleans them when called.
--
-- **Examples:**
--
-- ```lua
-- local conn = RunService.Heartbeat:Connect(function(dt)
-- 	print("delta time", dt)
-- end)
-- return Scope.wrap(conn)
-- ```
function export.wrap(...: Task): () -> ()
	local tasks
	if select("#", ...) == 1 then
		tasks = ...
	else
		tasks = {...}
	end
	return function()
		local t = tasks
		if t then
			tasks = nil
			clean(t)
		end
	end
end

return table.freeze(export)
