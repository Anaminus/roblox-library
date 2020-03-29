-- UnwrapBase unwraps an integer to a given base for a given number of digits.
-- Ordered by the least significant digit first.
--
-- Examples:
--     3-digit decimal: UnwrapBase(42, 10, 3)          -- 2, 4, 0
--     8-bit binary:    UnwrapBase(85, 2, 8)           -- 1, 0, 1, 0, 1, 0, 1, 0
--     DWORD:           UnwrapBase(0xDEADBEEF, 256, 4) -- 249, 190, 173, 222
--
local function UnwrapBase(value, base, length)
	if not length then
		length = math.ceil(math.log(value+1)/math.log(base))
	end
	local output = {}
	for i = 0, (length or 1) - 1 do
		output[i+1] = math.modf(value / base^i % base)
	end
	return unpack(output)
end
