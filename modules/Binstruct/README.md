# Binstruct
[Binstruct]: #binstruct

Binstruct encodes and decodes binary structures.

Example:
```lua
local Binstruct = require(script.Parent.Binstruct)
local z = Binstruct

local Float = z.float(32)
local String = z.str(8)
local Vector3 = z.struct(
    "X" , Float,
    "Y" , Float,
    "Z" , Float
)
local CFrame = z.struct(
    "Position" , Vector3,
    "Rotation" , z.array(9, Float)
)
local brick = z.struct(
    "Name"         , String,
    "CFrame"       , CFrame,
    "Size"         , Vector3,
    "Color"        , z.byte(),
    "Reflectance"  , z.uint(4),
    "Transparency" , z.uint(4),
    "CanCollide"   , z.bool(),
    "Shape"        , z.uint(3),
    "_"            , z.pad(4),
    "Material"     , z.uint(6),
    "_"            , z.pad(2)
)

local err, codec = Binstruct.new(brick)
if err ~= nil then
    error(err)
end
print(codec:Decode("\8"..string.rep("A", 73)))
-- {
--     ["CFrame"] = {
--         ["Position"] = {
--             ["X"] = 12.078,
--             ["Y"] = 12.078,
--             ["Z"] = 12.078
--         },
--         ["Rotation"] = {
--             [1] = 12.078,
--             [2] = 12.078,
--             [3] = 12.078,
--             [4] = 12.078,
--             [5] = 12.078,
--             [6] = 12.078,
--             [7] = 12.078,
--             [8] = 12.078,
--             [9] = 12.078
--         }
--     },
--     ["CanCollide"] = true,
--     ["Color"] = 65,
--     ["Material"] = 1,
--     ["Name"] = "AAAAAAAA",
--     ["Reflectance"] = 1,
--     ["Shape"] = 0,
--     ["Size"] = {
--         ["X"] = 12.078,
--         ["Y"] = 12.078,
--         ["Z"] = 12.078
--     },
--     ["Transparency"] = 4
-- }
```

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Binstruct][Binstruct]
	1. [Binstruct.compile][Binstruct.compile]
	2. [Binstruct.align][Binstruct.align]
	3. [Binstruct.array][Binstruct.array]
	4. [Binstruct.bool][Binstruct.bool]
	5. [Binstruct.byte][Binstruct.byte]
	6. [Binstruct.const][Binstruct.const]
	7. [Binstruct.fixed][Binstruct.fixed]
	8. [Binstruct.float][Binstruct.float]
	9. [Binstruct.instance][Binstruct.instance]
	10. [Binstruct.int][Binstruct.int]
	11. [Binstruct.pad][Binstruct.pad]
	12. [Binstruct.ptr][Binstruct.ptr]
	13. [Binstruct.str][Binstruct.str]
	14. [Binstruct.struct][Binstruct.struct]
	15. [Binstruct.ufixed][Binstruct.ufixed]
	16. [Binstruct.uint][Binstruct.uint]
	17. [Binstruct.union][Binstruct.union]
	18. [Binstruct.vector][Binstruct.vector]
2. [Codec][Codec]
	1. [Codec.Decode][Codec.Decode]
	2. [Codec.DecodeBuffer][Codec.DecodeBuffer]
	3. [Codec.Encode][Codec.Encode]
	4. [Codec.EncodeBuffer][Codec.EncodeBuffer]
3. [Calc][Calc]
4. [Clause][Clause]
5. [Expr][Expr]
6. [Field][Field]
7. [Filter][Filter]
8. [FilterFunc][FilterFunc]
9. [FilterTable][FilterTable]
10. [Hook][Hook]
11. [TypeDef][TypeDef]
12. [TypeDefBase][TypeDefBase]
13. [align][align]
14. [array][array]
15. [bool][bool]
16. [byte][byte]
17. [const][const]
18. [fixed][fixed]
19. [float][float]
20. [instance][instance]
21. [int][int]
22. [pad][pad]
23. [ptr][ptr]
24. [str][str]
25. [struct][struct]
26. [ufixed][ufixed]
27. [uint][uint]
28. [union][union]
29. [vector][vector]

</td></tr></tbody>
</table>

## Binstruct.compile
[Binstruct.compile]: #binstructcompile
```
Binstruct.compile(def: TypeDef): (err: error, codec: Codec)
```

Returns a [Codec][Codec] compiled from the given definition.

