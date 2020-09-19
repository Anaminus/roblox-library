-- Implements a custom scheduler for managing threads.
local Sched = {}

--[[
type Driver = number
type ErrorHandler = (thread: thread, err: string) -> ()
type Function = () -> ()

type Scheduler = {
	SetErrorHandler = (handler: ErrorHandler?) -> (),
	SetMinWaitTime  = (duration: number?) -> (),
	SetBudget       = (duration: number?) -> (),
	Delay           = (duration: number, func: Function) -> (),
	DelayCancel     = (duration: number, func: Function) -> Function,
	Spawn           = (func: Function) -> (),
	Wait            = (duration: number) -> (),
	Yield           = () -> (),
}
]]

local Heartbeat     = 0 -- local Heartbeat     : Driver = 0
local Stepped       = 1 -- local Stepped       : Driver = 1
local RenderStepped = 2 -- local RenderStepped : Driver = 2

-- driver contains constants used to specify a Driver.
Sched.driver = { -- Sched.driver: {[string]: Driver}
	-- Heartbeat uses RunService.Heartbeat as the driver. This is the default.
	Heartbeat     = Heartbeat,
	-- Stepped uses RunService.Stepped as the driver.
	Stepped       = Stepped,
	-- RenderStepped uses RunService.RenderStepped as the driver.
	RenderStepped = RenderStepped,
}

local Scheduler = {__index={}}

