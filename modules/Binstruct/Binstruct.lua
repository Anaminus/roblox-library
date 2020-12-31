--@sec: Binstruct
--@ord: -1
--@doc: Binstruct encodes and decodes binary structures.
--
-- Example:
-- ```lua
-- local Float = {"float", 32}
-- local String = {"string", 8}
-- local Vector3 = {"struct",
-- 	{"X" , Float},
-- 	{"Y" , Float},
-- 	{"Z" , Float},
-- }
-- local CFrame = {"struct",
-- 	{"Position" , Vector3},
-- 	{"Rotation" , {"array", 9, Float}},
-- }
-- local brick = {"struct",
-- 	{"Name"         , String},
-- 	{"CFrame"       , CFrame},
-- 	{"Size"         , Vector3},
-- 	{"Color"        , {"byte"}},
-- 	{"Reflectance"  , {"uint", 4}},
-- 	{"Transparency" , {"uint", 4}},
-- 	{"CanCollide"   , {"bool"}},
-- 	{"Shape"        , {"uint", 3}},
-- 	{"_"            , {"pad", 4}},
-- 	{"Material"     , {"uint", 6}},
-- 	{"_"            , {"pad", 2}},
-- }
--
-- local err, codec = Binstruct.new(brick)
-- if err ~= nil then
-- 	t:Fatalf(err)
-- end
-- print(codec:Decode("\8"..string.rep("A", 73)))
-- -- {
-- --     ["CFrame"] = {
-- --         ["Position"] = {
-- --             ["X"] = 12.078,
-- --             ["Y"] = 12.078,
-- --             ["Z"] = 12.078
-- --         },
-- --         ["Rotation"] = {
-- --             [1] = 12.078,
-- --             [2] = 12.078,
-- --             [3] = 12.078,
-- --             [4] = 12.078,
-- --             [5] = 12.078,
-- --             [6] = 12.078,
-- --             [7] = 12.078,
-- --             [8] = 12.078,
-- --             [9] = 12.078
-- --         }
-- --     },
-- --     ["CanCollide"] = true,
-- --     ["Color"] = 65,
-- --     ["Material"] = 1,
-- --     ["Name"] = "AAAAAAAA",
-- --     ["Reflectance"] = 1,
-- --     ["Shape"] = 0,
-- --     ["Size"] = {
-- --         ["X"] = 12.078,
-- --         ["Y"] = 12.078,
-- --         ["Z"] = 12.078
-- --     },
-- --     ["Transparency"] = 4
-- -- }
-- ```

