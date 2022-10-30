local Testing = require(script.Testing)

local runner = Testing.Runner({
	Scan = {script.Modules},
	Yield = wait,
	NoCopy = true,
})

local results = runner:Test(...)
print("\n" .. tostring(results))
