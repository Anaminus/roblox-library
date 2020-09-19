--@sec: Simplex
--@ord: -1
--@doc: Simplex noise algorithm in Lua.
--
-- - [Original Java implementation by Stefan Gustavson][java]
-- - [Paper][paper]
--
-- [java]: https://weber.itn.liu.se/~stegu/simplexnoise/SimplexNoise.java
-- [paper]: https://staffwww.itn.liu.se/~stegu/simplexnoise/simplexnoise.pdf
local Simplex = {}

local grad3 = {
	{ 1, 1, 0}, {-1, 1, 0}, { 1,-1, 0}, {-1,-1, 0},
	{ 1, 0, 1}, {-1, 0, 1}, { 1, 0,-1}, {-1, 0,-1},
	{ 0, 1, 1}, { 0,-1, 1}, { 0, 1,-1}, { 0,-1,-1},
}

local grad4 = {
	{ 0, 1, 1, 1}, { 0, 1, 1,-1}, { 0, 1,-1, 1}, { 0, 1,-1,-1},
	{ 0,-1, 1, 1}, { 0,-1, 1,-1}, { 0,-1,-1, 1}, { 0,-1,-1,-1},
	{ 1, 0, 1, 1}, { 1, 0, 1,-1}, { 1, 0,-1, 1}, { 1, 0,-1,-1},
	{-1, 0, 1, 1}, {-1, 0, 1,-1}, {-1, 0,-1, 1}, {-1, 0,-1,-1},
	{ 1, 1, 0, 1}, { 1, 1, 0,-1}, { 1,-1, 0, 1}, { 1,-1, 0,-1},
	{-1, 1, 0, 1}, {-1, 1, 0,-1}, {-1,-1, 0, 1}, {-1,-1, 0,-1},
	{ 1, 1, 1, 0}, { 1, 1,-1, 0}, { 1,-1, 1, 0}, { 1,-1,-1, 0},
	{-1, 1, 1, 0}, {-1, 1,-1, 0}, {-1,-1, 1, 0}, {-1,-1,-1, 0},
}

-- Skewing and unskewing factors for 2 dimensions
local F2 = (math.sqrt(3) - 1)/2
local G2 = (3 - math.sqrt(3))/6
local F3 = 1 / 3
local G3 = 1 / 6
local F4 = (math.sqrt(5) - 1)/4
local G4 = (5 - math.sqrt(5))/20

--@sec: Generator
--@def: type Generator
--@doc: Generator holds the state for generating simplex noise.
local mt = {__index={}}

