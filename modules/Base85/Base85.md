# Base85
[Base85]: #user-content-base85

Implements Base85 encoding similar to [Ascii85][Ascii85].

The encoding is based off of [RFC 1924][RFC1924], which is suitable for JSON
strings. Sequences of particular bytes (such as `\0\0\0\0\0`) are not encoded
exceptionally. Wrappers (such as `<~ ... ~>`) are neither added nor expected.

[Ascii85]: https://en.wikipedia.org/wiki/Ascii85
[RFC1924]: https://tools.ietf.org/html/rfc1924

## Base85.Decode
[Base85.Decode]: #user-content-base85decode
```
Base85.Decode(source: string): (data: string)
```

Decode returns the data decoded from source. Throws an error if the
source contains invalid base85 data or invalid bytes. Bytes that are spaces
are ignored.

## Base85.Encode
[Base85.Encode]: #user-content-base85encode
```
Base85.Encode(source: string): (data: string)
```

Encode returns the data encoded from source.

