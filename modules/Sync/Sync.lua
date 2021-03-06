--@sec: Sync
--@ord: -1
--@doc: Sync provides primitives for working with threads and events.
local Sync = {}

--@sec: Sync.resume
--@def: Sync.resume(thread: thread, ...any)
--@doc: resume resumes *thread* with the remaining arguments, returning no
-- values. If the thread returns an error, then the error is printed along with
-- a stack trace.
function Sync.resume(thread, ...)
	local ok, err = coroutine.resume(thread, ...)
	if ok then
		return
	end
	-- TODO: somehow emit as error.
	print("ERROR", err)
	-- TODO: somehow emit as info.
	print(debug.traceback(thread))
end

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

--@sec: Sync.anySignal
--@def: Sync.anySignal(signals: ...Signal): Signal
--@doc: anySignal returns a Signal that fires after any of the given signals
-- have fired.
--
-- Must not be used with signals that fire upon connecting (e.g. RemoteEvent).
function Sync.anySignal(...)
	local signals = table.pack(...)
	assertSignals(signals)
	local conns = {}
	local blocker = Instance.new("BindableEvent")
	for _, signal in ipairs(signals) do
		table.insert(conns, signal:Connect(function()
			blocker:Fire()
		end))
	end
	table.insert(conns, blocker.Event:Connect(function()
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
	end))
	return blocker.Event
end

--@sec: Sync.allSignals
--@def: Sync.allSignals(signals: ...Signal)
--@doc: allSignals returns a Signal that fires after all of the given signals
-- have fired.
--
-- Must not be used with signals that fire upon connecting (e.g. RemoteEvent).
function Sync.allSignals(...)
	local signals = table.pack(...)
	assertSignals(signals)
	local blocker = Instance.new("BindableEvent")
	local n = #signals
	for _, signal in ipairs(signals) do
		local conn; conn = signal:Connect(function()
			conn:Disconnect()
			n = n - 1
			if n > 0 then
				return
			end
			blocker:Fire()
		end)
	end
	return blocker.Event
end

--@sec: Group
--@def: type Group
--@doc: Group is used to wait for a collection of threads to finish.
local Group = {__index={}}

--@def: Group_incCounter(self: Group, delta: number)
local function Group_incCounter(self, delta)
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

--@sec: Group.Add
--@def: Group:Add(delta: number?)
--@doc: Add increments the group counter by delta or 1. If the counter becomes
-- zero, all threads blocked by Wait are released. Throws an error if the
-- counter becomes negative.
function Group.__index:Add(delta)
	Group_incCounter(self, (math.modf(delta or 1)))
end

--@sec: Group.Done
--@def: Group:Done()
--@doc: Done decrements the group counter by one.
function Group.__index:Done()
	Group_incCounter(self, -1)
end

--@sec: Group.Wait
--@def: Group:Wait()
--@doc: Wait blocks until the group counter is zero.
function Group.__index:Wait()
	if self.counter <= 0 then
		return
	end
	if self.blocker == nil then
		self.blocker = Instance.new("BoolValue")
	end
	self.blocker.Changed:Wait()
end

--@sec: Sync.group
--@def: Sync.group(counter: number?): Group
--@doc: group returns a new Group object. *counter* is an optional initial value
-- of the group counter, defaulting to 0.
function Sync.group(counter)
	return setmetatable({
		counter = math.modf(counter or 0),
		blocker = nil,
	}, Group)
end

--@sec: Mutex
--@def: type Mutex
--@doc: Mutex is a mutual exclusion lock.
local Mutex = {__index={}}

--@sec: Mutex.Lock
--@def: Mutex:Lock()
--@doc: Lock locks the mutex. If the lock is already in use, then the calling
-- thread blocks until the lock is available.
function Mutex.__index:Lock()
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

--@sec: Mutex.Unlock
--@def: Mutex:Unlock()
--@doc: Unlock unlocks the mutex. If threads are blocked by the mutex, then the
-- next blocked mutex will be resumed.
function Mutex.__index:Unlock()
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

--@sec: Mutex.Wrap
--@def: Mutex:Wrap(func: (...any)->(...any)) -> (...any)->(...any)
--@doc: Wrap returns a function that, when called, locks the mutex before *func*
-- is called, and unlocks it after *func* returns. The new function receives and
-- returns the same parameters as *func*.
function Mutex.__index:Wrap(func)
	return function(...)
		self:Lock()
		local results = table.pack(func(...))
		self:Unlock()
		return table.unpack(results, 1, results.n)
	end
end

--@sec: Sync.mutex
--@def: Sync.mutex(): Mutex
--@doc: mutex returns a new mutex.
function Sync.mutex()
	return setmetatable({blockers = {}}, Mutex)
end

--@sec: Connection
--@def: type Connection
--@doc: Connection represents the connection to an Event.
local Connection = {__index={}}

--@sec: Connection.Disconnect
--@def: Connection:Disconnect()
--@doc: Disconnect disconnects the connection, causing the associated listener
-- to no longer be called when the Event fires. Does nothing if the Connection
-- is already disconnected.
function Connection.__index:Disconnect()
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
	if not self.event then
		return
	end
	self.Connected = false
	local connections = self.event.connections
	for i = 1, #connections do
		if connections[i] == self then
			table.remove(connections, i)
			break
		end
	end
	Event_destruct(self.event)
	self.event = nil
end

--@sec: Connection.IsConnected
--@def: Connection:IsConnected(): bool
--@doc: IsConnected returns whether the Connection is connected.
function Connection.__index:IsConnected()
	if self.conn then
		return self.conn.Connected
	end
	return false