--@sec: Generator.Noise2D
--@def: Generator:Noise2D(x: number, y: number): number
--@doc: Returns a number in the interval [-1, 1] based on the given
-- two-dimensional coordinates and the generator's permutation state.
function mt.__index:Noise2D(xin, yin)
	local perm = self.perm
	local permMod12 = self.permMod12
	local n0, n1, n2 -- Noise contributions from the three corners
	-- Skew the input space to determine which simplex cell we're in
	local s = (xin + yin) * F2 -- Hairy factor for 2D

	local i = xin + s; i = i - i%1
	local j = yin + s; j = j - j%1
	local t = (i + j) * G2
	local X0 = i - t -- Unskew the cell origin back to (x,y) space
	local Y0 = j - t
	local x0 = xin - X0 -- The x,y distances from the cell origin
	local y0 = yin - Y0
	-- For the 2D case, the simplex shape is an equilateral triangle.
	-- Determine which simplex we are in.
	local i1, j1 -- Offsets for second (middle) corner of simplex in (i,j) coords
	if x0 > y0 then
		i1, j1 = 1, 0 -- lower triangle, XY order: (0,0)->(1,0)->(1,1)
	else
		i1, j1 = 0, 1 -- upper triangle, YX order: (0,0)->(0,1)->(1,1)
	end
	-- A step of (1,0) in (i,j) means a step of (1-c,-c) in (x,y), and
	-- a step of (0,1) in (i,j) means a step of (-c,1-c) in (x,y), where
	-- c = (3-sqrt(3))/6
	local x1 = x0 - i1 + G2 -- Offsets for middle corner in (x,y) unskewed coords
	local y1 = y0 - j1 + G2
	local x2 = x0 - 1 + 2 * G2 -- Offsets for last corner in (x,y) unskewed coords
	local y2 = y0 - 1 + 2 * G2
	-- Work out the hashed gradient indices of the three simplex corners
	local ii = i % 256
	local jj = j % 256
	-- Calculate the contribution from the three corners
	local t0 = 0.5 - x0*x0 - y0*y0
	if t0 < 0 then
		n0 = 0
	else
		t0 = t0 * t0
		local g = grad3[(1)+permMod12[(1)+ii+perm[(1)+jj]]]
		n0 = t0 * t0 * (g[1]*x0 + g[2]*y0) -- (x,y) of grad3 used for 2D gradient
	end

	local t1 = 0.5 - x1*x1 - y1*y1
	if t1 < 0 then
		n1 = 0
	else
		t1 = t1 * t1
		local g = grad3[(1)+permMod12[(1)+ii+i1+perm[(1)+jj+j1]]]
		n1 = t1 * t1 * (g[1]*x1 + g[2]*y1)
	end

	local t2 = 0.5 - x2*x2 - y2*y2
	if t2 < 0 then
		n2 = 0
	else
		t2 = t2 * t2
		local g = grad3[(1)+permMod12[(1)+ii+1+perm[(1)+jj+1]]]
		n2 = t2 * t2 * (g[1]*x2 + g[2]*y2)
	end
	-- Add contributions from each corner to get the final noise value.
	-- The result is scaled to return values in the interval [-1,1].
	return 70 * (n0 + n1 + n2)
end

