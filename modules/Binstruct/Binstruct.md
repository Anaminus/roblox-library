# Binstruct
[Binstruct]: #user-content-binstruct

Binstruct encodes and decodes binary structures.

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
type TypeDef = {[1]: string, ...}
```

TypeDef is a table where the first element determines the remaining
structure of the table:

    {"_", size: number}
        Padding. *size* is the number of bits to pad with.

    {"bool", size: number?}
        A boolean. *size* is the number of bits used to represent the value,
        defaulting to 1.

    {"int", size: number
        A signed integer. *size* is the number of bits used to represent the
        value.

    {"uint", size: number}
        An unsigned integer. *size* is the number of bits used to represent
        the value.

    {"byte"}
        Shorthand for `{"uint", 8}`.

    {"float", size: number?}
        A floating-point number. *size* is the number of bits used to represent
        the value, and must be 32 or 64. Defaults to 64.

    {"fixed", i: number, f: number}
        A signed fixed-point number. *i* is the number of bits used to represent
        the integer part, and *f* is the number of bits used to represent the
        fractional part.

    {"ufixed", i: number, f: number}
        An unsigned fixed-point number. *i* is the number of bits used to
        represent the integer part, and *f* is the number of bits used to
        represent the fractional part.

    {"string", size: number}
        A sequence of characters. Encoded as an unsigned integer indicating the
        length of the string, followed by the raw bytes of the string. *size* is
        the number of bits used to represent the length.

    {"struct", ...{[1]: string, [2]: TypeDef}}
        A set of named fields. Each element is a table indicating a field of the
        struct. The first element of a field is the name, and the second element
        is a TypeDef.

