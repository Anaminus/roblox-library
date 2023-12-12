--!strict
--!optimize 2

-- Derived largely from golang:src/runtime/slice.go

--@sec: Slices
--@ord: -1
--@doc: The Slices module produces values of and operates on the [Slice][Slice]
-- type. A Slice wraps Luau's [buffer][buffer] type to provide a more dynamic
-- type with higher-level operations. Slices are based largely on [Go's
-- slices][goslices].
--
-- This module provides a means for creating slices of built-in and custom data
-- types, as well as common methods for operating on slices.
--
-- [buffer]: https://luau-lang.org/library#buffer-library
-- [goslices]: https://go.dev/ref/spec#Slice_types
local export = {}

type reader<T> = (a: buffer, index: number) -> T
type writer<T> = (a: buffer, index: number, value: T) -> ()

--@sec: Definition
--@def: type Definition<T>
--@doc: Defines a slice type for elements of type T.
--
-- The *name* field specifies a name used to identify type.
--
-- The *size* field specifies the size of one element, in bytes.
--
-- The *read* field is a function that implements reading from the slice.
--
-- The *write* field is a function that implements writing to the slice.
--
-- The first argument to the read and write functions is a buffer. The second
-- argument is an index of the buffer that points to the start of the element
-- (this value is premultiplied by the element size). The write function
-- receives a third argument, which is the value to write. The read function
-- must return a value of the element type.
--
-- Read and write should avoid indexing beyond the given index plus the element
-- size.
--
-- As an example, the following definition implements the Vector3 type:
--
-- ```lua
-- {
-- 	name = "Vector3",
-- 	size = 12,
-- 	read = function(a: buffer, index: number): Vector3
-- 		return Vector3.new(
-- 			buffer.readf32(a, index + 0),
-- 			buffer.readf32(a, index + 4),
-- 			buffer.readf32(a, index + 8)
-- 		)
-- 	end,
-- 	write = function(a: buffer, index: number, value: Vector3)
-- 		buffer.writef32(a, index + 0, value.X)
-- 		buffer.writef32(a, index + 4, value.Y)
-- 		buffer.writef32(a, index + 8, value.Z)
-- 	end,
-- }
-- ```
export type Definition<T> = {
	name: string,
	size: number,
	read: reader<T>,
	write: writer<T>,
}

type typedef<T> = Definition<T> & {
	make: Make<T>,
}

--@sec: Make
--@def: type Make<T> = (len: number?, cap: number?) -> Slice<T>
--@doc: A function that returns a new slice of length *len* with elements of
-- type T. *len* defaults to 0. *cap* optionally defines the capacity of the
-- slice, defaulting to the length.
export type Make<T> = (len: number?, cap: number?) -> Slice<T>

local MAX_ALLOC = 2^30 -- Maximum buffer length.
local HALF_ALLOC = 2^15 -- Half bits of MAX_ALLOC, for multiplying.
local MAX_PTR = MAX_ALLOC - 1 -- Maximum buffer index.
local ZERO_BASE = buffer.create(0) -- Used for zero-width slices.

-- Returns the product of a and b, and whether the multiplication overflowed.
local function multiply_ptr(a: number, b: number): (number, boolean)
	if bit32.bor(a, b) < HALF_ALLOC or a == 0 then
		return a * b, false
	end
	local overflow = b > MAX_PTR // a
	return a * b, overflow
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--@sec: Slice
--@def: type Slice<T>
--@doc: Represents a slice of elements of type T.
--
-- A slice has no fields. Instead, the module provides functions for operating
-- on slices. The Slice type also implements several metamethods for the most
-- common operations.
local Slice = {}

--@sec: Next
--@def: type Next<T> = (self: Slice<T>, index: number?) -> (number?, T?)
--@doc: A function that iterates over the elements of a slice, suitable for use
-- with a generic for loop. Returned by [Slices.iter][Slices.iter].
export type Next<T> = (self: Slice<T>, index: number?) -> (number?, T?)

