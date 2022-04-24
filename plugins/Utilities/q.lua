--[[
Instance Query

	Select objects in the game from an expression.


API

Scans through each *scope* and their descendants. If no scopes are given, then
the current selection is used. If no objects are selected, then `game` is used.

Each object is evaluated with the Lua expression *expr*, where the variable `v`
is the object. If the expression evaulates to true, then that object is added to
the selection. Returns a list of selected objects.

Throws an error if the expression has a syntax error. A runtime error is the
same as evaluating to false.

	_G.q(expr: string, ...: Instance): {Instance}

Calling the table returned by the function will iterate over each element in the
table. When called with a function, the function is called with each element.
When called with a string, the string is evaluated.

	-- Rename everything named Foo to Bar.
	_G.q'v.Name=="Foo"'(function(v, i) v.Name = "Bar" end)
	_G.q'v.Name=="Foo"' 'v.Name="Bar"'


EXAMPLES

Select nothing.

	_G.q''

Select everything.

	_G.q'v'

Select where object equals value.

	_G.q'v == value'

...and so on.

	_G.q'v ~= value'

It's just a Lua expression. Do anything!

	_G.q'v.Material.Name == "Plastic" and v.BrickColor.Name == "Bright red"'


PSEUDO-METHODS

Several global functions are included in the filter's environment. These
functions can be called with an inverted method-like syntax on an expression
(`expr@method(args)`). Note that this syntax is rudimentarily pattern matched
and replaced. The expression is delimited by spaces.

The exact pattern is:

	([^%s]+)@(%w+)(%b())

Successful matches are replaced by the following:

	$2($1, function(v, i, n) return $3 end)

Replacement continues recursively until no matches are found. If something isn't
working, try calling a function directly.

Functions:

- child

	Select where any child matches an expression. The expression has variables
	`v` for a child, and `i` for the numerical index of the child.

		-- Select objects that have a child named Leaves.
		_G.q'v@child(v.Name=="Leaves")'

- allchild

	Select where all children match an expression. The expression has variables
	`v` for a child, and `i` for the numerical index of the child.

		-- Select objects where all children are Parts.
		_G.q'v@allchild(v.ClassName=="Part")'

- sib

	Select where any sibling matches an expression. The expression has variables
	`v` for a sibling, `i` for the numerical child index of the sibling, and `n`
	for the index of the object.

		-- Select objects with preceeding siblings named Apple.
		_G.q'v@sib(v.Name=="Apple" and i<n)'

- allsib

	Select where all siblings match an expression. The expression has variables
	`v` for a sibling, `i` for the numerical child index of the sibling, and `n`
	for the index of the object.

		-- Select objects that are the last sibling.
		_G.q'v@allsib(i<n)'

- dsc

	Select where any descendant matches an expression. The expression has
	variables `v` for a descendant, and `i` for the numerical child index of the
	descendant.

		-- Select Models that contain an object named Leaves.
		_G.q'v.ClassName=="Model" and v@dsc(v.Name=="Leaves")'

		-- Select objects that contain an object named Banana which is the third
		-- child of some parent.
		_G.q'v@dsc(i==3 and v.Name=="Banana")'

- alldsc

	Select where all descendants match an expression. The expression has
	variables `v` for a descendant, and `i` for the numerical child index of the
	descendant.

		-- Select MeshParts that contain only a tree of Bones.
		_G.q'v:IsA("MeshPart") and v@alldsc(v.ClassName=="Bone")

- asc

	Select where an ancestor matches expression. The expression has variables
	`v` for an ancestor, and `i` for the hierarchical distance between the
	object and the ancestor.

		-- Select objects that are a descendant of objects named Union.
		_G.q'v@asc(v.Name=="Union")'
		-- Select objects that have a grandparent.
		_G.q'v@asc(i>1)'

- allasc

	Select where all ancestors match an expression. The expression has variables
	`v` for an ancestor, and `i` for the hierarchical distance between the
	object and the ancestor.

		-- Select objects where all ancestors are Archivable.
		_G.q'v@allasc(v.Archivable)'

- scope

	Select where an object is a part of the initial selection.

		-- Select the children of each selection.
		_G.q'v.Parent@scope()'

- isapprox

	Select where a value is approximately equal to an expression.

		_G.q'v.Position.X@isapprox(0)'

- contains

	Select where a value contains a substring.

		_G.q'v.Name@contains("Player")'

- beginswith

	Select where a value begins with a string.

		_G.q'v.Name@beginswith("Event")'

- endswith

	Select where a value ends with a string.

		_G.q'v.Name@endswith("Info")'

- matches

	Select where a value matches a pattern.

		_G.q'v.Name@matches("^%w+%d$")'

- tag

	Select where an instance has a tag.

		_G.q'v@tag("KillBrick")'

- tags

	Returns a list of tags, with methods corresponding to contains, beginswith,
	endswith, and matches.

		_G.q'v@tags():contains("Player")'
		_G.q'v@tags():beginswith("Event")'
		_G.q'v@tags():endswith("Info")'
		_G.q'v@tags():matches("^%w+%d$")'

If something isn't working, try calling the function directly:

	-- No good; base expression contains space.
	_G.q'v["Left Shoulder"]@sib(v.Name=="Left Hip")'

	-- Just call function directly.
	_G.q'sib(v["Left Shoulder"], function(v) return v.Name=="Left Hip" end)'

	_G.q'v["Left Shoulder"].MaxVelocity@isapprox(0.1)' -- No good
	_G.q'isapprox(v["Left Shoulder"].MaxVelocity, 0.1)' -- Okay

REFINEMENT

The refinement syntax recursively refines each previous selection.

	-- Select according to expression A, then refine the results of A according
	-- to B, then refine the results of B according to C.
	_G.q'A | B | C'

This is equivalent to calling each expression individually. This should be done
instead if an expression must contain a `|` character.

	_G.q'A'
	_G.q'B'
	_G.q'C'

Example:

	-- Select all Models named Tree, then select all descendants named Leaves.
	_G.q'v.ClassName=="Model" and v.Name=="Tree" | v.Name=="Leaves"'
	-- Equivalent to:
	_G.q'v.Name=="Leaves" and v@asc(v.ClassName=="Model" and v.Name=="Tree")'

SKIP SELECTION

If the entire query begins with "!", then this causes selected instances to not
be added to the Selection service. This is usedful for running expressions on a
query without the overhead of the Selection service.

Example:

	-- Make all red parts blue. Selection is unchanged.
	_G.q'!v.BrickColor == BrickColor.Red()' 'v.BrickColor = BrickColor.Blue()'

]]
local Selection = game:GetService("Selection")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function replace(a, b, c)
	return b .. "(" .. a .. ", function(v, i, n) return " .. string.sub(c, 2, -2) .. " end)"
