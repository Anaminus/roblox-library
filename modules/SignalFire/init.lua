--!strict

--@sec: SignalFire
--@ord: -1
--@doc: The SignalFire module provides a small implementation of the [observer
-- pattern][observer].
--
-- Notable differences from Roblox's Signal pattern:
-- - Everything is a function.
-- - Listeners may be threads as well as functions.
-- - Listeners are always deferred.
-- - Listeners are unordered.
-- - After a signal is fired, only every listener with a connection *at the time
--   of firing* will be invoked.
--
-- [observer]: https://en.wikipedia.org/wiki/Observer_pattern
local export = {}

--@sec: Connector
--@ord: 1
--@def: type Connector = (listener: Listener) -> Disconnector
--@doc: A **Connector** creates a connection of [*listener*][Listener] to the
-- signal. The returned [Disconnector][Disconnector] breaks this connection when
-- called.
--
-- The same listener may be connected multiple times, and will be called for
-- each number of times it is connected.
--
-- After the signal is destroyed, calling the function does nothing except
-- return a disconnector, which also does nothing when called.
export type Connector = (listener: Listener) -> Disconnector

--@sec: Listener
--@ord: 2
--@def: type Listener = (...any) -> () | thread
--@doc: A **Listener** receives the arguments passed to a [Fire][Fire] function.
export type Listener = (...any) -> () | thread

--@sec Disconnector
--@ord: 3
--@def: type Disconnector = () -> ()
--@doc: A **Disconnector** breaks the connection of a [Listener][Listener] to a
-- signal when called. Does nothing if the connection is already broken.
export type Disconnector = () -> ()

--@sec: Fire
--@ord: 4
--@def: type Fire = (arguments: ...any) -> ()
--@doc: A **Fire** function invokes all of the [Listeners][Listener] connected
-- to the signal at the time Fire is called. Each given argument is passed to
-- each listener. Each function listener is called in its own separate thread.
--
-- The order in which listeners are invoked is **undefined**.
--
-- After the signal is destroyed, calling this function throws an error.
export type Fire = (...any) -> ()

--@sec: Destroyer
--@ord: 5
--@def: type Destroyer = () -> ()
--@doc: A **Destroyer** function destroys the signal by breaking all
-- connections. After the signal is destroyed, calling the [Fire][Fire] or
-- Destroyer functions will throw an error. The [Connector][Connector] function
-- will do nothing but return a disconnector, which will also do nothing.
export type Destroyer = () -> ()

--@sec: SignalFire.new
--@ord: 1
--@def: function SignalFire.new(): (Connector, Fire, Destroyer)
--@doc: The **new** constructor returns a signal, represented by associated
-- [Connector][Connector], [Fire][Fire] and [Destroyer][Destroyer] functions.
local function newSignal(): (Connector, Fire, Destroyer)
	local listeners: {[Disconnector]: Listener} | nil = {}
	local function connect(listener: Listener): Disconnector
		assert(
			type(listener) == "function" or
			type(listener) == "thread",
			"listener must be a function or thread"
		)
		if listeners == nil then
			return function()end
		else
			local function disconnect()
				if listeners == nil then
					return
				else
					listeners[disconnect] = nil
				end
			end
			listeners[disconnect] = listener
			return disconnect
		end
	end
	local function fire(...: any)
		if listeners == nil then
			error("signal is destroyed", 2)
		else
			for _, listener in pairs(listeners) do
				task.defer(listener, ...)
			end
		end
	end
	local function destroy()
		if listeners == nil then
			error("signal is destroyed", 2)
		else
			for ref in pairs(listeners) do
				listeners[ref] = nil
			end
			listeners = nil
		end
	end
	return connect, fire, destroy
end
export.new = newSignal

local function nopConnector(listener: Listener): Disconnector
	assert(
		type(listener) == "function" or
		type(listener) == "thread",
		"listener must be a function or thread"
	)
	return function()end
end

