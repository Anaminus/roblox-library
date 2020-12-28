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
-- - `encode`: A filter that transforms a value before encoding.
-- - `decode`: A filter that transforms a value after decoding.
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
--     {"bool", number?}
--         A boolean. The parameter is the number of bits used to represent the
--         value, defaulting to 1.
--
--     {"int", number}
--         A signed integer. The parameter is the number of bits used to
--         represent the value.
--
--     {"uint", number}
--         An unsigned integer. The parameter is the number of bits used to
--         represent the value.
--
--     {"byte"}
--         Shorthand for `{"uint", 8}`.
--
--     {"float", number?}
--         A floating-point number. The parameter is the number of bits used to
--         represent the value, and must be 32 or 64. Defaults to 64.
--
--     {"fixed", number, number}
--         A signed fixed-point number. The first parameter is the number of
--         bits used to represent the integer part, and the second parameter is
--         the number of bits used to represent the fractional part.
--
--     {"ufixed", number, number}
--         An unsigned fixed-point number. The first parameter is the number of
--         bits used to represent the integer part, and the second parameter is
--         the number of bits used to represent the fractional part.
--
--     {"string", number}
--         A sequence of characters. Encoded as an unsigned integer indicating
--         the length of the string, followed by the raw bytes of the string.
--         The parameter is the number of bits used to represent the length.
--
--     {"struct", ...{string, TypeDef}}
--         A set of named fields. Each parameter is a table defining a field of
--         the struct. The first element of a field definition is the name of
--         the field, and the second element indicate the type of the field.
--
--     {"array", number|string, TypeDef}
--         A list of unnamed fields. The first parameter is the *size* of the
--         array. If *size* is a number, this indicates a constant size. If
--         *size* is a string, it indicates the name of a field in the parent
--         struct from which the size is determined. Evaluates to 0 if this
--         field cannot be determined or is a non-number. The second parameter
--         is the type of each element in the array.

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
	JA    = true,
}

-- Copies registers in *from* to *to*, or a new frame if *to* is unspecified.
-- Returns *to*.
local function copyFrame(from, to)
	to = to or {}
	for k, v in pairs(from) do
		if frameRegisters[k] then
			to[k] = v
		end
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
		R.TABLE[R.KEY] = fn(R.BUFFER)
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
		R.TABLE[R.KEY] = fn(R.BUFFER)
		table.insert(R.STACK, copyFrame(R))
		R.TABLE = R.TABLE[R.KEY]
	end,
	function(R, fn)
		fn(R.BUFFER, R.TABLE[R.KEY])
		table.insert(R.STACK, copyFrame(R))
		R.TABLE = R.TABLE[R.KEY]
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
	function(R, fn)
		local frame = table.remove(R.STACK)
		copyFrame(frame, R)
	end,
	true,
}

-- Initialize a loop with a constant terminator.
Instructions.FORC = {op=6,
	function(R, c)
		R.JA = R.PC
		R.KEY = 1
		R.N = c
	end,
	true,
}

