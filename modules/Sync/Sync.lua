-- Sync provides primitives for working with threads and signals.
local Sync = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Resume resumes thread with the remaining arguments, returning no values. If
-- the thread returns an error, then the message is emitted along with a stack
-- trace.
local function Resume(thread, ...)
-- local function Resume(thread: thread, ...any)
	local ok, err = coroutine.resume(thread, ...)
	if ok then
		return
	end
	-- TODO: somehow emit as error.
	print("ERROR", err)
	-- TODO: somehow emit as info.
	print(debug.traceback(thread))
end

Sync.Resume = Resume

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Verify that each argument is a valid signal.
local function assertSignals(signals)
	for i, signal in ipairs(signals) do
		if typeof(signal) ~= "RBXScriptSignal" then
			error(string.format("argument #%d: signal expected, got %s", i, typeof(signal)), 3)
		end
		-- Detect signals that fire upon connecting. This only works because
		-- "OnServerEvent" and "OnClientEvent" are uniquely named across all
		-- signals in the API. Remove if this is no longer the case.
		local s = tostring(signal)
		if s == "Signal OnServerEvent" or s == "Signal OnClientEvent" then
			error(string.format("argument #%d: signal is not compatible", i), 3)
		end
	end
end

-- AnySignal blocks until any of the given signals have fired.
--
-- Must not be used with signals that fire upon connecting (e.g. RemoteEvent).
function Sync.AnySignal(...)
-- function Sync.AnySignal(signals: ...Event)
	local signals = table.pack(...)
	assertSignals(signals)
	local conns = {}
	local blocker = Instance.new("BoolValue")
	for _, signal in ipairs(signals) do
		table.insert(conns, signal:Connect(function()
			-- TODO: operate on current thread directly once Roblox has a way to
			-- resume threads with error handling.
			blocker.Value = not blocker.Value
		end))
	end
	blocker.Changed:Wait()
	for _, conn in ipairs(conns) do
		conn:Disconnect()
	end
end

-- AllSignals blocks until all of the given signals have fired.
--
-- Must not be used with signals that fire upon connecting (e.g. RemoteEvent).
function Sync.AllSignals(...)
-- function Sync.AllSignals(signals: ...Event)
	local signals = table.pack(...)
	assertSignals(signals)
	local blocker = Instance.new("BoolValue")
	local n = #signals
	for _, signal in ipairs(signals) do
		local conn; conn = signal:Connect(function()
			conn:Disconnect()
			n = n - 1
			if n > 0 then
				return
			end
			-- TODO: operate on current thread directly once Roblox has a way to
			-- resume threads with error handling.
			blocker.Value = not blocker.Value
		end)
	end
	blocker.Changed:Wait()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--[[
type Group = {
	Add: (delta: number?) => ()
	Done: () => ()
	Wait: () => ()
}
]]

-- Group is used to wait for a collection of threads to finish.
local Group = {__index={}}

local function Group_incCounter(self, delta)
-- local function Group_incCounter(self: Group, delta: number)
	if self.counter + delta < 0 then
		error("negative group counter", 3)
	elseif self.counter + delta > 0 then
		self.counter = self.counter + delta
		return
	end
	self.counter = 0
	if self.blocker == nil then
		-- No threads are waiting; do nothing.
		return
	end
	local blocker = self.blocker
	self.blocker = nil
	blocker.Value = not blocker.Value
end

-- Add increments the group counter by delta or 1. If the counter becomes zero,
-- all threads blocked by Wait are released. Throws an error if the counter
-- becomes negative.
function Group.__index:Add(delta)
-- function Group.__index:Add(delta: number?)
	Group_incCounter(self, (math.modf(delta or 1)))
end

-- Done decrements the group counter by one.
function Group.__index:Done()
-- function Group.__index:Done()
	Group_incCounter(self, -1)
end

-- Wait blocks until the group counter is zero.
function Group.__index:Wait()
-- function Group.__index:Wait()
	if self.counter <= 0 then
		return
	end
	if self.blocker == nil then
		self.blocker = Instance.new("BoolValue")
	end
	self.blocker.Changed:Wait()
end

-- Group returns a new Group object. *counter* is an optional initial value of
-- the group counter, defaulting to 0.
function Sync.Group(counter)
-- function Sync.Group(counter: number?) => Group
	return setmetatable({
		counter = math.modf(counter or 0),
		blocker = nil,
	}, Group)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--[[
type Mutex = {
	Lock: () => ()
	Unlock: () => ()
	Wrap((func: ...any)=>(...any)) => (...any)=>(...any)
}
]]

-- Mutex is a mutual exclusion lock.
local Mutex = {__index={}}

-- Lock locks the mutex. If the lock is already in use, then the calling thread
-- blocks until the lock is available.
function Mutex.__index:Lock()
-- function Mutex.__index:Lock()
	local blocker = Instance.new("BoolValue")
	-- TODO: benchmark; try a ring-buffer if needed. Also consider a single
	-- IntValue blocker. Each blocked thread runs a loop that breaks only when
	-- the Value matches the value of the thread. Such threads will be resumed
	-- and halted each unlock, but we get finer control over which thread
	-- resumes first.
	--
	-- In practice, dozens of threads on a single mutex is unlikely, so it's
	-- probably good enough as-is.
	table.insert(self.blockers, blocker)
	if #self.blockers > 1 then
		blocker.Changed:Wait()
	end
