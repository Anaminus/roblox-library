--[[
Instance Query

	Select objects in the game from an expression.

API

	-- Scans through each *root* and their descendants. If no roots are given,
	-- then the current selection is used. If no objects are selected, then
	-- `game` is used.
	--
	-- Each object is evaluated with the Lua expression *expr*, where the
	-- variable `a` is the object. If the expression evaulates to true, then
	-- that object is added to the selection. Returns a list of selected
	-- objects.
	--
	-- Throws an error if the expression has a syntax error. A runtime error is
	-- the same as evaluating to false.
	_G.q(expr: string, root: ...Instance): (selection: Array<Instance>)

EXAMPLES

	-- Select nothing.
	_G.q''

	-- Select everything.
	_G.q'a'

	-- Select where object equals value.
	_G.q'a == value'

	-- ...and so on.
	_G.q'a ~= value'

	-- It's just a Lua expression. Do anything!
	_G.q'a.Material == Enum.Material.Plastic and a.BrickColor == BrickColor.Gray()'

	-- Some extra syntax is available:

	-- Select where child matches expression.
	_G.q'a::child(a.Name=="Leaves")'

	-- Select where sibling matches expression.
	_G.q'a::sib(a.Name=="Apples")'

	-- Select where descendant matches expression.
	_G.q'a::dsc(a.Name=="Leaves") and a.ClassName=="Model"'

	-- Select where ancestor matches expression.
	_G.q'a::asc(a.Name=="Union")'

	-- Select where value is approximately equal to an expression.
	_G.q'a.Position.X::isapprox(0)'

	-- Select where value contains a substring.
	_G.q'a.Name::contains("Player")'

	-- Select where value begins with a string.
	_G.q'a.Name::beginswith("Event")'

	-- Select where value ends with a string.
	_G.q'a.Name::endswith("Info")'

	-- Select where value matches a pattern.
	_G.q'a.Name::matches("^%w+%d$")'

	-- Select where instance has tag.
	_G.q'a::hastag("KillBrick")'

	-- Select where tag matches expression.
	_G.q'a::tags():contains("Player")'
	_G.q'a::tags():beginswith("Event")'
	_G.q'a::tags():endswith("Info")'
	_G.q'a::tags():matches("^%w+%d$")'

	Note that this syntax is rudimentarily pattern matched and replaced. The
	exact pattern is:

		([^%s]+)::(%w+)(%b())

	If something isn't working, try calling the function directly:

		-- No good; base expression contains space.
		_G.q'a["Left Shoulder"]::sib(a.Name=="Left Hip")'

		-- Just call function directly.
		_G.q'sib(a["Left Shoulder"], function(a) return a.Name=="Left Hip" end)'

		_G.q'a["Left Shoulder"].MaxVelocity::isapprox(0.1)' -- No good
		_G.q'isapprox(a["Left Shoulder"].MaxVelocity, 0.1)' -- Okay

]]
local Selection = game:GetService("Selection")
local CollectionService = game:GetService("CollectionService")

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

	local function replace(a, b, c)
		return b .. "(" .. a .. ", function(a) return " .. string.sub(c, 2, -2) .. " end)"
	end
	repeat
		local e, n = string.gsub(expr, "([^%s]+)::(%w+)(%b())", replace)
		expr = e
	until n == 0
	expr = "local a = ... return ".. expr

	local filter, err = loadstring(expr)
	if filter == nil then
		error("bad expression:\n\n"..expr, 2)
	end

	local function unsafe(object)
		return not pcall(tostring, object)
	end

	local function query(selection, filter, object, recurse)
		if unsafe(object) then
			return
		end
		local ok, result = pcall(filter, object)
		if ok and result then
			table.insert(selection, object)
		end
		if not recurse then
			return
		end
		local ok, descendants = pcall(object.GetDescendants, object)
		if ok then
			for _, descendant in ipairs(descendants) do
				query(selection, filter, descendant, false)
			end
		end
	end

	local env; env = {
		child = function(object, filter)
			if typeof(object) ~= "Instance" then
				return false
			end
			local ok, children = pcall(object.GetChildren, object)
			if not ok then
				return false
			end
			for _, child in ipairs(children) do
				local ok, result = pcall(filter, child)
				if ok and result then
					return true
				end
			end
			return false
		end,
		sib = function(object, filter)
			if typeof(object) ~= "Instance" then
				return false
			end
			local ok, siblings = pcall(function()
				return object.Parent:GetChildren()
			end)
			for _, sibling in ipairs(siblings) do
				if sibling ~= object then
					local ok, result = pcall(filter, sibling)
					if ok and result then
						return true
					end
				end
			end
		end,
		dsc = function(object, filter)
			if typeof(object) ~= "Instance" then
				return false
			end
			local selection = {}
			query(selection, filter, object, true)
			return #selection > 0
		end,
		asc = function(object, filter)
			if typeof(object) ~= "Instance" then
				return false
			end
			local parent = object
			while parent do
				local ok, p = pcall(function(object)
					return object.Parent
				end, parent)
				if ok and p then
					local ok, result = pcall(filter, p)
					if ok and result then
						return true
					end
				end
				parent = p
			end
			return false
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
		hastag = function(object, value)
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
	setfenv(filter, setmetatable(env, {__index=getfenv()}))
	local selection = {}
	for _, object in ipairs(objects) do
		if typeof(object) == "Instance" then
			query(selection, filter, object, true)
		end
	end
	Selection:Set(selection)
	return selection
end
