--!strict

--@sec: TaskPolyfill
--@ord: -10
--@doc: Provides a compatiblity shim for Roblox's task library by implementing a
-- scheduler.
--
-- Example usage:
--
-- ```lua
-- local TaskPolyfill = require("TaskPolyfill")
--
-- local scheduler = TaskPolyfill.new()
-- scheduler:SetErrorHandler(function(err: any, thread: thread?)
-- 	print("ERROR:", err)
-- 	if thread then
-- 		print(debug.traceback(thread))
-- 	end
-- end)
--
-- local task = scheduler:Library()
--
-- task.defer(function()
-- 	task.delay(1.25, function()
-- 		local function a()
-- 			error("errored")
-- 		end
-- 		a()
-- 	end)
-- 	print("A", task.wait(1))
-- 	print("B", task.wait(0.5))
-- 	print("C", task.wait(0.75))
-- end)
--
-- print("BEGIN SCHEDULER")
-- local i = 0
-- while scheduler:Step(i/60) do
-- 	i += 1
-- end
-- print("END SCHEDULER", i/60)
--
-- --> BEGIN SCHEDULER
-- --> A	1
-- --> ERROR:	script:16: errored
-- --> script:16 function a
-- --> script:18
-- -->
-- --> B	0.5
-- --> C	0.75
-- --> END SCHEDULER	2.25
-- ```
local export = {}

--@sec: Scheduler
--@ord: -1
--@def: type Scheduler
--@doc: Schedules threads for the purpose of emulating Roblox's task library.
local Scheduler = {__index={}}

export type Scheduler = {
	Library: (self: Scheduler) -> TaskLibrary,
	SetErrorHandler: (self: Scheduler, handler: ErrorHandler?) -> (),
	Step: (self: Scheduler, delta: number) -> boolean,
}

type _Scheduler = Scheduler & {
	-- List of suspended threads.
	_suspended: {ThreadState},
	-- List of deferred threads.
	_deferred: {ThreadState},
	-- The current time according to Step.
	_clock: number,
	-- Thread that cycles over queue and resumes pending threads.
	_cycle: thread,
	-- Function to handle thread errors.
	_handleError: ErrorHandler,

	_cancelThread: (self: _Scheduler, thread: thread) -> (),
	_resumeState: (self: _Scheduler, state: ThreadState) -> (),
}

--@sec: ErrorHandler
--@def: type ErrorHandler = (err: any, thread: thread?) -> ()
--@doc: Called when a thread managed by a [Scheduler][Scheduler] produces an
-- error. *err* is the produced error. *thread* is the thread that produced the
-- error, which can be passed to debug.traceback to acquire a stack trace of the
-- error. *thread* will be nil if the error originated from the scheduler.
export type ErrorHandler = (err: any, thread: thread?) -> ()

--@sec: TaskLibrary
--@def: type TaskLibrary = {
--	cancel: (thread) -> (),
--	defer: <A..., R...>(((A...) -> (R...)) | thread, A...) -> thread,
--	delay: <A..., R...>(number?, ((A...) -> (R...)) | thread, A...) -> thread,
--	desynchronize: () -> (),
--	spawn: <A..., R...>(((A...) -> (R...)) | thread, A...) -> thread,
--	synchronize: () -> (),
--	wait: (number?) -> number,
--}
--@doc: A drop-in replacement of Roblox's task library.
export type TaskLibrary = {
	cancel: (thread) -> (),
	defer: <A..., R...>(((A...) -> (R...)) | thread, A...) -> thread,
	delay: <A..., R...>(number?, ((A...) -> (R...)) | thread, A...) -> thread,
	desynchronize: () -> (),
	spawn: <A..., R...>(((A...) -> (R...)) | thread, A...) -> thread,
	synchronize: () -> (),
	wait: (number?) -> number,
}

-- Contains the the state of a thread managed by the scheduler.
type ThreadState = {
	-- The thread itself.
	thread: thread,
	-- Arguments to be passed to the thread when resumed, or the clock time when
	-- the thread was scheduled.
	args: {[number]: any, n: number} | number,
	-- Time when the thread should be resumed.
	expy: number,
}

