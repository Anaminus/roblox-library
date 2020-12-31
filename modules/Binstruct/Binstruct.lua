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
-- 	hook   = Hook?,
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
--@def: type Filter = (value: any?, params: ...any) -> (any?, error?)
--@doc: Filter applies to a TypeDef by transforming *value* before encoding, or
-- after decoding. Should return the transformed *value*.
--
-- *params* are the elements of the TypeDef. Only primitive types are passed.
--
--
-- A non-nil error causes the program to halt, returning the given value.

--@sec: Hook
--@def: type Hook = (stack: (level: number)->any, global: table, h: boolean) -> (boolean, error?)
--@doc: Hook applies to a TypeDef by transforming *value* before encoding, or
-- after decoding. *params* are the parameters of the TypeDef. Should return the
-- transformed *value*.
--
-- Hook indicates whether a type is traversed. If it returns true, then the type
-- is traversed normally. If false is returned, then the type is skipped. If an
-- error is returned, the program halts, returning the error.
--
-- *stack* is used to index structures in the stack. *level* determines how far
-- down to index the stack. level 0 returns the current structure. Returns nil
-- if *level* is out of bounds.
--
-- *global* is the global table. This can be used to compare against globally
-- assigned values.
--
-- *h* is the accumulated result of each hook in the same scope. It will be true
-- only if no other hooks returned true.

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
-- "op" field indicates the value of the instruction op. The "decode" and
-- "encode" fields specify the columns of the instruction. Each column is a
-- function of the form `(registers, parameter): error`. If "encode" is a
-- non-function, then it is copied from "decode".
local Instructions = {}

-- Get or set TABLE[KEY] from BUFFER.
Instructions.SET = {op=1,
	decode = function(R, fn) -- fn: (Buffer) -> (value, error)
		local v, err = fn(R.BUFFER)
		if R.KEY ~= nil then
			R.TABLE[R.KEY] = v
		end
		return err
	end,
	encode = function(R, fn) -- fn: (Buffer, value) -> error
		local err = fn(R.BUFFER, R.TABLE[R.KEY])
		return err
	end,
}

-- Call the parameter with BUFFER.
Instructions.CALL = {op=2,
	decode = function(R, fn) -- fn: (Buffer) -> error
		local err = fn(R.BUFFER)
		return err
	end,
	encode = true,
}

-- Scope into a structural value. Must not be followed by an instruction that
-- reads KEY.
Instructions.PUSH = {op=3,
	decode = function(R, fn) -- fn: (Buffer) -> (value, error)
		-- *value* be a structural value to scope into.
		local v, err = fn(R.BUFFER)
		table.insert(R.STACK, copyFrame(R))
		R.TABLE = v
		R.H = true
		return err
	end,
	encode = function(R, fn) -- fn: (Buffer, value) -> (value, error)
		-- Result *value* must be a structural value to scope into.
		local v = R.TABLE[R.KEY]
		local v, err = fn(R.BUFFER, v)
		table.insert(R.STACK, copyFrame(R))
		R.TABLE = v
		R.H = true
		return err
	end,
}

-- Set KEY to the parameter.
Instructions.FIELD = {op=4,
	decode = function(R, v) -- v: any
		R.KEY = v
		return nil
	end,
	encode = true,
}

-- Scope out of a structural value.
Instructions.POP = {op=5,
	decode = function(R, fn) -- fn: (value) -> (value, error)
		local v, err = fn(R.TABLE)
		local frame = table.remove(R.STACK)
		copyFrame(frame, R)
		if R.KEY ~= nil then
			R.TABLE[R.KEY] = v
		end
		return err
	end,
	encode = function(R)
		local frame = table.remove(R.STACK)
		copyFrame(frame, R)
		return nil
	end,
}

-- Initialize a loop with a constant terminator.
Instructions.FORC = {op=6,
	decode = function(R, params) -- params: {jumpaddr, size}
		if params[2] >= 1 then
			R.KEY = 1
			R.N = params[2]
			return nil
		end
		R.PC = params[1]
		return nil
	end,
	encode = true,
}

-- Initialize a loop with a dynamic terminator, determined by a field in the
-- parent structure.
Instructions.FORF = {op=7,
	decode = function(R, params) -- params: {jumpaddr, field, level}
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
						return nil
					end
				end
			end
		end
		R.PC = params[1]
		return nil
	end,
	encode = true,
}

