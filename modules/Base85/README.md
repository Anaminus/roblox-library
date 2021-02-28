# Base85
[Base85]: #user-content-base85

Implements Base85 encoding similar to [Ascii85][Ascii85].

The encoding is based off of [RFC 1924][RFC1924], which is suitable for JSON
strings. Sequences of particular bytes (such as `\0\0\0\0\0`) are not encoded
exceptionally. Wrappers (such as `<~ ... ~>`) are neither added nor expected.

[Ascii85]: https://en.wikipedia.org/wiki/Ascii85
[RFC1924]: https://tools.ietf.org/html/rfc1924

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Base85][Base85]
	1. [Base85.decode][Base85.decode]
	2. [Base85.defaultEncoding][Base85.defaultEncoding]
	3. [Base85.encode][Base85.encode]
	4. [Base85.newCodec][Base85.newCodec]
2. [Encoding][Encoding]

</td></tr></tbody>
</table>

## Base85.decode
[Base85.decode]: #user-content-base85decode
```
Base85.decode(source: string): (err: error, data: string)
```

decode returns the data decoded from source. Returns an error if the
source contains invalid base85 data or invalid bytes. Bytes that are spaces
are ignored.

## Base85.encode
[Base85.encode]: #user-content-base85encode
```
Base85.encode(source: string): (data: string)
```

encode returns the data encoded from source.

