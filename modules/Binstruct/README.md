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

## Binstruct.new
[Binstruct.new]: #user-content-binstructnew
```
Binstruct.new(def: TypeDef): Codec
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
Codec:Decode(buffer: string): any
```

Decode decodes a binary string into a value according to the codec.

## Codec.Encode
[Codec.Encode]: #user-content-codecencode
```
Codec:Encode(data: any): string
```

Encode encodes a value into a binary string according to the codec.

# Filter
[Filter]: #user-content-filter
```
type Filter = (value: any?, params: ...any) -> any?
```

Filter applies to a TypeDef by transforming *value* before encoding, or
after decoding. *params* are the parameters of the TypeDef. Should return the
transformed *value*.

# TypeDef
[TypeDef]: #user-content-typedef
```
type TypeDef = {
	encode = Filter?,
	decode = Filter?,
	[1]: string,
	...,
}
```

TypeDef is a table where the first element indicates a type that
determines the remaining structure of the table.

Additionally, the following optional named fields can be specified:
- `encode`: A filter that transforms a structural value before encoding.
- `decode`: A filter that transforms a structural value after decoding.

Within a decode filter, only the top-level value is structural; components of
the value will have already been transformed (if defined to do so). Likewise,
an encode filter should return a value that itself is structural, but
contains transformed components as expected by the component's type
definition. Each component's definition will eventually transform the
component itself, so the outer definition must avoid making transformations
on the component.

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
        A boolean. The parameter is the number of bits used to represent the
        value, defaulting to 1.

        The zero for this type is `false`.

    {"int", number}
        A signed integer. The parameter is the number of bits used to
        represent the value.

        The zero for this type is `0`.

    {"uint", number}
        An unsigned integer. The parameter is the number of bits used to
        represent the value.

        The zero for this type is `0`.

    {"byte"}
        Shorthand for `{"uint", 8}`.

    {"float", number?}
        A floating-point number. The parameter is the number of bits used to
        represent the value, and must be 32 or 64. Defaults to 64.

        The zero for this type is `0`.

    {"fixed", number, number}
        A signed fixed-point number. The first parameter is the number of
        bits used to represent the integer part, and the second parameter is
        the number of bits used to represent the fractional part.

        The zero for this type is `0`.

    {"ufixed", number, number}
        An unsigned fixed-point number. The first parameter is the number of
        bits used to represent the integer part, and the second parameter is
        the number of bits used to represent the fractional part.

        The zero for this type is `0`.

    {"string", number}
        A sequence of characters. Encoded as an unsigned integer indicating
        the length of the string, followed by the raw bytes of the string.
        The parameter is the number of bits used to represent the length.

        The zero for this type is the empty string.

    {"struct", ...{any?, TypeDef}}
        A set of named fields. Each parameter is a table defining a field of
        the struct.

        The first element of a field definition is the key used to index the
        field. If nil, the value will be processed, but the field will not be
        assigned to when decoding. When encoding, a `nil` value will be
        received, so the zero-value of the field's type will be used.

        The second element of a field definition is the type of the field.

        The zero for this type is an empty struct.

    {"array", number, TypeDef, level: number?}
        A constant-size list of unnamed fields.

        The first parameter is the *size* of the array, which indicates a
        constant size.

        The second parameter is the type of each element in the array.

        If the *level* field is specified, then it indicates the ancestor
        struct where *size* will be searched. If *level* is less than 1 or
        greater than the number of ancestors, then *size* evaluates to 0.
        Defaults to 1.

        The zero for this type is an empty array.

    {"vector", any, TypeDef, level: number?}
        A dynamically sized list of unnamed fields.

        The first parameter is the *size* of the vector, which indicates the
        name of a field in the parent struct from which the size is
        determined. Evaluates to 0 if this field cannot be determined or is a
        non-number.

        The second parameter is the type of each element in the vector.

        If the *level* field is specified, then it indicates the ancestor
        struct where *size* will be searched. If *level* is less than 1 or
        greater than the number of ancestors, then *size* evaluates to 0.
        Defaults to 1.

        The zero for this type is an empty vector.

    {"instance", string, ...{any?, TypeDef}}
        A Roblox instance. The first parameter is the name of a Roblox class.
        Each remaining parameter is a table defining a property of the
        instance.

        The first element of a property definition is the name used to index
        the property. If nil, the value will be processed, but the field will
        not be assigned to when decoding. When encoding, a `nil` value will
        be received, so the zero-value of the field's type will be used.

        The second element of a property definition is the type of the
        property.

        The zero for this type is a new instance of the class.

