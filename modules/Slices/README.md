# Slices
[Slices]: #slices

The Slices module produces values of and operates on the [Slice][Slice]
type. A Slice wraps Luau's [buffer][buffer] type to provide a more dynamic
type with higher-level operations. Slices are based largely on [Go's
slices][goslices].

This module provides a means for creating slices of built-in and custom data
types, as well as common methods for operating on slices.

[buffer]: https://luau-lang.org/library#buffer-library
[goslices]: https://go.dev/ref/spec#Slice_types

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Slices][Slices]
	1. [Slices.make][Slices.make]
	2. [Slices.append][Slices.append]
	3. [Slices.cap][Slices.cap]
	4. [Slices.clear][Slices.clear]
	5. [Slices.copy][Slices.copy]
	6. [Slices.fill][Slices.fill]
	7. [Slices.from][Slices.from]
	8. [Slices.fromTable][Slices.fromTable]
	9. [Slices.is][Slices.is]
	10. [Slices.iter][Slices.iter]
	11. [Slices.join][Slices.join]
	12. [Slices.len][Slices.len]
	13. [Slices.maker][Slices.maker]
	14. [Slices.read][Slices.read]
	15. [Slices.slice][Slices.slice]
	16. [Slices.to][Slices.to]
	17. [Slices.toTable][Slices.toTable]
	18. [Slices.write][Slices.write]
2. [Definition][Definition]
3. [Make][Make]
4. [Next][Next]
5. [Slice][Slice]
	1. [Slice.__call][Slice.__call]
	2. [Slice.__index][Slice.__index]
	3. [Slice.__iter][Slice.__iter]
	4. [Slice.__len][Slice.__len]
	5. [Slice.__newindex][Slice.__newindex]

</td></tr></tbody>
</table>

## Slices.make
[Slices.make]: #slicesmake

Contains constructors for creating new slices of specific types. The
following types are included:

Name    | Element type
--------|-------------
i8      | 8-bit signed integer
u8      | 8-bit unsigned integer
i16     | 16-bit signed integer
u16     | 16-bit unsigned integer
i32     | 32-bit signed integer
u32     | 32-bit unsigned integer
f32     | 32-bit floating point number
f64     | 64-bit floating point number
boolean | Boolean truth value
Vector3 | Vector3 value

```lua
local sliceU8 = Slices.make.u8(3) -- Slice of 3 8-bit unsigned integers.
local sliceV3 = Slices.make.Vector3(4) -- Slice of 4 Vector3 values.
```

## Slices.append
[Slices.append]: #slicesappend
```
function Slices.append<T>(self: Slice<T>, ...: T): Slice<T>
```

Appends elements to a slice, growing the slice if necessary.

If the slice has enough capacity to contain the received elements, then they
are appended to the slice, and a slice with the same backing array is
returned. If the capacity is not large enough, then the current array is
untouched, and a new array is allocated with a length that is large enough to
contain the elements.

Appending only returns the same slice if no elements are passed. As such, the
previous slice should usually be replaced by the new slice:

```lua
slice = Slices.append(slice, 1, 2, 3)
```

## Slices.cap
[Slices.cap]: #slicescap
```
function Slices.cap<T>(self: Slice<T>): number
```

Returns the underlying capacity of the slice.

```lua
local capacity = Slices.cap(slice)
```

## Slices.clear
[Slices.clear]: #slicesclear
```
function Slices.clear<T>(self: Slice<T>): Slice<T>
```

Sets each element of the slice to its binary zero. The implementation
may not use the type's writer. Returns *self*.

```lua
Slices.clear(slice)
```

## Slices.copy
[Slices.copy]: #slicescopy
```
function Slices.copy<T>(dst: Slice<T>, src: Slice<T>): number
```

Copies elements from *src* to *dst*, returning the number of elements
copied. The number of elements copied is the minimum of the lengths of *dst*
and *src*.

```lua
local count = Slices.copy(dst, src)
```

## Slices.fill
[Slices.fill]: #slicesfill
```
function Slices.fill<T>(self: Slice<T>, value: T): Slice<T>
```

Sets each element of the slice to *value*. Guaranteed to use the type's
writer. Returns *self*.

```lua
Slices.fill(slice, 1) -- Fill with all ones.
```

## Slices.from
[Slices.from]: #slicesfrom
```
function Slices.from<T>(make: Make<T>, ...: T): Slice<T>
```

Returns a slice according to *make*, containing elements from the
remaining arguments.

```lua
local slice = Slices.from(Slices.make.u8, 1, 2, 3, 4)
```

## Slices.fromTable
[Slices.fromTable]: #slicesfromtable
```
function Slices.fromTable<T>(make: Make<T>, t: {T}): Slice<T>
```

Returns a slice according to *make*, containing elements from *t*.

```lua
local slice = Slices.fromTable(Slices.make.u8, {1, 2, 3, 4})
```

## Slices.is
[Slices.is]: #slicesis
```
function Slices.is(value: unknown): boolean
```

Returns whether *value* is a valid slice.

```lua
if Slices.is(slice) then
	print(slice)
end
```

## Slices.iter
[Slices.iter]: #slicesiter
```
function Slices.iter<T>(self: Slice<T>): (Next<T>, Slice<T>)
```

Returns a function that iterates over the elements of the slice,
suitable for passing to a generic for loop.

```lua
for index, value in Slices.iter(slice) do
	print(index, value)
end
```

## Slices.join
[Slices.join]: #slicesjoin
```
function Slices.join<T>(self: Slice<T>, ...: Slice<T>): Slice<T>
```

Appends to *self* each element from the remaining arguments.