export type Slice<T> = typeof(setmetatable({}, {
	__len = (nil::any) :: (self: Slice<T>) -> number,
	__index = (nil::any) :: (self: Slice<T>, index: number) -> T,
	__newindex = (nil::any) :: (self: Slice<T>, index: number, value: T) -> (),
	__call = (nil::any) :: (self: Slice<T>, low: number?, high: number?, max: number?) -> Slice<T>,
	__iter = (nil::any) :: (self: Slice<T>) -> (Next<T>, Slice<T>),
}))

-- The private representation of a slice. Despite being unrelated types, slices
-- are designed to implement both slice<T> and Slice<T>, and are internally
-- interchangeable through the to_slice and from_slice functions.
type slice<T> = {
	-- Type information shared by all slices of the type.
	_type: typedef<T>,
	-- The underlying buffer.
	_array: buffer,
	-- Buffer offset, in buffer units. Since there are no pointers to work with,
	-- the start of the slice is represented as an offset index from the start
	-- of the buffer. This would make it possible to allow a slice to extend
	-- backwards to the start of the buffer, but this isn't implemented to allow
	-- encapsulation.
	--
	-- The "base slice" refers to a slice where _ptr is 0, representing the
	-- entire range of the buffer.
	_ptr: number,
	-- Length of the slice, in slice units.
	_len: number,
	-- Capacity of the slice, in slice units. Usually corresponds to the full
	-- length of the buffer, but can be less to prevent the slice from extending
	-- for encapsulation purposes. When taking a slice, the lower bound must be
	-- subtracted from this to ensure the capacity remains within the bounds of
	-- the buffer.
	_cap: number,
}

-- Converts a public Slice<T> to a private slice<T>, asserting that *self* is a
-- slice type. *msg* is an optional message to emit when the assertion fails.
local function to_slice<T>(self: Slice<T>, msg: string?): slice<T>
	if getmetatable(self) == Slice then
		return (self::any) :: slice<T>
	else
		error(msg or "slice expected", 3)
	end
end

-- Same as to_slice, but without assertion.
local function to_slice_nop<T>(self: Slice<T>): slice<T>
	return (self::any) :: slice<T>
end

-- Converts a private slice<T> to a public Slice<T>. Only provides type
-- checking; is a no-op at runtime.
local function from_slice<T>(self: slice<T>): Slice<T>
	return (self::any) :: Slice<T>
end

-- Builds a new slice directly from arguments.
local function newSlice<T>(
	array: buffer,
	type: Definition<T>,
	ptr: number,
	len: number,
	cap: number): slice<T>
	return table.freeze(setmetatable({
		_array = array,
		_type = type,
		_ptr = ptr,
		_len = len,
		_cap = cap,
	}, Slice)) :: any
end

-- Performs a read of an element of type T.
local function read<T>(self: slice<T>, index: number): T
	return self._type.read(self._array, index*self._type.size + self._ptr)
end

-- Performs a write of an element of type T.
local function write<T>(self: slice<T>, index: number, value: T)
	self._type.write(self._array, index*self._type.size + self._ptr, value)
end

--@sec: Slice.__len
--@def: function Slice.__len<T>(self: Slice<T>): number
--@doc: Returns the number of elements in the slice.
--
-- Shorthand for [`Slices.len(self)`][Slices.len].
--
-- ```lua
-- local length = #slice
-- ```
function Slice.__len<T>(self: Slice<T>): number
	return export.len(self)
end

--@sec: Slice.__index
--@def: function Slice.__index<T>(self: Slice<T>, index: number): T
--@doc: Returns the value at *index* in the slice.
--
-- Shorthand for [`Slices.read(self, index)`][Slices.read].
--
-- ```lua
-- local value = slice[index]
-- ```
function Slice.__index<T>(self: Slice<T>, index: number): T
	return export.read(self, index)
end