--@sec: TypeDef
--@def: type TypeDef = {
-- 	encode = Filter?,
-- 	decode = Filter?,
-- 	[1]: string,
-- 	...,
-- }
--@doc: TypeDef is a table where the first element indicates a type that
-- determines the remaining structure of the table.
--
-- Additionally, the following optional named fields can be specified:
-- - `encode`: A filter that transforms a structural value before encoding.
-- - `decode`: A filter that transforms a structural value after decoding.
-- - `hook`: A function that determines whether the type should be used.
-- - `global`: A key that adds the type's value to a globally accessible table.
--
-- Within a decode filter, only the top-level value is structural; components of
-- the value will have already been transformed (if defined to do so). Likewise,
-- an encode filter should return a value that itself is structural, but
-- contains transformed components as expected by the component's type
-- definition. Each component's definition will eventually transform the
-- component itself, so the outer definition must avoid making transformations
-- on the component.
--
-- A hook indicates whether the type will be handled. If it returns true, then
-- the type is handled normally. If false is returned, then the type is skipped.
--
-- The hook receives a *stack* function as its first parameter, which is used to
-- index structures in the stack. The first parameter to *stack* is the *level*,
-- which determines how far down to index the stack. level 0 gets the current
-- structure. Returns nil if *level* is out of bounds.
--
-- The hook receives the global table as its second parameter. This can be used
-- to compare against globally assigned values.
--
-- The hook receives as its third parameter the accumulated result of each hook
-- in the same scope. It will be true only if no other hooks returned true.
--
-- Specifying a global key causes the value of a non-skipped type to be assigned
-- to the global table, which may then be accessed by the remainder of the
-- codec. Values are assigned in the order they are traversed.
--
-- When a type encodes the value `nil`, the zero-value for the type is used.
--
-- The following types are defined:
--
--     {"pad", number}
--         Padding. Does not read or write any value (filters are ignored). The
--         parameter is the number of bits to pad with.
--
--     {"align", number}
--         Pad until the buffer is aligned to the number of bits indicated by
--         the parameter. Does not read or write any value (filters are
--         ignored).
--
--     {"const", any?}
--         A constant value. The parameter is the value. This type is neither
--         encoded nor decoded.
--
--     {"bool", number?}
--         A boolean. The parameter is the number of bits used to represent the
--         value, defaulting to 1.
--
--         The zero for this type is `false`.
--
--     {"int", number}
--         A signed integer. The parameter is the number of bits used to
--         represent the value.
--
--         The zero for this type is `0`.
--
--     {"uint", number}
--         An unsigned integer. The parameter is the number of bits used to
--         represent the value.
--
--         The zero for this type is `0`.
--
--     {"byte"}
--         Shorthand for `{"uint", 8}`.
--
--     {"float", number?}
--         A floating-point number. The parameter is the number of bits used to
--         represent the value, and must be 32 or 64. Defaults to 64.
--
--         The zero for this type is `0`.
--
--     {"fixed", number, number}
--         A signed fixed-point number. The first parameter is the number of
--         bits used to represent the integer part, and the second parameter is
--         the number of bits used to represent the fractional part.
--
--         The zero for this type is `0`.
--
--     {"ufixed", number, number}
--         An unsigned fixed-point number. The first parameter is the number of
--         bits used to represent the integer part, and the second parameter is
--         the number of bits used to represent the fractional part.
--
--         The zero for this type is `0`.
--
--     {"string", number}
--         A sequence of characters. Encoded as an unsigned integer indicating
--         the length of the string, followed by the raw bytes of the string.
--         The parameter is the number of bits used to represent the length.
--
--         The zero for this type is the empty string.
--
--     {"union", ...TypeDef}
--
--         One of several types. Hooks can be used to select a single type.
--
--     {"struct", ...{any?, TypeDef}}
--         A set of named fields. Each parameter is a table defining a field of
--         the struct.
--
--         The first element of a field definition is the key used to index the
--         field. If nil, the value will be processed, but the field will not be
--         assigned to when decoding. When encoding, a `nil` value will be
--         received, so the zero-value of the field's type will be used.
--
--         The second element of a field definition is the type of the field.
--
--         A field definition may also specify a "hook" field, which is
--         described above. If the hook returns false, then the field is
--         skipped.
--
--         A field definition may also specify a "global" field, which is
--         described above. A non-nil global field assigns the field's value to
--         the specified global key.
--
--         The zero for this type is an empty struct.
--
--     {"array", number, TypeDef, level: number?}
--         A constant-size list of unnamed fields.
--
--         The first parameter is the *size* of the array, indicating a constant
--         size.
--
--         The second parameter is the type of each element in the array.
--
--         If the *level* field is specified, then it indicates the ancestor
--         struct where *size* will be searched. If *level* is less than 1 or
--         greater than the number of ancestors, then *size* evaluates to 0.
--         Defaults to 1.
--
--         The zero for this type is an empty array.
--
--     {"vector", any, TypeDef, level: number?}
--         A dynamically sized list of unnamed fields.
--
--         The first parameter is the *size* of the vector, which indicates the
--         key of a field in the parent struct from which the size is
--         determined. Evaluates to 0 if this field cannot be determined or is a
--         non-number.
--
--         The second parameter is the type of each element in the vector.
--
--         If the *level* field is specified, then it indicates the ancestor
--         structure where *size* will be searched. If *level* is less than 1 or
--         greater than the number of ancestors, then *size* evaluates to 0.
--         Defaults to 1, indicating the parent structure.
--
--         The zero for this type is an empty vector.
--
--     {"instance", string, ...{any?, TypeDef}}
--         A Roblox instance. The first parameter is the name of a Roblox class.
--         Each remaining parameter is a table defining a property of the
--         instance.
--
--         The first element of a property definition is the name used to index
--         the property. If nil, the value will be processed, but the field will
--         not be assigned to when decoding. When encoding, a `nil` value will
--         be received, so the zero-value of the field's type will be used.
--
--         The second element of a property definition is the type of the
--         property.
--
--         The zero for this type is a new instance of the class.

