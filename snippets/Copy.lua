-- Copy returns a copy of an array.
local function Copy(a)
	local b = table.create(#a)
	table.move(a, 1, #a, 1, b)
	return b
end
