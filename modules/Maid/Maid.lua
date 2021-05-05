--@sec: Maid
--@ord: -1
--@doc: Maid manages tasks. A task is a value that represents the active state
-- of some procedure or object. Finishing a task causes the procedure or object
-- to be finalized. How this occurs depends on the type:
--
-- - **function**: The function is called with no arguments.
-- - **RBXScriptConnection**: The Disconnect method is called.
-- - **Instance**: The Destroy method is called.
-- - **Maid**: The FinishAll method is called.
--
-- Unknown task types are held by the maid until finished, but are otherwise
-- ignored.
--
-- A task that yields is treated as an error.
local Maid = {__index={}}

-- finalizeTask checks the type of a task and finalizes it as appropriate.
-- Unknown types are ignored.
local function finalizeTask(task)
	local t = typeof(task)
	if t == "function" then
		task()
	elseif t == "RBXScriptConnection" then
		task:Disconnect()
	elseif t == "Instance" then
		task:Destroy()
	elseif getmetatable(task) == Maid then
		return task:FinishAll()
	end
end

--@sec: Maid.new
--@ord: -1
--@def: Maid.new(): Maid
--@doc: new returns a new Maid instance.
local function new()
	return setmetatable({
		_tasks = {},
		_thread = false,
	}, Maid)
end

--@sec: Maid.is
--@ord: -1
--@def: Maid.is(v: any): boolean
--@doc: is returns whether *v* is an instance of Maid.
local function is(v)
	return getmetatable(v) == Maid
end

local success = newproxy()
-- threadTask runs a task within a thread, which will both catch errors and
-- detect if the task yields. The thread can be reused as long as a task
-- behaves.
local function threadTask(self, task)
	if not self._thread then
		self._thread = coroutine.create(function()
			while true do
				finalizeTask(coroutine.yield(success))
			end
		end)
		-- Initialize to enter loop.
		coroutine.resume(self._thread)
	end
	local ok, err = coroutine.resume(self._thread, task)
	if not ok then
		-- Task errored, return it.
		self._thread = false
		return err
	elseif err ~= success then
		-- Task yielded, which isn't allowed.
		self._thread = false
		return "unexpected yield while finishing task"
	end
	return nil
end

--@sec: Maid.Task
--@def: Maid:Task(name: string, task: any?): (err: string?)
--@doc: Task assigns *task* to the maid with the given name. If *task* is nil,
-- and the maid has task *name*, then the task is completed. Returns an error if
-- the task yielded or errored.
function Maid.__index:Task(name, task)
	assert(type(name) == "string", "string expected")
	assert(string.sub(name, 1, 1) ~= "_", "name cannot begin with underscore")
	if task ~= nil then
		self._tasks[name] = task
		return nil
	end
	local task = self._tasks[name]
	if task == nil then
		return nil
	end
	self._tasks[name] = nil
	return threadTask(self, task)
end

--@sec: Maid.\__newindex
--@def: Maid[name: string] = (task: any?)
--@doc: Alias for Task. If an error occurs, it is thrown.
function Maid:__newindex(name, task)
	local err = self:Task(name, task)
	if err ~= nil then
		error(err, 2)
	end
end

--@sec: Maid.TaskEach
--@def: Maid:TaskEach(...any)
--@doc: TaskEach assigns each argument as an unnamed task.
function Maid.__index:TaskEach(...)
	local tasks = table.pack(...)
	for i = 1, tasks.n do
		table.insert(self._tasks, tasks[i])
	end
end

local errors = {
	__tostring = function(self)
		return table.concat(self, "\n")
	end,
}

--@sec: Maid.Finish
--@def: Maid:Finish(...string): (errs: {string}?)
--@doc: Finish completes the tasks of the given names. Names with no assigned
-- task are ignored. Returns an error for each task that yields or errors, or
-- nil if all tasks finished successfully.
function Maid.__index:Finish(...)
	local names = table.pack(...)
	local errs = nil
	for i = 1, names.n do
		local name = names[i]
		local task = self._tasks[name]
		if task ~= nil then
			local err = threadTask(self, task)
			if err then
				if errs == nil then
					errs = setmetatable({}, errors)
				end
				table.insert(errs, string.format("task %s: %s", tostring(name), err))
			end
			self._tasks[name] = nil
		end
	end
	return errs
end

--@sec: Maid.FinishAll
--@def: Maid:FinishAll(): (errs: {string}?)
--@doc: FinishAll completes all assigned tasks. Returns an error for each task
-- that yields or errors, or nil if all tasks finished successfully.
function Maid.__index:FinishAll()
	local errs = nil
	for name, task in pairs(self._tasks) do
		local err = threadTask(self, task)
		if err then
			if errs == nil then
				errs = setmetatable({}, errors)
			end
			table.insert(errs, string.format("task %s: %s", tostring(name), err))
		end
	end
	table.clear(self._tasks)
	return errs
end

return {
	new = new,
	is = is,
}