--@sec: Filter
--@def: type Filter = (value: any?, params: ...any) -> any?
--@doc: Filter applies to a TypeDef by transforming *value* before encoding, or
-- after decoding. *params* are the parameters of the TypeDef. Should return the
-- transformed *value*.

local Binstruct = {}

local Bitbuf = require(script.Parent.Bitbuf)

-- Registers that should be copied into a stack frame.
local frameRegisters = {
	TABLE = true,
	KEY   = true,
	N     = true,
	H     = true,
}

-- Copies registers in *from* to *to*, or a new frame if *to* is unspecified.
-- Returns *to*.
local function copyFrame(from, to)
	if to == nil then
		to = {}
	end
	for k in pairs(frameRegisters) do
		to[k] = from[k]
	end
	return to
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Set of instructions. Each key is an opcode. Each value is a table, where the
-- "op" field indicates the value of the instruction op. Numeric indices are the
-- columns of the instruction. Each column is a function that receives
-- registers, followed by an instruction parameter. If a column is `true`
-- instead, then it is assigned the value of the previous column.
local Instructions = {}

-- Get or set TABLE[KEY] from BUFFER.
Instructions.SET = {op=1,
	function(R, fn)
		-- *fn* must return the value to assign to TABLE[KEY].
		local v = fn(R.BUFFER)
		if R.KEY ~= nil then
			R.TABLE[R.KEY] = v
		end
	end,
	function(R, fn)
		fn(R.BUFFER, R.TABLE[R.KEY])
	end,
}

-- Call the parameter with BUFFER.
Instructions.CALL = {op=2,
	function(R, fn)
		fn(R.BUFFER)
	end,
	true,
}

-- Scope into a structural value. Must not be followed by an instruction that
-- reads KEY.
Instructions.PUSH = {op=3,
	function(R, fn)
		-- *fn* must return a structural value to scope into.
		local v = fn(R.BUFFER)
		table.insert(R.STACK, copyFrame(R))
		R.TABLE = v
		R.H = true
	end,
	function(R, fn)
		-- *fn* must return a structural value to scope into.
		local v = R.TABLE[R.KEY]
		v = fn(R.BUFFER, v)
		table.insert(R.STACK, copyFrame(R))
		R.TABLE = v
		R.H = true
	end,
}

-- Set KEY to the parameter.
Instructions.FIELD = {op=4,
	function(R, v)
		R.KEY = v
	end,
	true,
}

-- Scope out of a structural value.
Instructions.POP = {op=5,
	-- *fn* runs TABLE through the type's decode filter.
	function(R, fn)
		local v = fn(R.TABLE)
		local frame = table.remove(R.STACK)
		copyFrame(frame, R)
		if R.KEY ~= nil then
			R.TABLE[R.KEY] = v
		end
	end,
	function(R)
		local frame = table.remove(R.STACK)
		copyFrame(frame, R)
	end,
}

-- Initialize a loop with a constant terminator.
Instructions.FORC = {op=6,
	function(R, params)
		-- params: {jumpaddr, size}
		if params[2] >= 1 then
			R.KEY = 1
			R.N = params[2]
			return
		end
		R.PC = params[1]
	end,
	true,
}

-- Initialize a loop with a dynamic terminator, determined by a field in the
-- parent structure.
Instructions.FORF = {op=7,
	function(R, params)
		-- params: {jumpaddr, field, level}
		local level = #R.STACK-params[3]+1
		if level > 1 then
			local top = R.STACK[level]
			if top then
				local parent = top.TABLE
				if parent then
					local v = parent[params[2]]
					if type(v) == "number" then
						R.KEY = 1
						R.N = v
						return
					end
				end
			end
		end
		R.PC = params[1]
	end,
	true,
}

-- Jump to loop start if KEY is less than N.
Instructions.JMPN = {op=8,
	function(R, addr)
		if R.KEY < R.N then
			R.KEY += 1
			R.PC = addr
		end
	end,
	true,
}

