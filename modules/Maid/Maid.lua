--@sec: Errors
--@def: type Errors = {error}
--@doc: Errors is a list of errors.
local Errors = {}
function Errors:__tostring()
	if #self == 0 then
		return "no errors"
	elseif #self == 1 then
		return tostring(self[1])
	end
	local s = table.create(#self+1)
	table.insert(s, "multiple errors:")
	for _, err in ipairs(self) do
		table.insert(s, "\t" .. string.gsub(tostring(err), "\n", "\n\t"))
	end
	return table.concat(s, "\n")
end

local function newErrors()
	return setmetatable({}, Errors)
end

--@sec: TaskError
--@def: type TaskError = {Name: string|number, Err: error}
--@doc: TaskError indicates an error that occurred from the completion of a
-- task. The Name field is the name of the task that errored. The type will be a
-- number if the task was unnamed. The Err field is the underlying error that
-- occurred.
local TaskError = {}
function TaskError:__tostring()
	return string.format("task %s: %s", tostring(self.Name), tostring(self.Err))
end

local function newTaskError(name, err)
	return setmetatable({
		Name = name,
		Err = err,
	}, TaskError)
end

--@sec: Maid
--@ord: -1
--@doc: Maid manages tasks. A task is a value that represents the active state
-- of some procedure or object. Finishing a task causes the procedure or object
-- to be finalized. How this occurs depends on the type:
--
-- - `() -> error?`: The function is called. If an error is returned, it is
--   propagated to the caller as a [TaskError][TaskError].
-- - `RBXScriptConnection`: The Disconnect method is called.
-- - `Instance`: The Destroy method is called.
-- - `Maid`: The FinishAll method is called. If an error is returned, it is
--   propagated to the caller as a [TaskError][TaskError].
--
-- Unknown task types are held by the maid until finished, but are otherwise
-- ignored.
--
-- A task that yields is treated as an error. Additionally, an error occurs if a
-- maid tries to finalize a task while already finalizing a task.
local Maid = {__index={}}

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

-- finalizeTask checks the type of a task and finalizes it as appropriate.
-- Unknown types are ignored.
local function finalizeTask(task)
	local t = typeof(task)
	if t == "function" then
		local err = task()
		return err
	elseif t == "RBXScriptConnection" then
		task:Disconnect()
		return nil
	elseif t == "Instance" then
		task:Destroy()
		return nil
	elseif is(task) then
		return task:FinishAll()
	end
end

local success = newproxy()
local taskerr = newproxy()
-- threadTask runs a task within a thread, which will both catch errors and
-- detect if the task yields. The thread can be reused as long as a task
-- behaves.
local function threadTask(self, task)
	if not self._thread then
		self._thread = coroutine.create(function(task)
			while true do
				local err = finalizeTask(task)
				if err == nil then
					task = coroutine.yield(success)
				else
					task = coroutine.yield(taskerr, err)
				end
			end
		end)
	end
	if coroutine.status(self._thread) ~= "suspended" then
		return "cannot run finalizer within finalizer"
	end
	local ok, status, err = coroutine.resume(self._thread, task)
	if not ok then
		-- Task errored, return it.
		self._thread = false
		return status
	elseif status == taskerr then
		return err
	elseif status ~= success then
		-- Task yielded, which isn't allowed.
		self._thread = false
		return "unexpected yield while finishing task"
	end
	return nil
end

--@sec: Maid.Task
--@def: Maid:Task(name: string, task: any?): (err: error?)
--@doc: Task assigns *task* to the maid with the given name. If *task* is nil,
-- and the maid has task *name*, then the task is completed. Returns a
-- [TaskError][TaskError] if the completed task yielded or errored.
--
-- *name* is not allowed to begin with an underscore.
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
	local err = threadTask(self, task)
	if err ~= nil then
		return newTaskError(name, err)
	end
	return nil
end

--@sec: Maid.\__newindex
--@def: Maid[name: string] = (task: any?)
--@doc: Alias for Task. If an error occurs, it is thrown.
function Maid:__newindex(name, task)
	local err = self:Task(name, task)
	if err ~= nil then
		--TODO: return err directly once the engine can receive any value type.
		error(tostring(err), 2)
	end
end

--@sec: Maid.TaskEach
--@def: Maid:TaskEach(...: any)
--@doc: TaskEach assigns each argument as an unnamed task.
function Maid.__index:TaskEach(...)
	local tasks = table.pack(...)
	for i = 1, tasks.n do
		table.insert(self._tasks, tasks[i])
	end
end

--@sec: Maid.Skip
--@def: Maid:Skip(...: string)
--@doc: Skip removes the tasks of the given names without completing them. Names
-- with no assigned task are ignored.
function Maid.__index:Skip(...)
	local names = table.pack(...)
	for i = 1, names.n do
		local name = names[i]
		self._tasks[name] = nil
	end
end

--@sec: Maid.Finish
--@def: Maid:Finish(...: string): (errs: Errors?)
--@doc: Finish completes the tasks of the given names. Names with no assigned
-- task are ignored. Returns a [TaskError][TaskError] for each task that yields
-- or errors, or nil if all tasks finished successfully.
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
					errs = newErrors()
				end
				table.insert(errs, newTaskError(name, err))
			end
			self._tasks[name] = nil
		end
	end
	return errs
end

--@sec: Maid.FinishAll
--@def: Maid:FinishAll(): (errs: Errors?)
--@doc: FinishAll completes all assigned tasks. Returns a [TaskError][TaskError]
-- for each task that yields or errors, or nil if all tasks finished
-- successfully.
function Maid.__index:FinishAll()
	local errs = nil
	for name, task in pairs(self._tasks) do
		local err = threadTask(self, task)
		if err then
			if errs == nil then
				errs = newErrors()
			end
			table.insert(errs, newTaskError(name, err))
		end
	end
	table.clear(self._tasks)
	return errs
end

return {
	new = new,
	is = is,
}
