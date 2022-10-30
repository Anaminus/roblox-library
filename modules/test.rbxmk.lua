-- Build test file for module in working directory.

local dir = path.expand("$wd")
local game = Instance.new("DataModel")

local runnerSource = fs.read(path.expand("$sd/Testing/etc/Runner.server.lua"),"bin")

local ServerScriptService = game:GetService("ServerScriptService")
local runner = Instance.new("Script")
runner.Name = "Runner"
rbxmk.set(runner, "Source", runnerSource, "ProtectedString")
runner.Parent = ServerScriptService
local modules = Instance.new("Folder")
modules.Name = "Modules"
modules.Parent = runner
local testing = fs.read("../Testing/init.lua")
testing.Name = "Testing"
testing.Parent = runner

local pendingRequires = {}
local required = {}
local testPairs = {}
for _, file in ipairs(fs.dir(dir)) do
	if not file.IsDir then
		local stem = string.match(file.Name, "^(.+).lua$")
		if stem then
			if stem == "init" then
				stem = path.split(dir, "base")
			end
			if not testPairs[stem] then
				testPairs[stem] = {}
			end
			local filePath = path.join(dir, file.Name)
			testPairs[stem].Module = filePath
			table.insert(pendingRequires, {module=stem, path=filePath})
			print("found", stem, "=>", filePath)
		end

		local stem = string.match(file.Name, "^(.+).test.lua$")
		if stem then
			if not testPairs[stem] then
				testPairs[stem] = {}
			end
			testPairs[stem].Test = path.join(dir, file.Name)
		end
	end
end

local hasTestPairs = false
for name, pair in pairs(testPairs) do
	if pair.Module and pair.Test then
		local module = fs.read(pair.Module)
		local test = fs.read(pair.Test)
		module.Name = name
		module.Parent = modules
		test.Parent = modules
		hasTestPairs = true
	end
end

local function findRequires(source)
	local reqs = {}
	for line in string.gmatch(source, "require%b()") do
		local module = string.match(line, "require%(script%.Parent%.(.+)%)")
		if module then
			table.insert(reqs, module)
		end
	end
	return reqs
end

local function resolveRequires(moduleName, filePath)
	if required[moduleName] then
		return
	end
	required[moduleName] = true
	local source = fs.read(filePath, "bin")
	local reqs = findRequires(source)
	for _, req in ipairs(reqs) do
		if not required[req] then
			local filePath = path.join("..", req, "init.lua")
			local module = fs.read(filePath)
			module.Name = req
			module.Parent = modules
			table.insert(pendingRequires, {module=req, path=filePath})
			print("found", req, "=>", filePath)
		end
	end
end

while #pendingRequires > 0 do
	local r = table.remove(pendingRequires)
	resolveRequires(r.module, r.path)
end

if hasTestPairs then
	fs.mkdir(path.join(dir, "etc"))
	fs.write(path.join(dir, "etc", "Test.rbxl"), game)
end
