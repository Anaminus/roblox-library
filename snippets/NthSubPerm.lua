-- Like a permutation, but also includes subsets.
local function NthSubPerm(v, b)
	local B = #b
	if B <= 1 then return b:rep(v+1) end
	local p = math.floor(math.log((v+2)*(B-1))/math.log(B))-1
	v = v - math.modf(B*(B^p-1)/(B-1))
	local s = {}
	for i = 0, p do
		local j = math.modf(v / B^i % B)
		s[i+1] = b:sub(j+1,j+1)
	end
	return table.concat(s)
end

for i = 0, 40 do
	print(i, NthSubPerm(i,"AB"), NthSubPerm(i,"ABC"))
end
