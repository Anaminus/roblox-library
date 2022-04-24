local Maid = require(script.Maid)
local Dirty = require(script.Dirty)

local function ifError(msg, err, level)
	if err == nil then
		return
	end
	level = level or 2
	error(string.format(msg, tostring(err)), level + 1)
end

local function ifWarn(msg, err, level)
	if err == nil then
		return
	end
	level = level or 2
	warn(string.format(msg, tostring(err)), level + 1)
end

local function truncatedString(bits, value)
	if type(value) ~= "string" then
		return ""
	end
	return string.sub(value, 1, 2^bits)
end

local function accumulate(window, func)
	if window <= 0 then
		return func
	end
	local nextID = 0
	return function(...)
		local id = nextID + 1
		nextID = id
		task.delay(window, function(...)
			if nextID == id then
				func(...)
			end
		end, ...)
	end
end

local function runString(source, name)
	local module = Instance.new("ModuleScript")
	module.Name = name or "<UnnamedSource>"
	module.Source = source
	local ok, result = pcall(require, module)
	if not ok then
		return result, nil
	end
	return nil, result
end

local DATA_KEY = "ActionsData"

local function LoadData()
	local actions = plugin:GetSetting(DATA_KEY)
	return actions
end

local function SaveData(actions)
	plugin:SetSetting(DATA_KEY, actions)
end

local function UpdateData(container)
	local actions = {}--LoadData()
	for _, proxy in ipairs(container:GetChildren()) do
		if not proxy:IsA("ModuleScript") then
			continue
		end
		local id = truncatedString(8, proxy.Name)

		local action
		local i
		for j, a in ipairs(actions) do
			if a.ActionID == id then
				action = a
				i = j
				break
			end
		end
		if not action then
			action = {
				ActionID = id,
				Text = "",
				StatusTip = "",
				IconName = "",
				Source = "",
			}
			table.insert(actions, action)
			i = #actions
		end
		action.Text      = truncatedString(8, proxy:GetAttribute("Text"))
		action.StatusTip = truncatedString(8, proxy:GetAttribute("StatusTip"))
		action.IconName  = truncatedString(8, proxy:GetAttribute("IconName"))
		action.Source    = proxy.Source
	end

	table.sort(actions, function(a, b)
		return a.ActionID < b.ActionID
	end)

	SaveData(actions)
	warn("updated actions")
end

local pluginMaid = Maid.new()
pluginMaid.Unloading = plugin.Unloading:Connect(function()
	pluginMaid:FinishAll()
end)

local actionMaid = Maid.new()

local container = Instance.new("Folder")
container.Name = "Actions"
container.Archivable = false
pluginMaid.container = container

local actions = LoadData()
for _, action in ipairs(actions) do
	local id = action.ActionID

	local err, callback = runString(action.Source, id)
	ifWarn("error loading action source: %s", err)
	if type(callback) ~= "function" then
		warn(string.format("action source %s did not return a function", id))
	end

	local ok, pluginAction = pcall(
		plugin.CreatePluginAction, plugin,
		id,
		action.Text,
		action.StatusTip,
		action.IconName,
		true
	)
	if not ok then
		ifWarn("error creating action: %s", action)
		continue
	end

	if type(callback) ~= "function" then
		continue
	end

	local proxy = Instance.new("ModuleScript")
	proxy.Name = id
	proxy:SetAttribute("Text", action.Text)
	proxy:SetAttribute("StatusTip", action.StatusTip)
	proxy:SetAttribute("IconName", action.IconName)
	proxy.Source = action.Source
	proxy.Parent = container

	local store = {ID=0}
	actionMaid[id] = {
		pluginAction.Triggered:Connect(function()
			callback(plugin, store)
		end),
		proxy:GetPropertyChangedSignal("Source"):Connect(accumulate(2, function()
			local err, cb = runString(proxy.Source, id)
			if err then
				return
			end
			if type(cb) ~= "function" then
				return
			end
			callback = cb
			store.ID = (store.ID or 0) + 1
			warn(string.format("updated %s action", id))
		end)),
	}
end

container.Parent = game:GetService("CoreGui")
Dirty.monitor(container, 2, UpdateData)
