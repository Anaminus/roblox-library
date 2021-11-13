-- Returns a function that may call *func* after *rate* seconds. *func*
-- will not be called more frequently than *rate*.
local function Throttle(rate, func)
	if rate <= 0 then
		return func
	end
	local running = false
	local function throttledCallback(...)
		if running then
			return
		end
		running = true
		task.delay(rate, function(...)
			running = false
			func(...)
		end, ...)
	end
	return throttledCallback
end

-- Also returns a function that cancels the call.
local function Throttle(rate, func)
	if rate <= 0 then
		return func
	end
	local running = false
	local canceled = false
	local function throttledCallback(...)
		if running or canceled then
			return
		end
		running = true
		task.delay(rate, function(...)
			if canceled then
				return
			end
			running = false
			func(...)
		end, ...)
	end
	local function cancel()
		canceled = true
	end
	return throttledCallback, cancel
end
