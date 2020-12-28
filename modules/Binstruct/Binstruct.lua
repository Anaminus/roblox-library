--@sec: Binstruct
--@ord: -1
--@doc: Binstruct encodes and decodes binary structures.
--
-- Example:
-- ```lua
-- local vector3 = {"struct",
-- 	{"X" , {"fixed", 4, 4}},
-- 	{"Y" , {"fixed", 4, 4}},
-- 	{"Z" , {"fixed", 4, 4}},
-- }
--
-- local rotation = {"struct",
-- 	{"X" , {"uint", 5}},
-- 	{"Y" , {"uint", 5}},
-- 	{"Z" , {"uint", 5}},
-- 	{"_" , 1},
-- }
--
-- local brick = {"struct",
-- 	{"Position"     , vector3},
-- 	{"Rotation"     , rotation},
-- 	{"Size"         , vector3},
-- 	{"Color"        , {"byte"}},
-- 	{"Reflectance"  , {"uint", 4}},
-- 	{"Transparency" , {"uint", 4}},
-- 	{"CanCollide"   , {"bool"}},
-- 	{"Shape"        , {"uint", 3}},
-- 	{"_"            , {"_", 4}},
-- 	{"Material"     , {"uint", 6}},
-- 	{"_"            , {"_", 2}},
-- }
--
-- local codec = Binstruct.new(brick)
--```

--@sec: TypeDef
--@def: type TypeDef = {[1]: string, ...}
--@doc: TypeDef is a table where the first element determines the remaining
-- structure of the table:
--
--     {"_", size: number}
--         Padding. *size* is the number of bits to pad with.
--
--     {"align", size: number}
--         Pad until the buffer is aligned to *size* bits.
--
--     {"bool", size: number?}
--         A boolean. *size* is the number of bits used to represent the value,
--         defaulting to 1.
--
--     {"int", size: number
--         A signed integer. *size* is the number of bits used to represent the
--         value.
--
--     {"uint", size: number}
--         An unsigned integer. *size* is the number of bits used to represent
--         the value.
--
--     {"byte"}
--         Shorthand for `{"uint", 8}`.
--
--     {"float", size: number?}
--         A floating-point number. *size* is the number of bits used to represent
--         the value, and must be 32 or 64. Defaults to 64.
--
--     {"fixed", i: number, f: number}
--         A signed fixed-point number. *i* is the number of bits used to represent
--         the integer part, and *f* is the number of bits used to represent the
--         fractional part.
--
--     {"ufixed", i: number, f: number}
--         An unsigned fixed-point number. *i* is the number of bits used to
--         represent the integer part, and *f* is the number of bits used to
--         represent the fractional part.
--
--     {"string", size: number}
--         A sequence of characters. Encoded as an unsigned integer indicating the
--         length of the string, followed by the raw bytes of the string. *size* is
--         the number of bits used to represent the length.
--
--     {"struct", ...{[1]: string, [2]: TypeDef}}
--         A set of named fields. Each element is a table indicating a field of the
--         struct. The first element of a field is the name, and the second element
--         is a TypeDef.
--
--     {"array", size: number|string, type: TypeDef}
--         A list of unnamed fields. *size* indicates the size of the array. If
--         *size* is a number, this indicates a constant size. If *size* is a
--         string, it indicates the name of a field in the parent struct from
--         which the size is determined. Evaluates to 0 if the field cannot be
--         determined or is a non-number.

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

Types["_"] = function(list, size)
	if size and size > 0 then
		append(list, "CALL",
			function(buf) buf:Pad(size) end,
			function(buf) buf:Pad(size, true) end
		)
	end
end

Types["align"] = function(list, size)
	if size and size > 0 then
		append(list, "CALL",
			function(buf) buf:Align(size) end,
			function(buf) buf:Align(size, true) end
		)
	end
end

Types["bool"] = function(list, size)
	if size then
		size -= 1
	else
		size = 0
	end
	if size > 0 then
		append(list, "SET",
			function(buf) return buf:ReadBool() end,
			function(buf, v) buf:WriteBool(v) end
		)
		return
	end
	append(list, "SET",
		function(buf) local v = buf:ReadBool(); buf:Pad(size); return v end,
		function(buf, v) buf:WriteBool(v); buf:Pad(size, false) end
	)
end

Types["uint"] = function(list, size)
	append(list, "SET",
		function(buf) return buf:ReadUint(size) end,
		function(buf, v) buf:WriteUint(size, v) end
	)
end

Types["int"] = function(list, size)
	append(list, "SET",
		function(buf) return buf:ReadInt(size) end,
		function(buf, v) buf:WriteInt(size, v) end
	)
end

Types["byte"] = function(list)
	append(list, "SET",
		function(buf) return buf:ReadByte() end,
		function(buf, v) buf:WriteByte(v) end
	)
end

Types["float"] = function(list, size)
	size = size or 64
	append(list, "SET",
		function(buf) return buf:ReadFloat(size) end,
		function(buf, v) buf:WriteFloat(size, v) end
	)
end

Types["ufixed"] = function(list, i, f)
	append(list, "SET",
		function(buf) return buf:ReadUfixed(i, f) end,
		function(buf, v) buf:WriteUfixed(i, f, v) end
	)
end

Types["fixed"] = function(list, i, f)
	append(list, "SET",
		function(buf) return buf:ReadFixed(i, f) end,
		function(buf, v) buf:WriteFixed(i, f, v) end
	)
end

Types["string"] = function(list, size)
	append(list, "SET",
		function(buf) local len = buf:ReadUint(size); return buf:ReadBytes(len) end,
		function(buf, v) buf:WriteUint(size, #v); buf:WriteBytes(v) end
	)
end

Types["struct"] = function(list, ...)
	append(list, "PUSH", function() return {} end, nil)
	for _, field in ipairs({...}) do
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

Types["array"] = function(list, size, typ)
	append(list, "PUSH", function() return {} end, nil)
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

function parseDef(def, list)
	if type(def) ~= "table" then
		return "table expected"
	end
	local name = def[1]
	local t = Types[name]
	if not t then
		return string.format("unknown type %q", tostring(t))
	end
	return t(list, unpack(def, 2))
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
