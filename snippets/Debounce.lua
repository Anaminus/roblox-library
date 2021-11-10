-- Returns a function that immediately calls *func*. Afterwards, while the
-- function is called within *window* seconds, *func* will not be called.
local function Debounce(window, func)
	local cooling = false
	return function(...)
		if cooling then
			return
		end
		cooling = true
		task.delay(window, function()
			cooling = false
		end)
		return func(...)
	end
end