--@sec: Generator.Noise3D
--@def: Generator:Noise3D(x: number, y: number, z: number): number
--@doc: Returns a number in the interval [-1, 1] based on the given
-- three-dimensional coordinates and the generator's permutation state.
function mt.__index:Noise3D(xin, yin, zin)
	local perm = self.perm
	local permMod12 = self.permMod12
	local n0, n1, n2, n3; -- Noise contributions from the four corners
	-- Skew the input space to determine which simplex cell we're in
	local s = (xin + yin + zin) * F3 -- Very nice and simple skew factor for 3D
	local i = xin + s; i = i - i%1
	local j = yin + s; j = j - j%1
	local k = zin + s; k = k - k%1
	local t = (i + j + k) * G3
	local X0 = i - t -- Unskew the cell origin back to (x,y,z) space
	local Y0 = j - t
	local Z0 = k - t
	local x0 = xin - X0 -- The x,y,z distances from the cell origin
	local y0 = yin - Y0
	local z0 = zin - Z0
	-- For the 3D case, the simplex shape is a slightly irregular tetrahedron.
	-- Determine which simplex we are in.
	local i1, j1, k1 -- Offsets for second corner of simplex in (i,j,k) coords
	local i2, j2, k2 -- Offsets for third corner of simplex in (i,j,k) coords
	if x0 >= y0 then
		if y0 >= z0 then
			i1,j1,k1,i2,j2,k2 = 1,0,0,1,1,0 -- X Y Z order
		elseif x0 >= z0 then
			i1,j1,k1,i2,j2,k2 = 1,0,0,1,0,1 -- X Z Y order
		else
			i1,j1,k1,i2,j2,k2 = 0,0,1,1,0,1 -- Z X Y order
		end
	else -- x0 < y0
		if y0 < z0 then
			i1,j1,k1,i2,j2,k2 = 0,0,1,0,1,1 -- Z Y X order
		elseif x0 < z0 then
			i1,j1,k1,i2,j2,k2 = 0,1,0,0,1,1 -- Y Z X order
		else
			i1,j1,k1,i2,j2,k2 = 0,1,0,1,1,0 -- Y X Z order
		end
	end
	-- A step of (1,0,0) in (i,j,k) means a step of (1-c,-c,-c) in (x,y,z),
	-- a step of (0,1,0) in (i,j,k) means a step of (-c,1-c,-c) in (x,y,z), and
	-- a step of (0,0,1) in (i,j,k) means a step of (-c,-c,1-c) in (x,y,z), where
	-- c = 1/6.
	local x1 = x0 - i1 +   G3 -- Offsets for second corner in (x,y,z) coords
	local y1 = y0 - j1 +   G3
	local z1 = z0 - k1 +   G3
	local x2 = x0 - i2 + 2*G3 -- Offsets for third corner in (x,y,z) coords
	local y2 = y0 - j2 + 2*G3
	local z2 = z0 - k2 + 2*G3
	local x3 = x0 -  1 + 3*G3 -- Offsets for last corner in (x,y,z) coords
	local y3 = y0 -  1 + 3*G3
	local z3 = z0 -  1 + 3*G3
	-- Work out the hashed gradient indices of the four simplex corners
	local ii = i % 256
	local jj = j % 256
	local kk = k % 256
	-- Calculate the contribution from the four corners
	local t0 = 0.6 - x0*x0 - y0*y0 - z0*z0
	if t0 < 0 then
		n0 = 0
	else
		t0 = t0 * t0
		local g = grad3[(1)+permMod12[(1)+ii+perm[(1)+jj+perm[(1)+kk]]]]
		n0 = t0 * t0 * (g[1]*x0 + g[2]*y0 + g[3]*z0)
	end

	local t1 = 0.6 - x1*x1 - y1*y1 - z1*z1
	if t1 < 0 then
		n1 = 0
	else
		t1 = t1 * t1
		local g = grad3[(1)+permMod12[(1)+ii+i1+perm[(1)+jj+j1+perm[(1)+kk+k1]]]]
		n1 = t1 * t1 * (g[1]*x1 + g[2]*y1 + g[3]*z1)
	end

	local t2 = 0.6 - x2*x2 - y2*y2 - z2*z2
	if t2 < 0 then
		n2 = 0
	else
		t2 = t2 * t2
		local g = grad3[(1)+permMod12[(1)+ii+i2+perm[(1)+jj+j2+perm[(1)+kk+k2]]]]
		n2 = t2 * t2 * (g[1]*x2 + g[2]*y2 + g[3]*z2)
	end

	local t3 = 0.6 - x3*x3 - y3*y3 - z3*z3
	if t3 < 0 then
		n3 = 0
	else
		t3 = t3 * t3
		local g = grad3[(1)+permMod12[(1)+ii+1+perm[(1)+jj+1+perm[(1)+kk+1]]]]
		n3 = t3 * t3 * (g[1]*x3 + g[2]*y3 + g[3]*z3)
	end
	-- Add contributions from each corner to get the final noise value.
	-- The result is scaled to stay just inside [-1,1]
	return 32*(n0 + n1 + n2 + n3)
end

