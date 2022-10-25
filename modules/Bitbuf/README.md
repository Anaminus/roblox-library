# Bitbuf
[Bitbuf]: #bitbuf

Bitbuf implements a bit-level buffer, suitable for serialization and
storing data in-memory.

```lua
-- Create buffer.
local buf = Bitbuf.new(32*6 + 8 + 8*(2^8-1))

-- Encode part data.
buf:WriteFloat(32, part.Position.X)
buf:WriteFloat(32, part.Position.Y)
buf:WriteFloat(32, part.Position.Z)
buf:WriteFloat(32, part.Size.X)
buf:WriteFloat(32, part.Size.Y)
buf:WriteFloat(32, part.Size.Z)
buf:WriteUint(8, #part.Name)
buf:WriteBytes(part.Name)

-- Move cursor to start.
buf:SetIndex(0)

-- Decode part data.
local copy = Instance.new("Part")
copy.Position = Vector3.new(
	buf:ReadFloat(32),
	buf:ReadFloat(32),
	buf:ReadFloat(32)
)
copy.Size = Vector3.new(
	buf:ReadFloat(32),
	buf:ReadFloat(32),
	buf:ReadFloat(32)
)
copy.Name = buf:ReadBytes(buf:ReadUint(8))
```

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Bitbuf][Bitbuf]
	1. [Bitbuf.fromString][Bitbuf.fromString]
	2. [Bitbuf.isBuffer][Bitbuf.isBuffer]
	3. [Bitbuf.new][Bitbuf.new]
2. [Buffer][Buffer]
	1. [Buffer.Fits][Buffer.Fits]
	2. [Buffer.Index][Buffer.Index]
	3. [Buffer.Len][Buffer.Len]
	4. [Buffer.ReadAlign][Buffer.ReadAlign]
	5. [Buffer.ReadBool][Buffer.ReadBool]
	6. [Buffer.ReadByte][Buffer.ReadByte]
	7. [Buffer.ReadBytes][Buffer.ReadBytes]
	8. [Buffer.ReadFixed][Buffer.ReadFixed]
	9. [Buffer.ReadFloat][Buffer.ReadFloat]
	10. [Buffer.ReadInt][Buffer.ReadInt]
	11. [Buffer.ReadPad][Buffer.ReadPad]
	12. [Buffer.ReadUfixed][Buffer.ReadUfixed]
	13. [Buffer.ReadUint][Buffer.ReadUint]
	14. [Buffer.Reset][Buffer.Reset]
	15. [Buffer.SetIndex][Buffer.SetIndex]
	16. [Buffer.SetLen][Buffer.SetLen]
	17. [Buffer.String][Buffer.String]
	18. [Buffer.WriteAlign][Buffer.WriteAlign]
	19. [Buffer.WriteBool][Buffer.WriteBool]
	20. [Buffer.WriteByte][Buffer.WriteByte]
	21. [Buffer.WriteBytes][Buffer.WriteBytes]
	22. [Buffer.WriteFixed][Buffer.WriteFixed]
	23. [Buffer.WriteFloat][Buffer.WriteFloat]
	24. [Buffer.WriteInt][Buffer.WriteInt]
	25. [Buffer.WritePad][Buffer.WritePad]
	26. [Buffer.WriteUfixed][Buffer.WriteUfixed]
	27. [Buffer.WriteUint][Buffer.WriteUint]

</td></tr></tbody>
</table>

## Bitbuf.fromString
[Bitbuf.fromString]: #bitbuffromstring
```
function Bitbuf.fromString(s: string): Buffer
```

fromString returns a Buffer with the contents initialized with the bits
of *s*. The cursor is set to 0.

## Bitbuf.isBuffer
[Bitbuf.isBuffer]: #bitbufisbuffer
```
function Bitbuf.isBuffer(value: any): boolean
```

isBuffer returns whether *value* is a Buffer.

## Bitbuf.new
[Bitbuf.new]: #bitbufnew
```
function Bitbuf.new(size: number?): Buffer
```

new returns a new Buffer *size* bits in length, with the cursor set to
0. Defaults to a zero-length buffer.

# Buffer
[Buffer]: #buffer
```
type Buffer
```

Buffer is a variable-size bit-level buffer with methods for reading and
writing various common types.

The buffer has a cursor to determine where data is read and written, indexed
in bits. Methods that read and write advance the cursor automatically by the
given size. The buffer grows when the cursor moves beyond the length of the
buffer. Bits read past the length of the buffer are returned as zeros.

Bits are written in little-endian.

## Buffer.Fits
[Buffer.Fits]: #bufferfits
```
function Buffer:Fits(size: number): boolean
```

Fits returns whether *size* bits can be read from or written to the
buffer without exceeding its length.

## Buffer.Index
[Buffer.Index]: #bufferindex
```
function Buffer:Index(): number
```

Index returns the position of the cursor, in bits.

## Buffer.Len
[Buffer.Len]: #bufferlen
```
function Buffer:Len(): number
```

Len returns the length of the buffer in bits.

## Buffer.ReadAlign
[Buffer.ReadAlign]: #bufferreadalign
```
function Buffer:ReadAlign(size: number)
```

ReadAlign moves the cursor until its position is a multiple of *size*
without reading any data. Does nothing if *size* is less than or equal to 1.

## Buffer.ReadBool
[Buffer.ReadBool]: #bufferreadbool
```
function Buffer:ReadBool(): boolean
```

ReadBool reads one bit and returns false if the bit is 0, or true if the
bit is 1.

## Buffer.ReadByte
[Buffer.ReadByte]: #bufferreadbyte
```
function Buffer:ReadByte(): (v: number)
```

ReadByte is shorthand for `Buffer:ReadUint(8, v)`.

