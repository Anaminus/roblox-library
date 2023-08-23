-- Visit the permutations of elements of each array.
local function CartesianProduct(t, f, n, ...)
	n = n or #t
	if n <= 0 then
		f(...)
	else
		local v = t[n]
		for _, e in v do
			CartesianProduct(t, f, n-1, e, ...)
		end
	end
end

CartesianProduct({
	{"A","B"},
	{"C"},
	{"D","E","F"},
}, print)
--> A C D
--> B C D
--> A C E
--> B C E
--> A C F
--> B C F
