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
--
-- Within a decode filter, only the top-level value is structural; components of
-- the value will have already been transformed (if defined to do so). Likewise,
-- an encode filter should return a value that itself is structural, but
-- contains transformed components as expected by the component's type
-- definition. Each component's definition will eventually transform the
-- component itself, so the outer definition must avoid making transformations
-- on the component.
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
	end,
	function(R, fn)
		-- *fn* must return a structural value to scope into.
		local v = R.TABLE[R.KEY]
		v = fn(R.BUFFER, v)
		table.insert(R.STACK, copyFrame(R))
		R.TABLE = v
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
local function setjump(program, addr)
	local instr = program[addr]
	for i = 1, instr.n do
		instr[i][1] = #program
	end
end

local function nop(v)
	return v
end

local parseDef

Types["pad"] = function(program, def)
	local size = def[1]
	if size and size > 0 then
		append(program, "CALL",
			function(buf)
				buf:Pad(size)
			end,
			function(buf)
				buf:Pad(size, true)
			end
		)
	end
end

Types["align"] = function(program, def)
	local size = def[1]
	if size and size > 0 then
		append(program, "CALL",
			function(buf)
				buf:Align(size)
			end,
			function(buf)
				buf:Align(size, true)
			end
		)
	end
end

Types["const"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local value = def[1]
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
end

Types["bool"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
	if size then
		size -= 1
	else
		size = 0
	end
	if size > 0 then
		append(program, "SET",
			function(buf)
				local v = buf:ReadBool()
				v = dfilter(v, size)
				return v
			end,
			function(buf, v)
				if v == nil then v = false end
				v = efilter(v, size)
				buf:WriteBool(v)
			end
		)
		return
	end
	append(program, "SET",
		function(buf)
			local v = buf:ReadBool()
			v = dfilter(v, size)
			buf:Pad(size)
			return v
		end,
		function(buf, v)
			if v == nil then v = false end
			v = efilter(v, size)
			buf:WriteBool(v)
			buf:Pad(size, false)
		end
	)
end

Types["uint"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
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
end

Types["int"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
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
end

Types["byte"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
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
end

Types["float"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1] or 64
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
end

Types["ufixed"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local i = def[1]
	local f = def[2]
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
end

Types["fixed"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local i = def[1]
	local f = def[2]
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
end

Types["string"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
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
end

Types["struct"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
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
	for i = 1, #def do
		local field = def[i]
		if type(field) == "table" then
			local name = field[1]
			append(program, "FIELD", name, name)
			local err = parseDef(field[2], program)
			if err ~= nil then
				return string.format("field %q: %s", name, tostring(err))
			end
		end
	end
	append(program, "POP", function(v) return dfilter(v, unpack(def, 1, #def)) end, nil)
end

Types["array"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
	local vtype = def[2]
	if size <= 0 then
		-- Array is constantly empty.
		return nil
	end
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
	setjump(program, jumpaddr)
	append(program, "POP", function(v) return dfilter(v, size, vtype) end, nil)
end

Types["vector"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local size = def[1]
	local vtype = def[2]
	if size == nil then
		return "vector size cannot be nil"
	end
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
	setjump(program, jumpaddr)
	append(program, "POP", function(v) return dfilter(v, size, vtype) end, nil)
end

Types["instance"] = function(program, def)
	local dfilter = def.decode or nop
	local efilter = def.encode or nop
	local class = def[1]
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
		return "table expected"
	end
	local name = def[1]
	local t = Types[name]
	if not t then
		return string.format("unknown type %q", tostring(name))
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
--@def: Binstruct.new(def: TypeDef): Codec
--@doc: new constructs a Codec from the given definition.
function Binstruct.new(def)
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
		STACK = {},      -- Stores frames.
		TABLE = {data},  -- The working table.
		KEY = 1,         -- A key pointing to a field in TABLE.
		N = 0,           -- Maximum counter value.
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
function Codec.__index:Decode(buffer)
	local buf = Bitbuf.fromString(buffer)
	return execute(self.program, 1, buf, nil)
end

--@sec: Codec.Encode
--@def: Codec:Encode(data: any): string
--@doc: Encode encodes a value into a binary string according to the codec.
function Codec.__index:Encode(data)
	local buf = Bitbuf.new()
	execute(self.program, 2, buf, data)
	return buf:String()
end

local function formatArg(arg)
	if type(arg) == "function" then
		return "<f>"
	elseif type(arg) == "string" then
		return string.format("%q", arg)
	elseif type(arg) == "table" then
		return "{"..table.concat(arg, ", ").."}"
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