end

local function unsafe(object)
	return not pcall(tostring, object)
end

local function query(selection, filter, object, index, recurse)
	if unsafe(object) then
		return
	end
	local ok, result = pcall(filter, object, index)
	if ok and result then
		table.insert(selection, object)
	end
	if not recurse then
		return
	end
	local ok, children = pcall(object.GetChildren, object)
	if ok then
		for i, child in ipairs(children) do
			query(selection, filter, child, i, true)
		end
	end
end

local env; env = {
	scope = function(object, filter)
		if typeof(object) ~= "Instance" then return false end
		local scopes = coroutine.yield()
		for _, scope in ipairs(scopes) do
			if object == scope then return true end
		end
		return false
	end,
	child = function(object, filter)
		if typeof(object) ~= "Instance" then return false end
		local ok, children = pcall(object.GetChildren, object)
		if not ok then return false end
		for i, child in ipairs(children) do
			local ok, result = pcall(filter, child, i)
			if ok and result then return true end
		end
		return false
	end,
	allchild = function(object, filter)
		if typeof(object) ~= "Instance" then return false end
		local ok, children = pcall(object.GetChildren, object)
		if not ok then return false end
		for i, child in ipairs(children) do
			local ok, result = pcall(filter, child, i)
			if not ok or not result then return false end
		end
		return true
	end,
	sib = function(object, filter)
		if typeof(object) ~= "Instance" then return false end
		local ok, siblings = pcall(function()
			return object.Parent:GetChildren()
		end)
		if not ok then return false end
		local n
		for i, sibling in ipairs(siblings) do
			if sibling == object then
				n = i
				break
			end
		end
		for i, sibling in ipairs(siblings) do
			if sibling ~= object then
				local ok, result = pcall(filter, sibling, i, n)
				if ok and result then return true end
			end
		end
		return false
	end,
	allsib = function(object, filter)
		if typeof(object) ~= "Instance" then return false end
		local ok, siblings = pcall(function()
			return object.Parent:GetChildren()
		end)
		if not ok then return false end
		local n
		for i, sibling in ipairs(siblings) do
			if sibling == object then
				n = i
				break
			end
		end
		for i, sibling in ipairs(siblings) do
			if sibling ~= object then
				local ok, result = pcall(filter, sibling, i, n)
				if not ok or not result then return false end
			end
		end
		return true
	end,
	dsc = function(object, filter)
		if typeof(object) ~= "Instance" then return false end
		local function recurse(object, filter)
			local ok, children = pcall(object.GetChildren, object)
			if not ok then return false end
			for i, child in ipairs(children) do
				local ok, result = pcall(filter, child, i)
				if ok and result then return true end
				if recurse(child, filter) then return true end
			end
			return false
		end
		return recurse(object, filter)
	end,
	alldsc = function(object, filter)
		if typeof(object) ~= "Instance" then return false end
		local function recurse(object, filter)
			local ok, children = pcall(object.GetChildren, object)
			if not ok then return false end
			for i, child in ipairs(children) do
				local ok, result = pcall(filter, child, i)
				if not ok or not result then return false end
				if not recurse(child, filter) then return false end
			end
			return true
		end
		return recurse(object, filter)
	end,
	asc = function(object, filter)
		if typeof(object) ~= "Instance" then return false end
		local parent = object
		local i = 1
		while parent do
			local ok, p = pcall(function(object)
				return object.Parent
			end, parent)
			if ok and p then
				local ok, result = pcall(filter, p, i)
				if ok and result then return true end
			end
			parent = p
			i += 1
		end
		return false
	end,
	allasc = function(object, filter)
		if typeof(object) ~= "Instance" then return false end
		local parent = object
		local i = 1
		while parent do
			local ok, p = pcall(function(object)
				return object.Parent
			end, parent)
			if ok and p then
				local ok, result = pcall(filter, p, i)
				if not ok or not result then return false end
			end
			parent = p
			i += 1
		end
		return true
	end,
	isapprox = function(object, value)
		if type(value) == "function" then value = value() end
		object = tonumber(object)
		if object == nil then return false end
		return math.abs(object-value) < 10e-6
	end,
	contains = function(object, value)
		if type(value) == "function" then value = value() end
		if type(object) == "string" then
			return not not string.find(object, value, 1, true)
		elseif type(object) == "table" then
			for _, v in pairs(object) do
				if env.contains(v, value) then
					return true
				end
			end
		end
		return false
	end,
	beginswith = function(object, value)
		if type(value) == "function" then value = value() end
		if type(object) == "string" then
			return select(1, string.find(object, value, 1, true)) == 1
		elseif type(object) == "table" then
			for _, v in pairs(object) do
				if env.beginswith(v, value) then
					return true
				end
			end
		end
		return false
	end,
	endswith = function(object, value)
		if type(value) == "function" then value = value() end
		if type(object) == "string" then
			return select(2, string.find(object, value, 1, true)) == #object
		elseif type(object) == "table" then
			for _, v in pairs(object) do
				if env.endswith(v, value) then
					return true
				end
			end
		end
		return false
	end,
	matches = function(object, value)
		if type(value) == "function" then value = value() end
		if type(object) == "string" then
			return not not string.match(object, value)
		elseif type(object) == "table" then
			for _, v in pairs(object) do
				if env.matches(v, value) then
					return true
				end
			end
		end
		return false
	end,
	tag = function(object, value)
		if typeof(object) ~= "Instance" then return false end
		if type(value) == "function" then value = value() end
		local ok, value = pcall(tostring, value)
		if not ok then return false end
		return CollectionService:HasTag(object, value)
	end,
	tags = function(object)
		if typeof(object) ~= "Instance" then return false end
		local tags = CollectionService:GetTags(object)
		tags.contains = env.contains
		tags.beginswith = env.beginswith
		tags.endswith = env.endswith
		tags.matches = env.matches
		return tags
	end,
}

