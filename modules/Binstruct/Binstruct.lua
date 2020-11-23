--@sec: Binstruct
--@ord: -1
--@doc: Binstruct encodes and decodes binary structures.

--@sec: TypeDef
--@def: {[1]: string, ...}
--@doc: TypeDef is a table where the first element determines the remaining
-- structure of the table:
--
--     {"_", size: number}
--         Padding. *size* is the number of bits to pad with.
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

local Binstruct = {}

--[[

A Codec is implemented as two lists of instructions, one each for decoding and
encoding. Each data type is implemented as a function that appends instructions
to the lists.

REGISTERS

	Registers hold the state when encoding or decoding, and are modified by
	instructions.

	TAB : The current table.
	KEY : A key indicating a field in TAB.
	STK : A stack that stores tuples of TAB and KEY.
	BUF : A Bitbuf.Buffer to which data is encoded and decoded.

INSTRUCTIONS

	An instruction consists of an op code followed by some number of values. The
	behavior of some instructions are different when encoding versus decoding.

	Decoding
		SET (function)
			Sets TAB[KEY] the result of [1], which receives BUF.
		PSH (function)
			Sets TAB[KEY] to the result of [1], pushes (TAB, KEY) onto STK, then
			sets TAB to the result of [1].
			PSH must be followed directly by FLD or POP.
	Encoding
		SET (function)
			Calls [1], which receives BUF and TAB[KEY].
		PSH ()
			Sets TAB to TAB[KEY] and pushes (TAB, KEY) onto the stack.
			PSH must be followed directly by FLD or POP.
	Both
		FLD (string)
			Sets KEY to [1].
		POP ()
			Pops from STK to set TAB and KEY.

]]

local Bitbuf = require(script.Parent.Bitbuf)

local types = {}
local parseDef

local SET = 0 -- t[k] = v
local PSH = 1 -- t[k] = v; push(t, k); t = t[k]
local FLD = 2 -- k = v
local POP = 3 -- t, k = pop()

function types._(decode, encode, size)
	if size and size > 0 then
		table.insert(decode, {SET, function(buf)
			buf:Pad(size, true)
		end})
		table.insert(encode, {SET, function(buf, v)
			buf:Pad(size)
		end})
	end
end

function types.bool(decode, encode, size)
	if size then
		size -= 1
	else
		size = 0
	end
	if size > 0 then
		table.insert(decode, {SET, function(buf)
			return buf:ReadBool()
		end})
		table.insert(encode, {SET, function(buf, v)
			buf:WriteBool(v)
		end})
		return
	end
	table.insert(decode, {SET, function(buf)
		local v = buf:ReadBool()
		buf:Pad(size)
		return v
	end})
	table.insert(encode, {SET, function(buf, v)
		buf:WriteBool(v)
		buf:Pad(size, false)
	end})
end

function types.uint(decode, encode, size)
	table.insert(decode, {SET, function(buf)
		return buf:ReadUint(size)
	end})
	table.insert(encode, {SET, function(buf, v)
		buf:WriteUint(size, v)
	end})
end

function types.int(decode, encode, size)
	table.insert(decode, {SET, function(buf)
		return buf:ReadInt(size)
	end})
	table.insert(encode, {SET, function(buf, v)
		buf:WriteInt(size, v)
	end})
end

function types.byte(decode, encode)
	table.insert(decode, {SET, function(buf)
		return buf:ReadByte()
	end})
	table.insert(encode, {SET, function(buf, v)
		buf:WriteByte(v)
	end})
end

function types.float(decode, encode, size)
	size = size or 64
	table.insert(decode, {SET, function(buf)
		return buf:ReadFloat(size)
	end})
	table.insert(encode, {SET, function(buf, v)
		buf:WriteFloat(size, v)
	end})
end

function types.ufixed(decode, encode, i, f)
	table.insert(decode, {SET, function(buf)
		return buf:ReadUfixed(i, f)
	end})
	table.insert(encode, {SET, function(buf, v)
		buf:WriteUfixed(i, f, v)
	end})
end

function types.fixed(decode, encode, i, f)
	table.insert(decode, {SET, function(buf)
		return buf:ReadFixed(i, f)
	end})
	table.insert(encode, {SET, function(buf, v)
		buf:WriteFixed(i, f, v)
	end})
end

function types.string(decode, encode, size)
	table.insert(decode, {SET, function(buf)
		local len = buf:ReadUint(size)
		return buf:ReadBytes(len)
	end})
	table.insert(encode, {SET, function(buf, v)
		buf:WriteUint(size, #v)
		buf:WriteBytes(v)
	end})
end

function types.struct(decode, encode, ...)
	table.insert(decode, {PSH, function() return {} end})
	table.insert(encode, {PSH})
	for _, field in ipairs({...}) do
		if type(field) == "table" then
			local name = field[1]
			if type(name) ~= "string" then
				return "first element of field must be a string"
			end
			table.insert(decode, {FLD, name})
			table.insert(encode, {FLD, name})
			local err = parseDef(field[2], decode, encode)
			if err ~= nil then
				return string.format("field %q: %s", name, tostring(err))
			end
		end
	end
	table.insert(decode, {POP})
	table.insert(encode, {POP})
end

function parseDef(def, decode, encode)
	if type(def) ~= "table" then
		return "table expected"
	end
	local name = def[1]
	if type(name) ~= "string" then
		return "first element must be a string"
	end
	local t = types[name]
	if not t then
		return string.format("unknown type %q", tostring(t))
	end
	return t(decode, encode, unpack(def, 2))
end

--@sec: Codec
--@def: type Codec
--@doc: Codec contains instructions for encoding and decoding binary data.
local Codec = {__index={}}

--@sec: Binstruct.new
--@def: Binstruct.new(def: TypeDef): Codec
--@doc: new constructs a Codec from the given definition.
function Binstruct.new(def)
	local decode = {}
	local encode = {}
	local err = parseDef(def, decode, encode)
	if err ~= nil then
		return err, nil
	end

	local self = {
		decode = decode,
		encode = encode,
	}

	return nil, setmetatable(self, Codec)
end

--@sec: Codec.Decode
--@def: Codec:Decode(buffer: string): any
--@doc: Decode decodes a binary string into a value according to the codec.
function Codec.__index:Decode(buffer)
	local buf = Bitbuf.fromString(buffer)

	local tstack = {}
	local kstack = {}

	local tab = {nil}
	local key = 1

	for _, instruction in ipairs(self.decode) do
		local op = instruction[1]
		if op == SET then
			tab[key] = instruction[2](buf)
		elseif op == PSH then
			tab[key] = instruction[2](buf)
			table.insert(tstack, tab)
			table.insert(kstack, key)
			tab = tab[key]
		elseif op == FLD then
			key = instruction[2]
		elseif op == POP then
			tab = table.remove(tstack)
			key = table.remove(kstack)
		end
	end

	return tab[key]
end

--@sec: Codec.Encode
--@def: Codec:Encode(data: any): string
--@doc: Encode encodes a value into a binary string according to the codec.
function Codec.__index:Encode(data)
	local buf = Bitbuf.new()

	local tstack = {}
	local kstack = {}

	local tab = {data}
	local key = 1

	for _, instruction in ipairs(self.encode) do
		local op = instruction[1]
		if op == SET then
			instruction[2](buf, tab[key])
		elseif op == PSH then
			table.insert(tstack, tab)
			table.insert(kstack, key)
			tab = tab[key]
		elseif op == FLD then
			key = instruction[2]
		elseif op == POP then
			tab = table.remove(tstack)
			key = table.remove(kstack)
		end
	end

	return buf:String()
end

return Binstruct
