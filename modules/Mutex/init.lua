--@sec: Mutex
--@def: function Mutex(): Mutex
--@doc: Mutex is a mutual exclusion lock.
local Mutex = {__index={}}

--@sec: Mutex.Lock
--@def: function Mutex:Lock()
--@doc: Lock locks the mutex. If the lock is already in use, then the calling
-- thread is blocked until the lock is available.
function Mutex.__index:Lock()
	table.insert(self.threads, coroutine.running())
	if #self.threads > 1 then
		coroutine.yield()
	end
end

--@sec: Mutex.Unlock
--@def: function Mutex:Unlock()
--@doc: Unlock unlocks the mutex. If threads are blocked by the mutex, then the
-- next blocked thread will be resumed.
function Mutex.__index:Unlock()
	local thread = table.remove(self.threads, 1)
	if not thread then
		error("attempt to unlock non-locked mutex", 2)
	end
	if #self.threads == 0 then
		return
	end
	thread = self.threads[1]
	task.defer(thread)
end

--@sec: Mutex.Wrap
--@def: function Mutex:Wrap(func: (...any)->(...any)): (...any)->(...any)
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

return function()
	return setmetatable({threads = {}}, Mutex)
end
