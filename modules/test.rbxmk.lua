-- Build test file for module in working directory.

local dir = os.expand("$wd")
local game = DataModel.new()

local runnerSource = [[
local Testing = require(script.Testing)

local runner = Testing.Runner({
	Scan = {script.Modules},
	Yield = wait,
})

local results = runner:Test(...)
print("\n" .. tostring(results))
]]

local ServerScriptService = game:GetService("ServerScriptService")
local runner = Instance.new("Script")
runner.Name = "Runner"
runner.Source = types.ProtectedString(runnerSource)
runner.Parent = ServerScriptService
local modules = Instance.new("Folder")
modules.Name = "Modules"
modules.Parent = runner
local testing = fs.read("../Testing/Testing.lua")
testing.Parent = runner

local testPairs = {}
for _, file in ipairs(fs.dir(dir)) do
	if not file.IsDir then
		local stem = string.match(file.Name, "^(.+).lua$")
		if stem then
			if not testPairs[stem] then
				testPairs[stem] = {}
			end
			testPairs[stem].Module = os.join(dir, file.Name)
		end

		local stem = string.match(file.Name, "^(.+).test.lua$")
		if stem then
			if not testPairs[stem] then
				testPairs[stem] = {}
			end
			testPairs[stem].Test = os.join(dir, file.Name)
		end
	end
end

local hasTestPairs = false
for name, pair in pairs(testPairs) do
	if pair.Module and pair.Test then
		local module = fs.read(pair.Module)
		local test = fs.read(pair.Test)
		module.Parent = modules
		test.Parent = modules
		hasTestPairs = true
	end
end

if hasTestPairs then
	fs.mkdir(os.join(dir, "etc"))
	fs.write(os.join(dir, "etc", "Test.rbxl"), game)
end
