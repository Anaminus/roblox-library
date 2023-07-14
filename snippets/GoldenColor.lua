-- Generate distributed colors.
local GoldenColor do
	local PHI_CONJ = (math.sqrt(5)-1)/2
	local h = math.random()
	function GoldenColor(s: number?, v: number?): Color3
		h = (h + PHI_CONJ) % 1
		return Color3.fromHSV(h, s or 0.5, v or 0.95)
	end
end