--@sec: TaskPolyfill.new
--@def: TaskPolyfill.new(): Scheduler
--@doc: Returns a new [Scheduler][Scheduler].
function export.new()
	local self: _Scheduler = setmetatable({
		_suspended = {},
		_deferred = {},
		_clock = 0,
		_cycle = nil,
		_handleError = nil,
	}, Scheduler) :: any

	self._cycle = coroutine.create(function()
		local suspended = self._suspended
		local deferred = self._deferred

		while true do
			local entries = 0
			while #deferred > 0 do
				entries += 1
				if entries >= 80 then
					if self._handleError then
						self._handleError("maximum re-entrancy depth (80) exceeded", nil)
					end
					break
				end
				local snapshot = table.clone(deferred)
				table.clear(deferred)
				for _, state in snapshot do
					self:_resumeState(state)
				end
			end

			local pending: {ThreadState} = {}
			local i = 1
			local t = self._clock
			while i <= #suspended do
				local state = suspended[i]
				if t >= state.expy then
					-- Entry time has expired.
					table.remove(suspended, i)

					-- Insert so that pending is ordered ascending by expy.
					local j = #pending
					while j > 0 do
						if state.expy >= pending[j].expy then
							break
						end
						j = j - 1
					end
					table.insert(pending, j + 1, state)

					-- Skip increment; because of remove, the current index
					-- hasn't been checked yet.
				else
					i = i + 1
				end
			end

			for _, state in pending do
				self:_resumeState(state)
			end

			coroutine.yield(#suspended > 0 or #deferred > 0)
		end
		return false
	end)

	return self
end

-- Resumes a thread state.
function Scheduler.__index._resumeState(self: _Scheduler, state: ThreadState)
	-- if coroutine.status(state.thread) == "dead" then
	-- 	return
	-- end
	local args = state.args
	local ok, result
	if type(args) == "number" then
		ok, result = coroutine.resume(state.thread, self._clock-args)
	else
		ok, result = coroutine.resume(state.thread, table.unpack(args, 1, args.n))
	end
	if not ok and self._handleError then
		self._handleError(result, state.thread)
	end
end

-- Locates and removes *thread* from the scheduler's queue.
function Scheduler.__index._cancelThread(self: _Scheduler, thread: thread)
	--TODO: Robust removal.
	for i, data in self._suspended do
		if data.thread == thread then
			table.remove(self._suspended, i)
			return
		end
	end
	for i, data in self._deferred do
		if data.thread == thread then
			table.remove(self._deferred, i)
			return
		end
	end
end

--@sec: Scheduler.SetErrorHandler
--@def: Scheduler:SetErrorHandler(handler: ErrorHandler?)
--@doc: SetErrorHandler sets an [ErrorHandler][ErrorHandler] that is called when
-- a thread produces an error.
--
-- By default, no function is set, causing any errors to be discarded.
function Scheduler.__index.SetErrorHandler(self: _Scheduler, handler)
	self._handleError = handler
end

--@sec: Scheduler.Library
--@def: function Scheduler:Library(): TaskLibrary
--@doc: Returns a new [TaskLibrary][TaskLibrary] that uses the scheduler to
-- manage threads.
--
-- The desynchronize and synchronize functions are not implemented; calling them
-- does nothing.
function Scheduler.__index.Library(self: _Scheduler): TaskLibrary
	local function toThread<A..., R...>(f: ((A...) -> (R...)) | thread): thread
		if type(f) == "thread" then
			return f
		else
			return coroutine.create(f)
		end
	end
	return table.freeze{
		spawn = function<A..., R...>(f: ((A...) -> (R...)) | thread, ...: A...): thread
			local thread = toThread(f)
			self:_resumeState({
				thread = thread,
				args = table.pack(...),
				expy = 0,
			})
			return thread
		end,
		defer = function<A..., R...>(f: ((A...) -> (R...)) | thread, ...: A...): thread
			local thread = toThread(f)
			table.insert(self._deferred, {
				thread = thread,
				args = table.pack(...),
				expy = 0,
			})
			return thread
		end,
		delay = function<A..., R...>(duration: number?, f: ((A...) -> (R...)) | thread, ...: A...): thread
			local thread = toThread(f)
			table.insert(self._suspended, {
				thread = thread,
				args = table.pack(...),
				expy = self._clock + (duration or 0),
			})
			return thread
		end,
		wait = function(duration: number?): number
			table.insert(self._suspended, {
				thread = coroutine.running(),
				args = self._clock,
				expy = self._clock + (duration or 0),
			})
			return coroutine.yield()
		end,
		cancel = function(thread: thread)
			self:_cancelThread(thread)
			local ok, err = coroutine.close(thread)
			if not ok then
				error(err, 2)
			end
		end,
		desynchronize = function()end,
		synchronize = function()end,
	}
end

--@sec: Scheduler.Step
--@def: function Scheduler:Step(time: number): boolean
--@doc: Performs one frame of the scheduler. *time* is the current time. Returns
-- true if the scheduler is managing any threads.
--
-- Examples of usage:
--
-- ```lua
-- -- Drive scheduler using Roblox APIs.
-- task.spawn(function()
-- 	while true do
-- 		sheduler:Step(os.clock())
-- 		RunService.Heartbeat:Wait()
-- 	end
-- end)
-- ```
--
-- ```lua
-- -- One-off simulation of clock running at 60 FPS.
-- local i = 0
-- while scheduler:Step(i/60) do
-- 	i += 1
-- end
-- ```
function Scheduler.__index.Step(self: _Scheduler, time: number): boolean
	self._clock = time
	local ok, result = coroutine.resume(self._cycle)
	assert(ok, result)
	return result
end

return table.freeze(export)
