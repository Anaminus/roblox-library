local Base85 = require(script.Base85)
local Binstruct = require(script.Binstruct)
local Maid = require(script.Maid)
local Dirty = require(script.Dirty)

local ACTIONS_FORMAT = {"struct",
	{"Length"    , {"uint", 16}},
	{"ActionID"  , {"vector", "Length", {"string", 8}}},
	{"Text"      , {"vector", "Length", {"string", 8}}},
	{"StatusTip" , {"vector", "Length", {"string", 8}}},
	{"IconName"  , {"vector", "Length", {"string", 8}}},
	{"Source"    , {"vector", "Length", {"string", 32}}},
}

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

local err, codec = Binstruct.new(ACTIONS_FORMAT)
if err then
	ifError("error compiling data format: %s", err)
end

local DATA_KEY = "ActionsData"

local function LoadData()
	local err, bytes
	local encodedBytes = plugin:GetSetting(DATA_KEY)
	if type(encodedBytes) ~= "string" or #encodedBytes == 0 then
		bytes = "\0\0"
	else
		err, bytes = Base85.decode(encodedBytes)
		ifError("error decoding data: Base85: %s", err)
		if #bytes == 0 then
			bytes = "\0\0"
		end
	end
	local err, data = codec:Decode(bytes)
	ifError("error decoding data: %s", err)

	local actions = table.create(data.Length)
	for i = 1, data.Length do
		table.insert(actions, {
			ActionID = data.ActionID[i],
			Text = data.Text[i],
			StatusTip = data.StatusTip[i],
			IconName = data.IconName[i],
			Source = data.Source[i],
		})
	end

	return actions
end

local function SaveData(actions)
	local data = {
		Length = #actions,
		ActionID = table.create(#actions),
		Text = table.create(#actions),
		StatusTip = table.create(#actions),
		IconName = table.create(#actions),
		Source = table.create(#actions),
	}
	for i, action in ipairs(actions) do
		data.ActionID[i] = action.ActionID
		data.Text[i] = action.Text
		data.StatusTip[i] = action.StatusTip
		data.IconName[i] = action.IconName
		data.Source[i] = action.Source
	end

	local err, bytes = codec:Encode(data)
	ifError("error encoding data: %s", err)

	local encodedBytes = Base85.encode(bytes)

	plugin:SetSetting(DATA_KEY, encodedBytes)
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
	actionMaid[id] = {
		pluginAction.Triggered:Connect(function()
			callback(plugin)
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
			warn(string.format("updated %s action", id))
		end)),
	}
end

container.Parent = game:GetService("CoreGui")
Dirty.monitor(container, 2, UpdateData)
