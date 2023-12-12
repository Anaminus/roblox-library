--!strict
--!optimize 2

local Spek = require(script.Parent.Parent.Spek)
local Slices = require(script.Parent)

return function(t: Spek.T)
	local describe = t.describe
	local before_each = t.before_each
	local it = t.it
	local expect = t.expect
	local expect_error = t.expect_error

	describe "maker" (function()
		it "should return a function with a valid Definition" (function()
			expect(function()
				return type(Slices.maker{
					name = "",
					size = 1,
					read = function()return 0 end,
					write = function()end,
				}) == "function"
			end)
		end)
		it "should fail if Definition.name is not a string" (function()
			expect_error(function()
				return (Slices.maker::any){
					name = nil,
					size = 1,
					read = function()return 0 end,
					write = function()end,
				}
			end)
		end)
		it "should fail if Definition.size is not a number" (function()
			expect_error(function()
				return (Slices.maker::any){
					name = "",
					size = nil,
					read = function()return 0 end,
					write = function()end,
				}
			end)
		end)
		it "should fail if Definition.size is less than zero" (function()
			expect_error(function()
				return (Slices.maker::any){
					name = "",
					size = -1,
					read = function()return 0 end,
					write = function()end,
				}
			end)
		end)
		it "should allow Definition.size to be zero" (function()
			expect(function()
				return Slices.maker{
					name = "",
					size = 0,
					read = function()return 0 end,
					write = function()end,
				} ~= nil
			end)
		end)
		it "should fail if Definition.read is not a function" (function()
			expect_error(function()
				return (Slices.maker::any){
					name = "",
					size = 1,
					read = nil,
					write = function()end,
				}
			end)
		end)
		it "should fail if Definition.write is not a function" (function()
			expect_error(function()
				return (Slices.maker::any){
					name = "",
					size = 1,
					read = function()return 0 end,
					write = nil,
				}
			end)
		end)
	end)

	local make = Slices.maker({
		name = "v2",
		size = 2,
		read = function(a: buffer, i: number): number
			return buffer.readu16(a, i)
		end,
		write = function(a: buffer, i: number, v: number)
			buffer.writeu16(a, i, v)
		end,
	})
	local function range(n: number): Slices.Slice<number>
		local s = make(n)
		for i = 0, n-1 do
			Slices.write(s, i, i)
		end
		return s
	end

	describe "is" (function()
		it "should return true when argument is a slice" (function()
			expect(function()
				return Slices.is(make()) == true
			end)
		end)
		it "should return false when argument is not a slice" (function()
			expect(function()
				return Slices.is({}) == false
			end)
		end)
		it "can receive no arguments" (function()
			expect(function()
				return Slices.is() == false
			end)
		end)
	end)

	describe "make" (function()
		it "should return a slice" (function()
			expect(function()
				return Slices.is(make())
			end)
		end)
		it "should set length and capacity to zero with no arguments" (function()
			local s = make()
			expect(function()
				return Slices.len(s) == 0 and Slices.cap(s) == 0
			end)
		end)
		it "should allow one length argument that also sets capacity" (function()
			local s = make(42)
			expect(function()
				return Slices.len(s) == 42 and Slices.cap(s) == 42
			end)
		end)
		it "should allow length and capacity argument" (function()
			local s = make(0, 42)
			expect(function()
				return Slices.len(s) == 0 and Slices.cap(s) == 42
			end)
		end)
		it "should round non-integer length" (function()
			local s = make(3.14159)
			expect(function()
				return Slices.len(s) == 3
			end)
		end)
		it "should round non-integer capacity" (function()
			local s = make(2, 3.14159)
			expect(function()
				return Slices.cap(s) == 3
			end)
		end)
		it "should fail if length is less than zero" (function()
			expect_error(function()
				make(-1)
			end)
		end)
		it "should fail if length is greater than capacity" (function()
			expect_error(function()
				make(3, 2)
			end)
		end)
		it "should fail if capacity*size exceeds max buffer length" (function()
			local N = 2^15
			-- Attempt to allocate N elements, each of size N.
			expect_error(function()
				Slices.maker({
					name = "",
					size = N,
					read = function() return 0 end,
					write = function() end,
				})(N)
			end)
		end)
	end)

	describe "len" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.len::any)()
			end)
		end)
		it "should return the length of a slice" (function()
			expect(function()
				return Slices.len(make()) == 0
			end)
			expect(function()
				return Slices.len(make(42)) == 42
			end)
			expect(function()
				return Slices.len(make(42, 50)) == 42
			end)
		end)
	end)

	describe "cap" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.cap::any)()
			end)
		end)
		it "should return the capacity of a slice" (function()
			expect(function()
				return Slices.cap(make()) == 0
			end)
			expect(function()
				return Slices.cap(make(42)) == 42
			end)
			expect(function()
				return Slices.cap(make(42, 50)) == 50
			end)
		end)
	end)

	describe "iter" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.iter::any)()
			end)
		end)
		it "should enable iteration over a slice" (function()
			local s = range(10)
			for i, v in Slices.iter(s) do
				expect(function()
					return v == i
				end)
			end
		end)
	end)

	describe "read" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.read::any)()
			end)
		end)
		it "should fail when second argument is not a number" (function()
			expect_error(function()
				(Slices.read::any)(make(1), "")
			end)
		end)
		it "should fail when index is less than zero" (function()
			expect_error(function()
				Slices.read(make(1), -1)
			end)
		end)
		it "should fail when index is greater than or equal to slice length" (function()
			expect_error(function()
				Slices.read(make(10), 10)
			end)
			expect_error(function()
				Slices.read(make(10), 11)
			end)
		end)
		it "should return value at index" (function()
			local s = range(10)
			for i = 0, 9 do
				expect(function()
					return Slices.read(s, i) == i
				end)
			end
		end)
	end)

	describe "write" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.write::any)()
			end)
		end)
		it "should fail when second argument is not a number" (function()
			expect_error(function()
				(Slices.write::any)(make(1), "")
			end)
		end)
		it "should fail when index is less than zero" (function()
			expect_error(function()
				Slices.write(make(1), -1, 0)
			end)
		end)
		it "should fail when index is greater than or equal to slice length" (function()
			expect_error(function()
				Slices.write(make(10), 10, 0)
			end)
			expect_error(function()
				Slices.write(make(10), 11, 0)
			end)
		end)
		it "should write value at index" (function()
			local s = make(10)
			for i = 0, 9 do
				Slices.write(s, i, i)
				expect(function()
					return Slices.read(s, i) == i
				end)
			end
		end)
	end)

	local function expect_slice<T>(s: Slices.Slice<T>, e: {T}, cap: number?)
		expect "length" (function()
			return Slices.len(s) == #e
		end)
		if cap then
			expect "capacity" (function()
				return Slices.cap(s) == cap
			end)
		end
		for i, v in e do
			expect (`slice[{i}] == {v}`) (function()
				return Slices.read(s, i-1) == v
			end)
		end
	end

	describe "slice" (function()
		local s
		before_each(function()
			s = make(4, 8)
			for i = 0, 3 do
				Slices.write(s, i, i)
			end
		end)
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.slice::any)()
			end)
		end)
		it "arguments (nil, nil , nil) slice to [0  :len :cap]" (function()
			expect_slice(Slices.slice(s), {0, 1, 2, 3}, 8)
		end)
		it "arguments (low, nil , nil) slice to [low:len :cap]" (function()
			expect_slice(Slices.slice(s, 1), {1, 2, 3}, 7)
		end)
		it "arguments (nil, high, nil) slice to [0  :high:cap]" (function()
			expect_slice(Slices.slice(s, nil, 3), {0, 1, 2}, 8)
		end)
		it "arguments (low, high, nil) slice to [low:high:cap]" (function()
			expect_slice(Slices.slice(s, 1, 3), {1, 2}, 7)
		end)
		it "arguments (nil, nil , max) slice to [0  :len :max]" (function()
			expect_slice(Slices.slice(s, nil, nil, 7), {0, 1, 2, 3}, 7)
		end)
		it "arguments (low, nil , max) slice to [low:len :max]" (function()
			expect_slice(Slices.slice(s, 1, nil, 7), {1, 2, 3}, 6)
		end)
		it "arguments (nil, high, max) slice to [0  :high:max]" (function()
			expect_slice(Slices.slice(s, nil, 3, 7), {0, 1, 2}, 7)
		end)
		it "arguments (low, high, max) slice to [low:high:max]" (function()
			expect_slice(Slices.slice(s, 1, 3, 7), {1, 2}, 6)
		end)
		it "should allow growing within capacity" (function()
			expect_slice(Slices.slice(s, nil, 7), {0, 1, 2, 3, 0, 0, 0}, 8)
		end)
		it "should fail when low is less than zero" (function()
			expect_error(function()
				Slices.slice(s, -1)
			end)
		end)
		it "should fail when high is less than low" (function()
			expect_error(function()
				Slices.slice(s, 2, 1)
			end)
		end)
		it "should fail when high is greater than max" (function()
			expect_error(function()
				Slices.slice(s, nil, 4, 3)
			end)
		end)
		it "should fail when max is greater than capacity" (function()
			expect_error(function()
				Slices.slice(s, nil, nil, 9)
			end)
		end)
		it "should produce a slice with the same backing array" (function()
			local a = Slices.slice(s, 1)
			Slices.write(a, 0, 42)
			expect_slice(s, {0, 42, 2, 3}, 8)
		end)
	end)

	describe "clear" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.clear::any)()
			end)
		end)
		it "should set all bytes to zero" (function()
			local s = range(5)
			Slices.clear(s)
			expect_slice(s, {0, 0, 0, 0, 0}, 5)
		end)
		it "should only set bytes within the range of the slice" (function()
			local s = range(5)
			Slices.clear(Slices.slice(s, 2, 4))
			expect_slice(s, {0, 1, 0, 0, 4}, 5)
		end)
	end)

	describe "fill" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.fill::any)()
			end)
		end)
		it "should set all elements to the given value" (function()
			local s = range(5)
			Slices.fill(s, 10)
			expect_slice(s, {10, 10, 10, 10, 10}, 5)
		end)
		it "should only set bytes within the range of the slice" (function()
			local s = range(5)
			Slices.fill(Slices.slice(s, 2, 4), 10)
			expect_slice(s, {0, 1, 10, 10, 4}, 5)
		end)
	end)

	describe "copy" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.copy::any)()
			end)
		end)
		it "should fail when second argument is not a slice" (function()
			expect_error(function()
				(Slices.copy::any)(make(1))
			end)
		end)
		it "should copy elements from source to destination" (function()
			local dst = make(4)
			local src = range(4)
			expect "number of copied elements" (function()
				return Slices.copy(dst, src) == 4
			end)
			expect_slice(dst, {0,1,2,3})
		end)
		it "should copy elements only from the source range" (function()
			local dst = make(4)
			local src = range(8)
			expect "number of copied elements" (function()
				return Slices.copy(dst, Slices.slice(src, 2, 6)) == 4
			end)
			expect_slice(dst, {2,3,4,5})
		end)
		it "should copy elements only to the destination range" (function()
			local dst = make(8)
			local src = range(4)
			expect "number of copied elements" (function()
				return Slices.copy(Slices.slice(dst, 2, 6), src) == 4
			end)
			expect_slice(dst, {0,0,0,1,2,3,0,0})
		end)
		it "should copy only up to the length of the destination" (function()
			local dst = make(4)
			local src = range(8)
			expect "number of copied elements" (function()
				return Slices.copy(dst, src) == 4
			end)
			expect_slice(dst, {0,1,2,3})
		end)
		it "should copy only up to the length of the source" (function()
			local dst = make(8)
			local src = range(4)
			expect "number of copied elements" (function()
				return Slices.copy(dst, src) == 4
			end)
			expect_slice(dst, {0,1,2,3,0,0,0,0})
		end)
		it "should return how many elements were copied" (function()
			local dst = make(8)
			local src = range(4)
			expect(function()
				return Slices.copy(dst, src) == 4
			end)
		end)
		it "should return zero if no elements were copied" (function()
			local dst = make(8)
			local src = range(4)
			expect(function()
				return Slices.copy(Slices.slice(dst, 0, 0), src) == 0
			end)
			expect(function()
				return Slices.copy(dst, Slices.slice(src, 0, 0)) == 0
			end)
		end)
	end)

	describe "to" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.to::any)()
			end)
		end)
		it "should unpack the elements of the slice" (function()
			local a, b, c, d = Slices.to(range(4))
			expect(function() return a == 0 end)
			expect(function() return b == 1 end)
			expect(function() return c == 2 end)
			expect(function() return d == 3 end)
		end)
	end)

	describe "toTable" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.toTable::any)()
			end)
		end)
		it "should return a table containing each element" (function()
			local t = Slices.toTable(range(4))
			expect(function() return t[1] == 0 end)
			expect(function() return t[2] == 1 end)
			expect(function() return t[3] == 2 end)
			expect(function() return t[4] == 3 end)
		end)
	end)

	describe "append" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.append::any)()
			end)
		end)
		it "should append elements to the end of the slice" (function()
			local s = Slices.from(make, 0,1,2,3)
			expect_slice(Slices.append(s,10,11,12), {0,1,2,3,10,11,12})
		end)
		it "should grow the slice to accommodate values" (function()
			local s = make()
			expect_slice(s, {})
			s = Slices.append(s, 0,1,2,3)
			expect_slice(s, {0,1,2,3})
			s = Slices.append(s, 10,11,12,13)
			expect_slice(s, {0,1,2,3,10,11,12,13})
			s = Slices.append(s, 20,21,22,23)
			expect_slice(s, {0,1,2,3,10,11,12,13,20,21,22,23})
		end)
		it "should have the same backing array when not grown" (function()
			local a = make(2,5)
			expect_slice(a, {0,0}, 5)
			local b = Slices.append(a, 1,2)
			expect_slice(b, {0,0,1,2}, 5)
		end)
		it "should have a different backing array when grown" (function()
			local a = make(2,5)
			expect_slice(a, {0,0}, 5)
			local b = Slices.append(a, 1,2,3,4)
			expect_slice(b, {0,0,1,2,3,4})
			expect(function()
				return Slices.cap(b) > Slices.cap(a)
			end)
			Slices.write(b, 1, 10)
			expect_slice(a, {0,0})
			expect_slice(b, {0,10,1,2,3,4})
		end)
	end)

	describe "join" (function()
		it "should fail when first argument is not a slice" (function()
			expect_error(function()
				(Slices.join::any)()
			end)
		end)
		it "should append elements from each slice in order" (function()
			local a = Slices.from(make, 0, 1, 2, 3)
			local b = Slices.from(make, 10, 11, 12)
			local c = Slices.from(make, 20, 21)
			local d = Slices.from(make, 30, 31, 32, 33)
			local s = Slices.join(a, b, c, d)
			expect_slice(s, {0,1,2,3,10,11,12,20,21,30,31,32,33})
		end)
		it "should allow joining the same slice" (function()
			local a = Slices.from(make, 0, 1, 2, 3)
			expect_slice(Slices.join(a, a), {0,1,2,3,0,1,2,3})
		end)
		it "should allow joining from the same subslice" (function()
			local a = Slices.from(make, 0, 1, 2, 3)
			local b = Slices.slice(a, 1, 3)
			expect_slice(Slices.join(b, a), {1,2,0,1,2,3})
		end)
	end)

	describe "from" (function()
		it "should fail if the first argument is not a function" (function()
			expect_error(function()
				(Slices.from::any)()
			end)
		end)
		it "should fail if the make function does not return a slice" (function()
			expect_error(function()
				Slices.from(function() return nil::any end)
			end)
		end)
		it "should create a slice with a length that is at least the number of additional arguments" (function()
			local s = Slices.from(make, 1, 2, 3)
			expect(function()
				return Slices.len(s) >= 3
			end)
		end)
		it "should set each argument as an element to the slice" (function()
			local s = Slices.from(make, 1, 2, 3)
			expect_slice(s, {1,2,3})
		end)
	end)

	describe "fromTable" (function()
		it "should fail if the first argument is not a function" (function()
			expect_error(function()
				(Slices.fromTable::any)()
			end)
		end)
		it "should fail if the second argument is not a table" (function()
			expect_error(function()
				(Slices.fromTable::any)(make)
			end)
		end)
		it "should fail if the make function does not return a slice" (function()
			expect_error(function()
				Slices.fromTable(function() return nil::any end, {})
			end)
		end)
		it "should create a slice with a length that is at least the length of the table" (function()
			local s = Slices.fromTable(make, {1, 2, 3})
			expect(function()
				return Slices.len(s) >= 3
			end)
		end)
		it "should set each table element as an element to the slice" (function()
			local t = {1,2,3}
			local s = Slices.fromTable(make, t)
			expect_slice(s, t)
		end)
	end)

	describe "Slice.__len" (function()
		it "should return the length of a slice" (function()
			expect(function()
				return #make() == 0
			end)
			expect(function()
				return #make(42) == 42
			end)
			expect(function()
				return #make(42, 50) == 42
			end)
		end)
	end)

	describe "Slice.__index" (function()
		it "should fail when index is not a number" (function()
			expect_error(function()
				local _ = (make()::any)[""]
			end)
		end)
		it "should fail when index is less than zero" (function()
			expect_error(function()
				local _ = make()[-1]
			end)
		end)
		it "should fail when index is greater than or equal to slice length" (function()
			expect_error(function()
				local _ = make(10)[10]
			end)
			expect_error(function()
				local _ = make(10)[11]
			end)
		end)
		it "should return value at index" (function()
			local s = range(10)
			for i = 0, 9 do
				expect(function()
					return s[i] == i
				end)
			end
		end)
	end)

	describe "Slice.__newindex" (function()
		it "should fail when index is not a number" (function()
			expect_error(function()
				(make(1)::any)[""] = 0
			end)
		end)
		it "should fail when index is less than zero" (function()
			expect_error(function()
				make(1)[-1] = 0
			end)
		end)
		it "should fail when index is greater than or equal to slice length" (function()
			expect_error(function()
				make(10)[10] = 0
			end)
			expect_error(function()
				make(10)[11] = 0
			end)
		end)
		it "should write value at index" (function()
			local s = make(10)
			for i = 0, 9 do
				s[i] = i
				expect(function()
					return Slices.read(s, i) == i
				end)
			end
		end)
	end)

	describe "Slice.__call" (function()
		local s
		before_each(function()
			s = make(4, 8)
			for i = 0, 3 do
				Slices.write(s, i, i)
			end
		end)
		it "arguments (nil, nil , nil) slice to [0  :len :cap]" (function()
			expect_slice(s(), {0, 1, 2, 3}, 8)
		end)
		it "arguments (low, nil , nil) slice to [low:len :cap]" (function()
			expect_slice(s(1), {1, 2, 3}, 7)
		end)
		it "arguments (nil, high, nil) slice to [0  :high:cap]" (function()
			expect_slice(s(nil, 3), {0, 1, 2}, 8)
		end)
		it "arguments (low, high, nil) slice to [low:high:cap]" (function()
			expect_slice(s(1, 3), {1, 2}, 7)
		end)
		it "arguments (nil, nil , max) slice to [0  :len :max]" (function()
			expect_slice(s(nil, nil, 7), {0, 1, 2, 3}, 7)
		end)
		it "arguments (low, nil , max) slice to [low:len :max]" (function()
			expect_slice(s(1, nil, 7), {1, 2, 3}, 6)
		end)
		it "arguments (nil, high, max) slice to [0  :high:max]" (function()
			expect_slice(s(nil, 3, 7), {0, 1, 2}, 7)
		end)
		it "arguments (low, high, max) slice to [low:high:max]" (function()
			expect_slice(s(1, 3, 7), {1, 2}, 6)
		end)
		it "should allow growing within capacity" (function()
			expect_slice(s(nil, 7), {0, 1, 2, 3, 0, 0, 0}, 8)
		end)
		it "should fail when low is less than zero" (function()
			expect_error(function()
				s(-1)
			end)
		end)
		it "should fail when high is less than low" (function()
			expect_error(function()
				s(2, 1)
			end)
		end)
		it "should fail when high is greater than max" (function()
			expect_error(function()
				s(nil, 4, 3)
			end)
		end)
		it "should fail when max is greater than capacity" (function()
			expect_error(function()
				s(nil, nil, 9)
			end)
		end)
		it "should produce a slice with the same backing array" (function()
			local a = s(1)
			Slices.write(a, 0, 42)
			expect_slice(s, {0, 42, 2, 3}, 8)
		end)
	end)

	describe "Slice.__iter" (function()
		it "should enable iteration over a slice" (function()
			local s = range(10)
			for i, v in s do
				expect(function()
					return v == i
				end)
			end
		end)
	end)

	describe "built-in data types" (function()
		local function roundtrip<T>(mk: Slices.Make<T>, v: any, to: any)
			it (`should roundtrip value {v} to {to}`) (function()
				local s = mk(1)
				Slices.write(s, 0, v)
				expect(function()
					return Slices.read(s, 0) == to
				end)
			end)
		end
		local function suite<T>(mk: Slices.Make<T>, n: number)
			if n < 0 then
				n *= -1
				roundtrip(mk,  (2^n/1+1) ,  (      1))
				roundtrip(mk,  (2^n/1+0) ,  (      0))
				roundtrip(mk,  (2^n/1-1) ,  (     -1))
				roundtrip(mk,  (2^n/1-2) ,  (     -2))
				roundtrip(mk,  (2^n/2+1) , -(2^n/2-1))
				roundtrip(mk,  (2^n/2+0) , -(2^n/2+0))
				roundtrip(mk,  (2^n/2-1) ,  (2^n/2-1))
				roundtrip(mk,  (      1) ,  (      1))
				roundtrip(mk,  (      0) ,  (      0))
				roundtrip(mk,  (     -1) ,  (     -1))
				roundtrip(mk, -(2^n/2-1) , -(2^n/2-1))
				roundtrip(mk, -(2^n/2+0) , -(2^n/2+0))
				roundtrip(mk, -(2^n/2+1) ,  (2^n/2-1))
				roundtrip(mk, -(2^n/1-2) ,  (      2))
				roundtrip(mk, -(2^n/1-1) ,  (      1))
				roundtrip(mk, -(2^n/1+0) ,  (      0))
				roundtrip(mk, -(2^n/1+1) ,  (     -1))
			else
				roundtrip(mk,  (2^n/1+1) ,  (      1))
				roundtrip(mk,  (2^n/1+0) ,  (      0))
				roundtrip(mk,  (2^n/1-1) ,  (2^n/1-1))
				roundtrip(mk,  (2^n/1-2) ,  (2^n/1-2))
				roundtrip(mk,  (2^n/2+1) ,  (2^n/2+1))
				roundtrip(mk,  (2^n/2+0) ,  (2^n/2+0))
				roundtrip(mk,  (2^n/2-1) ,  (2^n/2-1))
				roundtrip(mk,  (      1) ,  (      1))
				roundtrip(mk,  (      0) ,  (      0))
				roundtrip(mk,  (     -1) ,  (2^n/1-1))
				roundtrip(mk, -(2^n/2-1) ,  (2^n/2+1))
				roundtrip(mk, -(2^n/2+0) ,  (2^n/2+0))
				roundtrip(mk, -(2^n/2+1) ,  (2^n/2-1))
				roundtrip(mk, -(2^n/1-2) ,  (      2))
				roundtrip(mk, -(2^n/1-1) ,  (      1))
				roundtrip(mk, -(2^n/1+0) ,  (      0))
				roundtrip(mk, -(2^n/1+1) ,  (2^n/1-1))
			end
		end
		describe "make.i8" (function()
			suite(Slices.make.i8, -8)
		end)

		describe "make.u8" (function()
			suite(Slices.make.u8, 8)
		end)

		describe "make.i16" (function()
			suite(Slices.make.i16, -16)
		end)

		describe "make.u16" (function()
			suite(Slices.make.u16, 16)
		end)

		describe "make.i32" (function()
			suite(Slices.make.i32, -32)
		end)

		describe "make.u32" (function()
			suite(Slices.make.u32, 32)
		end)

		local pi32 = 3.1415927410125732
		local pi64 = 3.141592653589793
		local inf = math.huge
		local nan = 0/0

		describe "make.f32" (function()
			local mk = Slices.make.f32
			roundtrip(mk, inf, inf)
			roundtrip(mk, pi64, pi32)
			roundtrip(mk, pi32, pi32)
			roundtrip(mk, 1, 1)
			roundtrip(mk, 0, 0)
			roundtrip(mk, -1, -1)
			roundtrip(mk, -pi32, -pi32)
			roundtrip(mk, -pi64, -pi32)
			roundtrip(mk, -inf, -inf)
			it (`should roundtrip NaN`) (function()
				local s = mk(1)
				Slices.write(s, 0, nan)
				expect(function()
					local v = Slices.read(s, 0)
					return v ~= v
				end)
			end)
		end)

		describe "make.f64" (function()
			local mk = Slices.make.f64
			roundtrip(mk, inf, inf)
			roundtrip(mk, pi64, pi64)
			roundtrip(mk, pi32, pi32)
			roundtrip(mk, 1, 1)
			roundtrip(mk, 0, 0)
			roundtrip(mk, -1, -1)
			roundtrip(mk, -pi32, -pi32)
			roundtrip(mk, -pi64, -pi64)
			roundtrip(mk, -inf, -inf)
			it (`should roundtrip NaN`) (function()
				local s = mk(1)
				Slices.write(s, 0, nan)
				expect(function()
					local v = Slices.read(s, 0)
					return v ~= v
				end)
			end)
		end)

		describe "make.boolean" (function()
			local mk = Slices.make.boolean
			roundtrip(mk, true, true)
			roundtrip(mk, false, false)
		end)

		if Vector3 then
			describe "make.Vector3" (function()
				local mk = Slices.make.Vector3
				roundtrip(mk, Vector3.one, Vector3.one)
				roundtrip(mk, Vector3.xAxis, Vector3.xAxis)
				roundtrip(mk, Vector3.yAxis, Vector3.yAxis)
				roundtrip(mk, Vector3.zAxis, Vector3.zAxis)
				roundtrip(mk, Vector3.zero, Vector3.zero)
				roundtrip(mk, -Vector3.one, -Vector3.one)
				roundtrip(mk, -Vector3.xAxis, -Vector3.xAxis)
				roundtrip(mk, -Vector3.yAxis, -Vector3.yAxis)
				roundtrip(mk, -Vector3.zAxis, -Vector3.zAxis)
				roundtrip(mk, -Vector3.zero, -Vector3.zero)
				roundtrip(mk, Vector3.new(1,2,3), Vector3.new(1,2,3))
				roundtrip(mk, Vector3.new(inf,inf,inf), Vector3.new(inf,inf,inf))
				it (`should roundtrip NaN`) (function()
					local s = mk(1)
					Slices.write(s, 0, Vector3.new(nan,nan,nan))
					expect(function()
						local v = Slices.read(s, 0)
						return v ~= v
					end)
				end)
			end)
		end
	end)
end