--@sec: Slice.__newindex
--@def: function Slice.__newindex<T>(self: Slice<T>, index: number, value: T)
--@doc: Sets *value* to *index* in the slice.
--
-- Shorthand for [`Slices.write(self, index, value)`][Slices.write].
--
-- ```lua
-- slice[index] = value
-- ```
function Slice.__newindex<T>(self: Slice<T>, index: number, value: T)
	export.write(self, index, value)
end

--@sec: Slice.__call
--@def: function Slice.__call<T>(self: Slice<T>, low: number?, high: number?, max: number?): Slice<T>
--@doc: Returns a sub-slice of the slice.
--
-- Shorthand for [`Slices.slice(self, low, high, max)`][Slices.slice].
--
-- ```lua
-- local sub = slice(low, high, max)
-- ```
function Slice.__call<T>(self: Slice<T>, low: number?, high: number?, max: number?): Slice<T>
	return export.slice(self, low, high, max)
end

--@sec: Slice.__iter
--@def: function Slice.__iter<T>(self: Slice<T>): (Next<T>, Slice<T>)
--@doc: Implements an iterator over each element of the slice.
--
-- Shorthand for [`Slices.iter(self)`][Slices.iter].
--
-- ```lua
-- for index, value in slice do
-- 	print(index, value)
-- end
-- ```
function Slice.__iter<T>(self: Slice<T>): (Next<T>, Slice<T>)
	return function(self: Slice<T>, index: number?): (number?, T?)
		local self = (self::any)::slice<T>
		local index = (index or -1) + 1
		if index >= self._len then
			return nil
		end
		return index, self._type.read(self._array, index*self._type.size + self._ptr)
	end, self
end

table.freeze(Slice)

--@sec: Slices.is
--@def: function Slices.is(value: unknown): boolean
--@doc: Returns whether *value* is a valid slice.
--
-- ```lua
-- if Slices.is(slice) then
-- 	print(slice)
-- end
-- ```
function export.is(value: unknown): boolean
	return getmetatable(value::any) == Slice
end

--@sec: Slices.len
--@def: function Slices.len<T>(self: Slice<T>): number
--@doc: Returns the length of the slice.
--
-- ```lua
-- local length = Slices.len(slice)
-- ```
function export.len<T>(self: Slice<T>): number
	local self = to_slice(self)
	return self._len
end

--@sec: Slices.cap
--@def: function Slices.cap<T>(self: Slice<T>): number
--@doc: Returns the capacity of the slice. The capacity is the number of
-- elements that the underlying array can contain. Having a capacity that is
-- larger than the length allows a slice to grow without having to reallocate
-- memory.
--
-- ```lua
-- local capacity = Slices.cap(slice)
-- ```
function export.cap<T>(self: Slice<T>): number
	local self = to_slice(self)
	return self._cap
end

--@sec: Slices.iter
--@def: function Slices.iter<T>(self: Slice<T>): (Next<T>, Slice<T>)
--@doc: Returns a function that iterates over the elements of the slice,
-- suitable for passing to a generic for loop.
--
-- ```lua
-- for index, value in Slices.iter(slice) do
-- 	print(index, value)
-- end
-- ```
function export.iter<T>(self: Slice<T>): (Next<T>, Slice<T>)
	to_slice(self)
	return function(self: Slice<T>, index: number?): (number?, T?)
		local self = (self::any)::slice<T>
		local index = (index or -1) + 1
		if index >= self._len then
			return nil
		end
		return index, self._type.read(self._array, index*self._type.size + self._ptr)
	end, self
end