end

-- Unlock unlocks the mutex. If threads are blocked by the mutex, then the next
-- blocked mutex will be resumed.
function Mutex.__index:Unlock()
-- function Mutex.__index:Unlock()
	local blocker = table.remove(self.blockers, 1)
	if not blocker then
		error("attempt to unlock non-locked mutex", 2)
	end
	if #self.blockers == 0 then
		return
	end
	blocker = self.blockers[1]
	blocker.Value = not blocker.Value
end

-- Wrap returns a function that, when called, locks the mutex before func is
-- called, and unlocks it after func returns. The new function receives and
-- returns the same parameters as func.
function Mutex.__index:Wrap(func)
-- function Mutex.__index:Wrap(func: (...any)=>(...any)) => (...any)=>(...any)
	return function(...)
		self:Lock()
		local results = table.pack(func(...))
		self:Unlock()
		return table.unpack(results, 1, results.n)
	end
end

-- Mutex creates a new mutex.
function Sync.Mutex()
-- function Sync.Mutex() => Mutex
	return setmetatable({blockers = {}}, Mutex)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--[[
type Connection = {
	Disconnect: () => (),
	Connected: boolean,
	IsConnected: () => boolean,
}
]]

local Connection = {__index={}}

function Connection.__index:Disconnect()
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
	if not self.signal then
		return
	end
	self.Connected = false
	local connections = self.signal.connections
	for i = 1, #connections do
		if connections[i] == self then
			table.remove(connections, i)
			break
		end
	end
	Signal_destruct(self.signal)
	self.signal = nil
end

function Connection.__index:IsConnected()
	if self.conn then
		return self.conn.Connected
	end
	return false
end

--[[
type Listener = (...any) => ()
type Event = {
	Connect: (Listener) => ()
}
]]

local Event = {__index={}}

function Event.__index:Connect(listener)
	local signal = self.signal
	Signal_construct(signal)
	local conn = setmetatable({
		signal = signal,
		conn = signal.usignal.Event:Connect(function(id)
			local args = signal.args[id]
			args[1] = args[1] - 1
			if args[1] <= 0 then
				signal.args[id] = nil
			end
			listener(table.unpack(args[2], 1, args[2].n))
		end),
		Connected = true,
	}, Connection)
	table.insert(signal.connections, conn)
	return conn
end

--[[
type Signal = {
	Fire: (...any) => ()
	Destroy: () => ()
	Event: Event
	GetEvent: () => Event
}
]]

local Signal = {__index={}}

function Signal.__index:GetEvent()
	return self.event
end

function Signal.__index:Fire(...)
	local id = self.nextID
	self.nextID = id + 1
	self.args[id] = {#self.connections, table.pack(...)}
	self.usignal:Fire(id)
end

function Signal.__index:Destroy()
	self.usignal:Destroy()
	self.usignal = Instance.new("BindableEvent")
	local connections = self.connections
	for i = #connections, 1, -1 do
		local conn = connections[i]
		conn.signal = nil
		conn.conn = nil
		conn.Connected = false
		connections[i] = nil
	end
	Signal_destruct(self)
end

local function Signal_construct(self)
	if #self.connections > 0 then
		return
	end
	if self.ctor and not self.ctorData then
		self.ctorData = table.pack(self.ctor(self))
	end
end

local function Signal_destruct(self)
	if #self.connections > 0 then
		return
	end
	if self.dtor and self.ctorData then
		self.dtor(self, table.unpack(self.ctorData, 1, self.ctorData.n))
		self.ctorData = nil
	end
end

function Sync.Signal(ctor, dtor)
	local self = {
		-- Constructor function.
		ctor = ctor,
		-- Destructor function.
		dtor = dtor,
		-- Values returned by ctor and passed dtor.
		ctorData = nil,
		-- Holds arguments for pending listener functions and threads.
		-- [id] = {#connections, {arguments}}
		args = {},
		-- Holds the next args ID.
		nextID = 0,
		-- Connections connected to the signal.
		connections = {},
		-- Dispatches scheduler-compatible threads.
		usignal = Instance.new("BindableEvent"),
		-- Associated event, encapsulating Connect the method.
		event = setmetatable({signal = self}, Event),
	}
	self.Event = self.event
	return setmetatable(self, Signal)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local Cond = {__index={}}

function Cond.__index:Fire(...)
	local id = self.nextID
	self.nextID = id + 1
	self.args[id] = {self.threads, table.pack(...)}
	self.threads = 0
	self.usignal:Fire(id)
end

function Cond.__index:Wait()
	self.threads = self.threads + 1
	local id = self.usignal.Event:Wait()
	local args = self.args[id]
	args[1] = args[1] - 1
	if args[1] <= 0 then
		self.args[id] = nil
	end
	return table.unpack(args[2], 1, args[2].n)
end

function Sync.Cond()
	return setmetatable({
		args    = {},
		nextID  = 0,
		threads = 0,
		usignal = Instance.new("BindableEvent"),
	}, Cond)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return Sync
