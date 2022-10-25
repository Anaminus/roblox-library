--@sec: Maid
--@doc: The Maid module provides methods to manage tasks. A **task** is any
-- value that encapsulates the finalization of some procedure or state.
-- "Cleaning" a task invokes it, causing the procedure or state to be finalized.
--
-- All tasks have the following contract when cleaning:
--
-- - A task must not produce an error.
-- - A task must not yield.
-- - A task must finalize only once; cleaning an already cleaned task should be
--   a no-op.
-- - A task must not cause the production of more tasks.
--
-- ### Maid class
--
-- The **Maid** class is used to manage tasks more conveniently. Tasks can be
-- assigned to a maid to be cleaned later.
--
-- A task can be assigned to a maid as "named" or "unnamed". With a named task:
--
-- - The name can be any non-nil value.
-- - A named task can be individually cleaned.
-- - A named task can be individually unassigned from the maid without cleaning
--   it.
--
-- Unnamed tasks can only be cleaned by destroying the maid.
--
-- Any value can be assigned to a maid. Even if a task is not a known task type,
-- the maid will still hold on to the value. This might be used to hold off
-- garbage collection of a value that otherwise has only weak references.
--
-- A maid is not reusable; after a maid has been destroyed, any tasks assigned
-- to the maid are cleaned immediately.
local export = {}

local DEBUG = false

export type Task = any

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

--@sec: Maid.clean
--@ord: -2
--@def: function Maid.clean(...: Task)
--@doc: The **clean** function cleans each argument. Does nothing for arguments
-- that are not known task types. The following types are handled:
--
-- - `function`: The function is called.
-- - `thread`: The thread is canceled with `task.cancel`.
-- - `RBXScriptConnection`: The Disconnect method is called.
-- - `Instance`: The Destroy method is called.
-- - `table` without metatable: The value of each entry is cleaned. This applies
--   recursively, and such tables are cleaned only once. The table is cleared
--   unless it is frozen.
-- - `table` with metatable and Destroy function: Destroy is called as a method.
function export.clean(...: Task)
	for i = 1, select("#", ...) do
		local task = select(i, ...)
		clean(task)
	end
end