-- new returns a new Scheduler driven by the specified driver, or Heartbeat if
-- no driver is specified.
function Sched.new(driver)
-- function Sched.new(driver: Driver?): (scheduler: Scheduler)
	local self = setmetatable({
		suspended = {},       -- Unordered list of suspended threads.
		pending = {},         -- List of threads to be resumed, ordered by time.
		minWaitTime = 0,      -- Minimum seconds that threads are allowed to yield.
		inactiveDuration = 2, -- Seconds before driver is disconnected.
		budget = math.huge,   -- Seconds the scheduler is allowed to spend resuming threads, per driver signal.
		driverSignal = nil,   -- Signal used as driver.
		driverConn = nil,     -- Connection to the driver signal.
		cycle = nil,          -- Thread that cycles over queue and resumes pending threads.
		activeExpy = 0,       -- Time when scheduler activity expires.
		budgetExpy = 0,       -- Time when the budget expires.
		handleError = nil,    -- Optional function to handle coroutine errors.
		uid = 0,              -- Current latest universal identifier.
	}, Scheduler)

	if driver == RenderStepped then
		self.driverSignal = game:GetService("RunService").RenderStepped
	elseif driver == Stepped then
		self.driverSignal = game:GetService("RunService").Stepped
	else
		self.driverSignal = game:GetService("RunService").Heartbeat
	end

	self.cycle = coroutine.create(function()
		local suspended = self.suspended
		local pending = self.pending
		while true do
			local t = tick()
			local i = 1
			while i <= #suspended do
				local entry = suspended[i]
				if t >= entry.expy then
					-- Entry time has expired, fast-remove it from the queue.
					suspended[i] = suspended[#suspended]
					suspended[#suspended] = nil

					-- Insert so that pending is ordered descending by expy.
					local j = #pending
					while j > 0 do
						if pending[j].expy > entry.expy then
							break
						end
						j = j - 1
					end
					table.insert(pending, j + 1, entry)

					-- Skip increment; because of fast remove, the current index
					-- hasn't been checked yet.
				else
					i = i + 1
				end
			end

			local inactive = #pending == 0
			while #pending > 0 do
				local entry = table.remove(pending)
				local ok, result = coroutine.resume(entry.thread)
				if not ok and self.handleError then
					self.handleError(entry.thread, result)
				end
				if tick() >= self.budgetExpy then
					-- Pause if budget is exceeded.
					coroutine.yield()
				end
			end
			if not inactive then
				-- Update activity of scheduler.
				self.activeExpy = tick() + self.inactiveDuration
			end

			if inactive or #suspended == 0 or tick() >= self.budgetExpy then
				-- Pause if scheduler is empty or the budget is exceeded.
				coroutine.yield()
			end
		end
	end)

	return self
end

-- pushThread pushes a thread into the queue, with an optional timestamp
-- indicating when the thread should be resumed. id is an optional unique
-- identifier that, when present, is expected to be used to pop the thread from
-- the queue.
function Scheduler.__index:pushThread(thread, time, id)
-- function Scheduler.__index:pushThread(thread: thread, time: number?, id: number?)
	table.insert(self.suspended, {
		thread = thread,
		expy = time or 0,
		id = id,
	})
	if self.driverConn then
		return
	end
	-- Connect the driver.
	self.activeExpy = tick() + self.inactiveDuration
	self.driverConn = self.driverSignal:Connect(function()
		self.budgetExpy = tick() + self.budget
		coroutine.resume(self.cycle)
		if #self.suspended == 0 and #self.pending == 0 and tick() >= self.activeExpy then
			-- Disconnect driver if scheduler is empty and has been inactive
			-- for the configured duration.
			self.driverConn:Disconnect()
			self.driverConn = nil
		end
	end)
end

-- popThread locates and force-removes a thread from the queue.
function Scheduler.__index:popThread(id)
-- function Scheduler.__index:popThread(id: number)
	local suspended = self.suspended
	for i = 1, #suspended do
		if suspended[i].id == id then
			suspended[i] = suspended[#suspended]
			suspended[#suspended] = nil
			return
		end
	end
end

-- SetErrorHandler sets a function that is called when a thread returns an
-- error. The first argument is the thread, which may be used with
-- debug.traceback to acquire a stack trace. The second argument is the error
-- message.
--
-- By default, no function is set, causing any errors to be discarded.
function Scheduler.__index:SetErrorHandler(handler)
-- function Scheduler.__index:SetErrorHandler(handler: ErrorHandler?)
	self.handleError = handler
end

-- SetMinWaitTime specifies the minimum duration that threads are allowed to
-- yield, in seconds. Defaults to 0.
function Scheduler.__index:SetMinWaitTime(duration)
-- function Scheduler.__index:SetMinWaitTime(duration: number?)
	self.minWaitTime = duration or 0
end

-- SetBudget specifies the duration each iteration of the driver is allowed to
-- run, in seconds. Defaults to infinite duration.
--
-- When the budget is exceeded, the driver suspends, resuming where it left
-- off on the next iteration.
function Scheduler.__index:SetBudget(duration)
-- function Scheduler.__index:SetBudget(duration: number?)
	self.budget = duration or math.huge
end

-- Delay queues `func` to be called after waiting for `duration` seconds.
function Scheduler.__index:Delay(duration, func)
-- function Scheduler.__index:Delay(duration: number, func: Function)
	local t = tick()
	if duration < self.minWaitTime then
		duration = self.minWaitTime
	end
	self:pushThread(coroutine.create(func), t + duration)
end

-- DelayCancel queues `func` to be called after waiting for `duration` seconds.
-- Returns a function that, when called, cancels the delayed call.
function Scheduler.__index:DelayCancel(duration, func)
-- function Scheduler.__index:Delay(duration: number, func: Function): (cancel: Function)
	local t = tick()
	if duration < self.minWaitTime then
		duration = self.minWaitTime
	end
	local thread = coroutine.create(func)
	local id = self.uid
	self.uid = id + 1
	self:pushThread(thread, t + duration, id)
	return function()
		if self ~= nil then
			self:popThread(id)
			self = nil
		end
	end
end

-- Spawn queues `func` to be called as soon as possible.
function Scheduler.__index:Spawn(func)
-- function Scheduler.__index:Spawn(func: Function)
	self:pushThread(coroutine.create(func))
end

-- Wait queues the running thread to be resumed after waiting for `duration`
-- seconds.
function Scheduler.__index:Wait(duration)
-- function Scheduler.__index:Wait(duration: number)
	local t = tick()
	if duration < self.minWaitTime then
		duration = self.minWaitTime
	end
	self:pushThread(coroutine.running(), t + duration)
	coroutine.yield()
end

-- Yield queues the running thread to be resumed as soon as possible.
function Scheduler.__index:Yield()
-- function Scheduler.__index:Yield()
	self:pushThread(coroutine.running())
	coroutine.yield()
end

return Sched