-- Prepare a function that indexes stack. If level is 0, then tab is indexed.
local function stackFn(stack, tab)
	if #stack == 0 then
		-- Stack is empty; tab is root, which must be inaccessible. Therefore,
		-- no level will return a valid value.
		return function() return nil end
	end
	local n = #stack+1
	return function(level)
		if level == 0 then
			return tab
		end
		local i = n-level
		if i > 1 then
			local top = stack[i]
			if top then
				return top.TABLE
			end
		end
		return nil
	end
end

-- Call hook, jump to addr if false is returned.
Instructions.HOOK = {op=9,
	function(R, params)
		-- params: {jumpaddr, hook}
		local r = not params[2](stackFn(R.STACK, R.TABLE), R.GLOBAL, R.H)
		R.H = R.H and r
		if r then
			R.PC = params[1]
		end
	end,
	true,
}

-- Set global value.
Instructions.GLOBAL = {op=10,
	function(R, key)
		if R.KEY ~= nil then
			R.GLOBAL[key] = R.TABLE[R.KEY]
		end
	end,
	true,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Set of value types. Each key is a type name. Each value is a function that
-- receives an instruction list, followed by TypeDef parameters. The `append`
-- function should be used to append instructions to the list.
local Types = {}

-- Appends to *list* the instruction corresponding to *opcode*. Each remaining
-- argument corresponds to an argument to be passed to the corresponding
-- instruction column. Returns the address of the appended instruction.
local function append(program, opcode, ...)
	table.insert(program, {op = Instructions[opcode].op, n = select("#", ...), ...})
	return #program
end

-- Sets the first element of each column of the instruction at *addr* to the
-- address of the the last instruction. Expects each column argument to be a
-- table.
local function setJump(program, addr)
	if addr == nil then
		return
	end
	local instr = program[addr]
	for i = 1, instr.n do
		instr[i][1] = #program
	end
end

local function prepareHook(program, def)
	if type(def.hook) ~= "function" then
		return nil
	end
	local params = {nil, def.hook}
	return append(program, "HOOK", params, params)
end

local function appendGlobal(program, def)
	if def.global == nil then
		return nil
	end
	return append(program, "GLOBAL", def.global, def.global)
end

local function nop(v)
	return v
end

local parseDef

Types["pad"] = function(program, def)
	local size = def[1]
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end

	if size and size > 0 then
		local hookaddr = prepareHook(program, def)
		append(program, "CALL",
			function(buf)
				buf:Pad(size)
			end,
			function(buf)
				buf:Pad(size, true)
			end
		)
		setJump(program, hookaddr)
	end
	return nil
end

Types["align"] = function(program, def)
	local size = def[1]
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end

	if size and size > 0 then
		local hookaddr = prepareHook(program, def)
		append(program, "CALL",
			function(buf)
				buf:Align(size)
			end,
			function(buf)
				buf:Align(size, true)
			end
		)
		setJump(program, hookaddr)
	end
	return nil
end

Types["const"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local value = def[1]

	local hookaddr = prepareHook(program, def)
	append(program, "SET",
		function(buf)
			local v = value
			v = dfilter(v)
			return v
		end,
		function(buf, v)
			v = efilter(v)
		end
	)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["bool"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end

	if size then
		size -= 1
	else
		size = 0
	end
	local decode
	local encode
	if size > 0 then
		decode = function(buf)
			local v = buf:ReadBool()
			v = dfilter(v, size)
			return v
		end
		encode = function(buf, v)
			if v == nil then v = false end
			v = efilter(v, size)
			buf:WriteBool(v)
		end
	else
		decode = function(buf)
			local v = buf:ReadBool()
			v = dfilter(v, size)
			buf:Pad(size)
			return v
		end
		encode = function(buf, v)
			if v == nil then v = false end
			v = efilter(v, size)
			buf:WriteBool(v)
			buf:Pad(size, false)
		end
	end

	local hookaddr = prepareHook(program, def)
	append(program, "SET", decode, encode)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["uint"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
	if type(size) ~= "number" then
		return "size must be a number"
	end

	local hookaddr = prepareHook(program, def)
	append(program, "SET",
		function(buf)
			local v = buf:ReadUint(size)
			v = dfilter(v, size)
			return v
		end,
		function(buf, v)
			if v == nil then v = 0 end
			v = efilter(v, size)
			buf:WriteUint(size, v)
		end
	)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["int"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
	if type(size) ~= "number" then
		return "size must be a number"
	end

	local hookaddr = prepareHook(program, def)
	append(program, "SET",
		function(buf)
			local v = buf:ReadInt(size)
			v = dfilter(v, size)
			return v
		end,
		function(buf, v)
			if v == nil then v = 0 end
			v = efilter(v, size)
			buf:WriteInt(size, v)
		end
	)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["byte"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop

	local hookaddr = prepareHook(program, def)
	append(program, "SET",
		function(buf)
			local v = buf:ReadByte()
			v = dfilter(v)
			return v
		end,
		function(buf, v)
			if v == nil then v = 0 end
			v = efilter(v)
			buf:WriteByte(v)
		end
	)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["float"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end
	size = size or 64

	local hookaddr = prepareHook(program, def)
	append(program, "SET",
		function(buf)
			local v = buf:ReadFloat(size)
			v = dfilter(v, size)
			return v
		end,
		function(buf, v)
			if v == nil then v = 0 end
			v = efilter(v, size)
			buf:WriteFloat(size, v)
		end
	)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["ufixed"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local i = def[1]
	local f = def[2]
	if type(i) ~= "number" then
		return "integer part must be a number"
	end
	if type(f) ~= "number" then
		return "fractional part must be a number"
	end

	local hookaddr = prepareHook(program, def)
	append(program, "SET",
		function(buf)
			local v = buf:ReadUfixed(i, f)
			v = dfilter(v, i, f)
			return v
		end,
		function(buf, v)
			if v == nil then v = 0 end
			v = efilter(v, i, f)
			buf:WriteUfixed(i, f, v)
		end
	)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["fixed"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local i = def[1]
	local f = def[2]
	if type(i) ~= "number" then
		return "integer part must be a number"
	end
	if type(f) ~= "number" then
		return "fractional part must be a number"
	end

	local hookaddr = prepareHook(program, def)
	append(program, "SET",
		function(buf)
			local v = buf:ReadFixed(i, f)
			v = dfilter(v, i, f)
			return v
		end,
		function(buf, v)
			if v == nil then v = 0 end
			v = efilter(v, i, f)
			buf:WriteFixed(i, f, v)
		end
	)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["string"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
	if type(size) ~= "number" then
		return "size must be a number"
	end

	local hookaddr = prepareHook(program, def)
	append(program, "SET",
		function(buf)
			local len = buf:ReadUint(size)
			local v = buf:ReadBytes(len)
			v = dfilter(v, size)
			return v
		end,
		function(buf, v)
			if v == nil then v = "" end
			v = efilter(v, size)
			buf:WriteUint(size, #v)
			buf:WriteBytes(v)
		end
	)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["union"] = function(program, def)
	local hookaddr = prepareHook(program, def)
	for i, subtype in ipairs(def) do
		local err = parseDef(subtype, program)
		if err ~= nil then
			return string.format("union[%d]: %s", i, tostring(err))
		end
	end
	setJump(program, hookaddr)
	return nil
end

Types["struct"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop

	local hookaddr = prepareHook(program, def)
	append(program, "PUSH",
		function(buf)
			return {}
		end,
		function(buf, v)
			if v == nil then v = {} end
			v = efilter(v, unpack(def, 1, #def))
			return v
		end
	)
	for _, field in ipairs(def) do
		if type(field) == "table" then
			local name = field[1]
			if field.hook ~= nil and type(field.hook) ~= "function" then
				return string.format("field %q: hook must be a function", name)
			end

			local hookaddr = prepareHook(program, field)
			append(program, "FIELD", name, name)
			local err = parseDef(field[2], program)
			if err ~= nil then
				return string.format("field %q: %s", name, tostring(err))
			end
			appendGlobal(program, field)
			setJump(program, hookaddr)
		end
	end
	append(program, "POP", function(v) return dfilter(v, unpack(def, 1, #def)) end, nil)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["array"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
	local vtype = def[2]
	if type(size) ~= "number" then
		return "size must be a number"
	end

	if size <= 0 then
		-- Array is constantly empty.
		return nil
	end
	local hookaddr = prepareHook(program, def)
	append(program, "PUSH",
		function(buf)
			return {}
		end,
		function(buf, v)
			if v == nil then v = {} end
			v = efilter(v, size, vtype)
			return v
		end
	)
	local params = {nil, size}
	local jumpaddr = append(program, "FORC", params, params)
	local err = parseDef(vtype, program)
	if err ~= nil then
		return string.format("array[%d]: %s", size, tostring(err))
	end
	append(program, "JMPN", jumpaddr, jumpaddr)
	setJump(program, jumpaddr)
	append(program, "POP", function(v) return dfilter(v, size, vtype) end, nil)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["vector"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
	local vtype = def[2]
	if size == nil then
		return "vector size cannot be nil"
	end

	local hookaddr = prepareHook(program, def)
	append(program, "PUSH",
		function(buf)
			return {}
		end,
		function(buf, v)
			if v == nil then v = {} end
			v = efilter(v, size, vtype)
			return v
		end
	)
	local level = def.level or 1
	if level < 0 then
		level = 0
	end
	local params = {nil, size, level}
	local jumpaddr = append(program, "FORF", params, params)
	local err = parseDef(vtype, program)
	if err ~= nil then
		return string.format("vector[%s]: %s", tostring(size), tostring(err))
	end
	append(program, "JMPN", jumpaddr, jumpaddr)
	setJump(program, jumpaddr)
	append(program, "POP", function(v) return dfilter(v, size, vtype) end, nil)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["instance"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local class = def[1]
	if type(class) ~= "string" then
		return "class must be a string"
	end

	local hookaddr = prepareHook(program, def)
	append(program, "PUSH",
		function(buf)
			return Instance.new(class)
		end,
		function(buf, v)
			if v == nil then v = Instance.new(class) end
			v = efilter(v, unpack(def, 2, #def))
			return v
		end
	)
	for i = 2, #def do
		local property = def[i]
		if type(property) == "table" then
			local name = property[1]
			append(program, "FIELD", name, name)
			local err = parseDef(property[2], program)
			if err ~= nil then
				return string.format("property %q: %s", name, tostring(err))
			end
		end
	end
	append(program, "POP", function(v) return dfilter(v, unpack(def, 2, #def)) end, nil)
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local instructions = {}
local opcodes = {}
for opcode, data in pairs(Instructions) do
	for i, k in ipairs(data) do
		if k == true then
			-- Copy previous entry.
			data[i] = data[i-1]
		end
	end
	instructions[data.op] = data
	opcodes[data.op] = opcode
end

function parseDef(def, program)
	if type(def) ~= "table" then
		return "type definition must be a table"
	end
	local name = def[1]
	local t = Types[name]
	if not t then
		return string.format("unknown type %q", tostring(name))
	end
	if def.hook ~= nil and type(def.hook) ~= "function" then
		return "hook must be a function"
	end
	if def.decode ~= nil and type(def.decode) ~= "function" then
		return "decode filter must be a function"
	end
	if def.encode ~= nil and type(def.encode) ~= "function" then
		return "encode filter must be a function"
	end
	local fields = table.create(#def-1)
	table.move(def, 2, #def, 1, fields)
	for k, v in pairs(def) do
		if type(k) ~= "number" then
			fields[k] = v
		end
	end
	return t(program, fields)
end

--@sec: Codec
--@def: type Codec
--@doc: Codec contains instructions for encoding and decoding binary data.
local Codec = {__index={}}

--@sec: Binstruct.new
--@def: Binstruct.new(def: TypeDef): (err: string?, codec: Codec)
--@doc: new constructs a Codec from the given definition.
function Binstruct.new(def)
	assert(type(def) == "table", "table expected")
	local program = {}
	local err = parseDef(def, program)
	if err ~= nil then
		return err, nil
	end
	local self = {program = program}
	return nil, setmetatable(self, Codec)
end

-- Executes the instructions in *program*. *k* selects the instruction argument
-- column. *buffer* is the bit buffer to use. *data* is the data on which to
-- operate.
local function execute(program, k, buffer, data)
	local PN = #program

	-- Registers.
	local R = {
		PC = 1,          -- Program counter.
		BUFFER = buffer, -- Bit buffer.
		GLOBAL = {},     -- A general-purpose per-execution table.
		STACK = {},      -- Stores frames.
		TABLE = {data},  -- The working table.
		KEY = 1,         -- A key pointing to a field in TABLE.
		N = 0,           -- Maximum counter value.
		H = true,        -- Accumulated result of each hook.
	}

	while R.PC <= PN do
		local inst = program[R.PC]
		local op = inst.op
		local exec = instructions[op]
		if not exec then
			R.PC += 1
			continue
		end
		exec[k](R, inst[k])
		R.PC += 1
	end

	return R.TABLE[R.KEY]
end

--@sec: Codec.Decode
--@def: Codec:Decode(buffer: string): any
--@doc: Decode decodes a binary string into a value according to the codec.
-- Returns the decoded value.
function Codec.__index:Decode(buffer)
	assert(type(buffer) == "string", "string expected")
	local buf = Bitbuf.fromString(buffer)
	return execute(self.program, 1, buf, nil)
end

--@sec: Codec.Encode
--@def: Codec:Encode(data: any): string
--@doc: Encode encodes a value into a binary string according to the codec.
-- Returns the encoded string.
function Codec.__index:Encode(data)
	local buf = Bitbuf.new()
	execute(self.program, 2, buf, data)
	return buf:String()
end

local function assertBuffer(buffer)
	if buffer == nil then
		return Bitbuf.new()
	elseif Bitbuf.isBuffer(buffer) then
		return buffer
	end
	error(string.format("Buffer expected, got %s", typeof(buffer)), 3)
end

--@sec: Codec.DecodeBuffer
--@def: Codec:DecodeBuffer(buffer: Bitbuf.Buffer?): any
--@doc: DecodeBuffer decodes a binary string into a value according to the
-- codec. *buffer* is an optional buffer to read from. Returns the decoded
-- value.
function Codec.__index:DecodeBuffer(buffer)
	local buf = assertBuffer(buffer)
	return execute(self.program, 1, buf, nil)
end

--@sec: Codec.EncodeBuffer
--@def: Codec:EncodeBuffer(data: any, buffer: Bitbuf.Buffer?): Bitbuf.Buffer
--@doc: EncodeBuffer encodes a value into a binary string according to the
-- codec. *buffer* is an optional Buffer to write to. Returns a Buffer with the
-- written data.
function Codec.__index:EncodeBuffer(data, buffer)
	local buf = assertBuffer(buffer)
	execute(self.program, 2, buf, data)
	return buf
end

local function formatArg(arg)
	if type(arg) == "function" then
		return "<f>"
	elseif type(arg) == "string" then
		return string.format("%q", arg)
	elseif type(arg) == "table" then
		local s = table.create(#arg)
		for i, v in ipairs(arg) do
			s[i] = formatArg(v)
		end
		return "{"..table.concat(s, ", ").."}"
	end
	return tostring(arg)
end

-- Prints a human-readable representation of the instructions of the codec.
function Codec.__index:Dump()
	local s = {}
	local width = {}
	for addr, inst in ipairs(self.program) do
		local opcode = opcodes[inst.op]
		local args = table.create(inst.n)
		for i = 1, inst.n do
			args[i] = formatArg(inst[i])
			if #args[i] > (width[i] or 0) then
				width[i] = #args[i]
			end
		end
		if #opcode > (width[0] or 0) then
			width[0] = #opcode
		end
		table.insert(s, {addr, opcode, args})
	end
	local fmt = "%0" .. math.ceil(math.log(#self.program+1, 10)) .. "d: %-" .. width[0] .. "s ( "
	for i, w in ipairs(width) do
		if i > 1 then
			fmt = fmt .. " | "
		end
		fmt = fmt .. "%-" .. w .. "s"
	end
	fmt = fmt .. " )"
	for i, v in ipairs(s) do
		s[i] = string.format(fmt, v[1], v[2], unpack(v[3]))
	end
	return table.concat(s, "\n")
end

return Binstruct