--@sec: Maid.wrap
--@ord: -2
--@def: function Maid.wrap(...: Task): () -> ()
--@doc: The **wrap** function encapsulates the given tasks in a function that
-- cleans them when called.
--
-- **Example:**
-- ```lua
-- local conn = RunService.Heartbeat:Connect(function(dt)
-- 	print("delta time", dt)
-- end)
-- return Maid.wrap(conn)
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

-- If debugging, wrap returns a callable table instead of a function, allowing
-- the contents to be inspected.
if DEBUG then
	function export.wrap(...: Task): () -> ()
		local self
		if select("#", ...) == 1 then
			self = {tasks = ...}
		else
			self = {tasks = {...}}
		end
		setmetatable(self, {
			__call = function(self)
				local tasks = self.tasks
				if tasks then
					self.tasks = nil
					clean(tasks)
				end
			end,
		})
		return self
	end
end

local Maid = {__index=setmetatable({}, {
	__index = function(self, k)
		error(string.format("cannot index maid with %q", tostring(k)), 2)
	end,
})}

export type Maid = typeof(setmetatable({}, Maid))

--@sec: Maid.new
--@ord: -1
--@def: function Maid.new(): Maid
--@doc: The **new** constructor returns a new instance of the Maid class.
--
-- **Example:**
-- ```lua
-- local maid = Maid.new()
-- ```
function export.new(): Maid
	local self = {
		-- Map of names to tasks. Can be nil, indicating that the maid is
		-- destroyed.
		_namedTasks = {},
		-- List of unnamed tasks.
		_unnamedTasks = {},
	}
	return setmetatable(self, Maid)
end

--@sec: Maid.Alive
--@def: function Maid:Alive(): boolean
--@doc: The **Alive** method returns false when the maid is destroyed, and true
-- otherwise.
--
-- **Example:**
-- ```lua
-- if maid:Alive() then
-- 	maid.heartbeat = RunService.Heartbeat:Connect(function(dt)
-- 		print("delta time", dt)
-- 	end)
-- end
-- ```
function Maid.__index:Alive(): boolean
	return not not self._namedTasks
end

--@sec: Maid.Assign
--@def: function Maid:Assign(name: any, task: Task?)
--@doc: The **Assign** method performs an action depending on the type of
-- *task*. If *task* is nil, then the task assigned as *name* is cleaned, if
-- present. Otherwise, *task* is assigned to the maid as *name*. If a different
-- task (according to rawequal) is already assigned as *name*, then it is
-- cleaned.
--
-- If the maid is destroyed, *task* is cleaned immediately.
--
-- **Examples:**
-- ```lua
-- maid:Assign("part", Instance.new("Part"))
-- ```
--
-- Setting an assigned task to nil unassigns it from the maid and cleans it.
--
-- ```lua
-- maid:Assign("part", nil) -- Remove task and clean it.
-- ```
--
-- Assigning a task with a name that is already assigned cleans the previous
-- task first.
--
-- ```lua
-- maid:Assign("part", Instance.new("Part"))
-- maid:Assign("part", Instance.new("WedgePart"))
-- ```
function Maid.__index:Assign(name: any, task: Task?)
	if not self._namedTasks then
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

--@sec: Maid.AssignEach
--@def: function Maid:AssignEach(...: Task)
--@doc: The **AssignEach** method assigns each given argument as an unnamed
-- task.
--
-- If the maid is destroyed, the each task is cleaned immediately.
function Maid.__index:AssignEach(...: Task)
	if not self._namedTasks then
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

--@sec: Maid.Clean
--@def: function Maid:Clean(...: any)
--@doc: The **Clean** method receives a number of names, and cleans the task
-- assigned to the maid for each name. Does nothing if the maid is destroyed,
-- and does nothing for names that have no assigned task.
function Maid.__index:Clean(...: any)
	if not self._namedTasks then
		return
	end
	for i = 1, select("#", ...) do
		local name = select(i, ...)
		local task = self._namedTasks[name]
		self._namedTasks[name] = nil
		clean(task)
	end
end

--@sec: Maid.Connect
--@def: function Maid:Connect(name: any?, signal: RBXScriptSignal, listener: () -> ())
--@doc: The **Connect** method connects *listener* to *signal*, then assigns the
-- resulting connection to the maid as *name*. If *name* is nil, then the
-- connection is assigned as an unnamed task instead. Does nothing if the maid
-- is destroyed.
--
-- Connect is the preferred method when using maids to manage signals, primarily
-- to resolve problems concerning the assignment to a destroyed maid:
-- - Slightly more efficient than regular assignment, since the connection of
--   the signal is never made.
-- - Certain signals can have side-effects when connecting, so avoiding the
--   connection entirely is more correct.
--
-- **Example:**
-- ```lua
-- maid:Connect("heartbeat", RunService.Heartbeat, function(dt)
-- 	print("delta time", dt)
-- end)
-- ```
function Maid.__index:Connect(name: any, signal: RBXScriptSignal, listener: () -> ())
	if not self._namedTasks then
		return
	end
	local connection = signal:Connect(listener)
	if name == nil then
		table.insert(self._unnamedTasks, connection)
	else
		self:Assign(name, connection)
	end
end

--@sec: Maid.Destroy
--@def: function Maid:Destroy()
--@doc: The **Destroy** method cleans all tasks currently assigned to the maid.
-- Does nothing if the maid is destroyed.
--
-- **Example:**
-- ```lua
-- maid:Destroy()
-- ```
function Maid.__index:Destroy()
	local namedTasks = self._namedTasks
	if not namedTasks then
		return
	end
	local unnamedTasks = self._unnamedTasks
	self._namedTasks = false
	self._unnamedTasks = false
	clean(namedTasks)
	clean(unnamedTasks)
end

--@sec: Maid.Unassign
--@def: function Maid:Unassign(name: any): Task
--@doc: The **Unassign** method removes the task assigned to the maid as *name*,
-- returning the task. Returns nil if no task is assigned as *name*, or if the
-- maid is Destroyed.
function Maid.__index:Unassign(name: any): Task
	if not self._namedTasks then
		return nil
	end
	local task = self._namedTasks[name]
	self._namedTasks[name] = nil
	return task
end

--@sec: Maid.Wrap
--@def: function Maid:Wrap(): () -> ()
--@doc: The **Wrap** method encapsulates the maid by returning a function that
-- cleans the maid when called.
--
-- **Example:**
-- ```lua
-- return maid:Wrap()
-- ```
function Maid.__index:Wrap(): () -> ()
	return export.wrap(self)
end

--@sec: Maid.__newindex
--@def: Maid[any] = Task?
--@doc: Assigns a task according to the [Assign][Maid.Assign] method, where the
-- index is the name, and the value is the task. If the index is a string that
-- is a single underscore, then the task is assigned according to
-- [AssignEach][Maid.AssignEach] instead.
--
-- Tasks can be assigned to the maid like a table:
--
-- ```lua
-- maid.foo = task -- Assign task as "foo".
-- ```
--
-- Setting an assigned task to nil unassigns it from the maid and cleans it:
--
-- ```lua
-- maid.foo = nil -- Remove task and clean it.
-- ```
--
-- Assigning a task with a name that is already assigned cleans the previous
-- task first:
--
-- ```lua
-- maid.foo = task      -- Assign task as "foo".
-- maid.foo = otherTask -- Remove task, clean it, and assign otherTask as "foo".
-- ```
--
-- Assigning to the special `_` index assigns an unnamed task (to explicitly
-- assign as `_`, use the [Assign][Maid.Assign] method).
--
-- ```lua
-- maid._ = task      -- Assign task.
-- maid._ = otherTask -- Assign otherTask.
-- ```
--
-- **Note**: Tasks assigned to the maid cannot be indexed:
--
-- ```lua
-- print(maid.foo)
-- --> ERROR: cannot index maid with "foo"
-- ```

function Maid:__newindex(name: any, task: Task?)
	if name == "_" then
		self:AssignEach(task)
	else
		self:Assign(name, task)
	end
end

return table.freeze(export)
