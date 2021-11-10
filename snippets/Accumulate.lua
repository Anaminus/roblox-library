-- Returns a function that calls *func* after *window* seconds. This window
-- resets while the function is called during the window.
local function Accumulate(window, func)
	if window <= 0 then
		return func
	end
	local nextID = 0
	return function(...)
		local id = nextID + 1
		nextID = id
		task.delay(window, function(...)
			if nextID == id then
				func(...)
			end
		end, ...)
	end
end

-- Improved alternative if task.delay returns a cancel function.
local function Accumulate(window, func)
	if window <= 0 then
		return func
	end
	local cancel
	return function(...)
		if cancel then
			cancel()
		end
		cancel = task.delay(window, function(...)
			cancel = nil
			func(...)
		end, ...)
	end
end