--@sec: Slices.read
--@def: function Slices.read<T>(self: Slice<T>, index: number): T
--@doc: Returns the value at *index*.
--
-- ```lua
-- local value = Slices.read(slice, index)
-- ```
function export.read<T>(self: Slice<T>, index: number): T
	local self = to_slice(self)
	assert(type(index) == "number", "index must be a number")
	assert(0 <= index and index < self._len, "index out of range")
	return read(self, index // 1)
end

--@sec: Slices.write
--@def: function Slices.write<T>(self: Slice<T>, index: number, value: T)
--@doc: Sets *index* in the slice to *value*.
--
-- ```lua
-- Slices.write(slice, index, value)
-- ```
function export.write<T>(self: Slice<T>, index: number, value: T)
	local self = to_slice(self)
	assert(type(index) == "number", "index must be a number")
	assert(0 <= index and index < self._len, "index out of range")
	write(self, index // 1, value)
end

--@sec: Slices.slice
--@def: function Slices.slice<T>(self: Slice<T>, low: number?, high: number?, max: number?): Slice<T>
--@doc: Returns a sub-slice of the slice.
--
-- *low* determines the lower bound of the new slice, defaulting to 0. *high*
-- determines the upper bound of the new slice, defaulting to the length of the
-- slice. The new slice has indices starting at 0 and a length of `high - low`.
--
-- *max* controls the capacity of the new slice by setting it to `max - low`. It
-- defaults to the current capacity of the slice.
--
-- The arguments must satisfy `0 <= low <= high <= max <= cap(self)`, or else
-- they are considered out of range.
--
-- ```lua
-- local sub = Slices.slice(slice, low, high, max)
-- ```
function export.slice<T>(self: Slice<T>, low: number?, high: number?, max: number?): Slice<T>
	local self = to_slice(self)
	local low = (low or 0) // 1
	local high = (high or self._len) // 1
	local max = (max or self._cap) // 1
	assert(0 <= low and low <= high, "lower bound out of range")
	assert(high <= max, "upper bound out of range")
	assert(max <= self._cap, "max bound out of range")
	return from_slice(newSlice(
		self._array,
		self._type,
		-- _ptr is added because low represents the lower bound of the current
		-- slice, rather than the base slice. low is multiplied by the size
		-- because _ptr is a direct index to the buffer.
		self._ptr + low*self._type.size,
		high - low,
		max - low
	))
end

--@sec: Slices.clear
--@def: function Slices.clear<T>(self: Slice<T>): Slice<T>
--@doc: Sets each element of the slice to its binary zero. The implementation
-- may not use the type's writer. Returns *self*.
--
-- ```lua
-- Slices.clear(slice)
-- ```
function export.clear<T>(self: Slice<T>): Slice<T>
	local self = to_slice(self)
	buffer.fill(self._array, self._ptr, 0, self._len*self._type.size)
	return from_slice(self)
end

--@sec: Slices.fill
--@def: function Slices.fill<T>(self: Slice<T>, value: T): Slice<T>
--@doc: Sets each element of the slice to *value*. Guaranteed to use the type's
-- writer. Returns *self*.
--
-- ```lua
-- Slices.fill(slice, 1) -- Fill with all ones.
-- ```
function export.fill<T>(self: Slice<T>, value: T): Slice<T>
	local self = to_slice(self)
	for i = 0, self._len-1 do
		write(self, i, value)
	end
	return from_slice(self)
end

--@sec: Slices.copy
--@def: function Slices.copy<T>(dst: Slice<T>, src: Slice<T>): number
--@doc: Copies elements from *src* to *dst*, returning the number of elements
-- copied. The number of elements copied is the minimum of the lengths of *dst*
-- and *src*.
--
-- ```lua
-- local count = Slices.copy(dst, src)
-- ```
function export.copy<T>(dst: Slice<T>, src: Slice<T>): number
	local dst = to_slice(dst, "destination must be a slice")
	local src = to_slice(src, "source must be a slice")
	if dst._type ~= src._type then
		error("cannot copy slices of different types", 2)
	end
	local dstLen = dst._len
	local srcLen = src._len
	if srcLen == 0 or dstLen == 0 then
		return 0
	end

	local n = srcLen
	if dstLen < n then
		n = dstLen
	end

	local width = dst._type.size
	if width == 0 then
		return n
	end

	local size = n * width
	buffer.copy(dst._array, dst._ptr, src._array, src._ptr, size)
	return n
end

--@sec: Slices.to
--@def: function Slices.elements<T>(self: Slice<T>): ...T
--@doc: Returns the unpacked elements of the slice.
--
-- ```lua
-- local a, b, c, d = Slices.to(slice)
-- ```
function export.to<T>(self: Slice<T>): ...T
	local self = to_slice(self)
	local elements = table.create(self._len)
	for i = 1, self._len do
		elements[i] = read(self, i - 1)
	end
	return table.unpack(elements, 1, self._len)
end

--@sec: Slices.toTable
--@def: function Slices.toTable<T>(self: Slice<T>): {T}
--@doc: Returns the elements of the slice in a table.
--
-- ```lua
-- local t = Slices.toTable(slice)
-- ```
function export.toTable<T>(self: Slice<T>): {T}
	local self = to_slice(self)
	local elements = table.create(self._len)
	for i = 1, self._len do
		elements[i] = read(self, i - 1)
	end
	return elements
end

-- Grows a slice to accommodate at least *num* more elements. The capacity of
-- the new slice is calculated based on the old slice to balance memory usage
-- with the frequency of grows. Grows by 2x for small slices, gradually reducing
-- to 1.25x for larger slices.
local function grow<T>(old: slice<T>, num: number): slice<T>
	local oldLen = old._len
	local oldCap = old._cap
	local newLen = oldLen + num
	if newLen < 0 then
		error("length out of range", 2)
	end
	if old._type.size == 0 then
		return newSlice(ZERO_BASE, old._type, 0, newLen, newLen)
	end

	local newcap = oldCap
	local doublecap = newcap + newcap
	if newLen > doublecap then
		newcap = newLen
	else
		local threshold = 256
		if oldCap < threshold then
			newcap = doublecap
		else
			-- Check 0 < newcap to detect overflow and prevent an infinite loop.
			while 0 < newcap and newcap < newLen do
				-- Transition from growing 2x for small slices to growing 1.25x
				-- for large slices. This formula gives a smooth-ish transition
				-- between the two.
				newcap += (newcap + 3*threshold) // 4
			end
			-- Set newcap to the requested cap when the newcap calculation
			-- overflowed.
			if newcap <= 0 then
				newcap = newLen
			end
		end
	end

	local lenmem = oldLen * old._type.size
	local capmem, overflow = multiply_ptr(old._type.size, newcap)
	newcap = capmem // old._type.size
	capmem = newcap * old._type.size

	if overflow or capmem > MAX_ALLOC then
		error("len out of range", 3)
	end

	local array = buffer.create(capmem)
	buffer.copy(array, 0, old._array, old._ptr, lenmem)
	-- The current slice is being grown rather than the base slice, so any data
	-- preceding the range of the slice is irrelevant, and _ptr is set to 0 for
	-- the new array.
	return newSlice(array, old._type, 0, newLen, newcap)
end

--@sec: Slices.append
--@def: function Slices.append<T>(self: Slice<T>, ...: T): Slice<T>
--@doc: Appends elements to a slice, growing the slice if necessary.
--
-- If the slice has enough capacity to contain the received elements, then they
-- are appended to the slice, and a slice with the same backing array is
-- returned. If the capacity is not large enough, then the current array is
-- untouched, and a new array is allocated with a length that is large enough to
-- contain the elements.
--
-- Appending only returns the same slice if no elements are passed. As such, the
-- previous slice should usually be replaced by the new slice:
--
-- ```lua
-- slice = Slices.append(slice, 1, 2, 3)
-- ```
function export.append<T>(self: Slice<T>, ...: T): Slice<T>
	local self = to_slice(self)
	local n = select("#", ...)
	if n == 0 then
		return from_slice(self)
	end
	local len = self._len
	if self._cap - len < n then
		-- Not large enough, so replace with a slice that has a larger buffer.
		self = grow(self, n)
	else
		-- Slice is frozen, so replace with slice that has new length.
		self = newSlice(self._array, self._type, self._ptr, len + n, self._cap)
	end

	for i = 1, n do
		local v = select(i, ...)
		write(self, len + i-1, v)
	end
	return from_slice(self)
end

--@sec: Slices.join
--@def: function Slices.join<T>(self: Slice<T>, ...: Slice<T>): Slice<T>
--@doc: Appends to *self* each element from the remaining arguments.
--
-- ```lua
-- local slice = Slices.join(sliceA, sliceB, sliceC)
-- ```
function export.join<T>(self: Slice<T>, ...: Slice<T>): Slice<T>
	local self = to_slice(self)
	local count = select("#", ...)
	if count == 0 then
		return from_slice(self)
	end
	local n = 0
	for i = 1, count do
		n += to_slice((select(i, ...)))._len
	end
	if n == 0 then
		return from_slice(self)
	end

	local len = self._len
	if self._cap - len < n then
		-- Not large enough, so replace with a slice that has a larger buffer.
		self = grow(self, n)
	else
		-- Slice is frozen, so replace with slice that has new length.
		self = newSlice(self._array, self._type, self._ptr, len + n, self._cap)
	end

	local i = len
	for a = 1, count do
		local slice = to_slice_nop((select(a, ...)))
		for j = 0, slice._len-1 do
			write(self, i, read(slice, j))
			i += 1
		end
	end
	return from_slice(self)
end

--@sec: Slices.from
--@def: function Slices.from<T>(make: Make<T>, ...: T): Slice<T>
--@doc: Returns a slice according to *make*, containing elements from the
-- remaining arguments.
--
-- ```lua
-- local slice = Slices.from(Slices.make.u8, 1, 2, 3, 4)
-- ```
function export.from<T>(make: Make<T>, ...: T): Slice<T>
	assert(type(make) == "function", "make must be a function")

	local n = select("#", ...)
	local self = to_slice(make(n))
	assert(getmetatable(self::any) == Slice, "make must return a slice")
	assert(self._len <= n, "make returned a slice with an unexpected length")
	for i = 1, n do
		local v = select(i, ...)
		write(self, i-1, v)
	end
	return from_slice(self)
end

--@sec: Slices.fromTable
--@def: function Slices.fromTable<T>(make: Make<T>, t: {T}): Slice<T>
--@doc: Returns a slice according to *make*, containing elements from *t*.
--
-- ```lua
-- local slice = Slices.fromTable(Slices.make.u8, {1, 2, 3, 4})
-- ```
function export.fromTable<T>(make: Make<T>, t: {T}): Slice<T>
	assert(type(make) == "function", "make must be a function")
	assert(type(t) == "table", "t must be a table")

	local n = #t
	local self = to_slice(make(n))
	assert(getmetatable(self::any) == Slice, "make must return a slice")
	assert(self._len <= n, "make returned a slice with an unexpected length")
	for i, v in t do
		write(self, i-1, v)
	end
	return from_slice(self)
end

--@sec: Slices.maker
--@def: function Slices.maker<T>(def: Definition<T>): Make<T>
--@doc: Returns a [make][Make] function that creates a slice of the type defined
--by [def][Definition].
--
-- ```lua
-- local makeU32 = export.maker({
-- 	name = "u32",
-- 	size = 4,
-- 	read = function(a: buffer, index: number): number
-- 		return buffer.readu32(a, index)
-- 	end,
-- 	write = function(a: buffer, index: number, value: number)
-- 		buffer.writeu32(a, index, value)
-- 	end,
-- })
-- ```
function export.maker<T>(def: Definition<T>): Make<T>
	local name = def.name
	assert(type(name) == "string", "name must be a string")

	local size = def.size
	assert(type(size) == "number", "size must be a number")
	assert(size >= 0, "size must be greater than or equal to zero")
	size //= 1

	local read = def.read
	assert(type(read) == "function", "read must be a function")

	local write = def.write
	assert(type(write) == "function", "write must be a function")

	local typedef: typedef<T>
	typedef = table.freeze({
		name = name,
		size = size,
		read = read,
		write = write,
		make = function(len: number?, cap: number?): Slice<T>
			local len = (len or 0) // 1
			local cap = (cap or len) // 1
			local mem, overflow = multiply_ptr(size, cap)
			if overflow or mem > MAX_ALLOC or len < 0 or len > cap then
				local mem, overflow = multiply_ptr(size, len)
				if overflow or mem > MAX_ALLOC or len < 0 then
					error("length out of range", 2)
				end
				error("capacity out of range", 2)
			end
			local array
			if mem == 0 then
				array = ZERO_BASE
			else
				array = buffer.create(mem)
			end
			return from_slice(newSlice(array, typedef, 0, len, cap))
		end,
	})

	return typedef.make
end

--@sec: Slices.make
--@ord: -1
--@doc: Contains constructors for creating new slices of specific types. The
-- following types are included:
--
-- Name    | Element type
-- --------|-------------
-- i8      | 8-bit signed integer
-- u8      | 8-bit unsigned integer
-- i16     | 16-bit signed integer
-- u16     | 16-bit unsigned integer
-- i32     | 32-bit signed integer
-- u32     | 32-bit unsigned integer
-- f32     | 32-bit floating point number
-- f64     | 64-bit floating point number
-- boolean | Boolean truth value, one per byte
-- Vector3 | Vector3 value
--
-- Each constructor is a [Make][Make] function.
--
-- ```lua
-- local sliceU8 = Slices.make.u8(3) -- Slice of 3 8-bit unsigned integers.
-- local sliceV3 = Slices.make.Vector3(4) -- Slice of 4 Vector3 values.
-- ```
export.make = {}

export.make.i8 = export.maker({
	name = "i8",
	size = 1,
	read = function(a: buffer, index: number): number
		return buffer.readi8(a, index)
	end,
	write = function(a: buffer, index: number, value: number)
		buffer.writei8(a, index, value)
	end,
})

export.make.u8 = export.maker({
	name = "u8",
	size = 1,
	read = function(a: buffer, index: number): number
		return buffer.readu8(a, index)
	end,
	write = function(a: buffer, index: number, value: number)
		buffer.writeu8(a, index, value)
	end,
})

export.make.i16 = export.maker({
	name = "i16",
	size = 2,
	read = function(a: buffer, index: number): number
		return buffer.readi16(a, index)
	end,
	write = function(a: buffer, index: number, value: number)
		buffer.writei16(a, index, value)
	end,
})

export.make.u16 = export.maker({
	name = "u16",
	size = 2,
	read = function(a: buffer, index: number): number
		return buffer.readu16(a, index)
	end,
	write = function(a: buffer, index: number, value: number)
		buffer.writeu16(a, index, value)
	end,
})

export.make.i32 = export.maker({
	name = "i32",
	size = 4,
	read = function(a: buffer, index: number): number
		return buffer.readi32(a, index)
	end,
	write = function(a: buffer, index: number, value: number)
		buffer.writei32(a, index, value)
	end,
})

export.make.u32 = export.maker({
	name = "u32",
	size = 4,
	read = function(a: buffer, index: number): number
		return buffer.readu32(a, index)
	end,
	write = function(a: buffer, index: number, value: number)
		buffer.writeu32(a, index, value)
	end,
})

export.make.f32 = export.maker({
	name = "f32",
	size = 4,
	read = function(a: buffer, index: number): number
		return buffer.readf32(a, index)
	end,
	write = function(a: buffer, index: number, value: number)
		buffer.writef32(a, index, value)
	end,
})

export.make.f64 = export.maker({
	name = "f64",
	size = 8,
	read = function(a: buffer, index: number): number
		return buffer.readf64(a, index)
	end,
	write = function(a: buffer, index: number, value: number)
		buffer.writef64(a, index, value)
	end,
})

export.make.boolean = export.maker({
	name = "boolean",
	size = 1,
	read = function(a: buffer, index: number): boolean
		return buffer.readu8(a, index) ~= 0
	end,
	write = function(a: buffer, index: number, value: boolean)
		buffer.writeu8(a, index, (if value then 1 else 0))
	end,
})

if Vector3 then
	export.make.Vector3 = export.maker({
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
	})
end

table.freeze(export.make)

return table.freeze(export)