-- Jump to loop start if KEY is less than N.
Instructions.JMPN = {op=8,
	decode = function(R, addr) -- addr: number
		if R.KEY < R.N then
			R.KEY += 1
			R.PC = addr
		end
		return nil
	end,
	encode = true,
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
	decode = function(R, params) -- params: {jumpaddr, hook}
		local r, err = params[2](stackFn(R.STACK, R.TABLE), R.GLOBAL, R.H)
		if err then
			return err
		end
		R.H = R.H and not r
		if not r then
			R.PC = params[1]
		end
		return nil
	end,
	encode = true,
}

-- Set global value.
Instructions.GLOBAL = {op=10,
	decode = function(R, key) -- key: any
		if R.KEY ~= nil then
			R.GLOBAL[key] = R.TABLE[R.KEY]
		end
		return nil
	end,
	encode = true,
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
local function append(program, opcode, def)
	def.op = Instructions[opcode].op
	table.insert(program, def)
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
	instr.decode[1] = #program
	instr.encode[1] = #program
end

local function prepareHook(program, def)
	if type(def.hook) ~= "function" then
		return nil
	end
	local params = {nil, def.hook}
	return append(program, "HOOK", {decode=params, encode=params})
end

local function appendGlobal(program, def)
	if def.global == nil then
		return nil
	end
	return append(program, "GLOBAL", {decode=def.global, encode=def.global})
end

local function nop(v)
	return v, nil
end

local EOF = "end of buffer"

local parseDef

Types["pad"] = function(program, def)
	local size = def[1]
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end

	if not size or size <= 0 then
		return nil
	end
	local hookaddr = prepareHook(program, def)
	append(program, "CALL", {
		decode = function(buf)
			if not buf:Fits(size) then return EOF end
			buf:ReadPad(size)
			return nil
		end,
		encode = function(buf)
			buf:WritePad(size)
			return nil
		end,
	})
	setJump(program, hookaddr)
end

Types["align"] = function(program, def)
	local size = def[1]
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end

	if not size or size <= 0 then
		return nil
	end
	local hookaddr = prepareHook(program, def)
	append(program, "CALL", {
		decode = function(buf)
			if not buf:Fits(size) then return EOF end
			buf:ReadAlign(size)
			return nil
		end,
		encode = function(buf)
			buf:WriteAlign(size)
			return nil
		end,
	})
	setJump(program, hookaddr)
	return nil
end

Types["const"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local value = def[1]

	local hookaddr = prepareHook(program, def)
	append(program, "SET", {
		decode = function(buf)
			local v = value
			local v, err = dfilter(v, unpack(def))
			return v, err
		end,
		encode = function(buf, v)
			local v, err = efilter(v, unpack(def))
			return err
		end,
	})
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

	size = size or 1
	local decode
	local encode
	if size == 1 then
		decode = function(buf)
			if not buf:Fits(1) then return nil, EOF end
			local v = buf:ReadBool()
			local v, err = dfilter(v, size)
			return v, err
		end
		encode = function(buf, v)
			if v == nil then v = false end
			local v, err = efilter(v, size)
			buf:WriteBool(v)
			return err
		end
	else
		decode = function(buf)
			if not buf:Fits(size) then return nil, EOF end
			local v = buf:ReadBool()
			local v, err = dfilter(v, size)
			buf:ReadPad(size-1)
			return v, err
		end
		encode = function(buf, v)
			if v == nil then v = false end
			local v, err = efilter(v, size)
			buf:WriteBool(v)
			buf:WritePad(size-1)
			return err
		end
	end

	local hookaddr = prepareHook(program, def)
	append(program, "SET", {decode=decode, encode=encode})
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
	append(program, "SET", {
		decode = function(buf)
			if not buf:Fits(size) then return nil, EOF end
			local v = buf:ReadUint(size)
			local v, err = dfilter(v, unpack(def))
			return v, err
		end,
		encode = function(buf, v)
			if v == nil then v = 0 end
			local v, err = efilter(v, unpack(def))
			buf:WriteUint(size, v)
			return err
		end,
	})
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
	append(program, "SET", {
		decode = function(buf)
			if not buf:Fits(size) then return nil, EOF end
			local v = buf:ReadInt(size)
			local v, err = dfilter(v, unpack(def))
			return v, err
		end,
		encode = function(buf, v)
			if v == nil then v = 0 end
			local v, err = efilter(v, unpack(def))
			buf:WriteInt(size, v)
			return err
		end,
	})
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

Types["byte"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop

	local hookaddr = prepareHook(program, def)
	append(program, "SET", {
		decode = function(buf)
			if not buf:Fits(8) then return nil, EOF end
			local v = buf:ReadByte()
			local v, err = dfilter(v, unpack(def))
			return v, err
		end,
		encode = function(buf, v)
			if v == nil then v = 0 end
			local v, err = efilter(v, unpack(def))
			buf:WriteByte(v)
		end,
	})
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
	append(program, "SET", {
		decode = function(buf)
			if not buf:Fits(size) then return nil, EOF end
			local v = buf:ReadFloat(size)
			local v, err = dfilter(v, unpack(def))
			return v, err
		end,
		encode = function(buf, v)
			if v == nil then v = 0 end
			local v, err = efilter(v, unpack(def))
			buf:WriteFloat(size, v)
			return err
		end,
	})
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
	append(program, "SET", {
		decode = function(buf)
			if not buf:Fits(i+f) then return nil, EOF end
			local v = buf:ReadUfixed(i, f)
			local v, err = dfilter(v, unpack(def))
			return v, err
		end,
		encode = function(buf, v)
			if v == nil then v = 0 end
			local v, err = efilter(v, unpack(def))
			buf:WriteUfixed(i, f, v)
			return err
		end,
	})
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
	append(program, "SET", {
		decode = function(buf)
			if not buf:Fits(i+f) then return nil, EOF end
			local v = buf:ReadFixed(i, f)
			local v, err = dfilter(v, unpack(def))
			return v, err
		end,
		encode = function(buf, v)
			if v == nil then v = 0 end
			local v, err = efilter(v, unpack(def))
			buf:WriteFixed(i, f, v)
			return err
		end,
	})
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
	append(program, "SET", {
		decode = function(buf)
			if not buf:Fits(size) then return nil, EOF end
			local len = buf:ReadUint(size)
			if not buf:Fits(len) then return nil, EOF end
			local v = buf:ReadBytes(len)
			local v, err = dfilter(v, unpack(def))
			return v, err
		end,
		encode = function(buf, v)
			if v == nil then v = "" end
			local v, err = efilter(v, unpack(def))
			buf:WriteUint(size, #v)
			buf:WriteBytes(v)
			return err
		end,
	})
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
	append(program, "PUSH", {
		decode = function(buf)
			return {}, nil
		end,
		encode = function(buf, v)
			if v == nil then v = {} end
			local v, err = efilter(v)
			return v, err
		end,
	})
	for _, field in ipairs(def) do
		if type(field) == "table" then
			local name = field[1]
			if field.hook ~= nil and type(field.hook) ~= "function" then
				return string.format("field %q: hook must be a function", name)
			end

			local hookaddr = prepareHook(program, field)
			append(program, "FIELD", {decode=name, encode=name})
			local err = parseDef(field[2], program)
			if err ~= nil then
				return string.format("field %q: %s", name, tostring(err))
			end
			appendGlobal(program, field)
			setJump(program, hookaddr)
		end
	end
	append(program, "POP", {
		decode = function(v)
			local v, err = dfilter(v)
			return v, err
		end,
		encode = nil,
	})
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
	append(program, "PUSH", {
		decode = function(buf)
			return {}, nil
		end,
		encode = function(buf, v)
			if v == nil then v = {} end
			local v, err = efilter(v, unpack(def, 1, 1))
			return v, err
		end,
	})
	local params = {nil, size}
	local jumpaddr = append(program, "FORC", {decode=params, encode=params})
	local err = parseDef(vtype, program)
	if err ~= nil then
		return string.format("array[%d]: %s", size, tostring(err))
	end
	append(program, "JMPN", {decode=jumpaddr, encode=jumpaddr})
	setJump(program, jumpaddr)
	append(program, "POP", {
		decode = function(v)
			local v, err = dfilter(v, unpack(def, 1, 1))
			return v, err
		end,
		encode = nil,
	})
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
	append(program, "PUSH", {
		decode = function(buf)
			return {}, nil
		end,
		encode = function(buf, v)
			if v == nil then v = {} end
			local v, err = efilter(v, unpack(def, 1, 1))
			return v, err
		end,
	})
	local level = def.level or 1
	if level < 0 then
		level = 0
	end
	local params = {nil, size, level}
	local jumpaddr = append(program, "FORF", {decode=params, encode=params})
	local err = parseDef(vtype, program)
	if err ~= nil then
		return string.format("vector[%s]: %s", tostring(size), tostring(err))
	end
	append(program, "JMPN", {decode=jumpaddr, encode=jumpaddr})
	setJump(program, jumpaddr)
	append(program, "POP", {
		decode = function(v)
			local v, err = dfilter(v, unpack(def, 1, 1))
			return v, err
		end,
		encode = nil,
	})
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
	append(program, "PUSH", {
		decode = function(buf)
			return Instance.new(class)
		end,
		encode = function(buf, v)
			if v == nil then v = Instance.new(class) end
			local v, err = efilter(v, unpack(def, 1, 1))
			return v, err
		end,
	})
	for i = 2, #def do
		local property = def[i]
		if type(property) == "table" then
			local name = property[1]
			append(program, "FIELD", {decode=name, encode=name})
			local err = parseDef(property[2], program)
			if err ~= nil then
				return string.format("property %q: %s", name, tostring(err))
			end
		end
	end
	append(program, "POP", {
		decode = function(v)
			local v, err = dfilter(v, unpack(def, 1, 1))
			return v, err
		end,
		encode = nil,
	})
	appendGlobal(program, def)
	setJump(program, hookaddr)
	return nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local instructions = {}
local opcodes = {}
for opcode, data in pairs(Instructions) do
	if type(data.encode) ~= "function" then
		data.encode = data.decode
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

	local err = nil
	while R.PC <= PN and err == nil do
		local instr = program[R.PC]
		local op = instr.op
		local exec = instructions[op]
		if not exec then
			R.PC += 1
			continue
		end
		err = exec[k](R, instr[k])
		R.PC += 1
	end

	if err then
		local stack = table.create(#R.STACK-1)
		for i = 2, #R.STACK do
			stack[i-1] = "["..tostring(R.STACK[i].KEY).."]"
		end
		err = string.format("root%s: %s", table.concat(stack), err)
		return err, nil
	end
	return nil, R.TABLE[R.KEY]
end

--@sec: Codec.Decode
--@def: Codec:Decode(buffer: string): (error, any)
--@doc: Decode decodes a binary string into a value according to the codec.
-- Returns the decoded value.
function Codec.__index:Decode(buffer)
	assert(type(buffer) == "string", "string expected")
	local buf = Bitbuf.fromString(buffer)
	return execute(self.program, "decode", buf, nil)
end

--@sec: Codec.Encode
--@def: Codec:Encode(data: any): (error, string)
--@doc: Encode encodes a value into a binary string according to the codec.
-- Returns the encoded string.
function Codec.__index:Encode(data)
	local buf = Bitbuf.new()
	local err, _ = execute(self.program, "encode", buf, data)
	if err then
		return err, ""
	end
	return nil, buf:String()
end

--@sec: Codec.DecodeBuffer
--@def: Codec:DecodeBuffer(buffer: Bitbuf.Buffer): (error, any)
--@doc: DecodeBuffer decodes a binary string into a value according to the
-- codec. *buffer* is the buffer to read from. Returns the decoded value.
function Codec.__index:DecodeBuffer(buffer)
	if not Bitbuf.isBuffer(buffer) then
		error(string.format("Buffer expected, got %s", typeof(buffer)), 3)
	end
	return execute(self.program, 1, buffer, nil)
end

--@sec: Codec.EncodeBuffer
--@def: Codec:EncodeBuffer(data: any, buffer: Bitbuf.Buffer?): (error, Bitbuf.Buffer)
--@doc: EncodeBuffer encodes a value into a binary string according to the
-- codec. *buffer* is an optional Buffer to write to. Returns the Buffer with
-- the written data.
function Codec.__index:EncodeBuffer(data, buffer)
	local buf
	if buffer == nil then
		buf = Bitbuf.new()
	elseif Bitbuf.isBuffer(buffer) then
		buf = buffer
	else
		error(string.format("Buffer expected, got %s", typeof(buffer)), 3)
	end
	local err, _ = execute(self.program, 2, buf, data)
	if err then
		return err, nil
	end
	return nil, buf
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
	local rows = table.create(#self.program)
	local width = table.create(3, 0)
	for addr, instr in ipairs(self.program) do
		local cols = {addr, opcodes[instr.op], instr.decode, instr.encode}
		if #cols[2] > width[1] then
			width[1] = #cols[2]
		end
		cols[3] = formatArg(cols[3])
		if #cols[3] > width[2] then
			width[2] = #cols[3]
		end
		cols[4] = formatArg(cols[4])
		if #cols[4] > width[3] then
			width[3] = #cols[4]
		end
		table.insert(rows, cols)
	end
	local fmt = "%0" .. math.ceil(math.log(#self.program+1, 10)) .. "d: " ..
		"%-" .. width[1] .. "s" ..
		" ( %-" .. width[2] .. "s" ..
		" | %-" .. width[3] .. "s" ..
		" )"
	for i, cols in ipairs(rows) do
		rows[i] = string.format(fmt, unpack(cols))
	end
	return table.concat(rows, "\n")
end

return Binstruct
