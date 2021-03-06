-- Append appends each argument to t.
local function Append(t, ...)
	local args = table.pack(...)
	for i = 1, args.n do
		table.insert(t, args[i])
	end
end

-- Copy returns a copy of an array.
local function Copy(a)
	local b = table.create(#a)
	table.move(a, 1, #a, 1, b)
	return b
end

-- Join returns a new table containing the elements of a followed by the
-- elements of b.
local function Join(a, b)
	local c = table.create(#a + #b)
	table.move(a, 1, #a, 1, c)
	table.move(b, 1, #b, #a+1, c)
	return c
end
