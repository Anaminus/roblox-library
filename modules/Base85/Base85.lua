--@sec: Base85
--@doc: Implements Base85 encoding similar to [Ascii85][Ascii85].
--
-- The encoding is based off of [RFC 1924][RFC1924], which is suitable for JSON
-- strings. Sequences of particular bytes (such as `\0\0\0\0\0`) are not encoded
-- exceptionally. Wrappers (such as `<~ ... ~>`) are neither added nor expected.
--
-- [Ascii85]: https://en.wikipedia.org/wiki/Ascii85
-- [RFC1924]: https://tools.ietf.org/html/rfc1924
local Base85 = {}

local encodeTable = {
	"0", "1", "2", "3", "4",
	"5", "6", "7", "8", "9",
	"A", "B", "C", "D", "E",
	"F", "G", "H", "I", "J",
	"K", "L", "M", "N", "O",
	"P", "Q", "R", "S", "T",
	"U", "V", "W", "X", "Y",
	"Z", "a", "b", "c", "d",
	"e", "f", "g", "h", "i",
	"j", "k", "l", "m", "n",
	"o", "p", "q", "r", "s",
	"t", "u", "v", "w", "x",
	"y", "z", "!", "#", "$",
	"%", "&", "(", ")", "*",
	"+", "-", ";", "<", "=",
	">", "?", "@", "^", "_",
	"`", "{", "|", "}", "~",
}

--@sec: Base85.encode
--@def: Base85.encode(source: string): (data: string)
--@doc: encode returns the data encoded from source.
function Base85.encode(source)
	local i = 1
	local j = 1
	local data = table.create(math.floor((#source+3)/4)*5)
	while i <= #source do
		local a, b, c, d = string.byte(source, i, i+3)
		local n = (a or 0)*16777216 + (b or 0)*65536 + (c or 0)*256 + (d or 0)
		for k = 4, 0, -1 do
			data[j+k] = encodeTable[math.floor(n%85)+1]
			n = math.floor(n/85)
		end
		i = i + 4
		j = j + 5
	end
	for i = 1, i-#source-1 do
		data[j-i] = nil
	end
	return table.concat(data)
end

local decodeTable = {
	-- Base85 characters.
	[ 48]= 0, [ 49]= 1, [ 50]= 2, [ 51]= 3, [ 52]= 4,
	[ 53]= 5, [ 54]= 6, [ 55]= 7, [ 56]= 8, [ 57]= 9,
	[ 65]=10, [ 66]=11, [ 67]=12, [ 68]=13, [ 69]=14,
	[ 70]=15, [ 71]=16, [ 72]=17, [ 73]=18, [ 74]=19,
	[ 75]=20, [ 76]=21, [ 77]=22, [ 78]=23, [ 79]=24,
	[ 80]=25, [ 81]=26, [ 82]=27, [ 83]=28, [ 84]=29,
	[ 85]=30, [ 86]=31, [ 87]=32, [ 88]=33, [ 89]=34,
	[ 90]=35, [ 97]=36, [ 98]=37, [ 99]=38, [100]=39,
	[101]=40, [102]=41, [103]=42, [104]=43, [105]=44,
	[106]=45, [107]=46, [108]=47, [109]=48, [110]=49,
	[111]=50, [112]=51, [113]=52, [114]=53, [115]=54,
	[116]=55, [117]=56, [118]=57, [119]=58, [120]=59,
	[121]=60, [122]=61, [ 33]=62, [ 35]=63, [ 36]=64,
	[ 37]=65, [ 38]=66, [ 40]=67, [ 41]=68, [ 42]=69,
	[ 43]=70, [ 45]=71, [ 59]=72, [ 60]=73, [ 61]=74,
	[ 62]=75, [ 63]=76, [ 64]=77, [ 94]=78, [ 95]=79,
	[ 96]=80, [123]=81, [124]=82, [125]=83, [126]=84,
	-- Skipped spacing.
	[  9]=-1, [ 10]=-1, [ 11]=-1, [ 12]=-1, [ 13]=-1,
	[ 32]=-1, [133]=-1, [160]=-1,
}

--@sec: Base85.decode
--@def: Base85.decode(source: string): (err: error, data: string)
--@doc: decode returns the data decoded from source. Returns an error if the
-- source contains invalid base85 data or invalid bytes. Bytes that are spaces
-- are ignored.
function Base85.decode(source)
	local data = table.create(math.floor(#source*4/5))
	local bytes = 0
	local value = 0
	for i = 1, #source do
		local b = decodeTable[string.byte(source, i)]
		if not b then
			return "invalid byte at " .. i, ""
		elseif b >= 0 then
			value = value*85 + b
			bytes = bytes + 1
			if bytes == 5 then
				table.insert(data, string.char(
					math.floor(value/16777216%256),
					math.floor(value/65536%256),
					math.floor(value/256%256),
					math.floor(value%256)
				))
				bytes = 0
				value = 0
			end
		end
	end
	if bytes > 0 then
		if bytes == 1 then
			return "corrupted base85 data at byte " .. #data-1, ""
		end
		for i = bytes, 4 do
			value = value*85 + 84
		end
		for i = 0, bytes-2 do
			table.insert(data, string.char(math.floor(value/16777216%256)))
			value = value * 256
		end
	end
	return nil, table.concat(data)
end

return Base85