## Buffer.ReadBytes
[Buffer.ReadBytes]: #bufferreadbytes
```
function Buffer:ReadBytes(size: number): (v: string)
```

ReadBytes reads *size* bytes from the buffer as a raw sequence of bytes.

## Buffer.ReadFixed
[Buffer.ReadFixed]: #bufferreadfixed
```
function Buffer:ReadFixed(i: number, f: number): (v: number)
```

ReadFixed reads a signed fixed-point number. *i* is the number of bits
used for the integer portion, and *f* is the number of bits used for the
fractional portion. Their combined size must be between 0 and 53.

## Buffer.ReadFloat
[Buffer.ReadFloat]: #bufferreadfloat
```
function Buffer:ReadFloat(size: number): (v: number)
```

ReadFloat reads a floating-point number. Throws an error if *size* is
not one of the following values:

- `32`: IEEE 754 binary32
- `64`: IEEE 754 binary64

## Buffer.ReadInt
[Buffer.ReadInt]: #bufferreadint
```
function Buffer:ReadInt(size: number): (v: number)
```

ReadInt reads *size* bits as a signed integer. *size* must be an integer
between 0 and 53.

## Buffer.ReadPad
[Buffer.ReadPad]: #bufferreadpad
```
function Buffer:ReadPad(size: number)
```

ReadPad moves the cursor by *size* bits without reading any data. Does
nothing if *size* is less than or equal to zero.

## Buffer.ReadUfixed
[Buffer.ReadUfixed]: #bufferreadufixed
```
function Buffer:ReadUfixed(i: number, f: number): (v: number)
```

ReadUfixed reads an unsigned fixed-point number. *i* is the number of
bits used for the integer portion, and *f* is the number of bits used for the
fractional portion. Their combined size must be between 0 and 53.

## Buffer.ReadUint
[Buffer.ReadUint]: #bufferreaduint
```
function Buffer:ReadUint(size: number): (v: number)
```

ReadUint reads *size* bits as an unsigned integer. *size* must be an
integer between 0 and 53.

## Buffer.Reset
[Buffer.Reset]: #bufferreset
```
function Buffer:Reset()
```

Reset clears the buffer, setting the length and cursor to 0.

## Buffer.SetIndex
[Buffer.SetIndex]: #buffersetindex
```
function Buffer:SetIndex(i: number)
```

SetIndex sets the position of the cursor to *i*, in bits. If *i* is
greater than the length of the buffer, then buffer is grown to length *i*.

## Buffer.SetLen
[Buffer.SetLen]: #buffersetlen
```
function Buffer:SetLen(size: number)
```

SetLen shrinks or grows the length of the buffer. Shrinking truncates
the buffer, and growing pads the buffer with zeros. If the cursor is greater
than *size*, then it is set to *size*.

## Buffer.String
[Buffer.String]: #bufferstring
```
function Buffer:String(): string
```

String converts the content of the buffer to a string. If the length is
not a multiple of 8, then the result will be padded with zeros until it is.

## Buffer.WriteAlign
[Buffer.WriteAlign]: #bufferwritealign
```
function Buffer:WriteAlign(size: number)
```

WriteAlign pads the buffer with zero bits until the position of the
cursor is a multiple of *size*. Does nothing if *size* is less than or equal
to 1.

## Buffer.WriteBool
[Buffer.WriteBool]: #bufferwritebool
```
function Buffer:WriteBool(v: any?)
```

WriteBool writes a 0 bit if *v* is falsy, or a 1 bit if *v* is truthy.

## Buffer.WriteByte
[Buffer.WriteByte]: #bufferwritebyte
```
function Buffer:WriteByte(v: number)
```

WriteByte is shorthand for `Buffer:WriteUint(8, v)`.

## Buffer.WriteBytes
[Buffer.WriteBytes]: #bufferwritebytes
```
function buffer:WriteBytes(v: string)
```

WriteBytes writes *v* by interpreting it as a raw sequence of bytes.

## Buffer.WriteFixed
[Buffer.WriteFixed]: #bufferwritefixed
```
function Buffer:WriteFixed(i: number, f: number, v: number)
```

WriteFixed writes *v* as a signed fixed-point number. *i* is the number
of bits used for the integer portion, and *f* is the number of bits used for
the fractional portion. Their combined size must be between 0 and 53.

## Buffer.WriteFloat
[Buffer.WriteFloat]: #bufferwritefloat
```
function Buffer:WriteFloat(size: number, v: number)
```

WriteFloat writes *v* as a floating-point number. Throws an error if
*size* is not one of the following values:

- `32`: IEEE 754 binary32
- `64`: IEEE 754 binary64

## Buffer.WriteInt
[Buffer.WriteInt]: #bufferwriteint
```
function Buffer:WriteInt(size: number, v: number)
```

WriteInt writes *v* as a signed integer of *size* bits. *size* must be
an integer between 0 and 53.

## Buffer.WritePad
[Buffer.WritePad]: #bufferwritepad
```
function Buffer:WritePad(size: number)
```

WritePad pads the buffer with *size* zero bits. Does nothing if *size*
is less than or equal to zero.

## Buffer.WriteUfixed
[Buffer.WriteUfixed]: #bufferwriteufixed
```
function Buffer:WriteUfixed(i: number, f: number, v: number)
```

WriteUfixed writes *v* as an unsigned fixed-point number. *i* is the
number of bits used for the integer portion, and *f* is the number of bits
used for the fractional portion. Their combined size must be between 0 and
53.

## Buffer.WriteUint
[Buffer.WriteUint]: #bufferwriteuint
```
function Buffer:WriteUint(size: number, v: number)
```

WriteUint writes *v* as an unsigned integer of *size* bits. *size* must
be an integer between 0 and 53.

