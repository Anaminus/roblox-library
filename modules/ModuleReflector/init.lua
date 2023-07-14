--@sec: ModuleReflector
--@ord: -1
--@doc: Enables tracking and indirect reloading of a set of ModuleScripts by
-- requiring virtual copies.
--
-- The [Reflector][Reflector] reflects a configured module and its dependencies.
-- These reflections can be required without caching, allowing the modules to be
-- "reloaded" any number of times without affecting the original. This is
-- accomplished by creating virtual copies of modules and requiring them
-- instead.
--
-- An option to reflect breakpoints is also available, allowing reflections to
-- be debugged as though they were the originals.
--
-- To enable reloading, a [callback][Config.Changed] can be configured to inform
-- the user when the Source of the module changes, or that of any of its
-- dependencies. Changes can be [accumulated][Config.ChangeWindow] over time to
-- avoid invoking the callback too often.

local Maid = require(script.Parent.Maid)
local Accumulate = require(script.Accumulate)
local BreakpointSyncer =require(script.BreakpointSyncer)

local export = {}

--@sec: Config
--@ord: 1
--@def: type Config
--@doc: Configures a [Reflector][Reflector].
export type Config = {
	--@sec: Config.Module
	--@ord: 1
	--@def: Config.Module: ModuleScript
	--@doc: The root module to reflect.
	Module: ModuleScript,

	--@sec: Config.Prefix
	--@ord: 2
	--@def: Config.Prefix: string?
	--@doc: An optional prefix assigned as the Name of the root of the virtual
	-- game tree.
	Prefix: string?,

	--@sec: Config.Changed
	--@ord: 3
	--@def: Config.Changed: (refl: Reflector) -> ()
	--@doc: Called when the Source of the root module or a dependency changes.
	-- Receives the Reflector itself to enable easy reloading.
	Changed: (refl: Reflector) -> (),

	--@sec: Config.ChangeWindow
	--@ord: 4
	--@def: Config.ChangeWindow: number?
	--@doc: Number of seconds to accumulate changes before calling
	-- [Changed][Config.Changed]. Defaults to 1.
	ChangeWindow: number?,
}

--@sec: Reflector
--@ord: 2
--@def: type Reflector
--@doc: Reflects a configured module and its dependencies.
export type Reflector = {
	--@sec: Reflector.Module
	--@ord: 1
	--@def: Reflector.Module: ModuleScript
	--@doc: The root module being reflected. Read-only.
	Module: ModuleScript,

	--@sec: Reflector.Require
	--@ord: 2
	--@def: Reflector:Require(): (result: any, err: error)
	--@doc: Initializes a new reflection of the module and attempts to require
	-- it, starting a new run.
	--
	-- On success, Require returns the result of requiring the module, and nil,
	-- indicating no error occurred. This run becomes the active run, replacing
	-- any previously active run.
	--
	-- On failure, the run is canceled, and Require returns nil and an error
	-- indicating why the run failed. Any previously active run continues as
	-- normal.
	Require: (self: Reflector) -> (any, error),

	--@sec: Reflector.Debug
	--@ord: 3
	--@def: Reflector:Debug(): (result: any, err: error)
	--@doc: Behaves the same as [Require][Reflector.Require], but enables
	-- debugging by synchronizing breakpoints from modules to their reflections.
	--
	-- Due to security limitations, this method cannot be called by plugins.
	-- However, it can be called by Studio's command bar. Recommended use of
	-- this method is to expose it to the command bar through the _G table.
	Debug: (self: Reflector) -> (any, error),

	--@sec: Reflector.Release
	--@ord: 4
	--@def: Reflector:Release()
	--@doc: Stops any active run, if present.
	Release: () -> (),

	--@sec: Reflector.Destroy
	--@ord: 5
	--@def: Reflector:Destroy()
	--@doc: Destroys the Reflector, stopping any active runs and decoupling from
	-- the module.
	Destroy: (self: Reflector) -> (),
}

export type error = any

