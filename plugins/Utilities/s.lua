--[=[
Selection

	Quickly manipulate the current selection.

API

	-- Get nth selection.
	print(_G.s[n])

	-- Insert object as nth selection.
	_G.s[n] = object

	-- Remove nth selection.
	_G.s[n] = nil

	-- Get length of selection.
	print(#_G.s)

	-- Append object to selection.
	_G.s += object

	-- Remove object from selection.
	_G.s -= object

	-- Call expression with each selection.
	_G.s'print(v, i)' -- object, index

	-- Call function with each selection.
	_G.s(function(v, i) print(v, i) end) -- object, index

	-- Get selection table.
	_G.s()

	-- Set selection table.
	_G.s{...} -- objects and tables of objects, recursively

]=]

local Selection = game:GetService('Selection')

local s = newproxy(true)
local mt = getmetatable(s)

function mt:__index(k)
	return Selection:Get()[k]
end

function mt:__newindex(k, v)
	local t = Selection:Get()
	if v == nil then
		table.remove(t, k)
	else
		table.insert(t, k, v)
	end
	Selection:Set(t)
end

function mt:__len()
	return #Selection:Get()
end

function mt:__add(object)
	local t = Selection:Get()
	table.insert(t, object)
	Selection:Set(t)
	return self
end

function mt:__sub(object)
	local t = Selection:Get()
	table.insert(t, object)
	Selection:Set(t)
	return self
end

local function appendRecursively(t, v)
	for _, v in ipairs(v) do
		if typeof(v) == "Instance" then
			table.insert(t, v)
		elseif type(v) == "table" then
			r(t, v)
		end
	end
end

function mt:__call(f)
	if type(f) == 'function' then
		for i, v in pairs(Selection:Get()) do
			f(v, i)
		end
	elseif type(f) == 'string' then
		local func, o = loadstring([[return function(v, i) ]]..f..[[ end]])
		if func then
			func = func()
			for i, v in pairs(Selection:Get()) do
				func(v, i)
			end
		else
			print(o)
		end
	elseif type(f) == 'table' then
		local t = {}
		appendRecursively(t, f)
		Selection:Set(t)
	elseif type(f) == 'nil' then
		return Selection:Get()
	end
end

_G.s = s
