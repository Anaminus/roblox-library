-- Append appends each argument to *a*.
local function Append(a: {any}, ...: any): {any}
	local args = table.pack(...)
	for i = 1, args.n do
		table.insert(a, args[i])
	end
	return a
end

-- AppendNoAlloc appends each argument to *a* without allocating an extra table.
-- Has worse performance for larger numbers of arguments.
local function AppendNoAlloc(a: {any}, ...: any): {any}
	for i = 1, select("#", ...) do
		table.insert(a, (select(i, ...)))
	end
	return a
end

-- Copy returns a copy of *a*.
local function Copy(a: {any}): {any}
	local b = table.create(#a)
	table.move(a, 1, #a, 1, b)
	return b
end

-- Join returns a new table containing the elements of *a* followed by the
-- elements of *b*.
local function Join(a: {any}, b: {any}): {any}
	local c = table.create(#a + #b)
	table.move(a, 1, #a, 1, c)
	table.move(b, 1, #b, #a+1, c)
	return c
end

-- FastRemove removes element *i* from *a* without preserving order. Assumes
-- that 1 <= i <= #a
local function FastRemove(a: {any}, i: number)
	local n = #a
	if n > 0 then
		a[i] = a[n]
		a[n] = nil
	end
end

-- BulkFastRemove removes elements from *a* for which *cond* returns true,
-- without preserving order.
local function BulkFastRemove(a: {any}, cond: (any)->boolean)
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

-- Truncate removes elements from the end of *a* until its length is at most
-- *length*. Clears *a* if *length* is less than or equal to zero.
local function Truncate(a: {any}, length: number): {any}
	if length <= 0 then
		table.clear(a)
		return a
	end
	return table.move({}, 1, #a-length, length+1, a)
end

-- Compact removes duplicate adjacent elements from *a*. If *a* has been sorted,
-- then it will contain only unique elements.
local function Compact(a: {any}): {any}
	if #a < 2 then
		return a
	end
	local i = 2
	for j = 2, #a do
		if a[j] ~= a[j-1] then
			if i ~= j then
				a[i] = a[j]
			end
			i += 1
		end
	end
	return table.move({}, 1, #a-i+1, i, a)
end
