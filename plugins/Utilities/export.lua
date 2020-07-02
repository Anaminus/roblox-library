--[[
Export

	Export objects to Lua.

API

	-- Exports each *object* to a Lua script. If no objects are given, then the
	-- current selection is exported instead.
	_G.export(objects: ...Instance)

]]

local function append(t, ...)
	local args = table.pack(...)
	for i = 1, args.n do
		table.insert(t, args[i])
	end
	return t
end

local GetDump do
	local latestURL = "https://raw.githubusercontent.com/RobloxAPI/build-archive/master/data/production/latest.json"
	local dumpURL   = "https://raw.githubusercontent.com/RobloxAPI/build-archive/master/data/production/builds/%s/API-Dump.json"
	local HttpService = game:GetService("HttpService")
	local dump = nil
	function GetDump()
		if not dump then
			if not HttpService.HttpEnabled then
				HttpService.HttpEnabled = true
			end

			local resp = HttpService:RequestAsync({Url = latestURL})
			if resp.StatusCode < 200 or resp.StatusCode >= 300 then
				error("failed to get latest build data", 2)
			end
			local latest = HttpService:JSONDecode(resp.Body)

			local resp = HttpService:RequestAsync({Url = string.format(dumpURL, latest.GUID)})
			if resp.StatusCode < 200 or resp.StatusCode >= 300 then
				error("failed to get latest dump data", 2)
			end
			local rawDump = HttpService:JSONDecode(resp.Body)
			local classes = {}
			for _, rawClass in ipairs(rawDump.Classes) do
				local class = {[1]=rawClass.Superclass}
				for _, member in ipairs(rawClass.Members) do
					if member.MemberType ~= "Property" then
						continue
					end
					if not member.Serialization.CanSave then
						continue
					end
					if member.Tags and table.find(member.Tags, "ReadOnly") then
						continue
					end
					if member.Tags and table.find(member.Tags, "Deprecated") then
						continue
					end
					if member.Tags and table.find(member.Tags, "Hidden") then
						continue
					end
					class[member.Name] = member.ValueType
				end
				classes[rawClass.Name] = class
			end
			-- for name, class in pairs(classes) do
			-- 	if not class[1] then
			-- 		continue
			-- 	end
			-- 	if not classes[class[1]] then
			-- 		class[1] = nil
			-- 	end
			-- end
			-- for name, class in pairs(classes) do
			-- 	if not class[1] then
			-- 		continue
			-- 	end
			-- 	local super = classes[class[1]]
			-- 	while super do
			-- 		for name, value in pairs(super) do
			-- 			if type(name) == "string" then
			-- 				class[name] = value
			-- 			end
			-- 		end
			-- 		class[1] = nil
			-- 		super = classes[super[1]]
			-- 	end
			-- end
			-- dump = classes

			dump = {}
			for name, class in pairs(classes) do
				local p = {}
				local c = class
				while c do
					-- Get each superclass of this class.
					p[#p+1] = c
					c = classes[c[1]]
				end
				local set = {}
				local list = {}
				local o = {Set=set, List=list}
				for i=#p,1,-1 do
					-- Order properties by most primative class first.
					local sort = {}
					for k,v in pairs(p[i]) do
						if k ~= 1 then
							sort[#sort+1] = k
							set[k] = v
						end
					end
					table.sort(sort,function(a,b)
						local ta = set[a]
						local tb = set[b]
						ta = ta.Category .. ":" .. ta.Name
						tb = tb.Category .. ":" .. tb.Name
						if ta == tb then
							return a < b
						else
							return ta < tb
						end
					end)
					for i=1,#sort do
						list[#list+1] = sort[i]
					end
				end
				dump[name] = o
			end
		end
		return dump
	end
end

local typeFormat do
	local function num(n, t)
		if n == math.huge then
			return "math.huge"
		elseif n ~= n then
			return "0/0"
		end
		return string.format(t or "%g", n)
	end

	typeFormat = {
		--[[default]] function(v)
			return tostring(v)
		end;
		bool = function(v)
			return tostring(v)
		end,
		double = function(v)
			return num(v)
		end,
		float = function(v)
			return num(v)
		end,
		int = function(v)
			return num(v, "%d")
		end,
		int64 = function(v)
			return num(v, "%d")
		end,
		string = function(v)
			return string.format("%q", v)
		end,
		Axes = function(v)
			local a = {}
			if v.X then table.insert(a, "Enum.Axis.X") end
			if v.Y then table.insert(a, "Enum.Axis.Y") end
			if v.Z then table.insert(a, "Enum.Axis.Z") end
			return string.format("Axes.new(%s)", table.concat(a, ", "))
		end,
		BinaryString = function(v)
			return string.format("%q", v)
		end,
		BrickColor = function(v)
			return string.format("BrickColor.new(%i)", v.Number)
		end,
		CFrame = function(v)
			local c = {v:components()}
			for i, v in ipairs(c) do
				c[i] = num(v)
			end
			return string.format(
				"CFrame.new(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
				table.unpack(c)
			)
		end,
		Color3 = function(v)
			return string.format(
				"Color3.fromRGB(%s, %s, %s)",
				num(math.floor(v.r*255)),
				num(math.floor(v.g*255)),
				num(math.floor(v.b*255))
			)
		end,
		ColorSequence = function(v)
			local a = v.Keypoints
			for i, v in ipairs(a) do
				a[i] = typeFormat.ColorSequenceKeypoint(v)
			end
			return string.format("ColorSequence.new({%s})", table.concat(a, ", "))
		end,
		ColorSequenceKeypoint = function(v)
			return string.format(
				"ColorSequenceKeypoint.new(%s, %s)",
				num(v.Time),
				typeFormat.Color3(v.Value)
			)
		end,
		Content = function(v)
			return string.format("%q", v)
		end,
		Enum = function(v)
			return string.format("Enum.%s.%s", tostring(v.EnumType), v.Name)
		end,
		Faces = function(v)
			local a = {}
			if v.Right then table.insert(a, "Enum.NormalId.Right") end
			if v.Top then table.insert(a, "Enum.NormalId.Top") end
			if v.Back then table.insert(a, "Enum.NormalId.Back") end
			if v.Left then table.insert(a, "Enum.NormalId.Left") end
			if v.Bottom then table.insert(a, "Enum.NormalId.Bottom") end
			if v.Front then table.insert(a, "Enum.NormalId.Front") end
			return string.format("Faces.new(%s)", table.concat(a, ", "))
		end,
		Instance = function(v, object, prop, refs, defer)
			local var = refs[v]
			if var then
				return var
			end
			table.insert(defer, {object, prop, v})
			return "nil"
		end,
		NumberRange = function(v)
			return string.format(
				"NumberRange.new(%s, %s)",
				num(v.Min),
				num(v.Max)
			)
		end,
		NumberSequence = function(v)
			local a = v.Keypoints
			for i, v in ipairs(a) do
				a[i] = typeFormat.NumberSequenceKeypoint(v)
			end
			return string.format("NumberSequence.new({%s})", table.concat(a, ", "))
		end,
		NumberSequenceKeypoint = function(v)
			return string.format(
				"NumberSequenceKeypoint.new(%s, %s, %s)",
				num(v.Time),
				num(v.Value),
				num(v.Envelope)
			)
		end,
		PhysicalProperties = function(v)
			if not v then
				return "nil"
			end
			return string.format(
				"PhysicalProperties.new(%s, %s, %s, %s, %s)",
				num(v.Density),
				num(v.Friction),
				num(v.Elasticity),
				num(v.FrictionWeight),
				num(v.ElasticityWeight)
			)
		end,
		ProtectedString = function(v)
			return string.format("%q", v)
		end,
		Ray = function(v)
			return string.format(
				"Ray.new(%s, %s)",
				typeFormat.Vector3(v.Origin),
				typeFormat.Vector3(v.Direction)
			)
		end,
		Rect = function(v)
			return string.format(
				"Rect.new(%s, %s, %s, %s)",
				num(v.Min.X),
				num(v.Min.Y),
				num(v.Max.X),
				num(v.Max.Y)
			)
		end,
		UDim = function(v)
			return string.format(
				"UDim.new(%s, %s)",
				num(v.Scale),
				num(v.Offset)
			)
		end,
		UDim2 = function(v)
			return string.format(
				"UDim2.new(%s, %s, %s, %s)",
				num(v.X.Scale),
				num(v.X.Offset),
				num(v.Y.Scale),
				num(v.Y.Offset)
			)
		end,
		Vector2 = function(v)
			return string.format(
				"Vector2.new(%s, %s)",
				num(v.x),
				num(v.y)
			)
		end,
		Vector3 = function(v)
			return string.format(
				"Vector3.new(%s, %s, %s)",
				num(v.x),
				num(v.y),
				num(v.z)
			)
		end,
	}
end

-- tries to sanitize a string into a valid variable name
local function toVarName(name)
	-- remove all non-alphanumeric characters; remove leading digits
	name = name:gsub("[^%w_]",""):gsub("^%d+","")
	return #name > 0 and name
end

local defaultCache = {}
local function formatObjects(objects, options, refs)
	options = options or {}
	refs = refs or {}


	local tab = 0
	local tabStr = options.Indent or "\t"
	local objName = options.VariableName or "object"
	local loc = options.Local and "local " or ""

	local classes = GetDump()
	local output = {}
	local defer = {}
	local function recurse(object, parentVar)
		local className = object.ClassName
		if classes[className] then
			local objVar = refs[object]
			if not objVar then
				-- if the Name can't be converted into a variable name, use the default
				objVar = options.UseName and toVarName(object.Name) or objName
				if refs[objVar] then
					local n = refs[objVar] + 1
					refs[objVar] = n
					objVar = objVar .. n
				else
					refs[objVar] = 0
				end
				refs[objects] = objVar
			end
			local t = string.rep(tabStr, tab)
			append(output, t, loc, objVar, " = Instance.new(\"", className, "\"", (parentVar and not options.ParentLast and (", " .. parentVar) or ""), ")\n")
			local set = classes[className].Set
			if options.IgnoreDefault then
				local defaultInstance = defaultCache[className]
				if defaultInstance == nil then
					local ok, inst = pcall(Instance.new, className)
					if ok and inst then
						defaultCache[className] = inst
						defaultInstance = inst
					else
						defaultCache[className] = false
					end
				end
				if defaultInstance then
					for i,name in pairs(classes[className].List) do
						local ok, value = pcall(function() return object[name] end)
						if ok and value ~= defaultInstance[name] then
							append(output, t, objVar, ".", name, " = ", (typeFormat[set[name].Name] or typeFormat[1])(value, object, name, refs, defer), "\n")
						end
					end
				else
					for i,name in pairs(classes[className].List) do
						local ok, value = pcall(function() return object[name] end)
						if ok then
							append(output, t, objVar, ".", name, " = ", (typeFormat[set[name].Name] or typeFormat[1])(value, object, name, refs, defer), "\n")
						end
					end
				end
			else
				for i,name in pairs(classes[className].List) do
					local ok, value = pcall(function() return object[name] end)
					if ok then
						append(output, t, objVar, ".", name, " = ", (typeFormat[set[name].Name] or typeFormat[1])(value, object, name, refs, defer), "\n")
					end
				end
			end
			if parentVar and options.ParentLast then
				append(output, t, objVar, ".Parent = ", parentVar, "\n")
			end
			tab = tab + 1
			for i,child in pairs(object:GetChildren()) do
				recurse(child, objVar)
			end
			tab = tab - 1
		end
	end
	for _, object in ipairs(objects) do
		recurse(object)
	end
	for i, d in ipairs(defer) do
		local var = refs[d[3]]
		if var then
			append(output, refs[d[1]], ".", d[2], " = ", var, "\n")
		end
	end
	return table.concat(output)
end

local Selection = game:GetService("Selection")
local CoreGui = game:GetService("CoreGui")
function _G.export(...)
	local args = table.pack(...)
	if args.n == 0 then
		args = Selection:Get()
	end
	local output = CoreGui:FindFirstChild("~export#")
	if not output then
		 output = Instance.new("Script")
		output.Name = "~export#"
		output.Archivable = false
		output.Disabled = true
		output.Parent = CoreGui
	end
	local s = formatObjects(args, {
		Indent        = "\t",
		VariableName  = "object",
		IgnoreDefault = true,
		ParentLast    = true,
		UseName       = true,
		Local         = true,
	})
	if pcall(function() output.Source = s end) then
		Selection:Set({output})
		if plugin then
			plugin:OpenScript(output)
		end
	else
		print(s)
	end
end
