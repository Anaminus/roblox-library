local Maid = require(script.Parent.Maid)

--@sec: Dirty
--@doc: The **Dirty** module detects changes to an instance tree.
local Dirty = {}

local function throttle(rate, func)
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
	end)
	return throttledCallback, cancel
end

--@sec: Dirty.monitor
--@def: function Dirty.monitor(root: Instance, window: number, callback: (Instance) -> ()): (disconnect: () -> ())
--@doc: The **monitor** function begins monitoring *root* for changes. After a
-- change occurs, the monitor will wait *window* seconds before invoking
-- *callback*, passing *root* as the argument. During this time, other changes
-- will not cause *callback* to be invoked. That is, *callback* will not be
-- invoked more frequently than *window*.
--
-- If *window* is less than or equal to 0, then every change will invoke
-- *callback* immediately.
--
-- Calling *disconnect* will cause monitoring to stop and release any resources.
function Dirty.monitor(root, window, callback)
	assert(typeof(root) == "Instance", "Instance expected")
	assert(type(window) == "number", "number expected")
	assert(type(callback) == "function", "function expected")
	local maid = Maid.new()

	callback, maid.cancelCallback = throttle(window, callback)

	local function descInit(desc)
		maid[desc] = {
			desc.Changed:Connect(function() callback(root) end),
			desc.AttributeChanged:Connect(function() callback(root) end),
			desc:GetPropertyChangedSignal("Parent"):Connect(function()
				if not desc:IsDescendantOf(root) then
					maid[desc] = nil
				end
				callback(root)
			end),
		}
	end

	maid.descendantAdded = root.DescendantAdded:Connect(function(desc)
		descInit(desc)
		callback(root)
	end)
	for _, desc in ipairs(root:GetDescendants()) do
		descInit(desc)
	end

	maid.changed = root.Changed:Connect(function() callback(root) end)
	maid.attributeChanged = root.AttributeChanged:Connect(function() callback(root) end)

	return function()
		if maid then
			maid:FinishAll()
			maid = nil
		end
	end
end

return Dirty
