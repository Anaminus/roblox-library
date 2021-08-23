-- GetFlags parses its arguments like command-line options. Returns a table
-- where each flag is mapped to a value in the dictionary part, and values with
-- no flag are appended to the array part.
--
-- The following rules determine how flags are parsed:
--
-- - A flag is a string argument that begins with "--" or "-". The name of a
--   flag is the string without the preceding "--" or "-".
-- - When a flag is followed by a non-flag, the name of the flag is mapped to
--   the non-flag.
-- - When a flag is not followed by a non-flag, the flag name is mapped to true.
-- - When a non-flag is not preceded by a flag, it is appended to the result.
local function GetFlags(...)
	local result = {}
	local args = table.pack(...)
	local i = 1
	local key = nil
	while i <= args.n do
		local arg = args[i]
		local name
		if type(arg) == "string" then
			name = arg:match("^%-%-?(.*)$")
		end
		if key then
			if name then
				result[key] = true
			else
				result[key] = arg
				i = i + 1
			end
			key = nil
		else
			key = name
			if not key then
				table.insert(result, arg)
			end
			i = i + 1
		end
	end
	if key then
		result[key] = true
	end
	return result
end
