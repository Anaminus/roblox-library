-- Append appends each argument to t.
local function Append(t, ...)
	local args = table.pack(...)
	for i = 1, args.n do
		table.insert(t, args[i])
	end
end

-- AppendNoAlloc appends each argument to t without allocating an extra table.
-- Has worse performance for larger numbers of arguments.
local function AppendNoAlloc(t, ...)
	for i = 1, select("#", ...) do
		table.insert(t, (select(i, ...)))
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

-- FastRemove removes an element without preserving order. Assumes 1 <= i <= #a
local function FastRemove(a, i)
	local n = #a
	if n > 0 then
		a[i] = a[n]
		a[n] = nil
	end
end

-- BulkFastRemove removes elements for which *cond* returns true, without
-- preserving order.
local function BulkFastRemove(a, cond)
	local i = 1
	local n = #a
	while i <= n do
		if cond(a[i]) then
			a[i] = a[n]
			a[n] = nil
			n -= 1
		else
			i += 1
		end
	end
end
