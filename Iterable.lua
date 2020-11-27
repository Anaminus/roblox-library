-- IterableArray is a metatable that causes a table to be iterable as an array
-- directly with a generic for loop.
local IterableArray = {
	__call = function(t, _, i)
		if i == nil then
			i = 1
		else
			i = i + 1
		end
		local v = t[i]
		if v == nil then
			return nil
		end
		return i, v
	end,
}

-- IterableMap is a metatable that causes a table to be iterable as a map
-- directly with a generic for loop.
local IterableMap = {
	__call = function(t, _, k)
		return next(t, k)
	end,
}

local t = {'a', 'b', 'c', 'd', a = 1, b = 2, c = 3, d = 4}

setmetatable(t, IterableArray)
print("array")
for i, v in t do
	print(i, v)
end

setmetatable(t, IterableMap)
print("map")
for k, v in t do
	print(k, v)
end
