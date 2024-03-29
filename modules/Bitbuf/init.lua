--!strict
--!nolint FunctionUnused

--@sec: Bitbuf
--@ord: -1
--@doc: Bitbuf implements a bit-level buffer, suitable for serialization and
-- storing data in-memory.
--
-- ```lua
-- -- Create buffer.
-- local buf = Bitbuf.new(32*6 + 8 + 8*(2^8-1))
--
-- -- Encode part data.
-- buf:WriteFloat(32, part.Position.X)
-- buf:WriteFloat(32, part.Position.Y)
-- buf:WriteFloat(32, part.Position.Z)
-- buf:WriteFloat(32, part.Size.X)
-- buf:WriteFloat(32, part.Size.Y)
-- buf:WriteFloat(32, part.Size.Z)
-- buf:WriteUint(8, #part.Name)
-- buf:WriteBytes(part.Name)
--
-- -- Move cursor to start.
-- buf:SetIndex(0)
--
-- -- Decode part data.
-- local copy = Instance.new("Part")
-- copy.Position = Vector3.new(
-- 	buf:ReadFloat(32),
-- 	buf:ReadFloat(32),
-- 	buf:ReadFloat(32)
-- )
-- copy.Size = Vector3.new(
-- 	buf:ReadFloat(32),
-- 	buf:ReadFloat(32),
-- 	buf:ReadFloat(32)
-- )
-- copy.Name = buf:ReadBytes(buf:ReadUint(8))
-- ```

local export = {}

-- Returns uint as int of *size* bits.
local function int_from_uint(size: number, v: number): number
	local n = 2^size
	v %= n
	if v >= n/2 then
		return v - n
	end
	return v
end

local function int_to_uint(size: number, v: number): number
	return v % 2^size
end

local function float32_to_uint(v: number): number
	return string.unpack("<I4", string.pack("<f", v))
end

local function float32_from_uint(v: number): number
	return string.unpack("<f", string.pack("<I4", v))
end

local function float64_to_uint(v: number): number
	return string.unpack("<I8", string.pack("<d", v))
end

local function float64_from_uint(v: number): number
	return string.unpack("<d", string.pack("<I8", v))
end

local function float_to_fixed(i: number, f: number, v: number): number
	return int_from_uint(i + f, math.floor(v * 2^f))
end

local function float_from_fixed(i: number, f: number, v: number): number
	return math.floor(int_from_uint(i + f, v)) * 2^-f
end

local function float_to_ufixed(i: number, f: number, v: number): number
	return int_to_uint(i + f, math.floor(v * 2^f))
end

local function float_from_ufixed(i: number, f: number, v: number): number
	return math.floor(int_to_uint(i + f, v)) * 2^-f
end

--@sec: Buffer
--@def: type Buffer
--@doc: Buffer is a variable-size bit-level buffer with methods for reading and
-- writing various common types.
--
-- The buffer has a cursor to determine where data is read and written, indexed
-- in bits. Methods that read and write advance the cursor automatically by the
-- given size. The buffer grows when the cursor moves beyond the length of the
-- buffer. Bits read past the length of the buffer are returned as zeros.
--
-- Bits are written in little-endian.
local Buffer = {__index={}}

export type Buffer = {
	Fits: (self: Buffer, size: number) -> boolean,
	Index: (self: Buffer) -> number,
	Len: (self: Buffer) -> number,
	ReadAlign: (self: Buffer, size: number) -> (),
	ReadBool: (self: Buffer) -> boolean,
	ReadByte: (self: Buffer) -> number,
	ReadBytes: (self: Buffer, size: number) -> string,
	ReadFixed: (self: Buffer, i: number, f: number) -> number,
	ReadFloat: (self: Buffer, size: number) -> number,
	ReadInt: (self: Buffer, size: number) -> number,
	ReadPad: (self: Buffer, size: number) -> (),
	ReadUfixed: (self: Buffer, i: number, f: number) -> number,
	ReadUint: (self: Buffer, size: number) -> number,
	Reset: (self: Buffer) -> (),
	SetIndex: (self: Buffer, i: number) -> (),
	SetLen: (self: Buffer, size: number) -> (),
	String: (self: Buffer) -> string,
	WriteAlign: (self: Buffer, size: number) -> (),
	WriteBool: (self: Buffer, v: any?) -> (),
	WriteByte: (self: Buffer, v: number) -> (),
	WriteBytes: (self: Buffer, v: string) -> (),
	WriteFixed: (self: Buffer, i: number, f: number, v: number) -> (),
	WriteFloat: (self: Buffer, size: number, v: number) -> (),
	WriteInt: (self: Buffer, size: number, v: number) -> (),
	WritePad: (self: Buffer, size: number) -> (),
	WriteUfixed: (self: Buffer, i: number, f: number, v: number) -> (),
	WriteUint: (self: Buffer, size: number, v: number) -> (),
}