```lua
local slice = Slices.join(sliceA, sliceB, sliceC)
```

## Slices.len
[Slices.len]: #sliceslen
```
function Slices.len<T>(self: Slice<T>): number
```

Returns the length of the slice.

```lua
local length = Slices.len(slice)
```

## Slices.maker
[Slices.maker]: #slicesmaker
```
function Slices.maker<T>(def: Definition<T>): Make<T>
```

Returns a [make][Make] function that creates a slice of the type defined
by [def][Definition].

```lua
local makeU32 = export.maker({
	name = "u32",
	size = 4,
	read = function(a: buffer, index: number): number
		return buffer.readu32(a, index)
	end,
	write = function(a: buffer, index: number, value: number)
		buffer.writeu32(a, index, value)
	end,
})
```

## Slices.read
[Slices.read]: #slicesread
```
function Slices.read<T>(self: Slice<T>, index: number): T
```

Returns the value at *index*.

```lua
local value = Slices.read(slice, index)
```

## Slices.slice
[Slices.slice]: #slicesslice
```
function Slices.slice<T>(self: Slice<T>, low: number?, high: number?, max: number?): Slice<T>
```

Returns a sub-slice of the slice.

*low* determines the lower bound of the new slice, defaulting to 0. *high*
determines the upper bound of the new slice, defaulting to the length of the
slice. The new slice has indices starting at 0 and a length of `high - low`.

*max* controls the capacity of the new slice by setting it to `max - low`. It
defaults to the current capacity of the slice.

The arguments must satisfy `0 <= low <= high <= max <= cap(self)`, or else
they are considered out of range.

```lua
local sub = Slices.slice(slice, low, high, max)
```

## Slices.to
[Slices.to]: #slicesto
```
function Slices.elements<T>(self: Slice<T>): ...T
```

Returns the unpacked elements of the slice.

```lua
local a, b, c, d = Slices.to(slice)
```

## Slices.toTable
[Slices.toTable]: #slicestotable
```
function Slices.toTable<T>(self: Slice<T>): {T}
```

Returns the elements of the slice in a table.

```lua
local t = Slices.toTable(slice)
```

## Slices.write
[Slices.write]: #sliceswrite
```
function Slices.write<T>(self: Slice<T>, index: number, value: T)
```

Sets *index* in the slice to *value*.

```lua
Slices.write(slice, index, value)
```

# Definition
[Definition]: #definition
```
type Definition<T>
```

Defines a slice type for elements of type T.

The *name* field specifies a name used to identify type.

The *size* field specifies the size of one element, in bytes.

The *read* field is a function that implements reading from the slice.

The *write* field is a function that implements writing to the slice.

The first argument to the read and write functions is a buffer. The second
argument is an index of the buffer that points to the start of the element
(this value is premultiplied by the element size). The write function
receives a third argument, which is the value to write. The read function
must return a value of the element type.

Read and write should avoid indexing beyond the given index plus the element
size.

As an example, the following definition implements the Vector3 type:

```lua
{
	name = "Vector3",
	size = 12,
	read = function(a: buffer, index: number): Vector3
		return Vector3.new(
			buffer.readf32(a, index + 0),
			buffer.readf32(a, index + 4),
			buffer.readf32(a, index + 8)
		)
	end,
	write = function(a: buffer, index: number, value: Vector3)
		buffer.writef32(a, index + 0, value.X)
		buffer.writef32(a, index + 4, value.Y)
		buffer.writef32(a, index + 8, value.Z)
	end,
}
```

# Make
[Make]: #make
```
type Make<T> = (len: number?, cap: number?) -> Slice<T>
```

A function that returns a new slice of type T.

# Next
[Next]: #next
```
type Next<T> = (self: Slice<T>, index: number?) -> (number?, T?)
```

A function that iterates over the elements of a slice, suitable for use
with a generic for loop. Returned by [Slices.iter][Slices.iter].

# Slice
[Slice]: #slice
```
type Slice<T>
```

Represents a slice of elements of type T.

A slice has no fields. Instead, the module provides functions for operating
on slices. The Slice type also implements several metamethods for the most
common operations.

## Slice.__call
[Slice.__call]: #slice__call
```
function Slice.__call<T>(self: Slice<T>, low: number?, high: number?, max: number?): Slice<T>
```

Returns a sub-slice of the slice.

Shorthand for [`Slices.slice(self, low, high, max)`][Slices.slice].

```lua
local sub = slice(low, high, max)
```

## Slice.__index
[Slice.__index]: #slice__index
```
function Slice.__index<T>(self: Slice<T>, index: number): T
```

Returns the value at *index* in the slice.

Shorthand for [`Slices.read(self, index)`][Slices.read].

```lua
local value = slice[index]
```

## Slice.__iter
[Slice.__iter]: #slice__iter
```
function Slice.__iter<T>(self: Slice<T>): (Next<T>, Slice<T>)
```

Implements an iterator over each element of the slice.

Shorthand for [`Slices.iter(self)`][Slices.iter].

```lua
for index, value in slice do
	print(index, value)
end
```

## Slice.__len
[Slice.__len]: #slice__len
```
function Slice.__len<T>(self: Slice<T>): number
```

Returns the number of elements in the slice.

Shorthand for [`Slices.len(self)`][Slices.len].

```lua
local length = #slice
```

## Slice.__newindex
[Slice.__newindex]: #slice__newindex
```
function Slice.__newindex<T>(self: Slice<T>, index: number, value: T)
```

Sets *value* to *index* in the slice.

Shorthand for [`Slices.write(self, index, value)`][Slices.write].

```lua
slice[index] = value
```