--@sec: ModuleReflector.new
--@def: ModuleReflector.new(config: Config): Reflector
--@doc: Returns a new [Reflector][Reflector].
function export.new(config: Config): Reflector
	local rootModule = config.Module
	local prefix = config.Prefix
	local changed = config.Changed
	local changeWindow = config.ChangeWindow

	assert(typeof(rootModule) == "Instance" and rootModule:IsA("ModuleScript"), "Module must be a ModuleScript")
	assert(prefix == nil or type(prefix) == "string", "Prefix must be a string")
	assert(type(changed) == "function", "Changed must be a function")
	assert(changeWindow == nil or type(changeWindow) == "number", "ChangeWindow must be a number")

	-- Represents all run attempts.
	local rootMaid = Maid.new()

	local changeAccumulator = Accumulate(changeWindow or 1, changed)

	local self = {
		Module = rootModule,
	}

	local function doRequire(debuggingEnabled: boolean): (any, error)
		if not rootMaid:Alive() then
			return nil, "reflector is destroyed"
		end

		-- Represents current run attempt.
		local maid = Maid.new()

		-- Virtual representation of the DataModel.
		local root = Instance.new("Folder")
		maid._ = root
		root.Name = prefix or "[Reflected]"
		root.Archivable = false
		-- Adding the virtual tree to the DataModel allows ScriptDebuggers to be
		-- created for virtual ModuleScripts.
		root.Parent = game

		local virtualCopies = {[game] = root}
		-- Create or get a virtual copy of a subject.
		local function findVirtualInstance(subject: Instance?): Instance?
			if subject then
				local copy = virtualCopies[subject]
				if copy then
					return copy
				end

				copy = Instance.new("Folder")
				copy.Name = subject.Name
				copy.Archivable = false
				-- Refer using self so that, in case the subject is a module
				-- that gets required later, this Folder representation can be
				-- replaced.
				maid[copy] = {
					copy,
					subject:GetPropertyChangedSignal("Name"):Connect(function()
						copy.Name = subject.Name
					end),
				}
				virtualCopies[subject] = copy
				if subject ~= game then
					-- Because root is located under game, its Parent must be
					-- ignored here.
					copy.Parent = findVirtualInstance(subject.Parent)
				end
				return copy
			end
			return nil
		end

		-- Create a virtual copy of a module.
		local function createVirtualModule(module: ModuleScript): ModuleScript
			local copy = virtualCopies[module]
			if copy then
				if copy:IsA("ModuleScript") then
					-- Since modules are cached, this shouldn't be reachable,
					-- but whatever.
					return copy
				else
					-- Destroy Folder representation of unrequired module, if
					-- present.
					maid[copy] = nil
				end
			end

			copy = Instance.new("ModuleScript")
			copy.Name = module.Name
			copy.Archivable = false
			copy.Source = `--[[BookshelfPreamble]]return function(s,r)script,require=s,r;s,r=nil,nil;--[[/BookshelfPreamble]]{module.Source}\n--[[BookshelfPostamble]]end--[[/BookshelfPostamble]]`
			maid._ = {
				copy,
				module:GetPropertyChangedSignal("Name"):Connect(function()
					copy.Name = module.Name
				end),
				module:GetPropertyChangedSignal("Source"):Connect(function()
					changeAccumulator(self)
				end),
				if debuggingEnabled then BreakpointSyncer.new(module, copy) else nil,
			}
			copy.Parent = findVirtualInstance(module.Parent)
			return copy
		end

		-- Caches results of modules, to emulate normal require behavior.
		local cache = setmetatable({}, {__mode="k"})
		-- If a module returns itself, then its cache entry will never be
		-- collected (ephemeron tables are needed to fix this), so the cache
		-- must be cleared explicitly when its no longer in use.
		maid._ = function() table.clear(cache) end

		-- Proxy of require passed to copy of each required module.
		local function requireProxy(module: ModuleScript): any
			if typeof(module) ~= "Instance" and not module:IsA("ModuleScript") then
				error("Attempted to call require with invalid argument(s).", 2)
			end

			-- Reuse cached result.
			local result = cache[module]
			if result ~= nil then
				return result
			end

			-- Create virtual copy of required module.
			local copy = createVirtualModule(module)

			-- Acquire wrapper function.
			local ok, init = pcall(require, copy)
			if not ok then
				-- Must be a syntax error.
				error("Requested module experienced an error while loading", 2)
			end

			-- Call wrapper to pass in proxy environment.
			ok, result = pcall(init, module, requireProxy)
			if not ok then
				-- Must be a runtime error.
				error("Requested module experienced an error while loading", 2)
			end

			-- Check result.
			if result == nil then
				error("Module code did not return exactly one value", 2)
			end

			-- Cache result.
			cache[module] = result
			return result
		end

		-- Start by requiring root module.
		local ok, result = pcall(requireProxy, rootModule)
		if not ok then
			-- Cleanup failed attempt.
			maid:Destroy()
			return nil, result
		end

		-- Replace previous run.
		rootMaid.active = maid

		return result, nil
	end

	function self:Require()
		return doRequire(false)
	end

	function self:Debug()
		return doRequire(true)
	end

	function self:Release()
		-- Cancel active run, if present.
		rootMaid.active = nil
	end

	function self:Destroy()
		rootMaid:Destroy()
	end

	return table.freeze(self)
end

return table.freeze(export)