local ForEach = {}
function ForEach:__call(f)
	ChangeHistoryService:SetWaypoint("Run expression on each selection")
	if type(f) == 'function' then
		for i, v in ipairs(self) do
			f(v, i)
		end
	elseif type(f) == 'string' then
		local func, o = loadstring([[return function(v, i) ]]..f..[[ end]])
		if func then
			func = func()
			for i, v in ipairs(self) do
				func(v, i)
			end
		else
			print(o)
		end
	end
end

function _G.q(...)
	local expr = ...
	if type(expr) ~= "string" then
		error("expression must be a string", 2)
	end

	local objects
	if select("#", ...) == 1 then
		objects = Selection:Get()
		if #objects == 0 then
			table.insert(objects, game)
		end
	else
		objects = {select(2, ...)}
	end

	local skip = false
	if string.sub(expr, 1, 1) == "!" then
		skip = true
		expr = string.sub(expr, 2)
	end

	local exprs = {}
	for e in expr:gmatch("[^|]+") do
		table.insert(exprs, e)
	end

	for i, expr in ipairs(exprs) do
		repeat
			local e, n = string.gsub(expr, "([^%s]+)@(%w+)(%b())", replace)
			expr = e
		until n == 0
		expr = "return function(v, i, n) return ".. expr .. " end"

		local f = Instance.new("ModuleScript")
		f.Name = "Expression" .. i
		f.Source = expr
		local ok, filter = pcall(require, f)
		if not ok then
			error("bad expression:\n\n"..filter, 0)
		end

		setfenv(filter, setmetatable(env, {__index=getfenv()}))
		local selection = {}
		local thread = coroutine.create(function(selection, objects, filter)
			for i, object in ipairs(objects) do
				if typeof(object) == "Instance" then
					query(selection, filter, object, i, true)
				end
			end
		end)
		local ok, err = coroutine.resume(thread, selection, objects, filter)
		if not ok then
			error(err)
		end
		while coroutine.status(thread) ~= "dead" do
			local ok, err = coroutine.resume(thread, objects)
			if not ok then
				error(err)
			end
		end
		objects = selection
	end
	if not skip then
		Selection:Set(objects)
	end
	return setmetatable(objects, ForEach)
end
