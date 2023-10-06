--!strict

local LiveBindTag = "LiveBind"

local CollectionService = game:GetService("CollectionService")
local CoreGui = game:GetService("CoreGui")

local Scope = require(script.Scope)
local ModuleReflector = require(script.ModuleReflector)

local PluginScope = Scope.new()
local PluginContext = PluginScope:Context()
PluginContext:Connect(nil, plugin.Unloading, function()
	PluginScope:Destroy()
end)

local RootParent = Instance.new("Folder")
PluginContext:AssignEach(RootParent)
RootParent.Name = "[LiveBind]"
RootParent.Archivable = false
RootParent.Parent = CoreGui

local function handleModule(moduleContext: Scope.Context, module: ModuleScript)
	local function updateName()
		if module:GetAttribute("Disabled") then
			moduleContext:Clean("tagScope")
			return
		end
		local tag = module.Name
		local tagScope = Scope.new()
		local tagContext = tagScope:Context()
		moduleContext:Assign("tagScope", tagScope)

		local function sourceChanged(reflector: ModuleReflector.Reflector, edited: boolean?)
			local sourceScope = Scope.new()
			local sourceContext = sourceScope:Context()

			local bindInstance, err = reflector:Require()
			if err ~= nil then
				warn(string.format("binding %q: %s", tag, err))
				return
			end
			local bindTag = nil
			if type(bindInstance) == "table" then
				bindTag = bindInstance.tag
				if type(bindTag) ~= "function" then
					bindTag = nil
				end
				bindInstance = bindInstance.instance
			end
			if type(bindInstance) ~= "function" then
				if bindTag == nil then
					return
				end
			end

			-- Override *after* confirming that the binding has been resolved.
			-- This causes the previous binding to continue working while the
			-- current binding is failing.
			tagContext:Assign("sourceScope", sourceScope)

			if edited then
				warn(string.format("updated %s", tag))
			end

			local count = 0
			local function instanceAdded(instance: Instance)
				if count == 0 and bindTag then
					local bindTagScope = Scope.new()
					sourceContext:Assign("bindTagScope", bindTagScope)
					task.spawn(bindTag, bindTagScope:Context())
				end
				count += 1
				if bindInstance then
					local instanceScope = Scope.new()
					sourceContext:Assign(instance, instanceScope)
					bindInstance(instanceScope:Context(), instance)
				end
			end

			sourceContext:Connect("instanceAdded", CollectionService:GetInstanceAddedSignal(tag), instanceAdded)
			sourceContext:Connect("instanceRemoved", CollectionService:GetInstanceRemovedSignal(tag), function(instance: Instance)
				sourceContext:Clean(instance)
				count -= 1
				if count == 0 then
					sourceContext:Clean("bindTagScope")
				end
			end)
			for _, instance in CollectionService:GetTagged(tag) do
				instanceAdded(instance)
			end
		end

		local reflector = ModuleReflector.new({
			Module = module,
			Prefix = `[{tag}]`,
			RootParent = RootParent,
			Changed = function(refl: ModuleReflector.Reflector)
				sourceChanged(refl, true)
			end,
		})
		tagContext:AssignEach(reflector)
		task.spawn(sourceChanged, reflector)
	end

	moduleContext:Connect(nil, module:GetAttributeChangedSignal("Disabled"), updateName)
	moduleContext:Connect(nil, module:GetPropertyChangedSignal("Name"), updateName)
	updateName()
end

local moduleScopes: {[ModuleScript]: Scope.Scope} = {}
local containerScopes: {[Instance]: Scope.Scope} = {}
local function containerAdded(instance: Instance)
	local containerScope = PluginScope:Derive()
	local containerContext = containerScope:Context()
	containerScopes[instance] = containerScope

	local function moduleAdded(module: Instance)
		if module:IsA("ModuleScript") then
			local moduleScope = containerScope:Derive()
			moduleScopes[module] = moduleScope
			handleModule(moduleScope:Context(), module)
		end
	end

	containerContext:Connect(nil, instance.ChildAdded, moduleAdded)
	containerContext:Connect(nil, instance.ChildRemoved, function(child: Instance)
		local scope = moduleScopes[child::ModuleScript]
		if scope then
			moduleScopes[child::ModuleScript] = nil
			scope:Destroy()
		end
	end)
	for _, child in instance:GetChildren() do
		moduleAdded(child)
	end
end
PluginContext:Connect(nil, CollectionService:GetInstanceAddedSignal(LiveBindTag), containerAdded)
PluginContext:Connect(nil, CollectionService:GetInstanceRemovedSignal(LiveBindTag), function(instance: Instance)
	local containerScope = containerScopes[instance]
	if containerScope then
		containerScopes[instance] = nil
		containerScope:Destroy()
	end
end)
for _, instance in CollectionService:GetTagged(LiveBindTag) do
	containerAdded(instance)
end
