-- Returns a function that calls *func* after *window* seconds. This window
-- resets while the function is called during the window.
local function Accumulate<T...>(window: number, func: (T...) -> ()): (T...) -> ()
	if window <= 0 then
		return func
	end
	local active
	return function(...)
		if active then
			task.cancel(active)
		end
		active = task.delay(window, function(...)
			active = nil
			func(...)
		end, ...)
	end
end

return Accumulate