--@sec: Generator.Noise4D
--@def: Generator:Noise4D(x: number, y: number, z: number, w: number): number
--@doc: Returns a number in the interval [-1, 1] based on the given
-- four-dimensional coordinates and the generator's permutation state.
function mt.__index:Noise4D(x, y, z, w)
	local perm = self.perm
	local n0, n1, n2, n3, n4 -- Noise contributions from the five corners
	-- Skew the (x,y,z,w) space to determine which cell of 24 simplices we're in
	local s = (x + y + z + w) * F4 -- Factor for 4D skewing
	local i = x + s; i = i - i%1
	local j = y + s; j = j - j%1
	local k = z + s; k = k - k%1
	local l = w + s; l = l - l%1
	local t = (i + j + k + l) * G4 -- Factor for 4D unskewing
	local X0 = i - t -- Unskew the cell origin back to (x,y,z,w) space
	local Y0 = j - t
	local Z0 = k - t
	local W0 = l - t
	local x0 = x - X0	-- The x,y,z,w distances from the cell origin
	local y0 = y - Y0
	local z0 = z - Z0
	local w0 = w - W0
	-- For the 4D case, the simplex is a 4D shape I won't even try to describe.
	-- To find out which of the 24 possible simplices we're in, we need to
	-- determine the magnitude ordering of x0, y0, z0 and w0.
	-- Six pair-wise comparisons are performed between each possible pair
	-- of the four coordinates, and the results are used to rank the numbers.
	local rankx = 0
	local ranky = 0
	local rankz = 0
	local rankw = 0
	if x0 > y0 then rankx=rankx+1 else ranky=ranky+1 end
	if x0 > z0 then rankx=rankx+1 else rankz=rankz+1 end
	if x0 > w0 then rankx=rankx+1 else rankw=rankw+1 end
	if y0 > z0 then ranky=ranky+1 else rankz=rankz+1 end
	if y0 > w0 then ranky=ranky+1 else rankw=rankw+1 end
	if z0 > w0 then rankz=rankz+1 else rankw=rankw+1 end
	local i1, j1, k1, l1 -- The integer offsets for the second simplex corner
	local i2, j2, k2, l2 -- The integer offsets for the third simplex corner
	local i3, j3, k3, l3 -- The integer offsets for the fourth simplex corner
	-- simplex[c] is a 4-vector with the numbers 0, 1, 2 and 3 in some order.
	-- Many values of c will never occur, since e.g. x>y>z>w makes x<z, y<w and x<w
	-- impossible. Only the 24 indices which have non-zero entries make any sense.
	-- We use a thresholding to set the coordinates in turn from the largest magnitude.
	-- Rank 3 denotes the largest coordinate.
	i1 = rankx >= 3 and 1 or 0
	j1 = ranky >= 3 and 1 or 0
	k1 = rankz >= 3 and 1 or 0
	l1 = rankw >= 3 and 1 or 0
	-- Rank 2 denotes the second largest coordinate.
	i2 = rankx >= 2 and 1 or 0
	j2 = ranky >= 2 and 1 or 0
	k2 = rankz >= 2 and 1 or 0
	l2 = rankw >= 2 and 1 or 0
	-- Rank 1 denotes the second smallest coordinate.
	i3 = rankx >= 1 and 1 or 0
	j3 = ranky >= 1 and 1 or 0
	k3 = rankz >= 1 and 1 or 0
	l3 = rankw >= 1 and 1 or 0
	-- The fifth corner has all coordinate offsets = 1, so no need to compute that.
	local x1 = x0 - i1 +   G4 -- Offsets for second corner in (x,y,z,w) coords
	local y1 = y0 - j1 +   G4
	local z1 = z0 - k1 +   G4
	local w1 = w0 - l1 +   G4
	local x2 = x0 - i2 + 2*G4 -- Offsets for third corner in (x,y,z,w) coords
	local y2 = y0 - j2 + 2*G4
	local z2 = z0 - k2 + 2*G4
	local w2 = w0 - l2 + 2*G4
	local x3 = x0 - i3 + 3*G4 -- Offsets for fourth corner in (x,y,z,w) coords
	local y3 = y0 - j3 + 3*G4
	local z3 = z0 - k3 + 3*G4
	local w3 = w0 - l3 + 3*G4
	local x4 = x0 -  1 + 4*G4 -- Offsets for last corner in (x,y,z,w) coords
	local y4 = y0 -  1 + 4*G4
	local z4 = z0 -  1 + 4*G4
	local w4 = w0 -  1 + 4*G4
	-- Work out the hashed gradient indices of the five simplex corners
	local ii = i % 256
	local jj = j % 256
	local kk = k % 256
	local ll = l % 256
	-- Calculate the contribution from the five corners
	local t0 = 0.6 - x0*x0 - y0*y0 - z0*z0 - w0*w0
	if t0 < 0 then
		n0 = 0
	else
		t0 = t0 * t0
		local g = grad4[(1)+perm[(1)+ii+perm[(1)+jj+perm[(1)+kk+perm[(1)+ll]]]]%32]
		n0 = t0 * t0 * (g[1]*x0 + g[2]*y0 + g[3]*z0 + g[4]*w0)
	end

	local t1 = 0.6 - x1*x1 - y1*y1 - z1*z1 - w1*w1
	if t1 < 0 then
		n1 = 0
	else
		t1 = t1 * t1
		local g = grad4[(1)+perm[(1)+ii+i1+perm[(1)+jj+j1+perm[(1)+kk+k1+perm[(1)+ll+l1]]]]%32]
		n1 = t1 * t1 * (g[1]*x1 + g[2]*y1 + g[3]*z1 + g[4]*w1)
	end

	local t2 = 0.6 - x2*x2 - y2*y2 - z2*z2 - w2*w2
	if t2 < 0 then
		n2 = 0
	else
		t2 = t2 * t2
		local g = grad4[(1)+perm[(1)+ii+i2+perm[(1)+jj+j2+perm[(1)+kk+k2+perm[(1)+ll+l2]]]]%32]
		n2 = t2 * t2 * (g[1]*x2 + g[2]*y2 + g[3]*z2 + g[4]*w2)
	end

	local t3 = 0.6 - x3*x3 - y3*y3 - z3*z3 - w3*w3
	if t3 < 0 then
		n3 = 0
	else
		t3 = t3 * t3
		local g = grad4[(1)+perm[(1)+ii+i3+perm[(1)+jj+j3+perm[(1)+kk+k3+perm[(1)+ll+l3]]]]%32]
		n3 = t3 * t3 * (g[1]*x3 + g[2]*y3 + g[3]*z3 + g[4]*w3)
	end

	local t4 = 0.6 - x4*x4 - y4*y4 - z4*z4 - w4*w4
	if t4 < 0 then
		n4 = 0
	else
		t4 = t4 * t4
		local g = grad4[(1)+perm[(1)+ii+1+perm[(1)+jj+1+perm[(1)+kk+1+perm[(1)+ll+1]]]]%32]
		n4 = t4 * t4 * (g[1]*x4 + g[2]*y4 + g[3]*z4 + g[4]*w4)
	end
	-- Sum up and scale the result to cover the range [-1,1]
	return 27 * (n0 + n1 + n2 + n3 + n4)
