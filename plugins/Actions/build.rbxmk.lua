local plugins = ...
local modules = path.expand("$sd/../../modules")

local plugin = Instance.new("DataModel")

local main = fs.read("Main.script.lua")
main.Parent = plugin

local function Require(...)
	local module = fs.read(path.join(...))
	module.Parent = main
	return module
end

local function Output(...)
	fs.write(path.join(...), plugin)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Require(modules, "Maid/Maid.lua")
Require(modules, "Dirty/Dirty.lua")

Output(plugins, "Actions.rbxm")