## Binstruct.align
[Binstruct.align]: #binstructalign
```
Binstruct.align(size: number): align
```

Constructs an [align][align] that aligns to *size* bits.

## Binstruct.array
[Binstruct.array]: #binstructarray
```
Binstruct.array(size: number|TypeDef, value: TypeDef): array
```

Constructs an [array][array] of *size* elements of type *value*.

## Binstruct.bool
[Binstruct.bool]: #binstructbool
```
Binstruct.bool(size: number?): bool
```

Constructs a [bool][bool] of *size* bits, defaulting to 1.

## Binstruct.byte
[Binstruct.byte]: #binstructbyte
```
Binstruct.byte(): byte
```

Constructs a [byte][byte].

## Binstruct.const
[Binstruct.const]: #binstructconst
```
Binstruct.const(value: any?): const
```

Constructs a [const][const] with *value*.

## Binstruct.fixed
[Binstruct.fixed]: #binstructfixed
```
Binstruct.fixed(i: number, f: number): fixed
```

Constructs a [fixed][fixed] of *i* bits for the integer part, and *f*
bits for the fractional part.

## Binstruct.float
[Binstruct.float]: #binstructfloat
```
Binstruct.float(size: number): float
```

Constructs a [float][float] of *size* bits.

## Binstruct.instance
[Binstruct.instance]: #binstructinstance
```
Binstruct.instance(class: string, ...: any): instance
```

Constructs an [instance][instance] of the given class with properties
defined by the remaining arguments. Arguments form key-value pairs to set the
"properties" of the instance, where the key sets the "key" of a
[Field][Field], and the value sets the "value" of the field.

## Binstruct.int
[Binstruct.int]: #binstructint
```
Binstruct.int(size: number): int
```

Constructs an [int][int] of *size* bits.

## Binstruct.pad
[Binstruct.pad]: #binstructpad
```
Binstruct.pad(size: number): pad
```

Constructs a [pad][pad] of *size* bits.

## Binstruct.ptr
[Binstruct.ptr]: #binstructptr
```
Binstruct.ptr(value: TypeDef?): ptr
```

Constructs a [ptr][ptr] that points to *value*.

## Binstruct.str
[Binstruct.str]: #binstructstr
```
Binstruct.str(size: number): str
```

Constructs a [str][str] with a length occupying *size* bits.

## Binstruct.struct
[Binstruct.struct]: #binstructstruct
```
Binstruct.struct(...: any): struct
```

Constructs a [struct][struct] out of the arguments. Arguments form
key-value pairs to set the "fields" of the struct, where the key sets the
"key" of a [Field][Field], and the value sets the "value" of the field.

## Binstruct.ufixed
[Binstruct.ufixed]: #binstructufixed
```
Binstruct.ufixed(i: number, f: number): ufixed
```

Constructs a [ufixed][ufixed] with *i* bits for the integer part, and
*f* bits for the fractional part.

## Binstruct.uint
[Binstruct.uint]: #binstructuint
```
Binstruct.uint(size: number): uint
```

Constructs a [uint][uint] of *size* bits.

## Binstruct.union
[Binstruct.union]: #binstructunion
```
Binstruct.union(...any): union
```

Constructs a [union][union] where each pair of arguments forms a
[Clause][Clause]. The first in a pair sets the "expr" field, while the second
sets the "value" field.

## Binstruct.vector
[Binstruct.vector]: #binstructvector
```
Binstruct.vector(size: any, value: TypeDef, level: number?): vector
```

Constructs a [vector][vector] that uses *size* as the "size", *value* as
the "value", and *level* as the "level".

# Codec
[Codec]: #codec
```
type Codec
```

Codec contains instructions for encoding and decoding binary data.

## Codec.Decode
[Codec.Decode]: #codecdecode
```
Codec:Decode(buffer: string): (error, any)
```

Decode decodes a binary string into a value according to the codec.
Returns the decoded value.

## Codec.DecodeBuffer
[Codec.DecodeBuffer]: #codecdecodebuffer
```
Codec:DecodeBuffer(buffer: Buffer): (error, any)
```

DecodeBuffer decodes a binary string into a value according to the
codec. *buffer* is the buffer to read from. Returns the decoded value.

## Codec.Encode
[Codec.Encode]: #codecencode
```
Codec:Encode(data: any): (error, string)
```

Encode encodes a value into a binary string according to the codec.
Returns the encoded string.