end

--@sec: Simplex.new
--@def: Simplex.new(permutations: {[number]: number} | number | Random | (number)->(number)): Generator
--@doc Returns a generator initialized with a table of permutations.
--
-- *permutations* may be an array containing each integer between 0 and 255,
-- inclusive. The order of these integers can be arbitrary.
--
-- *permutations* may be a number, which is used as a random seed to shuffle a
-- generated table of permutations.
--
-- *permutations* may be a Random object, which will be used to shuffle a
-- generated table of permutations.
--
-- *permutations* may be a function that receives an integer, and returns an
-- integer between 1 and the given value, inclusive. In this case, a generated
-- table of permutations will be shuffled using this function. math.random is an
-- example of such a function.
--
-- Otherwise, a shuffled table of permutations is generated from a random
-- source.
function Simplex.new(permutations)
	if type(permutations) == "table" then
		-- Validate permutations table.
		local found = {}
		for i = 1, 256 do
			local v = permutations[i]
			if v == nil then
				error(string.format("permutations missing index %d", i))
			end
			found[v] = true
		end
		for i = 0, 255 do
			if found[i] ~= true then
				error(string.format("permutations missing value %d", i))
			end
		end
	else
		local random
		if type(permutations) == "number" then
			local source = Random.new(permutations)
			function random(n)
				return source:NextInteger(1, n)
			end
		elseif typeof(permutations) == "Random" then
			local source = Random.new()
			function random(n)
				return source:NextInteger(1, n)
			end
		elseif type(permutations) ~= "function" then
			random = math.random
		end
		permutations = {}
		for i = 1, 256 do
			local j = random(i)
			permutations[j], permutations[i] = i-1, permutations[j]
		end
	end

	local perm = {}
	local permMod12 = {}
	for i = 0, 511 do
		perm[i+1] = permutations[(i % 256) + 1]
		permMod12[i+1] = (perm[i+1] % 12)
	end

	return setmetatable({perm = perm, permMod12 = permMod12}, mt)
end

return Simplex
