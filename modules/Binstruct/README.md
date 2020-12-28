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

# TypeDef
[TypeDef]: #user-content-typedef
```
type TypeDef = {
	[1]: string,
	...,
}
```

TypeDef is a table where the first element indicates a type that
determines the remaining structure of the table. The following types are
defined:

    {"pad", number}
        Padding. Does not read or write any value. The parameter is the
        number of bits to pad with.

    {"align", number}
        Pad until the buffer is aligned to the number of bits indicated by
        the parameter. Does not read or write any value.

    {"bool", number?}
        A boolean. The parameter is the number of bits used to represent the
        value, defaulting to 1.

    {"int", number}
        A signed integer. The parameter is the number of bits used to
        represent the value.

    {"uint", number}
        An unsigned integer. The parameter is the number of bits used to
        represent the value.

    {"byte"}
        Shorthand for `{"uint", 8}`.

    {"float", number?}
        A floating-point number. The parameter is the number of bits used to
        represent the value, and must be 32 or 64. Defaults to 64.

    {"fixed", number, number}
        A signed fixed-point number. The first parameter is the number of
        bits used to represent the integer part, and the second parameter is
        the number of bits used to represent the fractional part.

    {"ufixed", number, number}
        An unsigned fixed-point number. The first parameter is the number of
        bits used to represent the integer part, and the second parameter is
        the number of bits used to represent the fractional part.

    {"string", number}
        A sequence of characters. Encoded as an unsigned integer indicating
        the length of the string, followed by the raw bytes of the string.
        The parameter is the number of bits used to represent the length.

    {"struct", ...{string, TypeDef}}
        A set of named fields. Each parameter is a table defining a field of
        the struct. The first element of a field definition is the name of
        the field, and the second element indicate the type of the field.

    {"array", number|string, TypeDef}
        A list of unnamed fields. The first parameter is the *size* of the
        array. If *size* is a number, this indicates a constant size. If
        *size* is a string, it indicates the name of a field in the parent
        struct from which the size is determined. Evaluates to 0 if this
        field cannot be determined or is a non-number. The second parameter
        is the type of each element in the array.

