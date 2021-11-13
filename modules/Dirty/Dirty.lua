local Maid = require(script.Parent.Maid)

--@sec: Dirty
--@doc: The **Dirty** module detects changes to an instance tree.
local Dirty = {}

local function accumulate(window, callback)
	if window <= 0 then
		return callback
	end
	local running = false
	return function(...)
		if running then
			return
		end
		running = true
		task.delay(window, function(...)
			running = false
			callback(...)
		end, ...)
	end
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
	callback = accumulate(window, callback)
	local maid = Maid.new()
	local function descInit(desc)
		maid[desc] = {
			desc.Changed:Connect(function() callback(root) end),
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
	return function()
		if maid then
			maid:FinishAll()
			maid = nil
		end
	end
end

return Dirty
