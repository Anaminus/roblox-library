# Bitbuf
[Bitbuf]: #user-content-bitbuf

Bitbuf implements a bit-level buffer, suitable for serialization and
storing data in-memory.

## Bitbuf.fromString
[Bitbuf.fromString]: #user-content-bitbuffromstring
```
function Bitbuf.fromString(s: string): Buffer
```

fromString returns a Buffer with the contents initialized with the bits
of *s*.

## Bitbuf.new
[Bitbuf.new]: #user-content-bitbufnew
```
function Bitbuf.new(size: number?): Buffer
```

new returns a new Buffer *size* bits in length. Defaults to a
zero-length buffer.

# Buffer
[Buffer]: #user-content-buffer
```
type Buffer
```

Buffer is a variable-size bit buffer with methods for reading and
writing various common types.

The buffer has a cursor, or index, to determine where data is read and
written. Methods that read and write advance the cursor automatically by the
given size. The buffer grows when the cursor moves beyond the length of the
buffer. Bits read past the length of the buffer are returned as zeros.

Bits are written in little-endian.

## Buffer.Align
[Buffer.Align]: #user-content-bufferalign
```
function Buffer:Align(size: number)
```

Align writes zero bits until the position of the cursor is a multiple of
*size*. Does nothing if *size* is less than or equal to 1.

## Buffer.Fits
[Buffer.Fits]: #user-content-bufferfits
```
function Buffer:Fits(size: number): boolean
```

Fits returns whether *size* bits can be read from or written to the
buffer without exceeding its length.

## Buffer.Index
[Buffer.Index]: #user-content-bufferindex
```
function Buffer:Index(): number
```

Index returns the position of the cursor, in bits.

## Buffer.Len
[Buffer.Len]: #user-content-bufferlen
```
function Buffer:Len(): number
```

Len returns the length of the buffer in bits.

## Buffer.Pad
[Buffer.Pad]: #user-content-bufferpad
```
function Buffer:Pad(size: number)
```

Pad pads the buffer with *size* zero bits. Does nothing if *size* is
less than or equal to zero.

## Buffer.ReadBool
[Buffer.ReadBool]: #user-content-bufferreadbool
```
function Buffer:ReadBool(): boolean
```

ReadBool reads one bit and returns false if the bit is 0, or true if the
bit is 1.

## Buffer.ReadByte
[Buffer.ReadByte]: #user-content-bufferreadbyte
```
function Buffer:ReadByte(): (v: number)
```

ReadByte is shorthand for `Buffer:ReadUint(8, v)`.

## Buffer.ReadBytes
[Buffer.ReadBytes]: #user-content-bufferreadbytes
```
function Buffer:ReadBytes(size: number): (v: string)
```

ReadBytes reads *size* bytes from the buffer as a raw sequence of bytes.

## Buffer.ReadFixed
[Buffer.ReadFixed]: #user-content-bufferreadfixed
```
function Buffer:ReadFixed(i: number, f: number): (v: number)
```

ReadFixed reads a signed fixed-point number. *i* is the number of bits
used for the integer portion, and *f* is the number of bits used for the
fractional portion. Their combined size must be in the range [0, 53].

## Buffer.ReadFloat
[Buffer.ReadFloat]: #user-content-bufferreadfloat
```
function Buffer:ReadFloat(size: number): (v: number)
```

ReadFloat reads a floating-point number. Throws an error if *size* is
not one of the following values:

- `32`: IEEE 754 binary32
- `64`: IEEE 754 binary64

## Buffer.ReadInt
[Buffer.ReadInt]: #user-content-bufferreadint
```
function Buffer:ReadInt(size: number): (v: number)
```

ReadInt reads *size* bits as a signed integer. *size* must be an integer
between 0 and 53.

## Buffer.ReadUfixed
[Buffer.ReadUfixed]: #user-content-bufferreadufixed
```
function Buffer:ReadUfixed(i: number, f: number): (v: number)
```

ReadUfixed reads an unsigned fixed-point number. *i* is the number of
bits used for the integer portion, and *f* is the number of bits used for the
fractional portion. Their combined size must be in the range [0, 53].

## Buffer.ReadUint
[Buffer.ReadUint]: #user-content-bufferreaduint
```
function Buffer:ReadUint(size: number): (v: number)
```

ReadUint reads *size* bits as an unsigned integer. *size* must be an
integer between 0 and 53.

## Buffer.Reset
[Buffer.Reset]: #user-content-bufferreset
```
function Buffer:Reset()
```

Reset clears the buffer, setting the length and cursor to 0.

## Buffer.SetIndex
[Buffer.SetIndex]: #user-content-buffersetindex
```
function Buffer:SetIndex(i: number)
```

SetIndex sets the position of the cursor to *i*, in bits. If *i* is
greater than the length of the buffer, then buffer is grown to length *i*.

## Buffer.SetLen
[Buffer.SetLen]: #user-content-buffersetlen
```
function Buffer:SetLen(size: number)
```

SetLen shrinks or grows the length of the buffer. Shrinking truncates
the buffer, and growing pads the buffer with zeros. If the cursor is greater
than *size*, then it is set to *size*.

## Buffer.String
[Buffer.String]: #user-content-bufferstring
```
function Buffer:String(): string
```

String converts the content of the buffer to a string. If the length is
not a multiple of 8, then the result will be padded with zeros until it is.

## Buffer.WriteBool
[Buffer.WriteBool]: #user-content-bufferwritebool
```
function Buffer:WriteBool(v: any?)
```

WriteBool writes a 0 bit if *v* is falsy, or a 1 bit if *v* is truthy.

## Buffer.WriteByte
[Buffer.WriteByte]: #user-content-bufferwritebyte
```
function Buffer:WriteByte(v: number)
```

WriteByte is shorthand for `Buffer:WriteUint(8, v)`.

## Buffer.WriteBytes
[Buffer.WriteBytes]: #user-content-bufferwritebytes
```
function buffer:WriteBytes(v: string)
```

WriteBytes writes *v* by interpreting it as a raw sequence of bytes.

## Buffer.WriteFixed
[Buffer.WriteFixed]: #user-content-bufferwritefixed
```
function Buffer:WriteFixed(i: number, f: number, v: number)
```

WriteFixed writes *v* as a signed fixed-point number. *i* is the number
of bits used for the integer portion, and *f* is the number of bits used for
the fractional portion. Their combined size must be in the range [0, 53].

## Buffer.WriteFloat
[Buffer.WriteFloat]: #user-content-bufferwritefloat
```
function Buffer:WriteFloat(size: number, v: number)
```

WriteFloat writes *v* as a floating-point number. Throws an error if
*size* is not one of the following values:

- `32`: IEEE 754 binary32
- `64`: IEEE 754 binary64

## Buffer.WriteInt
[Buffer.WriteInt]: #user-content-bufferwriteint
```
function Buffer:WriteInt(size: number, v: number)
```

WriteInt writes *v* as a signed integer of *size* bits. *size* must be
an integer between 0 and 53.

## Buffer.WriteUfixed
[Buffer.WriteUfixed]: #user-content-bufferwriteufixed
```
function Buffer:WriteUfixed(i: number, f: number, v: number)
```

WriteUfixed writes *v* as an unsigned fixed-point number. *i* is the
number of bits used for the integer portion, and *f* is the number of bits
used for the fractional portion. Their combined size must be in the range [0,
53].

## Buffer.WriteUint
[Buffer.WriteUint]: #user-content-bufferwriteuint
```
function Buffer:WriteUint(size: number, v: number)
```

WriteUint writes *v* as an unsigned integer of *size* bits. *size* must
be an integer between 0 and 53.

