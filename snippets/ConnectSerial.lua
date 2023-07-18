-- Connects *listener* to *signal*, ensuring that *listener* is invoked serially
-- in one consistent thread. Returns a function that disconnects the connection
-- when called.
--
-- Works with unruly signals that fire immediately upon connecting. All
-- invocations of the listener will occur in the one thread; none will occur in
-- the thread that calls ConnectSerial.
local function ConnectSerial<T...>(
	signal: RBXScriptSignal<T...>,
	listener: (T...) -> ()
): () -> ()
	local thread = task.spawn(function()
		while true do
			listener(signal:Wait())
		end
	end)
	return function()
		task.cancel(thread)
	end
end
