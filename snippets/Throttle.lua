-- Returns a function that may call *func* after *rate* seconds. *func*
-- will not be called more frequently than *rate*.
local function Throttle(rate, func)
	if rate <= 0 then
		return func
	end
	local running = false
	return function(...)
		if running then
			return
		end
		running = true
		task.delay(rate, function(...)
			running = false
			func(...)
		end, ...)
	end
end
