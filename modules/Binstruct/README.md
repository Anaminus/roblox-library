# Binstruct
[Binstruct]: #user-content-binstruct

Binstruct encodes and decodes binary structures.

Example:
```lua
local Float = {"float", 32}
local String = {"string", 8}
local Vector3 = {"struct",
	{"X" , Float},
	{"Y" , Float},
	{"Z" , Float},
}
local CFrame = {"struct",
	{"Position" , Vector3},
	{"Rotation" , {"array", 9, Float}},
}
local brick = {"struct",
	{"Name"         , String},
	{"CFrame"       , CFrame},
	{"Size"         , Vector3},
	{"Color"        , {"byte"}},
	{"Reflectance"  , {"uint", 4}},
	{"Transparency" , {"uint", 4}},
	{"CanCollide"   , {"bool"}},
	{"Shape"        , {"uint", 3}},
	{"_"            , {"pad", 4}},
	{"Material"     , {"uint", 6}},
	{"_"            , {"pad", 2}},
}

local err, codec = Binstruct.new(brick)
if err ~= nil then
	t:Fatalf(err)
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
	1. [Binstruct.new][Binstruct.new]
2. [Codec][Codec]
	1. [Codec.Decode][Codec.Decode]
	2. [Codec.DecodeBuffer][Codec.DecodeBuffer]
	3. [Codec.Encode][Codec.Encode]
	4. [Codec.EncodeBuffer][Codec.EncodeBuffer]
3. [Filter][Filter]
4. [FilterFunc][FilterFunc]
5. [FilterTable][FilterTable]
6. [Hook][Hook]
7. [TypeDef][TypeDef]

</td></tr></tbody>
</table>

## Binstruct.new
[Binstruct.new]: #user-content-binstructnew
```
Binstruct.new(def: TypeDef): (err: string?, codec: Codec)
```

new constructs a Codec from the given definition.

# Codec
[Codec]: #user-content-codec
```
type Codec
```

Codec contains instructions for encoding and decoding binary data.

## Codec.Decode
[Codec.Decode]: #user-content-codecdecode
```
Codec:Decode(buffer: string): (error, any)
```

Decode decodes a binary string into a value according to the codec.
Returns the decoded value.

## Codec.DecodeBuffer
[Codec.DecodeBuffer]: #user-content-codecdecodebuffer
```
Codec:DecodeBuffer(buffer: Bitbuf.Buffer): (error, any)
```

DecodeBuffer decodes a binary string into a value according to the
codec. *buffer* is the buffer to read from. Returns the decoded value.

## Codec.Encode
[Codec.Encode]: #user-content-codecencode
```
Codec:Encode(data: any): (error, string)
```

Encode encodes a value into a binary string according to the codec.
Returns the encoded string.

## Codec.EncodeBuffer
[Codec.EncodeBuffer]: #user-content-codecencodebuffer
```
Codec:EncodeBuffer(data: any, buffer: Bitbuf.Buffer?): (error, Bitbuf.Buffer)
```

EncodeBuffer encodes a value into a binary string according to the
codec. *buffer* is an optional Buffer to write to. Returns the Buffer with
the written data.

# Filter
[Filter]: #user-content-filter
```
type Filter = FilterFunc | FilterTable
```

Filter applies to a TypeDef by transforming a value before encoding, or
after decoding.

# FilterFunc
[FilterFunc]: #user-content-filterfunc
```
type FilterFunc = (value: any?, params: ...any) -> (any?, error?)
```

FilterFunc transforms *value* by using a function. The function should
return the transformed *value*.

The *params* received depend on the type, but are usually the elements of the
TypeDef.

A non-nil error causes the program to halt, returning the given value.

# FilterTable
[FilterTable]: #user-content-filtertable
```
type FilterTable = {[any] = any}
```

FilterTable transforms a value by mapping the original value to the
transformed value.

# Hook
[Hook]: #user-content-hook
```
type Hook = (stack: (level: number)->any, global: table, h: boolean) -> (boolean, error?)
```

Hook applies to a TypeDef by transforming *value* before encoding, or
after decoding. *params* are the parameters of the TypeDef. Should return the
transformed *value*.

Hook indicates whether a type is traversed. If it returns true, then the type
is traversed normally. If false is returned, then the type is skipped. If an
error is returned, the program halts, returning the error.

*stack* is used to index structures in the stack. *level* determines how far
down to index the stack. level 0 returns the current structure. Returns nil
if *level* is out of bounds.

*global* is the global table. This can be used to compare against globally
assigned values.

*h* is the accumulated result of each hook in the same scope. It will be true
only if no other hooks returned true.

# TypeDef
[TypeDef]: #user-content-typedef
```
type TypeDef = {
	encode = Filter?,
	decode = Filter?,
	hook   = Hook?,
	[1]: string,
	...,
}
```

TypeDef is a table where the first element indicates a type that
determines the remaining structure of the table.

Additionally, the following optional named fields can be specified:
- `encode`: A filter that transforms a structural value before encoding.
- `decode`: A filter that transforms a structural value after decoding.
- `hook`: A function that determines whether the type should be used.
- `global`: A key that adds the type's value to a globally accessible table.

Within a decode filter, only the top-level value is structural; components of
the value will have already been transformed (if defined to do so). Likewise,
an encode filter should return a value that itself is structural, but
contains transformed components as expected by the component's type
definition. Each component's definition will eventually transform the
component itself, so the outer definition must avoid making transformations
on the component.

A hook indicates whether the type will be handled. If it returns true, then
the type is handled normally. If false is returned, then the type is skipped.

Specifying a global key causes the value of a non-skipped type to be assigned
to the global table, which may then be accessed by the remainder of the
codec. Values are assigned in the order they are traversed.

When a type encodes the value `nil`, the zero-value for the type is used.

The following types are defined:

    {"pad", number}
        Padding. Does not read or write any value (filters are ignored). The
        parameter is the number of bits to pad with.

    {"align", number}
        Pad until the buffer is aligned to the number of bits indicated by
        the parameter. Does not read or write any value (filters are
        ignored).

    {"const", any?}
        A constant value. The parameter is the value. This type is neither
        encoded nor decoded.

    {"bool", number?}
        A boolean. The parameter is *size*, or the number of bits used to
        represent the value, defaulting to 1.

        *size* is passed to filters as additional arguments.

        The zero for this type is `false`.

    {"int", number}
        A signed integer. The parameter is *size*, or the number of bits used
        to represent the value.

        *size* is passed to filters as additional arguments.

        The zero for this type is `0`.

    {"uint", number}
        An unsigned integer. The parameter is *size*, or the number of bits
        used to represent the value.

        *size* is passed to filters as additional arguments.

        The zero for this type is `0`.

    {"byte"}
        Shorthand for `{"uint", 8}`.

    {"float", number?}
        A floating-point number. The parameter is *size*, or the number of
        bits used to represent the value, and must be 32 or 64. Defaults to
        64.

        *size* is passed to filters as additional arguments.

        The zero for this type is `0`.

    {"fixed", number, number}
        A signed fixed-point number. The first parameter is *i*, or the
        number of bits used to represent the integer part. The second
        parameter is *f*, or the number of bits used to represent the
        fractional part.

        *i* and *f* are passed to filters as additional arguments.

        The zero for this type is `0`.

    {"ufixed", number, number}
        An unsigned fixed-point number. The first parameter is *i*, or the
        number of bits used to represent the integer part. The second
        parameter is *f*, or the number of bits used to represent the
        fractional part.

        *i* and *f* are passed to filters as additional arguments.

        The zero for this type is `0`.

    {"string", number}
        A sequence of characters. Encoded as an unsigned integer indicating
        the length of the string, followed by the raw bytes of the string.
        The parameter is *size*, or the number of bits used to represent the
        length.

        *size* is passed to filters as additional arguments.

        The zero for this type is the empty string.

    {"union", ...TypeDef}

        One of several types. Hooks can be used to select a single type.

    {"struct", ...{any?, TypeDef}}
        A set of named fields. Each parameter is a table defining a field of
        the struct.

        The first element of a field definition is the key used to index the
        field. If nil, the value will be processed, but the field will not be
        assigned to when decoding. When encoding, a `nil` value will be
        received, so the zero-value of the field's type will be used.

        The second element of a field definition is the type of the field.

        A field definition may also specify a "hook" field, which is
        described above. If the hook returns false, then the field is
        skipped.

        A field definition may also specify a "global" field, which is
        described above. A non-nil global field assigns the field's value to
        the specified global key.

        The zero for this type is an empty struct.

    {"array", number, TypeDef, level: number?}
        A constant-size list of unnamed fields.

        The first parameter is the *size* of the array, indicating a constant
        size.

        The second parameter is the type of each element in the array.

        If the *level* field is specified, then it indicates the ancestor
        struct where *size* will be searched. If *level* is less than 1 or
        greater than the number of ancestors, then *size* evaluates to 0.
        Defaults to 1.

        *size* is passed to filters as additional arguments.

        The zero for this type is an empty array.

    {"vector", any, TypeDef, level: number?}
        A dynamically sized list of unnamed fields.

        The first parameter is the *size* of the vector, which indicates the
        key of a field in the parent struct from which the size is
        determined. Evaluates to 0 if this field cannot be determined or is a
        non-number.

        The second parameter is the type of each element in the vector.

        If the *level* field is specified, then it indicates the ancestor
        structure where *size* will be searched. If *level* is less than 1 or
        greater than the number of ancestors, then *size* evaluates to 0.
        Defaults to 1, indicating the parent structure.

        *size* is passed to filters as additional arguments.

        The zero for this type is an empty vector.

    {"instance", string, ...{any?, TypeDef}}
        A Roblox instance. The first parameter is *class*, or the name of a
        Roblox class. Each remaining parameter is a table defining a property
        of the instance.

        The first element of a property definition is the name used to index
        the property. If nil, the value will be processed, but the field will
        not be assigned to when decoding. When encoding, a `nil` value will
        be received, so the zero-value of the field's type will be used.

        The second element of a property definition is the type of the
        property.

        *class* is passed to filters as additional arguments.

        The zero for this type is a new instance of the class.