-- Initialize a loop with a dynamic terminator, determined by a field in the
-- parent structure.
Instructions.FORF = {op=7,
	function(R, f)
		R.JA = R.PC
		R.KEY = 1
		local top = R.STACK[#R.STACK]
		if not top then
			R.N = 0
			return
		end
		local parent = top.TABLE
		if not parent then
			R.N = 0
			return
		end
		local v = parent[f]
		if type(v) ~= "number" then
			R.N = 0
			return
		end
		R.N = v
	end,
	true,
}

-- Jump to loop start if KEY is less than N.
Instructions.JMPN = {op=8,
	function(R, fn)
		if R.KEY < R.N then
			R.KEY += 1
			R.PC = R.JA
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
-- instruction column.
local function append(list, opcode, ...)
	table.insert(list, {op = Instructions[opcode].op, n = select("#", ...), ...})
end

local parseDef

Types["pad"] = function(list, decode, encode, size)
	if size and size > 0 then
		append(list, "CALL",
			function(buf)
				buf:Pad(size)
			end,
			function(buf)
				buf:Pad(size, true)
			end
		)
	end
end

Types["align"] = function(list, decode, encode, size)
	if size and size > 0 then
		append(list, "CALL",
			function(buf)
				buf:Align(size)
			end,
			function(buf)
				buf:Align(size, true)
			end
		)
	end
end

Types["bool"] = function(list, decode, encode, size)
	if size then
		size -= 1
	else
		size = 0
	end
	if size > 0 then
		append(list, "SET",
			function(buf)
				local v = buf:ReadBool()
				v = decode(v, size)
				return v
			end,
			function(buf, v)
				v = encode(v, size)
				buf:WriteBool(v)
			end
		)
		return
	end
	append(list, "SET",
		function(buf)
			local v = buf:ReadBool()
			v = decode(v, size)
			buf:Pad(size)
			return v
		end,
		function(buf, v)
			v = encode(v, size)
			buf:WriteBool(v)
			buf:Pad(size, false)
		end
	)
end

Types["uint"] = function(list, decode, encode, size)
	append(list, "SET",
		function(buf)
			local v = buf:ReadUint(size)
			v = decode(v, size)
			return v
		end,
		function(buf, v)
			v = encode(v, size)
			buf:WriteUint(size, v)
		end
	)
end

Types["int"] = function(list, decode, encode, size)
	append(list, "SET",
		function(buf)
			local v = buf:ReadInt(size)
			v = decode(v, size)
			return v
		end,
		function(buf, v)
			v = encode(v, size)
			buf:WriteInt(size, v)
		end
	)
end

Types["byte"] = function(list, decode, encode)
	append(list, "SET",
		function(buf)
			local v = buf:ReadByte()
			v = decode(v)
			return v
		end,
		function(buf, v)
			v = encode(v)
			buf:WriteByte(v)
		end
	)
end

Types["float"] = function(list, decode, encode, size)
	size = size or 64
	append(list, "SET",
		function(buf)
			local v = buf:ReadFloat(size)
			v = decode(v, size)
			return v
		end,
		function(buf, v)
			v = encode(v, size)
			buf:WriteFloat(size, v)
		end
	)
end

Types["ufixed"] = function(list, decode, encode, i, f)
	append(list, "SET",
		function(buf)
			local v = buf:ReadUfixed(i, f)
			v = decode(v, i, f)
			return v
		end,
		function(buf, v)
			v = encode(v, i, f)
			buf:WriteUfixed(i, f, v)
		end
	)
end

Types["fixed"] = function(list, decode, encode, i, f)
	append(list, "SET",
		function(buf)
			local v = buf:ReadFixed(i, f)
			v = decode(v, i, f)
			return v
		end,
		function(buf, v)
			v = encode(v, i, f)
			buf:WriteFixed(i, f, v)
		end
	)
end

Types["string"] = function(list, decode, encode, size)
	append(list, "SET",
		function(buf)
			local len = buf:ReadUint(size)
			local v = buf:ReadBytes(len)
			v = decode(v, size)
			return v
		end,
		function(buf, v)
			v = encode(v, size)
			buf:WriteUint(size, #v)
			buf:WriteBytes(v)
		end
	)
end

Types["struct"] = function(list, decode, encode, ...)
	local fields = table.pack(...)
	append(list, "PUSH",
		function(buf)
			local v = {}
			v = decode(v, table.unpack(fields, 1, fields.n))
			return v
		end,
		function(buf, v)
			v = encode(v, table.unpack(fields, 1, fields.n))
		end
	)
	for i = 1, fields.n do
		local field = fields[i]
		if type(field) == "table" then
			local name = field[1]
			if type(name) ~= "string" then
				return "first element of field must be a string"
			end
			append(list, "FIELD", name, name)
			local err = parseDef(field[2], list)
			if err ~= nil then
				return string.format("field %q: %s", name, tostring(err))
			end
		end
	end
	append(list, "POP", nil, nil)
end

Types["array"] = function(list, decode, encode, size, typ)
	append(list, "PUSH",
		function(buf)
			local v = {}
			v = decode(v, size, typ)
			return v
		end,
		function(buf, v)
			v = encode(v, size, typ)
		end
	)
	if type(size) == "number" then
		append(list, "FORC", size, size)
	else
		append(list, "FORF", size, size)
	end
	local err = parseDef(typ, list)
	if err ~= nil then
		return string.format("array[%s]: %s", tostring(size), tostring(err))
	end
	append(list, "JMPN", nil, nil)
	append(list, "POP", nil, nil)
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

local function nop(v) return v end
function parseDef(def, list)
	if type(def) ~= "table" then
		return "table expected"
	end
	local name = def[1]
	local t = Types[name]
	if not t then
		return string.format("unknown type %q", tostring(t))
	end
	if def.decode ~= nil and type(def.decode) ~= "function" then
		return "decode filter must be a function"
	end
	if def.encode ~= nil and type(def.encode) ~= "function" then
		return "encode filter must be a function"
	end
	local decode = def.decode or nop
	local encode = def.encode or nop
	return t(list, decode, encode, unpack(def, 2))
end

--@sec: Codec
--@def: type Codec
--@doc: Codec contains instructions for encoding and decoding binary data.
local Codec = {__index={}}

--@sec: Binstruct.new
--@def: Binstruct.new(def: TypeDef): Codec
--@doc: new constructs a Codec from the given definition.
function Binstruct.new(def)
	local list = {}
	local err = parseDef(def, list)
	if err ~= nil then
		return err, nil
	end
	local self = {list = list}
	return nil, setmetatable(self, Codec)
end

-- Executes the instructions in *list*. *k* selects the instruction argument
-- column. *buffer* is the bit buffer to use. *data* is the data on which to
-- operate.
local function execute(list, k, buffer, data)
	local PN = #list

	-- Registers.
	local R = {
		PC = 1,          -- Program counter.
		BUFFER = buffer, -- Bit buffer.
		STACK = {},      -- Stores frames.
		TABLE = {data},  -- The working table.
		KEY = 1,         -- A key pointing to a field in TABLE.
		N = 0,           -- Maximum counter value.
		JA = 0,          -- Jump address.
	}

	while R.PC <= PN do
		local inst = list[R.PC]
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
	return execute(self.list, 1, buf, nil)
end

--@sec: Codec.Encode
--@def: Codec:Encode(data: any): string
--@doc: Encode encodes a value into a binary string according to the codec.
function Codec.__index:Encode(data)
	local buf = Bitbuf.new()
	execute(self.list, 2, buf, data)
	return buf:String()
end

local function formatArg(arg)
	if arg == nil then
		return "nil"
	elseif type(arg) == "function" then
		return "<f>"
	elseif type(arg) == "string" then
		return string.format("%q", arg)
	end
	return tostring(arg)
end

-- Prints a human-readable representation of the instructions of the codec.
function Codec.__index:Dump()
	local s = {}
	local width = {}
	for addr, inst in ipairs(self.list) do
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
	local fmt = "%0" .. math.ceil(math.log(#self.list+1, 16)) .. "X: %-" .. width[0] .. "s ( "
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
