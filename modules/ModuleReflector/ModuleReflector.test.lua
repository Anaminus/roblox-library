local T = {}

local function Module(name, source, children)
	local module = Instance.new("ModuleScript")
	module.Name = name
	module.Archivable = false
	module.Source = source
	if children then
		for _, child in children do
			child.Parent = module
		end
	end
	return module
end

function T.TestReflector(t, require)
	local ModuleReflector = require()

	local A = Module("A", [[local B = require(script.B); return "A" .. B]], {
		Module("B", [[local C = require(script.C); return "B" .. C]], {
			Module("C", [[return "C"]]),
		})
	})

	local refl = ModuleReflector.new{
		Module = A,
		Prefix = "[Test]",
		ChangeWindow = 0,
		Changed = function(refl)
			local result, err = refl:Require()
			if err ~= nil then
				t:Fatalf("unexpected error: %s", err)
			end
			if result ~= "ZBC" then
				t:Fatalf("expected result \"ZBC\", got %q", result)
			end
		end,
	}
	local result, err = refl:Require()
	if err ~= nil then
		t:Fatalf("unexpected error: %s", err)
	end
	if result ~= "ABC" then
		t:Fatalf("expected result \"ABC\", got %q", result)
	end

	A.Source = [[local B = require(script.B); return "Z" .. B]]
end

return T
