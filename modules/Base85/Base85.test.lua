local testData = {
	large = {true,
		"Man is distinguished, not only by his reason, but by this singular p"..
		"assion from other animals, which is a lust of the mind, that by a pe"..
		"rseverance of delight in the continued and indefatigable generation "..
		"of knowledge, exceeds the short vehemence of any carnal pleasure.",

		"O<`^zX>%ZCX>)XGZfA9Ab7*B`EFf-gbRchTY<VDJc_3(Mb0BhMVRLV8EFfZabRc4RAar"..
		"PHb0BkRZfA9DVR9gFVRLh7Z*CxFa&K)QZ**v7av))DX>DO_b1WctXlY|;AZc?TVIXXEb"..
		"95kYW*~HEWgu;7Ze%PVbZB98AYyqSVIXj2a&u*NWpZI|V`U(3W*}r`Y-wj`bRcPNAarP"..
		"DAY*TCbZKsNWn>^>Ze$>7Ze(R<VRUI{VPb4$AZKN6WpZJ3X>V>IZ)PBCZf|#NWn^b%EF"..
		"figV`XJzb0BnRWgv5CZ*p`Xc4cT~ZDnp_Wgu^6AYpEKAY);2ZeeU7aBO8^b9HiME&",
	},
	empty = {true,
		"",
		"",
	},
	zeros = {true,
		"\0\0\0\0\0",
		"0000000",
	},
	-- TODO: test invalid bytes.
	-- TODO: test corrupted bytes.
}

local T = {}

local function z(s)
	return string.gsub(s, "%z", "\\0")
end

function T.TestEncode(t, require)
	local Base85 = require()
	for name, pair in pairs(testData) do
		local okay = pair[1]
		local source = pair[2]
		local data = pair[3]
		local ok, result = pcall(Base85.Encode, source)
		if ok ~= okay then
			if okay then
				t:Errorf("test %s: unexpected error: %s", name, result)
			else
				t:Errorf("test %s: expected error", name)
			end
		elseif result ~= data then
			t:Errorf("test %s:\n\texpected %s\n\treceived %s", name, z(data), z(result))
		end
	end
end

function T.TestDecode(t, require)
	local Base85 = require()
	for name, pair in pairs(testData) do
		local okay = pair[1]
		local source = pair[2]
		local data = pair[3]
		local ok, result = pcall(Base85.Decode, data)
		if ok ~= okay then
			if okay then
				t:Errorf("test %s: unexpected error: %s", name, result)
			else
				t:Errorf("test %s: expected error", name)
			end
		elseif result ~= source then
			t:Errorf("test %s:\n\texpected %s\n\treceived %s", name, z(source), z(result))
		end
	end
end

function T.BenchmarkEncode(b, require)
	local Base85 = require()
	local source = testData.large[2]
	b:ResetTimer()
	for i = 1, b.N do
		Base85.Encode(source)
	end
end

function T.BenchmarkDecode(b, require)
	local Base85 = require()
	local source = testData.large[3]
	b:ResetTimer()
	for i = 1, b.N do
		Base85.Decode(source)
	end
end

return T