end

--@sec: Signal
--@def: type Signal
--@doc: Signal encapsulates the part of an Event that connects listeners.
local Signal = {__index={}}

--@sec: Signal.Connect
--@def: Signal:Connect(listener: (...any) -> ()): Connection
--@doc: Connect attaches *listener* to the Event, to be called when the Event
-- fires. *listener* receives the arguments passed to Event.Fire.
function Signal.__index:Connect(listener)
	local event = self.event
	Event_construct(event)
	local conn = setmetatable({
		event = event,
		conn = event.uevent.Event:Connect(function(id)
			local args = event.args[id]
			args[1] = args[1] - 1
			if args[1] <= 0 then
				event.args[id] = nil
			end
			listener(table.unpack(args[2], 1, args[2].n))
		end),
		--@sec: Connection.Connected
		--@def: Connection.Connected: bool
		--@doc: Connected returns whether the Connection is connected. Readonly.
		--
		-- The Connected field exists to be API-compatible with
		-- RBXScriptConnections. The IsConnected method is the preferred way to
		-- check the connection.
		Connected = true,
	}, Connection)
	table.insert(event.connections, conn)
	return conn
end

--@sec: Event
--@def: type Event
--@doc: Event is an implementation of the Roblox event pattern, similar to the
-- BindableEvent type.
--
-- Event does not include a Wait method in its implementation. See [Cond][Cond]
-- for equivalent behavior.
local Event = {__index={}}

--@sec: Event.Signal
--@def: Event:Signal(): Signal
--@doc: Signal returns the Signal associated with the event.
function Event.__index:Signal()
	return self.signal
end

--@sec: Event.Fire
--@def: Event:Fire(args: ...any)
--@doc: Fire calls all listeners connected to the event. *args* are passed to
-- each listener. Values are not copied.
function Event.__index:Fire(...)
	local id = self.nextID
	self.nextID = id + 1
	self.args[id] = {#self.connections, table.pack(...)}
	self.uevent:Fire(id)
end

--@sec: Event.Destroy
--@def: Event:Destroy()
--@doc: Destroy releases all resources used by the object. Listeners are
--disconnected, and the event's destructor is invoked, if defined.
function Event.__index:Destroy()
	self.uevent:Destroy()
	self.uevent = Instance.new("BindableEvent")
	local connections = self.connections
	for i = #connections, 1, -1 do
		local conn = connections[i]
		conn.event = nil
		conn.conn = nil
		conn.Connected = false
		connections[i] = nil
	end
	Event_destruct(self)
end

--@def: Event_construct(self: Event)
local function Event_construct(self)
	if #self.connections > 0 then
		return
	end
	if self.ctor and not self.ctorData then
		self.ctorData = table.pack(self.ctor(self))
	end
end

--@def: Event_destruct(self: Event)
local function Event_destruct(self)
	if #self.connections > 0 then
		return
	end
	if self.dtor and self.ctorData then
		self.dtor(self, table.unpack(self.ctorData, 1, self.ctorData.n))
		self.ctorData = nil
	end
end

--@sec: Sync.event
--@def: Sync.event(ctor: ((event: Event) -> (...any))?, dtor: ((event: Event, args: ...any) -> ())?): Event
--@doc: event returns a new Event.
--
-- *ctor* and *dtor* optionally define a constructor and destructor. When the
-- first listener is connected to the event, *ctor* is called. When the last
-- listener is disconnected from the event, *dtor* is called, receiving the
-- values returned by *ctor*.
function Sync.event(ctor, dtor)
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
		-- Connections connected to the event.
		connections = {},
		-- Dispatches scheduler-compatible threads.
		uevent = Instance.new("BindableEvent"),
		-- Associated signal, encapsulating Connect the method.
		signal = setmetatable({event = self}, Signal),
	}
	--@sec: Event.Event
	--@def: Event.Event: Signal
	--@doc: Event returns the Signal associated with the event.
	--
	-- The Event field exists to be API-compatible with BindableEvents. The
	-- Signal method is the preferred way to get the signal.
	self.Event = self.signal
	return setmetatable(self, Event)
end

--@sec: Cond
--@def: type Cond
--@doc: Cond blocks threads until a condition is met.
local Cond = {__index={}}

--@sec: Cond.Fire
--@def: Cond:Fire(...any)
--@doc: Fire causes resumes all blocked threads. Each argument is returned by
-- the call to Wait. Values are not copied.
function Cond.__index:Fire(...)
	local id = self.nextID
	self.nextID = id + 1
	self.args[id] = {self.threads, table.pack(...)}
	self.threads = 0
	self.uevent:Fire(id)
end

--@sec: Cond.Wait
--@def: Cond:Wait(): (...any)
--@doc: Wait blocks the running thread until Fire is called. Returns the
-- arguments passed to Fire.
function Cond.__index:Wait()
	self.threads = self.threads + 1
	local id = self.uevent.Event:Wait()
	local args = self.args[id]
	args[1] = args[1] - 1
	if args[1] <= 0 then
		self.args[id] = nil
	end
	return table.unpack(args[2], 1, args[2].n)
end

--@sec: Sync.cond
--@def: Sync.cond(): Cond
--@doc: cond returns a new Cond.
function Sync.cond()
	return setmetatable({
		args    = {},
		nextID  = 0,
		threads = 0,
		uevent = Instance.new("BindableEvent"),
	}, Cond)
end

return Sync