--@sec: SignalFire.all
--@ord: 3
--@def: function SignalFire.all(...: Connector): (Connector, Destroyer)
--@doc: The **all** function returns the [Connector][Connector] and
-- [Destroyer][Destroyer] of a signal that fires after all of the signals
-- associated with the given connectors have fired. The signal will fire up to
-- one time.
function export.all(...: Connector): (Connector, Destroyer)
	local arguments = table.pack(...)
	local count = arguments.n
	if count == 0 then
		return nopConnector, function()end
	end
	local signalConnect, signalFire, signalDestroy: Destroyer? = newSignal()
	local disconnectors: {[Disconnector]: true} = {}
	for i = 1, arguments.n do
		local connect = arguments[i]
		assert(type(connect) == "function", "connector must be a function")
		local disconnect: Disconnector?
		local function finish(...)
			if disconnect then
				local d = disconnect
				disconnectors[disconnect] = nil
				disconnect = nil
				d()
				count -= 1
				if count <= 0 then
					signalFire()
				end
			end
		end
		disconnect = connect(finish)
		assert(type(disconnect) == "function", "disconnector must be a function")
		disconnectors[disconnect] = true
	end
	local function destroy()
		if signalDestroy then
			for disconnect in pairs(disconnectors) do
				disconnect()
			end
			table.clear(disconnectors)
			local d = signalDestroy
			signalDestroy = nil
			task.defer(d)
		else
			error("signal is destroyed", 2)
		end
	end
	return signalConnect, destroy
end

--@sec: SignalFire.any
--@ord: 3
--@def: function SignalFire.any(...: Connector): (Connector, Destroyer)
--@doc: The **any** function returns the [Connector][Connector] and
-- [Destroyer][Destroyer] of a signal that fires after any of the signals
-- associated with the given connectors have fired. The signal passes the
-- arguments of the first signal that fired it. The signal will fire until
-- destroyed.
function export.any(...: Connector): (Connector, Destroyer)
	local arguments = table.pack(...)
	if arguments.n == 0 then
		return nopConnector, function()end
	end
	local signalConnect, signalFire, signalDestroy = newSignal()
	local disconnectors: {Disconnector}? = table.create(arguments.n)
	assert(disconnectors)
	for i = 1, arguments.n do
		local connect = arguments[i]
		assert(type(connect) == "function", "connector must be a function")
		local disconnect = connect(signalFire)
		assert(type(disconnect) == "function", "disconnector must be a function")
		disconnectors[i] = disconnect
	end
	local function destroy()
		if disconnectors == nil then
			error("signal is destroyed", 2)
		else
			local d = disconnectors
			disconnectors = nil
			for _, disconnect in ipairs(d) do
				disconnect()
			end
			table.clear(d)
			-- Must be deferred, because calls to signalFire are deferred.
			task.defer(signalDestroy)
		end
	end
	return signalConnect, destroy
end

--@sec: SignalFire.wait
--@ord: 3
--@def: function SignalFire.wait(connect: Connector): (() -> (...any))
--@doc: The **wait** function returns a function that, when called, yields the
-- running thread. The thread is resumed after the signal associated with
-- *connect* fires, returning the arguments passed through the signal.
local function waitSignal(connect: Connector): (() -> (...any))
	assert(type(connect) == "function", "connector must be a function")
	return function()
		local thread = coroutine.running()
		local disconnect: Disconnector?
		disconnect = connect(function(...)
			if disconnect then
				local d = disconnect
				disconnect = nil
				d()
				task.defer(thread, ...)
			end
		end)
		assert(type(disconnect) == "function", "disconnector must be a function")
		return coroutine.yield()
	end
end
export.wait = waitSignal

--@sec: SignalFire.limit
--@ord: 3
--@def: function SignalFire.limit(connect: Connector, limit: number?): Connector
--@doc: The **limit** function wraps *connect*, returning a
-- [Connector][Connector] that will cause its connected [Listeners][Listener] to
-- be fired only up to *limit* times. The limit defaults to 1.
function export.limit(connect: Connector, limit: number?): Connector
	assert(type(connect) == "function", "connector must be a function")
	assert(type(limit) == "number" or limit == nil, "limit must be a number or nil")
	local n = limit or 1
	n = math.floor(n)
	assert(n >= 0, "limit must be a positive integer")
	if n == 0 then
		return nopConnector
	end
	return function(listener: Listener)
		local disconnect: Disconnector?
		disconnect = connect(function(...)
			if disconnect then
				n -= 1
				if n <= 0 then
					local d = disconnect
					disconnect = nil
					d()
				end
				task.spawn(listener, ...)
			end
		end)
		return assert(disconnect, "disconnector must be a function")
	end
