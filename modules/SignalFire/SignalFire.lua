--@sec: SignalFire
--@ord: -1
--@doc: The SignalFire module provides a small implementation of the [observer
-- pattern][observer].
--
-- Notable differences from Roblox's Signal pattern:
-- - Everything is a function.
-- - Listeners may be threads as well as functions.
-- - Listeners are always deferred.
-- - Listeners are unordered. Relying on this was always a bad idea.
-- - After a signal is fired, every listener with a connection *at the time of
--   firing* will be invoked.
--
-- [observer]: https://en.wikipedia.org/wiki/Observer_pattern
local SignalFire = {}

--@sec: Connector
--@ord: 1
--@def: type Connector = (listener: Listener) -> Disconnector
--@doc: A **Connector** creates a connection of [*listener*][Listener] to the
-- signal. The returned [Disconnector][Disconnector] breaks this connection when
-- called.
--
-- The same listener may be connected multiple times, and will be called for
-- each number of times it is connected.

--@sec: Listener
--@ord: 2
--@def: type Listener = (...any) -> () | thread
--@doc: A **Listener** receives the arguments passed to a [Fire][Fire] function.

--@sec Disconnector
--@ord: 3
--@def: type Disconnector = () -> ()
--@doc: A **Disconnector** breaks the connection of a [Listener][Listener] to a
-- signal when called. Does nothing if the connection is already broken.

--@sec: Fire
--@ord: 4
--@def: type Fire = (...any) -> ()
--@doc: A **Fire** function invokes all of the [Listeners][Listener] connected
-- to the signal at the time Fire is called. Each given argument is passed to
-- each listener. Each function listener is called in its own separate thread.
--
-- The order in which listeners are invoked is **undefined**.

--@sec: SignalFire.new
--@ord: 1
--@def: function SignalFire.new(): (Connector, Fire)
--@doc: The **new** constructor returns a signal, represented by a
-- [Connector][Connector] function and associated [Fire][Fire] function.
local function newSignal()
	local listeners = {}
	local function connect(listener)
		assert(
			type(listener) == "function" or
			type(listener) == "thread",
			"function or thread expected"
		)
		local function disconnect()
			listeners[disconnect] = nil
		end
		listeners[disconnect] = listener
		return disconnect
	end
	local function fire(...)
		for _, listener in pairs(listeners) do
			task.defer(listener, ...)
		end
	end
	return connect, fire
end
SignalFire.new = newSignal

--@sec: SignalFire.all
--@ord: 2
--@def: function SignalFire.all(...: Connector): Connector
--@doc: The **all** constructor returns the [Connector][Connector] of a signal
-- that fires after all of the signals associated with the given connectors have
-- fired. The signal fires up to one time.
function SignalFire.all(...)
	local connect, fire = newSignal()
	local arguments = {...}
	local count = #arguments
	for _, connect in ipairs(arguments) do
		assert(type(connect) == "function", "function expected")
		local disconnect
		local function finish()
			disconnect()
			count -= 1
			if count <= 0 then
				fire()
			end
		end
		disconnect = connect(finish)
		assert(type(disconnect) == "function", "disconnector must be a function")
	end
	return connect
end

--@sec: SignalFire.any
--@ord: 2
--@def: function SignalFire.any(...: Connector): Connector
--@doc: The **any** constructor returns the [Connector][Connector] of a signal
-- that fires after any of the signals associated with the given connectors have
-- fired. The signal fires up to one time.
function SignalFire.any(...)
	local connect, fire = newSignal()
	local connections = {...}
	local function finish()
		for _, disconnect in ipairs(connections) do
			disconnect()
		end
		fire()
	end
	for i, connect in ipairs(connections) do
		assert(type(connect) == "function", "function expected")
		local disconnect = connect(finish)
		assert(type(disconnect) == "function", "disconnector must be a function")
		connections[i] = disconnect
	end
	return connect
end

--@sec: SignalFire.wait
--@ord: 2
--@def: function SignalFire.wait(connect: Connector): (() -> (...any))
--@doc: The **wait** constructor returns a function that, when called, yields
-- the running thread. The thread is resumed after the signal associated with
-- *connect* fires, returning the arguments passed through the signal.
function SignalFire.wait(connect)
	assert(type(connect) == "function", "function expected")
	return function()
		local thread = coroutine.running()
		local disconnect
		disconnect = connect(function(...)
			disconnect()
			task.defer(thread, ...)
		end)
		assert(type(disconnect) == "function", "disconnector must be a function")
		return coroutine.yield()
	end
end

--@sec: SignalFire.wrap
--@ord: 2
--@def: function SignalFire.wrap(signal: RBXScriptSignal): Connector
--@doc: The **wrap** constructor returns a [Connector][Connector] that wraps
-- *signal*. [Listeners][Listener] passed to the connector must be passable to
-- [RBXScriptSignal.Connect][Connect].
--
-- [Connect]: https://developer.roblox.com/en-us/api-reference/datatype/RBXScriptSignal#functions
function SignalFire.wrap(signal)
	assert(typeof(signal) == "RBXScriptSignal", "RBXScriptSignal expected")
	return function(listener)
		local connection = signal:Connect(listener)
		return function()
			connection:Disconnect()
		end
	end
end

return SignalFire
