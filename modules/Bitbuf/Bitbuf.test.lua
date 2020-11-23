local T = {}

local SHOW_ERRORS = false
local SLOW = false

local function pass(t, v, msg)
	msg = msg or "expected pass"
	if type(v) == "function" then
		local ok, err = pcall(v)
		if not ok then
			t:Errorf("%s: %s", msg, err)
			return
		end
		if not err then
			t:Error(msg)
		end
	elseif not v then
		t:Errorf(msg)
	end
end

local function fail(t, v, msg)
	msg = msg or "expected fail"
	if type(v) == "function" then
		local ok, err = pcall(v)
		if ok then
			if err then
				t:Error(msg)
			end
			t:Errorf(msg)
			return
		elseif SHOW_ERRORS then
			t:Logf("ERROR: %s\n", err)
		end
	elseif v then
		t:Errorf(msg)
	end
end

local function bits(t, buf, len, bits)
	if buf:Len() ~= len then
		t:Errorf("expected length %d, got %d", len, buf:Len())
		return true
	end
	if buf:String() ~= bits then
		t:Errorf("unexpected buffer content")
		return true
	end
	return false
end

local function truncate(size, s)
	if size == 0 then
		return ""
	end
	if #s*8 <= size then
		return s
	end
	local q = math.floor(size/8)
	local r = bit32.band(string.byte(s, q+1), 2^(size%8)-1)
	r = (r == 0 and size%8 == 0) and "" or string.char(r)
	return string.sub(s, 1, q) .. r
end

local ones do
	local pow2 = {1, 3, 7, 15, 31, 63, 127}
	function ones(size)
		local r = size % 8
		if r == 0 then
			return string.rep("\255", math.floor(size/8))
		end
		return string.rep("\255", math.floor(size/8)) .. string.char(pow2[r])
	end
end

local function explode(v, size)
	size = size or #v*8
	local a = table.create(size, 0)
	for i = 0, math.floor(size/8)-1 do
		for j = 0, 7 do
			a[i*8+j+1] = bit32.extract(string.byte(v, i+1) or 0, j) == 0 and "0" or "1"
		end
	end
	local i = math.floor(size/8)
	for j = 0, size%8-1 do
		a[i*8+j+1] = bit32.extract(string.byte(v, i+1) or 0, j) == 0 and "0" or "1"
	end
	return table.concat(a, "", 1, size)
end

local function explodeBuf(buf)
	return explode(buf:String(), buf:Len())
end

-- Emits error resulting from a super test. Prepends message with "[l:i:v]: ".
local function superError(t, l, i, v, msg, ...)
	t:Errorf("[%d:%d:%d]: "..msg, l, i, v, ...)
	return true
end

local unprint = "[^\32-\126]"
local function compError(want, got)
	if string.match(want, unprint) or string.match(got, unprint) then
		want = "*" .. string.gsub(want, ".", function(c) return string.format("\\x%02X", string.byte(c)) end)
		got = "*" .. string.gsub(got, ".", function(c) return string.format("\\x%02X", string.byte(c)) end)
	end
	return "unexpected buffer content:\n\twant: %s\n\t got: %s", want, got
end

-- If string *got* does not equal *want*, emit error that displays the contents
-- of both.
local function compData(t,l,i,v, want, got)
	if got ~= want then
		return superError(t,l,i,v, compError(want, got))
	end
	return false
end

-- Exhaustively runs tests with Buffers of varying lengths and indexes. *cb*
-- receives the buffer, it's length, it's index, and a numerical value. *cb*
-- should return true if an error occurs.
local function superTest(t, Bitbuf, cb)
	local n = 0
	local a = os.clock()
	for l = 0, 64 do
		for i = 0, l do
			for v = 0, 64 do
				local buf = Bitbuf.new(l)
				buf:SetIndex(i)
				if cb(buf, l, i, v) then
					n = n + 1
				end
				if n >= 10 then
					t:Fatal("too many errors")
				end
				if os.clock()-a >= 1 then
					t:Yield()
					a = os.clock()
				end
			end
		end
	end
end

