local T = {}

function T.TestNew(t, require)
	local Simplex = require()

	local perm = table.create(255)
	for i = 1, 256 do
		perm[i] = i-1
	end
	local source = Random.new(0)

	if not Simplex.isGenerator(Simplex.new()) then
		T:Error("value returned by new is not a Generator")
	end
	if not Simplex.isGenerator(Simplex.fromArray(perm)) then
		T:Error("value returned by fromArray is not a Generator")
	end
	if not Simplex.isGenerator(Simplex.fromFunction(math.random)) then
		T:Error("value returned by fromFunction is not a Generator")
	end
	if not Simplex.isGenerator(Simplex.fromRandom(source)) then
		T:Error("value returned by fromRandom is not a Generator")
	end
	if not Simplex.isGenerator(Simplex.fromSeed(1)) then
		T:Error("value returned by fromSeed is not a Generator")
	end
end

return T