## Codec.EncodeBuffer
[Codec.EncodeBuffer]: #codecencodebuffer
```
Codec:EncodeBuffer(data: any, buffer: Buffer?): (error, Buffer)
```

EncodeBuffer encodes a value into a binary string according to the
codec. *buffer* is an optional Buffer to write to. Returns the Buffer with
the written data.

# Calc
[Calc]: #calc
```
type Calc = (stack: (level: number)->any, global: table) -> (number, error?)
```

Calc is used to calculate the length of a value dynamically.

*stack* is used to index structures in the stack. *level* determines how far
down to index the stack. level 0 returns the current structure. Returns nil
if *level* is out of bounds.

*global* is the global table. This can be used to compare against globally
assigned values.

# Clause
[Clause]: #clause
```
type Clause = {expr: Expr|true, value: TypeDef?, global: any?}
```

One element of a [union][union].

When traversing a union, each *expr* is evaluated in the same way as an
if-statement: the first clause that evaluates to true is selected. Specifying
`true` as *expr* is similar to an "else" clause.

If the clause is selected, then *value* is used as the value. *global*
behaves the same as in [TypeDefBase][TypeDefBase].

# Expr
[Expr]: #expr
```
type Expr = (stack: (level: number)->any, global: table) -> (boolean, error?)
```

Expr is used to evaluate the clause of a union. It is similar to
[Hook][Hook].

*stack* is used to index structures in the stack. *level* determines how far
down to index the stack. level 0 returns the current structure. Returns nil
if *level* is out of bounds.

*global* is the global table. This can be used to compare against globally
assigned values.

# Field
[Field]: #field
```
{key: any?, value: TypeDef, hook: Hook?, global: any?}
```

Defines the field of a struct or property of an instance.

*key* is the key used to index the field. If nil, the value will be
processed, but the field will not be assigned to when decoding. When
encoding, a `nil` value will be received, causing the zero value for the
field's type to be used.

*value* is the type of the field.

*hook* and *global* behave the same as in [TypeDefBase][TypeDefBase].

# Filter
[Filter]: #filter
```
type Filter = FilterFunc | FilterTable
```

Filter applies to a [TypeDef][TypeDef] by transforming a value before
encoding, or after decoding.

# FilterFunc
[FilterFunc]: #filterfunc
```
type FilterFunc = (value: any?, params: ...any) -> (any?, error?)
```

FilterFunc transforms *value* by using a function. The function should
return the transformed *value*.

The *params* received depend on the type, but are usually the elements of the
[TypeDef][TypeDef].

A non-nil error causes the program to halt, returning the given value.

# FilterTable
[FilterTable]: #filtertable
```
type FilterTable = {[any] = any}
```

FilterTable transforms a value by mapping the original value to the
transformed value.

# Hook
[Hook]: #hook
```
type Hook = (stack: (level: number)->any, global: table, h: boolean) -> (boolean, error?)
```

Hook indicates whether a type is traversed. If it returns true, then the
type is traversed normally. If false is returned, then the type is skipped.
If an error is returned, the program halts, returning the error.

*stack* is used to index structures in the stack. *level* determines how far
down to index the stack. level 0 returns the current structure. Returns nil
if *level* is out of bounds.

*global* is the global table. This can be used to compare against globally
assigned values.

*h* is the accumulated result of each hook in the same scope. It will be true
only if no other hooks returned true.

# TypeDef
[TypeDef]: #typedef
```
type TypeDef = ptr | pad | align | const | bool | int | uint | byte | float | fixed | ufixed | str | union | struct | array | vector | instance
```

TypeDef indicates the definition of one of a number of types.

# TypeDefBase
[TypeDefBase]: #typedefbase
```
type TypeDefBase = {hook: Hook?, decode: Filter?, encode: Filter?, global: any?}
```

TypeDefBase defines fields common to most [TypeDef][TypeDef] types.

*hook* determines whether the type should be used.

*decode* transforms the value after decoding, while *encode* transforms the
value before encoding.

If *global* is not nil, then the type's value is added to a globally
accessible table under the given key.

# align
[align]: #align
```
type align = {type: "align", size: number} & TypeDefBase
```

Pads with bits until the buffer is aligned to the number of bits
indicated by *size*. Does not read or write any value (filters are ignored).

# array
[array]: #array
```
type array = {type: "array", size: number|TypeDef, value: TypeDef} & TypeDefBase
```

A constant-size list of unnamed elements.