local p = string.pack
local intTests = {
	{ value =                    -4 --[[-2^ 1-2]] , bits = "\xFC\xFF\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                    -3 --[[-2^ 1-1]] , bits = "\xFD\xFF\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                    -2 --[[-2^ 1+0]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                    -1 --[[-2^ 1+1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                     0 --[[ 2^ 1-2]] , bits = "\x00\x00\x00\x00\x00\x00\x00\x00" },
	{ value =                     1 --[[ 2^ 1-1]] , bits = "\x01\x00\x00\x00\x00\x00\x00\x00" },
	{ value =                     2 --[[ 2^ 1+0]] , bits = "\x02\x00\x00\x00\x00\x00\x00\x00" },
	{ value =                     3 --[[ 2^ 1+1]] , bits = "\x03\x00\x00\x00\x00\x00\x00\x00" },
	{ value =                  -130 --[[-2^ 7-2]] , bits = "\x7E\xFF\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                  -129 --[[-2^ 7-1]] , bits = "\x7F\xFF\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                  -128 --[[-2^ 7+0]] , bits = "\x80\xFF\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                  -127 --[[-2^ 7+1]] , bits = "\x81\xFF\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                   126 --[[ 2^ 7-2]] , bits = "\x7E\x00\x00\x00\x00\x00\x00\x00" },
	{ value =                   127 --[[ 2^ 7-1]] , bits = "\x7F\x00\x00\x00\x00\x00\x00\x00" },
	{ value =                   128 --[[ 2^ 7+0]] , bits = "\x80\x00\x00\x00\x00\x00\x00\x00" },
	{ value =                   129 --[[ 2^ 7+1]] , bits = "\x81\x00\x00\x00\x00\x00\x00\x00" },
	{ value =                  -258 --[[-2^ 8-2]] , bits = "\xFE\xFE\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                  -257 --[[-2^ 8-1]] , bits = "\xFF\xFE\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                  -256 --[[-2^ 8+0]] , bits = "\x00\xFF\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                  -255 --[[-2^ 8+1]] , bits = "\x01\xFF\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                   254 --[[ 2^ 8-2]] , bits = "\xFE\x00\x00\x00\x00\x00\x00\x00" },
	{ value =                   255 --[[ 2^ 8-1]] , bits = "\xFF\x00\x00\x00\x00\x00\x00\x00" },
	{ value =                   256 --[[ 2^ 8+0]] , bits = "\x00\x01\x00\x00\x00\x00\x00\x00" },
	{ value =                   257 --[[ 2^ 8+1]] , bits = "\x01\x01\x00\x00\x00\x00\x00\x00" },
	{ value =                  -514 --[[-2^ 9-2]] , bits = "\xFE\xFD\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                  -513 --[[-2^ 9-1]] , bits = "\xFF\xFD\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                  -512 --[[-2^ 9+0]] , bits = "\x00\xFE\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                  -511 --[[-2^ 9+1]] , bits = "\x01\xFE\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                   510 --[[ 2^ 9-2]] , bits = "\xFE\x01\x00\x00\x00\x00\x00\x00" },
	{ value =                   511 --[[ 2^ 9-1]] , bits = "\xFF\x01\x00\x00\x00\x00\x00\x00" },
	{ value =                   512 --[[ 2^ 9+0]] , bits = "\x00\x02\x00\x00\x00\x00\x00\x00" },
	{ value =                   513 --[[ 2^ 9+1]] , bits = "\x01\x02\x00\x00\x00\x00\x00\x00" },
	{ value =                -32770 --[[-2^15-2]] , bits = "\xFE\x7F\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                -32769 --[[-2^15-1]] , bits = "\xFF\x7F\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                -32768 --[[-2^15+0]] , bits = "\x00\x80\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                -32767 --[[-2^15+1]] , bits = "\x01\x80\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                 32766 --[[ 2^15-2]] , bits = "\xFE\x7F\x00\x00\x00\x00\x00\x00" },
	{ value =                 32767 --[[ 2^15-1]] , bits = "\xFF\x7F\x00\x00\x00\x00\x00\x00" },
	{ value =                 32768 --[[ 2^15+0]] , bits = "\x00\x80\x00\x00\x00\x00\x00\x00" },
	{ value =                 32769 --[[ 2^15+1]] , bits = "\x01\x80\x00\x00\x00\x00\x00\x00" },
	{ value =                -65538 --[[-2^16-2]] , bits = "\xFE\xFF\xFE\xFF\xFF\xFF\xFF\xFF" },
	{ value =                -65537 --[[-2^16-1]] , bits = "\xFF\xFF\xFE\xFF\xFF\xFF\xFF\xFF" },
	{ value =                -65536 --[[-2^16+0]] , bits = "\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                -65535 --[[-2^16+1]] , bits = "\x01\x00\xFF\xFF\xFF\xFF\xFF\xFF" },
	{ value =                 65534 --[[ 2^16-2]] , bits = "\xFE\xFF\x00\x00\x00\x00\x00\x00" },
	{ value =                 65535 --[[ 2^16-1]] , bits = "\xFF\xFF\x00\x00\x00\x00\x00\x00" },
	{ value =                 65536 --[[ 2^16+0]] , bits = "\x00\x00\x01\x00\x00\x00\x00\x00" },
	{ value =                 65537 --[[ 2^16+1]] , bits = "\x01\x00\x01\x00\x00\x00\x00\x00" },
	{ value =               -131074 --[[-2^17-2]] , bits = "\xFE\xFF\xFD\xFF\xFF\xFF\xFF\xFF" },
	{ value =               -131073 --[[-2^17-1]] , bits = "\xFF\xFF\xFD\xFF\xFF\xFF\xFF\xFF" },
	{ value =               -131072 --[[-2^17+0]] , bits = "\x00\x00\xFE\xFF\xFF\xFF\xFF\xFF" },
	{ value =               -131071 --[[-2^17+1]] , bits = "\x01\x00\xFE\xFF\xFF\xFF\xFF\xFF" },
	{ value =                131070 --[[ 2^17-2]] , bits = "\xFE\xFF\x01\x00\x00\x00\x00\x00" },
	{ value =                131071 --[[ 2^17-1]] , bits = "\xFF\xFF\x01\x00\x00\x00\x00\x00" },
	{ value =                131072 --[[ 2^17+0]] , bits = "\x00\x00\x02\x00\x00\x00\x00\x00" },
	{ value =                131073 --[[ 2^17+1]] , bits = "\x01\x00\x02\x00\x00\x00\x00\x00" },
	{ value =              -8388610 --[[-2^23-2]] , bits = "\xFE\xFF\x7F\xFF\xFF\xFF\xFF\xFF" },
	{ value =              -8388609 --[[-2^23-1]] , bits = "\xFF\xFF\x7F\xFF\xFF\xFF\xFF\xFF" },
	{ value =              -8388608 --[[-2^23+0]] , bits = "\x00\x00\x80\xFF\xFF\xFF\xFF\xFF" },
	{ value =              -8388607 --[[-2^23+1]] , bits = "\x01\x00\x80\xFF\xFF\xFF\xFF\xFF" },
	{ value =               8388606 --[[ 2^23-2]] , bits = "\xFE\xFF\x7F\x00\x00\x00\x00\x00" },
	{ value =               8388607 --[[ 2^23-1]] , bits = "\xFF\xFF\x7F\x00\x00\x00\x00\x00" },
	{ value =               8388608 --[[ 2^23+0]] , bits = "\x00\x00\x80\x00\x00\x00\x00\x00" },
	{ value =               8388609 --[[ 2^23+1]] , bits = "\x01\x00\x80\x00\x00\x00\x00\x00" },
	{ value =             -16777218 --[[-2^24-2]] , bits = "\xFE\xFF\xFF\xFE\xFF\xFF\xFF\xFF" },
	{ value =             -16777217 --[[-2^24-1]] , bits = "\xFF\xFF\xFF\xFE\xFF\xFF\xFF\xFF" },
	{ value =             -16777216 --[[-2^24+0]] , bits = "\x00\x00\x00\xFF\xFF\xFF\xFF\xFF" },
	{ value =             -16777215 --[[-2^24+1]] , bits = "\x01\x00\x00\xFF\xFF\xFF\xFF\xFF" },
	{ value =              16777214 --[[ 2^24-2]] , bits = "\xFE\xFF\xFF\x00\x00\x00\x00\x00" },
	{ value =              16777215 --[[ 2^24-1]] , bits = "\xFF\xFF\xFF\x00\x00\x00\x00\x00" },
	{ value =              16777216 --[[ 2^24+0]] , bits = "\x00\x00\x00\x01\x00\x00\x00\x00" },
	{ value =              16777217 --[[ 2^24+1]] , bits = "\x01\x00\x00\x01\x00\x00\x00\x00" },
	{ value =             -33554434 --[[-2^25-2]] , bits = "\xFE\xFF\xFF\xFD\xFF\xFF\xFF\xFF" },
	{ value =             -33554433 --[[-2^25-1]] , bits = "\xFF\xFF\xFF\xFD\xFF\xFF\xFF\xFF" },
	{ value =             -33554432 --[[-2^25+0]] , bits = "\x00\x00\x00\xFE\xFF\xFF\xFF\xFF" },
	{ value =             -33554431 --[[-2^25+1]] , bits = "\x01\x00\x00\xFE\xFF\xFF\xFF\xFF" },
	{ value =              33554430 --[[ 2^25-2]] , bits = "\xFE\xFF\xFF\x01\x00\x00\x00\x00" },
	{ value =              33554431 --[[ 2^25-1]] , bits = "\xFF\xFF\xFF\x01\x00\x00\x00\x00" },
	{ value =              33554432 --[[ 2^25+0]] , bits = "\x00\x00\x00\x02\x00\x00\x00\x00" },
	{ value =              33554433 --[[ 2^25+1]] , bits = "\x01\x00\x00\x02\x00\x00\x00\x00" },
	{ value =           -2147483650 --[[-2^31-2]] , bits = "\xFE\xFF\xFF\x7F\xFF\xFF\xFF\xFF" },
	{ value =           -2147483649 --[[-2^31-1]] , bits = "\xFF\xFF\xFF\x7F\xFF\xFF\xFF\xFF" },
	{ value =           -2147483648 --[[-2^31+0]] , bits = "\x00\x00\x00\x80\xFF\xFF\xFF\xFF" },
	{ value =           -2147483647 --[[-2^31+1]] , bits = "\x01\x00\x00\x80\xFF\xFF\xFF\xFF" },
	{ value =            2147483646 --[[ 2^31-2]] , bits = "\xFE\xFF\xFF\x7F\x00\x00\x00\x00" },
	{ value =            2147483647 --[[ 2^31-1]] , bits = "\xFF\xFF\xFF\x7F\x00\x00\x00\x00" },
	{ value =            2147483648 --[[ 2^31+0]] , bits = "\x00\x00\x00\x80\x00\x00\x00\x00" },
	{ value =            2147483649 --[[ 2^31+1]] , bits = "\x01\x00\x00\x80\x00\x00\x00\x00" },
	{ value =           -4294967298 --[[-2^32-2]] , bits = "\xFE\xFF\xFF\xFF\xFE\xFF\xFF\xFF" },
	{ value =           -4294967297 --[[-2^32-1]] , bits = "\xFF\xFF\xFF\xFF\xFE\xFF\xFF\xFF" },
	{ value =           -4294967296 --[[-2^32+0]] , bits = "\x00\x00\x00\x00\xFF\xFF\xFF\xFF" },
	{ value =           -4294967295 --[[-2^32+1]] , bits = "\x01\x00\x00\x00\xFF\xFF\xFF\xFF" },
	{ value =            4294967294 --[[ 2^32-2]] , bits = "\xFE\xFF\xFF\xFF\x00\x00\x00\x00" },
	{ value =            4294967295 --[[ 2^32-1]] , bits = "\xFF\xFF\xFF\xFF\x00\x00\x00\x00" },
	{ value =            4294967296 --[[ 2^32+0]] , bits = "\x00\x00\x00\x00\x01\x00\x00\x00" },
	{ value =            4294967297 --[[ 2^32+1]] , bits = "\x01\x00\x00\x00\x01\x00\x00\x00" },
	{ value =           -8589934594 --[[-2^33-2]] , bits = "\xFE\xFF\xFF\xFF\xFD\xFF\xFF\xFF" },
	{ value =           -8589934593 --[[-2^33-1]] , bits = "\xFF\xFF\xFF\xFF\xFD\xFF\xFF\xFF" },
	{ value =           -8589934592 --[[-2^33+0]] , bits = "\x00\x00\x00\x00\xFE\xFF\xFF\xFF" },
	{ value =           -8589934591 --[[-2^33+1]] , bits = "\x01\x00\x00\x00\xFE\xFF\xFF\xFF" },
	{ value =            8589934590 --[[ 2^33-2]] , bits = "\xFE\xFF\xFF\xFF\x01\x00\x00\x00" },
	{ value =            8589934591 --[[ 2^33-1]] , bits = "\xFF\xFF\xFF\xFF\x01\x00\x00\x00" },
	{ value =            8589934592 --[[ 2^33+0]] , bits = "\x00\x00\x00\x00\x02\x00\x00\x00" },
	{ value =            8589934593 --[[ 2^33+1]] , bits = "\x01\x00\x00\x00\x02\x00\x00\x00" },
	{ value =         -549755813890 --[[-2^39-2]] , bits = "\xFE\xFF\xFF\xFF\x7F\xFF\xFF\xFF" },
	{ value =         -549755813889 --[[-2^39-1]] , bits = "\xFF\xFF\xFF\xFF\x7F\xFF\xFF\xFF" },
	{ value =         -549755813888 --[[-2^39+0]] , bits = "\x00\x00\x00\x00\x80\xFF\xFF\xFF" },
	{ value =         -549755813887 --[[-2^39+1]] , bits = "\x01\x00\x00\x00\x80\xFF\xFF\xFF" },
	{ value =          549755813886 --[[ 2^39-2]] , bits = "\xFE\xFF\xFF\xFF\x7F\x00\x00\x00" },
	{ value =          549755813887 --[[ 2^39-1]] , bits = "\xFF\xFF\xFF\xFF\x7F\x00\x00\x00" },
	{ value =          549755813888 --[[ 2^39+0]] , bits = "\x00\x00\x00\x00\x80\x00\x00\x00" },
	{ value =          549755813889 --[[ 2^39+1]] , bits = "\x01\x00\x00\x00\x80\x00\x00\x00" },
	{ value =        -1099511627778 --[[-2^40-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFE\xFF\xFF" },
	{ value =        -1099511627777 --[[-2^40-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFE\xFF\xFF" },
	{ value =        -1099511627776 --[[-2^40+0]] , bits = "\x00\x00\x00\x00\x00\xFF\xFF\xFF" },
	{ value =        -1099511627775 --[[-2^40+1]] , bits = "\x01\x00\x00\x00\x00\xFF\xFF\xFF" },
	{ value =         1099511627774 --[[ 2^40-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\x00\x00\x00" },
	{ value =         1099511627775 --[[ 2^40-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\x00\x00\x00" },
	{ value =         1099511627776 --[[ 2^40+0]] , bits = "\x00\x00\x00\x00\x00\x01\x00\x00" },
	{ value =         1099511627777 --[[ 2^40+1]] , bits = "\x01\x00\x00\x00\x00\x01\x00\x00" },
	{ value =        -2199023255554 --[[-2^41-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFD\xFF\xFF" },
	{ value =        -2199023255553 --[[-2^41-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFD\xFF\xFF" },
	{ value =        -2199023255552 --[[-2^41+0]] , bits = "\x00\x00\x00\x00\x00\xFE\xFF\xFF" },
	{ value =        -2199023255551 --[[-2^41+1]] , bits = "\x01\x00\x00\x00\x00\xFE\xFF\xFF" },
	{ value =         2199023255550 --[[ 2^41-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\x01\x00\x00" },
	{ value =         2199023255551 --[[ 2^41-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\x01\x00\x00" },
	{ value =         2199023255552 --[[ 2^41+0]] , bits = "\x00\x00\x00\x00\x00\x02\x00\x00" },
	{ value =         2199023255553 --[[ 2^41+1]] , bits = "\x01\x00\x00\x00\x00\x02\x00\x00" },
	{ value =      -140737488355330 --[[-2^47-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\x7F\xFF\xFF" },
	{ value =      -140737488355329 --[[-2^47-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\x7F\xFF\xFF" },
	{ value =      -140737488355328 --[[-2^47+0]] , bits = "\x00\x00\x00\x00\x00\x80\xFF\xFF" },
	{ value =      -140737488355327 --[[-2^47+1]] , bits = "\x01\x00\x00\x00\x00\x80\xFF\xFF" },
	{ value =       140737488355326 --[[ 2^47-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\x7F\x00\x00" },
	{ value =       140737488355327 --[[ 2^47-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\x7F\x00\x00" },
	{ value =       140737488355328 --[[ 2^47+0]] , bits = "\x00\x00\x00\x00\x00\x80\x00\x00" },
	{ value =       140737488355329 --[[ 2^47+1]] , bits = "\x01\x00\x00\x00\x00\x80\x00\x00" },
	{ value =      -281474976710658 --[[-2^48-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFF\xFE\xFF" },
	{ value =      -281474976710657 --[[-2^48-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFF\xFE\xFF" },
	{ value =      -281474976710656 --[[-2^48+0]] , bits = "\x00\x00\x00\x00\x00\x00\xFF\xFF" },
	{ value =      -281474976710655 --[[-2^48+1]] , bits = "\x01\x00\x00\x00\x00\x00\xFF\xFF" },
	{ value =       281474976710654 --[[ 2^48-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFF\x00\x00" },
	{ value =       281474976710655 --[[ 2^48-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00" },
	{ value =       281474976710656 --[[ 2^48+0]] , bits = "\x00\x00\x00\x00\x00\x00\x01\x00" },
	{ value =       281474976710657 --[[ 2^48+1]] , bits = "\x01\x00\x00\x00\x00\x00\x01\x00" },
	{ value =      -562949953421314 --[[-2^49-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFF\xFD\xFF" },
	{ value =      -562949953421313 --[[-2^49-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFF\xFD\xFF" },
	{ value =      -562949953421312 --[[-2^49+0]] , bits = "\x00\x00\x00\x00\x00\x00\xFE\xFF" },
	{ value =      -562949953421311 --[[-2^49+1]] , bits = "\x01\x00\x00\x00\x00\x00\xFE\xFF" },
	{ value =       562949953421310 --[[ 2^49-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFF\x01\x00" },
	{ value =       562949953421311 --[[ 2^49-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFF\x01\x00" },
	{ value =       562949953421312 --[[ 2^49+0]] , bits = "\x00\x00\x00\x00\x00\x00\x02\x00" },
	{ value =       562949953421313 --[[ 2^49+1]] , bits = "\x01\x00\x00\x00\x00\x00\x02\x00" },
	{ value =     -2251799813685250 --[[-2^51-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFF\xF7\xFF" },
	{ value =     -2251799813685249 --[[-2^51-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFF\xF7\xFF" },
	{ value =     -2251799813685248 --[[-2^51+0]] , bits = "\x00\x00\x00\x00\x00\x00\xF8\xFF" },
	{ value =     -2251799813685247 --[[-2^51+1]] , bits = "\x01\x00\x00\x00\x00\x00\xF8\xFF" },
	{ value =      2251799813685246 --[[ 2^51-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFF\x07\x00" },
	{ value =      2251799813685247 --[[ 2^51-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFF\x07\x00" },
	{ value =      2251799813685248 --[[ 2^51+0]] , bits = "\x00\x00\x00\x00\x00\x00\x08\x00" },
	{ value =      2251799813685249 --[[ 2^51+1]] , bits = "\x01\x00\x00\x00\x00\x00\x08\x00" },
	{ value =     -4503599627370498 --[[-2^52-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFF\xEF\xFF" },
	{ value =     -4503599627370497 --[[-2^52-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFF\xEF\xFF" },
	{ value =     -4503599627370496 --[[-2^52+0]] , bits = "\x00\x00\x00\x00\x00\x00\xF0\xFF" },
	{ value =     -4503599627370495 --[[-2^52+1]] , bits = "\x01\x00\x00\x00\x00\x00\xF0\xFF" },
	{ value =      4503599627370494 --[[ 2^52-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFF\x0F\x00" },
	{ value =      4503599627370495 --[[ 2^52-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFF\x0F\x00" },
	{ value =      4503599627370496 --[[ 2^52+0]] , bits = "\x00\x00\x00\x00\x00\x00\x10\x00" },
	{ value =      4503599627370497 --[[ 2^52+1]] , bits = "\x01\x00\x00\x00\x00\x00\x10\x00" },
	{ value =     -9007199254740994 --[[-2^53-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFF\xDF\xFF" },
--	{ value =     -9007199254740993 --[[-2^53-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFF\xDF\xFF" },
	{ value =     -9007199254740992 --[[-2^53+0]] , bits = "\x00\x00\x00\x00\x00\x00\xE0\xFF" },
	{ value =     -9007199254740991 --[[-2^53+1]] , bits = "\x01\x00\x00\x00\x00\x00\xE0\xFF" },
	{ value =      9007199254740990 --[[ 2^53-2]] , bits = "\xFE\xFF\xFF\xFF\xFF\xFF\x1F\x00" },
	{ value =      9007199254740991 --[[ 2^53-1]] , bits = "\xFF\xFF\xFF\xFF\xFF\xFF\x1F\x00" },
	{ value =      9007199254740992 --[[ 2^53+0]] , bits = "\x00\x00\x00\x00\x00\x00\x20\x00" },
--	{ value =      9007199254740993 --[[ 2^53+1]] , bits = "\x01\x00\x00\x00\x00\x00\x20\x00" },
}

local pi64Bits = string.pack("<d", math.pi)
local pi32Bits = string.pack("<f", math.pi)

function T.TestNew(t, require)
	local Bitbuf = require()

	pass(t, Bitbuf.new():Len() == 0, "no argument expects zero-length buffer")
	pass(t, Bitbuf.new(42):Len() == 42, "argument sets buffer length")
	pass(t, Bitbuf.new(42):Index() == 0, "index of new buffer is 0")

	bits(t, Bitbuf.new(42), 42, "\0\0\0\0\0\0")
end

function T.TestFromString(t, require)
	local Bitbuf = require()

	for i = 1, #pi64Bits do
		local buf = Bitbuf.fromString(string.sub(pi64Bits, 1, i))
		if buf:Len() ~= i*8 then
			t:Errorf("[%d]: expected length %d, got %d", i, i*8, buf:Len())
		end
	end

	bits(t, Bitbuf.fromString(string.sub(pi64Bits, 1, 8)), 64, "\24\45\68\84\251\33\9\64")
	bits(t, Bitbuf.fromString(string.sub(pi64Bits, 1, 7)), 56, "\24\45\68\84\251\33\9")
	bits(t, Bitbuf.fromString(string.sub(pi64Bits, 1, 6)), 48, "\24\45\68\84\251\33")
	bits(t, Bitbuf.fromString(string.sub(pi64Bits, 1, 5)), 40, "\24\45\68\84\251")
	bits(t, Bitbuf.fromString(string.sub(pi64Bits, 1, 4)), 32, "\24\45\68\84")
	bits(t, Bitbuf.fromString(string.sub(pi64Bits, 1, 3)), 24, "\24\45\68")
	bits(t, Bitbuf.fromString(string.sub(pi64Bits, 1, 2)), 16, "\24\45")
	bits(t, Bitbuf.fromString(string.sub(pi64Bits, 1, 1)),  8, "\24")
	bits(t, Bitbuf.fromString(""), 0, "")
end

function T.TestBuffer_String(t, require)
	local Bitbuf = require()
	--TODO
end

function T.TestBuffer_Len(t, require)
	local Bitbuf = require()

	for i = 0, 256 do
		local n = Bitbuf.new(i):Len()
		if n ~= i then
			t:Errorf("length %d expected, got %d", i, n)
		end
	end
end

function T.TestBuffer_SetLen(t, require)
	local Bitbuf = require()

	superTest(t, Bitbuf, function(buf, l, i, v)
		buf:SetLen(v)
		if buf:Len() ~= v then
			return superError(t,l,i,v, "expected length %d, got %d", v, buf:Len())
		end
		local expi = math.min(i, v)
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		return compData(t,l,i,v, string.rep("\0", math.ceil(v/8)), buf:String())
	end)
end

function T.TestBuffer_Index(t, require)
	local Bitbuf = require()

	pass(t, Bitbuf.new(42):Index() == 0, "new buffer index is 0")
	local buf = Bitbuf.new()
	pass(t, buf:Index() == 0, "buffer index is 0")
	pass(t, buf:Len() == 0, "buffer length is 0")
	bits(t, buf, 0, "")

	buf:SetIndex(10)
	pass(t, buf:Index() == 10, "buffer index set to 10")
	pass(t, buf:Len() == 10, "buffer length grows to 10")
	bits(t, buf, 10, "\0\0")

	buf:SetIndex(5)
	pass(t, buf:Index() == 5, "buffer index set to 5")
	pass(t, buf:Len() == 10, "buffer length still 10")
	bits(t, buf, 10, "\0\0")

	buf:SetIndex(202)
	pass(t, buf:Index() == 202, "buffer index set to 202")
	pass(t, buf:Len() == 202, "buffer length grows to 202")
	bits(t, buf, 202, "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0")

	buf:SetIndex(20)
	pass(t, buf:Index() == 20, "buffer index set to 20")
	pass(t, buf:Len() == 202, "buffer length still 202")
	bits(t, buf, 202, "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0")

	buf:SetIndex(-10)
	pass(t, buf:Index() == 0, "setting negative buffer index clamps to 0")
	bits(t, buf, 202, "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0")

	local buf = Bitbuf.new()
	for i = 0, 256 do
		buf:SetIndex(i)
		if buf:Index() ~= i then
			t:Errorf("[%d]: got index %d", i, buf:Index())
			return
		end
		if buf:Len() ~= i then
			t:Errorf("[%d]: got length %d", i, buf:Len())
			return
		end
		local s = buf:String()
		if s ~= string.rep("\0", math.ceil(i/8)) then
			t:Errorf("[%d]: unexpected buffer content: %s", i, s:gsub(".", function(c) return "\\"..c:byte() end))
			return
		end
	end
end

function T.TestBuffer_Fits(t, require)
	local Bitbuf = require()

	superTest(t, Bitbuf, function(buf, l, i, v)
		if buf:Fits(v) ~= (i+v <= l) then
			return superError(t,l,i,v, "%d+%d > %d", i, v, l)
		end
	end)
end

function T.TestBuffer_Pad(t, require)
	local Bitbuf = require()
	--TODO: init with ones
	t:Log("test nil")
	superTest(t, Bitbuf, function(buf, l, i, v)
		buf:Pad(v)

		local expi = i+v
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		return compData(t,l,i,v, string.rep("\0", math.ceil(explen/8)), buf:String())
	end)

	t:Log("test false")
	superTest(t, Bitbuf, function(buf, l, i, v)
		buf:Pad(v, false)

		local expi = i+v
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		return compData(t,l,i,v, string.rep("\0", math.ceil(explen/8)), buf:String())
	end)

	t:Log("test true")
	superTest(t, Bitbuf, function(buf, l, i, v)
		buf:Pad(v, true)

		local expi = i+v
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		return compData(t,l,i,v, string.rep("\0", math.ceil(explen/8)), buf:String())
	end)
end

function T.TestBuffer_Align(t, require)
	local Bitbuf = require()

	t:Log("test nil")
	superTest(t, Bitbuf, function(buf, l, i, v)
		buf:Align(v)

		local expi = v == 0 and i or math.ceil(i/v)*v
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		return compData(t,l,i,v, string.rep("\0", math.ceil(explen/8)), buf:String())
	end)

	t:Log("test false")
	superTest(t, Bitbuf, function(buf, l, i, v)
		buf:Align(v, false)

		local expi = v == 0 and i or math.ceil(i/v)*v
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		return compData(t,l,i,v, string.rep("\0", math.ceil(explen/8)), buf:String())
	end)

	t:Log("test true")
	superTest(t, Bitbuf, function(buf, l, i, v)
		buf:Align(v, true)

		local expi = v == 0 and i or math.ceil(i/v)*v
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		return compData(t,l,i,v, string.rep("\0", math.ceil(explen/8)), buf:String())
	end)
end

function T.TestBuffer_Reset(t, require)
	local Bitbuf = require()

	local buf = Bitbuf.fromString(pi64Bits)
	buf:Reset()
	pass(t, buf:Len() == 0, "reset buffer length is 0")
	pass(t, buf:Index() == 0, "reset buffer index is 0")
	pass(t, buf:String() == "", "reset buffer content is empty")
end

function T.TestBuffer_WriteBytes(t, require)
	local Bitbuf = require()

	superTest(t, Bitbuf, function(buf, l, i, v)
		local s = ones(v)
		buf:WriteBytes(s)

		local expi = i + #s*8
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		if SLOW then
			local data = string.rep("0", i) .. explode(s) .. string.rep("0", math.max(0, l-i-#s*8))
			return compData(t,l,i,v, data, explodeBuf(buf))
		end
	end)
end

function T.TestBuffer_ReadBytes(t, require)
	local Bitbuf = require()

	superTest(t, Bitbuf, function(buf, l, i, v)
		local a = ones(v)
		buf:WriteBytes(a)
		buf:SetIndex(i)
		local b = buf:ReadBytes(math.ceil(v/8))

		local expi = i + #a*8
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		return compData(t,l,i,v, a, b)
	end)
end

function T.TestBuffer_WriteUint(t, require)
	local Bitbuf = require()

	t:Log("test ones")
	superTest(t, Bitbuf, function(buf, l, i, v)
		if v > 53 then
			return
		end
		local a = ones(v)
		local b = v == 0 and 0 or string.unpack("<I"..math.ceil(v/8), a)
		buf:WriteUint(v, b)

		local expi = i + v
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		if SLOW then
			local data = string.rep("0", i) .. explode(a, v) .. string.rep("0", math.max(0, l-i-v))
			return compData(t,l,i,v, data, explodeBuf(buf))
		end
	end)

	fail(t, function() return Bitbuf.new():WriteUint(54, 0) end, "size 54 not in range [0,53]")
	fail(t, function() return Bitbuf.new():WriteUint(-1, 0) end, "size -1 not in range [0,53]")

	t:Log("test ints")
	local n = 0
	local a = os.clock()
	local buf = Bitbuf.new()
	for i, test in ipairs(intTests) do
		for size = 0, 53 do
			if n >= 10 then
				t:Fatal("too many errors")
			end
			if os.clock()-a >= 1 then
				t:Yield()
				a = os.clock()
			end
			buf:Reset()
			buf:WriteUint(size, test.value)
			if buf:Len() ~= size then
				t:Errorf("[%d:%d]: expected size %d, got %d", test.value, size, size, buf:Len())
				n = n + 1
				continue
			end
			local want = truncate(size, test.bits)
			local got = buf:String()
			if got ~= want then
				local r = {compError(want, got)}
				t:Errorf("[%d:%d]: "..r[1], test.value, size, unpack(r, 2))
				n = n + 1
				continue
			end
		end
	end
end

function T.TestBuffer_ReadUint(t, require)
	local Bitbuf = require()

	t:Log("test ones")
	superTest(t, Bitbuf, function(buf, l, i, v)
		if v > 53 then
			return
		end
		buf:WriteBytes(ones(v))
		buf:SetIndex(i)

		local got = buf:ReadUint(v)
		local expi = i + v
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		local want = 2^v-1
		if got ~= want then
			return superError(t,l,i,v, "expected value %d, got %d", want, got)
		end
	end)

	t:Log("test ints")
	local n = 0
	local a = os.clock()
	local buf = Bitbuf.new()
	for i, test in ipairs(intTests) do
		for size = 0, 53 do
			if n >= 10 then
				t:Fatal("too many errors")
			end
			if os.clock()-a >= 1 then
				t:Yield()
				a = os.clock()
			end
			local buf = Bitbuf.fromString(truncate(size, test.bits))
			local want = test.value % 2^size
			local got = buf:ReadUint(size)
			if got ~= want then
				t:Errorf("[%d:%d]: expected %d, got %d", test.value, size, want, got)
				n = n + 1
				continue
			end
		end
	end
end

function T.TestBuffer_WriteBool(t, require)
	local Bitbuf = require()

	t:Log("test true")
	superTest(t, Bitbuf, function(buf, l, i, v)
		for i = 0, v-1 do
			buf:WriteBool(true)
		end

		local expi = i + v
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		if SLOW then
			local want = string.rep("0", i) .. string.rep("1", v) .. string.rep("0", math.max(0, l-i-v))
			return compData(t,l,i,v, want, explodeBuf(buf))
		end
	end)

	t:Log("test false")
	superTest(t, Bitbuf, function(buf, l, i, v)
		for i = 0, v-1 do
			buf:WriteBool(false)
		end

		local expi = i + v
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		if SLOW then
			local want = string.rep("0", i+v + math.max(0, l-i-v))
			return compData(t,l,i,v, want, explodeBuf(buf))
		end
	end)
end

function T.TestBuffer_ReadBool(t, require)
	local Bitbuf = require()

	t:Log("test true")
	superTest(t, Bitbuf, function(buf, l, i, v)
		buf:WriteBytes(ones(v))
		buf:SetIndex(i)
		for i = 0, v-1 do
			local b = buf:ReadBool()
			if b ~= true then
				return superError(t,l,i,v, "expected true on bit %d, got %s", i, tostring(b))
			end
		end
		local expi = i + v
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
	end)

	t:Log("test false")
	superTest(t, Bitbuf, function(buf, l, i, v)
		for i = 0, v-1 do
			local b = buf:ReadBool()
			if b ~= false then
				return superError(t,l,i,v, "expected false on bit %d, got %s", i, tostring(b))
			end
		end
		local expi = i + v
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
	end)
end

function T.TestBuffer_WriteByte(t, require)
	local Bitbuf = require()
	--TODO
end

function T.TestBuffer_ReadByte(t, require)
	local Bitbuf = require()
	--TODO
end

function T.TestBuffer_WriteInt(t, require)
	local Bitbuf = require()

	t:Log("test ones")
	superTest(t, Bitbuf, function(buf, l, i, v)
		if v > 53 then
			return
		end
		local a = ones(v)
		local b = v == 0 and 0 or string.unpack("<i"..math.ceil(v/8), a)
		buf:WriteInt(v, b)

		local expi = i + v
		local explen = math.max(expi, l)
		if buf:Len() ~= explen then
			return superError(t,l,i,v, "expected length %d, got %d", explen, buf:Len())
		end
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		if SLOW then
			local data = string.rep("0", i) .. explode(a, v) .. string.rep("0", math.max(0, l-i-v))
			return compData(t,l,i,v, data, explodeBuf(buf))
		end
	end)

	fail(t, function() return Bitbuf.new():WriteInt(54, 0) end, "size 54 not in range [0,53]")
	fail(t, function() return Bitbuf.new():WriteInt(-1, 0) end, "size -1 not in range [0,53]")

	t:Log("test ints")
	local n = 0
	local a = os.clock()
	local buf = Bitbuf.new()
	for i, test in ipairs(intTests) do
		for size = 0, 53 do
			if n >= 10 then
				t:Fatal("too many errors")
			end
			if os.clock()-a >= 1 then
				t:Yield()
				a = os.clock()
			end
			buf:Reset()
			buf:WriteInt(size, test.value)
			if buf:Len() ~= size then
				t:Errorf("[%d:%d]: expected size %d, got %d", test.value, size, size, buf:Len())
				n = n + 1
				continue
			end
			local want = truncate(size, test.bits)
			local got = buf:String()
			if got ~= want then
				local r = {compError(want, got)}
				t:Errorf("[%d:%d]: "..r[1], test.value, size, unpack(r, 2))
				n = n + 1
				continue
			end
		end
	end
end

local function uint2int(size, v)
	local n = 2^size
	v = v % n
	if v >= n/2 then
		return v - n
	end
	return v
end

function T.TestBuffer_ReadInt(t, require)
	local Bitbuf = require()

	t:Log("test ones")
	superTest(t, Bitbuf, function(buf, l, i, v)
		if v > 53 then
			return
		end
		buf:WriteBytes(ones(v))
		buf:SetIndex(i)

		local got = buf:ReadInt(v)
		local expi = i + v
		if buf:Index() ~= expi then
			return superError(t,l,i,v, "expected index %d, got %d", expi, buf:Index())
		end
		local want = v == 0 and 0 or -1
		if got ~= want then
			return superError(t,l,i,v, "expected value %d, got %d", want, got)
		end
	end)

	t:Log("test ints")
	local n = 0
	local a = os.clock()
	local buf = Bitbuf.new()
	for i, test in ipairs(intTests) do
		for size = 0, 53 do
			if n >= 10 then
				t:Fatal("too many errors")
			end
			if os.clock()-a >= 1 then
				t:Yield()
				a = os.clock()
			end
			local buf = Bitbuf.fromString(truncate(size, test.bits))
			local want = uint2int(size, test.value)
			local got = buf:ReadInt(size)
			if got ~= want then
				t:Errorf("[%d:%d]: expected %d, got %d", test.value, size, want, got)
				n = n + 1
				continue
			end
		end
	end
end

function T.TestBuffer_WriteFloat(t, require)
	local Bitbuf = require()

	local buf = Bitbuf.new()
	buf:WriteFloat(32, math.pi)
	pass(t, buf:Len() == 32, "buffer length is 32")
	pass(t, buf:Index() == 32, "buffer index is 32")
	pass(t, buf:String() == pi32Bits, "32-bit pi")

	local buf = Bitbuf.new()
	buf:WriteFloat(64, math.pi)
	pass(t, buf:Len() == 64, "buffer length is 64")
	pass(t, buf:Index() == 64, "buffer index is 64")
	pass(t, buf:String() == pi64Bits, "64-bit pi")

	fail(t, function() buf:WriteFloat(1, 0) end, "invalid size")
end

function T.TestBuffer_ReadFloat(t, require)
	local Bitbuf = require()

	local pi32 = string.unpack("<f", string.pack("<f", math.pi))
	local buf = Bitbuf.fromString(pi32Bits)
	pass(t, buf:ReadFloat(32) == pi32, "32-bit pi")
	pass(t, buf:Index() == 32, "buffer index is 32")

	local buf = Bitbuf.fromString(pi64Bits)
	pass(t, buf:ReadFloat(64) == math.pi, "64-bit pi")
	pass(t, buf:Index() == 64, "buffer index is 32")

	fail(t, function() buf:ReadFloat(1, 0) end, "invalid size")
end

function T.TestBuffer_WriteUfixed(t, require)
	local Bitbuf = require()
	--TODO
end

function T.TestBuffer_ReadUfixed(t, require)
	local Bitbuf = require()
	--TODO
end

function T.TestBuffer_WriteFixed(t, require)
	local Bitbuf = require()
	--TODO
end

function T.TestBuffer_ReadFixed(t, require)
	local Bitbuf = require()
	--TODO
end

return T