end

--@sec: SignalFire.wrap
--@ord: 3
--@def: function SignalFire.wrap(signal: RBXScriptSignal): Connector
--@doc: The **wrap** function returns a [Connector][Connector] that wraps
-- *signal*. If the connector is passed a thread as a [Listener][Listener], it
-- is connected via a function that calls task.defer with the thread and the
-- received arguments.
function export.wrap(signal: RBXScriptSignal): Connector
	assert(typeof(signal) == "RBXScriptSignal", "RBXScriptSignal expected")
	return function(listener: Listener)
		if type(listener) == "function" then
			local connection = signal:Connect(listener)
			return function()
				connection:Disconnect()
			end
		elseif type(listener) == "thread" then
			local connection = signal:Connect(function(...)
				task.defer(listener, ...)
			end)
			return function()
				connection:Disconnect()
			end
		else
			error("listener must be a function or thread", 2)
		end
	end
end

--@sec: Bindable
--@ord: 10
--@def: type Bindable = {
-- 	Event   : Signal,
-- 	Fire    : (self: Bindable, ...any) -> (),
-- 	Destroy : (self: Bindable) -> (),
-- }
--@doc: A **Bindable** implements the principle interface of
-- [BindableEvent][BindableEvent].
--
-- [BindableEvent]: https://developer.roblox.com/en-us/api-reference/class/BindableEvent
export type Bindable = {
	Event: Signal,
	Fire: (self: Bindable, ...any) -> (),
	Destroy: (self: Bindable) -> (),
}

--@sec: Signal
--@ord: 11
--@def: type Signal = {
-- 	Connect : (self: Signal, listener: Listener) -> (Connection),
-- 	Wait    : (self: Signal) -> (...any),
-- }
--@doc: A **Signal** implements the same interface as
-- [RBXScriptSignal][RBXScriptSignal]. Not to be confused with the signal
-- represented by an associated [Connector][Connector], [Fire][Fire] and
-- [Destroyer][Destroyer].
--
-- [RBXScriptSignal]: https://developer.roblox.com/en-us/api-reference/datatype/RBXScriptSignal
export type Signal = {
	Connect: (self: Signal, listener: Listener) -> (Connection),
	Wait: (self: Signal) -> (...any),
}

--@sec: Connection
--@ord: 12
--@def: type Connection = {
-- 	IsConnected : boolean,
-- 	Disconnect  : (self: Connection) -> (),
-- }
--@doc: A **Connection** implements the same interface as
-- [RBXScriptConnection][RBXScriptConnection].
--
-- [RBXScriptConnection]: https://developer.roblox.com/en-us/api-reference/datatype/RBXScriptConnection
export type Connection = {
	IsConnected: boolean,
	Disconnect: (self: Connection) -> (),
}

--@sec: SignalFire.bindable
--@ord: 2
--@doc: The **bindable** constructor returns a new [Bindable][Bindable],
-- implemented using the functions from [SignalFire.new][SignalFire.new].
function export.bindable(): (Bindable)
	local signalConnect, signalFire, signalDestroy = newSignal()
	local signalWait = waitSignal(signalConnect)

	local signal = {
		Connect = function(self: Signal, listener: Listener): Connection
			local disconnect = signalConnect(listener)
			local connection = {
				IsConnected = true,
				Disconnect = function(self: Connection)
					self.IsConnected = false
					disconnect()
				end,
			}
			return connection
		end,
		Wait = function(self: Signal): (...any)
			return signalWait()
		end,
	}

	local bindable = {
		Event = signal,
		Fire = function(self: Bindable, ...: any)
			signalFire(...)
		end,
		Destroy = function(self: Bindable)
			signalDestroy()
		end,
	}

	return bindable
end

return export