*size* specifies the number of elements, which can be an constant integer. If
a [TypeDef][TypeDef] is specified instead, then a value of that type will be
encoded or decoded, and used as the length. The value must evaluate to a
numeric type.

*value* is the type of each element in the array.

*size* is passed to filters as additional arguments.

The zero for this type is an empty array.

# bool
[bool]: #bool
```
type bool = {type: "bool", size: number?} & TypeDefBase
```

A boolean value. *size* is the number of bits used to represent the
value, defaulting to 1.

*size* is passed to filters as additional arguments.

The zero for this type is `false`.

# byte
[byte]: #byte
```
type byte = {type: "byte"} & TypeDefBase
```

Shorthand for a [uint][uint] of size 8.

# const
[const]: #const
```
type const = {type: "const", value: any?} & TypeDefBase
```

A constant value. *value* is the value, which is neither encoded nor
decoded.

# fixed
[fixed]: #fixed
```
type fixed = {type: "fixed", i: number, f: number} & TypeDefBase
```

A signed fixed-point number. *i* is the number of bits used to represent
the integer part. *f* is the number of bits used to represent the fractional
part.

*i* and *f* are passed to filters as additional arguments.

The zero for this type is `0`.

# float
[float]: #float
```
type float = {type: "float", size: number?} & TypeDefBase
```

A floating-point number. *size is the number of bits used to represent
the value, and must be 32 or 64. Defaults to 64.

*size* is passed to filters as additional arguments.

The zero for this type is `0`.

# instance
[instance]: #instance
```
type instance = {type: "instance", class: string, properties: {Field}} & TypeDefBase
```

A Roblox instance. *class* is the name of a Roblox class. Each
[Field][Field] of *properties* defines the properties of the instance.

*class* is passed to filters as additional arguments.

The zero for this type is a new instance of the class.

# int
[int]: #int
```
type int = {type: "int", size: number} & TypeDefBase
```

A signed integer. *size* is the number of bits used to represent the
value.

*size* is passed to filters as additional arguments.

The zero for this type is `0`.

# pad
[pad]: #pad
```
type pad = {type: "pad", size: number} & TypeDefBase
```

Specifies only bit padding, and does not read or write any value
(filters are ignored). *size* is the number of bits to pad with.

# ptr
[ptr]: #ptr
```
type ptr = {type: "ptr", value: TypeDef?}
```

A ptr is a TypeDef that resolve to another type definition. The purpose
is to allow definitions to use a type before it is defined. When compiling,
an error is thrown if the the ptr points to nothing, or if it is
self-referring.

# str
[str]: #str
```
type str = {type: "str", size: number} & TypeDefBase
```

A sequence of characters. Encoded as an unsigned integer indicating the
length of the string, followed by the raw bytes of the string. *size* is the
number of bits used to represent the length.

*size* is passed to filters as additional arguments.

The zero for this type is the empty string.

# struct
[struct]: #struct
```
type struct = {type: "struct", fields: {Field}} & TypeDefBase
```

A set of named fields. *fields* defines an ordered list of
[Fields][Field] of the struct.

The zero for this type is an empty struct.

# ufixed
[ufixed]: #ufixed
```
type ufixed = {type: "ufixed", i: number, f: number} & TypeDefBase
```

An unsigned fixed-point number. *i* is the number of bits used to
represent the integer part, and *f* is the number of bits used to represent
the fractional part.

*i* and *f* are passed to filters as additional arguments.

The zero for this type is `0`.

# uint
[uint]: #uint
```
type uint = {type: "uint", size: number} & TypeDefBase
```

An unsigned integer. *size* is the number of bits used to represent the
value.

*size* is passed to filters as additional arguments.

The zero for this type is `0`.

# union
[union]: #union
```
type union = {type: "union", clauses: {Clause}} & TypeDefBase
```

One of several types, where each [Clause][Clause] is evaluated to select
a single type.

# vector
[vector]: #vector
```
type vector = {type: "vector", size: any, value: TypeDef, level: number?} & TypeDefBase
```

A dynamically sized list of unnamed elements.

*size* indicates the key of a field in the parent struct from which the size
is determined. Evaluates to 0 if this field cannot be determined or is a
non-number.

*value* is the type of each element in the vector.

If *level* is specified, then it indicates the ancestor structure that is
index by *size*. If *level* is less than 1 or greater than the number of
ancestors, then *size* evaluates to 0. Defaults to 1, indicating the parent
structure.

*size* is passed to filters as additional arguments.

The zero for this type is an empty vector.