type _Buffer = Buffer & {
	buf: {number},
	len: number,
	i: number,
	writeUnit: (self: _Buffer, size: number, v: number) -> (),
	readUnit: (self: _Buffer, size: number) -> number,
}


--@sec: Bitbuf.new
--@def: function Bitbuf.new(size: number?): Buffer
--@doc: new returns a new Buffer *size* bits in length, with the cursor set to
-- 0. Defaults to a zero-length buffer.
function export.new(size: number?): Buffer
	assert(size == nil or type(size) == "number", "number expected")
	size = size or 0
	local self = {
		buf = table.create(math.ceil(size::number/32), 0),
		len = size,
		i = 0,
	}
	return setmetatable(self, Buffer)::any
end

--@sec: Bitbuf.fromString
--@def: function Bitbuf.fromString(s: string): Buffer
--@doc: fromString returns a Buffer with the contents initialized with the bits
-- of *s*. The cursor is set to 0.
function export.fromString(s: string): Buffer
	assert(type(s) == "string", "string expected")
	local n = math.ceil(#s/4)
	local self = {
		buf = table.create(n, 0),
		len = #s*8,
		i = 0,
	}
	for i = 0, math.floor(#s/4)-1 do
		local a, b, c, d = string.byte(s, i*4+1, i*4+4)
		self.buf[i+1] = bit32.bor(a, b*256, c*65536, d*16777216)
	end
	for i = 0, #s%4-1 do
		self.buf[n] = bit32.bor(self.buf[n], string.byte(s, (n-1)*4+i+1)*256^i)
	end
	return setmetatable(self, Buffer)::any
end

--@sec: Buffer.String
--@def: function Buffer:String(): string
--@doc: String converts the content of the buffer to a string. If the length is
-- not a multiple of 8, then the result will be padded with zeros until it is.
function Buffer.__index:String(): string
	self = self::_Buffer
	local n = math.ceil(self.len/32)
	local s = table.create(n, "")
	for i in ipairs(s) do
		local v = self.buf[i]
		if v then
			s[i] = string.pack("<I4", v)
		else
			s[i] = "\0\0\0\0"
		end
	end
	local rem = self.len % 32
	if rem > 0 then
		-- Truncate to length.
		local v = bit32.band(self.buf[n] or 0, bit32.lshift(1, rem)-1)
		local width = math.floor((self.len-1)/8)%4+1
		s[n] = string.pack("<I"..width, v)
	end
	return table.concat(s)
end

--@def: function Buffer:writeUnit(size: number, v: number)
--@doc: writeUnit writes the first *size* bits of the unsigned integer *v* to
-- the buffer, and advances the cursor by *size* bits. *size* must be an integer
-- between 0 and 32. *v* is normalized according to the bit32 library. The
-- capacity of the buffer is extended as needed to write the value.
--
-- The buffer is assumed to be a sequence of 32-bit unsigned integers.
function Buffer.__index:writeUnit(size: number, v: number)
	self = self::_Buffer
	assert(size>=0 and size<=32, "size must be in range [0,32]")
	if size == 0 then
		return
	end
	-- Index of unit in buffer.
	local i = bit32.rshift(self.i, 5) + 1
	-- Index of first unread bit in unit.
	local u = self.i % 32
	if u == 0 and size == 32 then
		self.buf[i] = bit32.band(v, 0xFFFFFFFF)
	else
		-- Index of of unit end relative to first unread bit.
		local f = 32 - u
		local r = size - f
		if r <= 0 then
			-- Size fits within current unit.
			self.buf[i] = bit32.replace(self.buf[i] or 0, v, u, size)
		else
			-- Size extends into next unit.
			self.buf[i] = bit32.replace(self.buf[i] or 0, bit32.extract(v, 0, f), u, f)
			self.buf[i+1] = bit32.replace(self.buf[i+1] or 0, bit32.extract(v, f, r), 0, r)
		end
	end
	self.i += size
	if self.i > self.len then
		self.len = self.i
	end
end

--@def: function Buffer:readUnit(size: number): (v: number)
--@doc: readUnit reads *size* bits as an unsigned integer from the buffer, and
-- advances the cursor by *size* bits. *size* must be an integer between 0 and
-- 32.
--
-- The buffer is assumed to be a sequence of 32-bit unsigned integers. Bits past
-- the length of the buffer are read as zeros.
function Buffer.__index:readUnit(size: number): number
	self = self::_Buffer
	assert(size>=0 and size<=32, "size must be in range [0,32]")
	if size == 0 then
		return 0
	end
	local i = bit32.rshift(self.i, 5) + 1
	local u = self.i % 32
	self.i += size
	if self.i > self.len then
		self.len = self.i
	end
	if u == 0 and size == 32 then
		return self.buf[i] or 0
	end
	local f = 32 - u
	local r = f - size
	if r >= 0 then
		return bit32.extract(self.buf[i] or 0, u, size)
	end
	return bit32.bor(
		bit32.extract(self.buf[i] or 0, u, f),
		bit32.lshift(bit32.extract(self.buf[i+1] or 0, 0, -r), f)
	)
end

--@sec: Buffer.Len
--@def: function Buffer:Len(): number
--@doc: Len returns the length of the buffer in bits.
function Buffer.__index:Len(): number
	self = self::_Buffer
	return self.len
end

--@sec: Buffer.SetLen
--@def: function Buffer:SetLen(size: number)
--@doc: SetLen shrinks or grows the length of the buffer. Shrinking truncates
-- the buffer, and growing pads the buffer with zeros. If the cursor is greater
-- than *size*, then it is set to *size*.
function Buffer.__index:SetLen(size: number)
	self = self::_Buffer
	if size < 0 then
		size = 0
	end
	-- Clear removed portion of buffer.
	if size < self.len then
		local lower = math.floor(size/32)+1
		-- Truncate lower unit.
		if size % 32 == 0 then
			self.buf[lower] = nil
		else
			self.buf[lower] = bit32.band(self.buf[lower], 2^(size%32)-1)
		end
		-- Clear everything after lower unit.
		local upper = math.floor((self.len-1)/32)+1
		for i = lower+1, upper do
			self.buf[i] = nil
		end
	end
	self.len = size
	if self.i > size then
		self.i = size
	end
end

--@sec: Buffer.Index
--@def: function Buffer:Index(): number
--@doc: Index returns the position of the cursor, in bits.
function Buffer.__index:Index(): number
	self = self::_Buffer
	return self.i
end

--@sec: Buffer.SetIndex
--@def: function Buffer:SetIndex(i: number)
--@doc: SetIndex sets the position of the cursor to *i*, in bits. If *i* is
-- greater than the length of the buffer, then buffer is grown to length *i*.
function Buffer.__index:SetIndex(i: number)
	self = self::_Buffer
	if i < 0 then
		i = 0
	end
	self.i = i
	if i > self.len then
		self.len = i
	end
end

--@sec: Buffer.Fits
--@def: function Buffer:Fits(size: number): boolean
--@doc: Fits returns whether *size* bits can be read from or written to the
-- buffer without exceeding its length.
function Buffer.__index:Fits(size: number): boolean
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	return size <= self.len - self.i
end

local function readPad(self: _Buffer, size: number)
	self.i += size
	if self.i > self.len then
		self.len = self.i
	end
end

local function writePad(self: _Buffer, size: number)
	for i = 1, math.floor(size/32) do
		self:writeUnit(32, 0)
	end
	self:writeUnit(size%32, 0)
end

--@sec: Buffer.WritePad
--@def: function Buffer:WritePad(size: number)
--@doc: WritePad pads the buffer with *size* zero bits. Does nothing if *size*
-- is less than or equal to zero.
function Buffer.__index:WritePad(size: number)
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	if size <= 0 then
		return
	end
	writePad(self, size)
end

--@sec: Buffer.ReadPad
--@def: function Buffer:ReadPad(size: number)
--@doc: ReadPad moves the cursor by *size* bits without reading any data. Does
-- nothing if *size* is less than or equal to zero.
function Buffer.__index:ReadPad(size: number)
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	if size <= 0 then
		return
	end
	readPad(self, size)
end

--@sec: Buffer.WriteAlign
--@def: function Buffer:WriteAlign(size: number)
--@doc: WriteAlign pads the buffer with zero bits until the position of the
-- cursor is a multiple of *size*. Does nothing if *size* is less than or equal
-- to 1.
function Buffer.__index:WriteAlign(size: number)
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	if size <= 1 or self.i%size == 0 then
		return
	end
	size = math.floor(math.ceil(self.i/size)*size - self.i)
	writePad(self, size)
end

--@sec: Buffer.ReadAlign
--@def: function Buffer:ReadAlign(size: number)
--@doc: ReadAlign moves the cursor until its position is a multiple of *size*
-- without reading any data. Does nothing if *size* is less than or equal to 1.
function Buffer.__index:ReadAlign(size: number)
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	if size <= 1 or self.i%size == 0 then
		return
	end
	size = math.floor(math.ceil(self.i/size)*size - self.i)
	readPad(self, size)
end

--@sec: Buffer.Reset
--@def: function Buffer:Reset()
--@doc: Reset clears the buffer, setting the length and cursor to 0.
function Buffer.__index:Reset()
	self = self::_Buffer
	self.i = 0
	self.len = 0
	table.clear(self.buf)
end

--@def: function fastWriteBytes(buf: Buffer, s: string)
--@doc: fastWriteBytes writes a raw sequence of bytes by assuming that the
-- buffer is aligned to 8 bits.
local function fastWriteBytes(self: _Buffer, s: string)
	-- Handle short string.
	if #s <= 4 then
		self:writeUnit(#s*8, (string.unpack("<I"..#s, s)))
		return
	end

	-- Write until cursor is aligned to unit.
	local a = math.floor(3-(self.i/8-1)%4)
	if a > 0 then
		self:writeUnit(a*8, (string.unpack("<I"..a, s)))
	end

	-- Write unit-aligned groups of 32 bits.
	local c = math.floor((#s-a)/4)
	local n = bit32.rshift(self.i, 5) + 1
	for i = 0, c-1 do
		self.buf[n+i] = string.unpack("<I4", s, a+i*4+1)
	end
	self.i += c*32
	if self.i > self.len then
		self.len = self.i
	end
	-- Write remainder.
	local r = (#s-a)%4
	if r > 0 then
		self:writeUnit(r*8, string.unpack("<I"..r, s, #s-r+1))
	end
end

--@sec: Buffer.WriteBytes
--@def: function buffer:WriteBytes(v: string)
--@doc: WriteBytes writes *v* by interpreting it as a raw sequence of bytes.
function Buffer.__index:WriteBytes(v: string)
	self = self::_Buffer
	assert(type(v) == "string", "string expected")
	if v == "" then
		return
	end
	if self.i%8 == 0 then
		fastWriteBytes(self, v)
		return
	end
	for i = 1, #v do
		self:writeUnit(8, string.byte(v, i))
	end
end

--@def: function fastReadBytes(buf: Buffer, size: number): (v: string)
--@doc: fastReadBytes reads a raw sequence of bytes by assuming that the buffer
-- is aligned to 8 bits.
local function fastReadBytes(self: _Buffer, size: number): string
	-- Handle short string.
	if size <= 4 then
		return string.pack("<I"..size, self:readUnit(size*8))
	end

	local a = math.floor(3-(self.i/8-1)%4)
	local r = (size-a)%4
	local v = table.create((size-a)/4 + r)
	local i = 1

	-- Read until cursor is aligned to unit.
	if a > 0 then
		v[i] = string.pack("<I"..a, self:readUnit(a*8))
		i += 1
	end

	-- Read unit-aligned groups of 32 bits.
	local c = math.floor((size-a)/4)
	local n = bit32.rshift(self.i, 5) + 1
	for j = 0, c-1 do
		local x = self.buf[n+j]
		if x then
			v[i] = string.pack("<I4", x)
		else
			v[i] = "\0\0\0\0"
		end
			i += 1
	end
	self.i += c*32
	if i > self.len then
		self.len = i
	end
	-- Read remainder.
	if r > 0 then
		v[i] = string.pack("<I"..r, self:readUnit(r*8))
	end

	return table.concat(v)
end

--@sec: Buffer.ReadBytes
--@def: function Buffer:ReadBytes(size: number): (v: string)
--@doc: ReadBytes reads *size* bytes from the buffer as a raw sequence of bytes.
function Buffer.__index:ReadBytes(size: number): string
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	if size == 0 then
		return ""
	end
	if self.i%8 == 0 then
		return fastReadBytes(self, size)
	end
	local v = table.create(size, "")
	for i = 1, size do
		v[i] = string.char(self:readUnit(8))
	end
	return table.concat(v)
end

--@sec: Buffer.WriteUint
--@def: function Buffer:WriteUint(size: number, v: number)
--@doc: WriteUint writes *v* as an unsigned integer of *size* bits. *size* must
-- be an integer between 0 and 53.
function Buffer.__index:WriteUint(size: number, v: number)
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	assert(type(v) == "number", "number expected")
	assert(size>=0 and size<=53, "size must be in range [0,53]")
	if size == 0 then
		return
	elseif size <= 32 then
		self:writeUnit(size, v)
		return
	end
	v %= 2^size
	self:writeUnit(32, v)
	self:writeUnit(size-32, math.floor(v/2^32))
end

--@sec: Buffer.ReadUint
--@def: function Buffer:ReadUint(size: number): (v: number)
--@doc: ReadUint reads *size* bits as an unsigned integer. *size* must be an
-- integer between 0 and 53.
function Buffer.__index:ReadUint(size: number): number
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	assert(size>=0 and size<=53, "size must be in range [0,53]")
	if size == 0 then
		return 0
	elseif size <= 32 then
		return self:readUnit(size)
	end
	return self:readUnit(32) + self:readUnit(size-32)*2^32
end

--@sec: Buffer.WriteBool
--@def: function Buffer:WriteBool(v: any?)
--@doc: WriteBool writes a 0 bit if *v* is falsy, or a 1 bit if *v* is truthy.
function Buffer.__index:WriteBool(v: unknown)
	self = self::_Buffer
	if v then
		self:writeUnit(1, 1)
		return
	end
	self:writeUnit(1, 0)
end

--@sec: Buffer.ReadBool
--@def: function Buffer:ReadBool(): boolean
--@doc: ReadBool reads one bit and returns false if the bit is 0, or true if the
-- bit is 1.
function Buffer.__index:ReadBool(): boolean
	self = self::_Buffer
	return self:readUnit(1) == 1
end

--@sec: Buffer.WriteByte
--@def: function Buffer:WriteByte(v: number)
--@doc: WriteByte is shorthand for `Buffer:WriteUint(8, v)`.
function Buffer.__index:WriteByte(v: number)
	self = self::_Buffer
	assert(type(v) == "number", "number expected")
	self:writeUnit(8, v)
end

--@sec: Buffer.ReadByte
--@def: function Buffer:ReadByte(): (v: number)
--@doc: ReadByte is shorthand for `Buffer:ReadUint(8, v)`.
function Buffer.__index:ReadByte(): number
	self = self::_Buffer
	return self:readUnit(8)
end

--@sec: Buffer.WriteInt
--@def: function Buffer:WriteInt(size: number, v: number)
--@doc: WriteInt writes *v* as a signed integer of *size* bits. *size* must be
-- an integer between 0 and 53.
function Buffer.__index:WriteInt(size: number, v: number)
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	assert(type(v) == "number", "number expected")
	assert(size>=0 and size<=53, "size must be in range [0,53]")
	if size == 0 then
		return
	end
	v = int_to_uint(size, v)
	if size <= 32 then
		self:writeUnit(size, v)
		return
	end
	self:writeUnit(32, v)
	self:writeUnit(size-32, math.floor(v/2^32))
end

--@sec: Buffer.ReadInt
--@def: function Buffer:ReadInt(size: number): (v: number)
--@doc: ReadInt reads *size* bits as a signed integer. *size* must be an integer
-- between 0 and 53.
function Buffer.__index:ReadInt(size: number): number
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	assert(size>=0 and size<=53, "size must be in range [0,53]")
	if size == 0 then
		return 0
	end
	local v
	if size <= 32 then
		v = self:readUnit(size)
	else
		v = self:readUnit(32) + self:readUnit(size-32)*2^32
	end
	return int_from_uint(size, v)
end

--@sec: Buffer.WriteFloat
--@def: function Buffer:WriteFloat(size: number, v: number)
--@doc: WriteFloat writes *v* as a floating-point number. Throws an error if
-- *size* is not one of the following values:
--
-- - `32`: IEEE 754 binary32
-- - `64`: IEEE 754 binary64
function Buffer.__index:WriteFloat(size: number, v: number)
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	assert(type(v) == "number", "number expected")
	assert(size==32 or size==64, "size must be 32 or 64")
	if size == 32 then
		self:WriteBytes(string.pack("<f", v))
	else
		self:WriteBytes(string.pack("<d", v))
	end
end

--@sec: Buffer.ReadFloat
--@def: function Buffer:ReadFloat(size: number): (v: number)
--@doc: ReadFloat reads a floating-point number. Throws an error if *size* is
-- not one of the following values:
--
-- - `32`: IEEE 754 binary32
-- - `64`: IEEE 754 binary64
function Buffer.__index:ReadFloat(size: number): number
	self = self::_Buffer
	assert(type(size) == "number", "number expected")
	assert(size==32 or size==64, "size must be 32 or 64")
	local s = self:ReadBytes(size/8)
	if size == 32 then
		return string.unpack("<f", s)
	else
		return string.unpack("<d", s)
	end
end

--@sec: Buffer.WriteUfixed
--@def: function Buffer:WriteUfixed(i: number, f: number, v: number)
--@doc: WriteUfixed writes *v* as an unsigned fixed-point number. *i* is the
-- number of bits used for the integer portion, and *f* is the number of bits
-- used for the fractional portion. Their combined size must be between 0 and
-- 53.
function Buffer.__index:WriteUfixed(i: number, f: number, v: number)
	self = self::_Buffer
	assert(type(i) == "number", "number expected")
	assert(type(f) == "number", "number expected")
	assert(i>=0, "integer size must be >= 0")
	assert(f>=0, "fractional size must be >= 0")
	assert(i+f<=53, "combined size must be <= 53")
	assert(type(v) == "number", "number expected")
	self:WriteUint(i + f, float_to_ufixed(i, f, v))
end

--@sec: Buffer.ReadUfixed
--@def: function Buffer:ReadUfixed(i: number, f: number): (v: number)
--@doc: ReadUfixed reads an unsigned fixed-point number. *i* is the number of
-- bits used for the integer portion, and *f* is the number of bits used for the
-- fractional portion. Their combined size must be between 0 and 53.
function Buffer.__index:ReadUfixed(i: number, f: number): number
	self = self::_Buffer
	assert(type(i) == "number", "number expected")
	assert(type(f) == "number", "number expected")
	assert(i>=0, "integer size must be >= 0")
	assert(f>=0, "fractional size must be >= 0")
	assert(i+f<=53, "combined size must be <= 53")
	return float_from_ufixed(i, f, self:ReadUint(i + f))
end

--@sec: Buffer.WriteFixed
--@def: function Buffer:WriteFixed(i: number, f: number, v: number)
--@doc: WriteFixed writes *v* as a signed fixed-point number. *i* is the number
-- of bits used for the integer portion, and *f* is the number of bits used for
-- the fractional portion. Their combined size must be between 0 and 53.
function Buffer.__index:WriteFixed(i: number, f: number, v: number)
	self = self::_Buffer
	assert(type(i) == "number", "number expected")
	assert(type(f) == "number", "number expected")
	assert(i>=0, "integer size must be >= 0")
	assert(f>=0, "fractional size must be >= 0")
	assert(i+f<=53, "combined size must be <= 53")
	assert(type(v) == "number", "number expected")
	self:WriteInt(i + f, float_to_fixed(i, f, v))
end

--@sec: Buffer.ReadFixed
--@def: function Buffer:ReadFixed(i: number, f: number): (v: number)
--@doc: ReadFixed reads a signed fixed-point number. *i* is the number of bits
-- used for the integer portion, and *f* is the number of bits used for the
-- fractional portion. Their combined size must be between 0 and 53.
function Buffer.__index:ReadFixed(i: number, f: number): number
	self = self::_Buffer
	assert(type(i) == "number", "number expected")
	assert(type(f) == "number", "number expected")
	assert(i>=0, "integer size must be >= 0")
	assert(f>=0, "fractional size must be >= 0")
	assert(i+f<=53, "combined size must be <= 53")
	return float_from_fixed(i, f, self:ReadInt(i + f))
end

--@sec: Bitbuf.isBuffer
--@def: function Bitbuf.isBuffer(value: any): boolean
--@doc: isBuffer returns whether *value* is a Buffer.
function export.isBuffer(value: any): boolean
	return getmetatable(value) == Buffer
end

return export
