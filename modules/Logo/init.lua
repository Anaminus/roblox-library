local ContentQueue = require(script.Parent.ContentQueue)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local function Heartbeat()
	return RunService.Heartbeat:Wait()
end

--@sec: Logo
--@ord: -1
--@doc: The Logo module facilitates the display of production logos when a
-- client joins. The user can create a driver that configures the timing and
-- allowed capabilities of logos, such as 2D, 3D, lighting, and sound.
--
-- Logos themselves are files in a specific format. See
-- [logo.rbxm](logo.rbxm.md) for a specification of this format.
local export = {}

--@sec: Root
--@def: type Root = Instance
--@doc: **Root** is an instance that contains objects comprising a logo. A
-- [logo.rbxm](logo.rbxm.md) file may contain one or more Roots.
export type Root = Instance

--@sec: Sequence
--@def: type Sequence
--@doc: **Sequence** is an ordered sequence of logos constructed from one or more
-- [Roots][Root].
export type Sequence = {
	--@sec: Sequence.Options
	--@def: function Sequence:Options(id: string?): Options?
	--@doc: The **Options** method lists capabilities requested by logo *id*. If
	-- *id* is nil, then returns the logical disjunction of each capability for
	-- all logos. Returns nil if *id* is not a valid logo.
	Options: (self: Sequence, id: string?) -> Options?,
	--@sec: Sequence.Run
	--@def: function Sequence:Run(config: DriverConfig): Monitor
	--@doc: The **Run** method begins the logo sequence by preloading content
	-- and presenting each logo according to the given configuration.
	Run: (self: Sequence, config: DriverConfig) -> Monitor,
}

--@sec: Monitor
--@def: type Monitor
--@doc: Monitor manages the progress of a running [Sequence][Sequence].
export type Monitor = {
	--@sec: Monitor.Cancel
	--@def: function Monitor:Cancel()
	--@doc: The **Cancel** method causes the sequence to stop immediately.
	-- Returns immediately if the sequence is finished or cancelled.
	Cancel: (self: Monitor) -> (),
	--@sec: Monitor.Wait
	--@def: function Monitor:Wait()
	--@doc: The **Wait** method blocks until the Sequence has finished
	-- presenting each logo, and the underlying ContentQueue is empty. Returns
	-- immediately if the sequence is finished or cancelled.
	Wait: (self: Monitor) -> (),
	--@sec: Monitor.Finish
	--@def: function Monitor:Finish(time: number?)
	--@doc: The **Finish** method finalizes the rendering of the Sequence by
	-- fading the blanker out to reveal whatever is displayed behind it. *time*
	-- is the duration of the fade-in effect, defaulting to the FadeInTime of
	-- the driver configuration.
	--
	-- Finish will block before fading the blanker until the Sequence is
	-- finished or cancelled.
	Finish: (self: Monitor, time: number?) -> (),
	--@sec: Monitor.ContentQueue
	--@def: function Monitor:ContentQueue(): ContentQueue.Queue
	--@doc: The **ContentQueue** method returns the queue used by the driver to
	-- load assets. Content added to the queue will begin preloading after any
	-- logo content. The monitor will wait until the queue is empty before
	-- finishing.
	ContentQueue: (self: Monitor) -> ContentQueue.Queue,
}

--@sec: Options
--@def: type Options = {
-- 	-- True if driver has 2D environment, or if logo contains 2D objects.
-- 	TwoD: boolean,
--
-- 	-- True if driver has 3D environment, or if logo contains 3D objects.
-- 	ThreeD: boolean,
--
-- 	-- True if driver allows lighting config, or if logo contains lighting data.
-- 	-- Implies ThreeD.
-- 	Lighting: boolean,
--
-- 	-- True if driver allows terrain config, or if logo contains terrain data.
-- 	-- Implies ThreeD.
-- 	Terrain: boolean,
--
-- 	-- True if driver allows scripting, or if logo contains a Main module.
-- 	Scripting: boolean,
--
-- 	-- True if driver allows sounds, or if logo contains objects for sound.
-- 	Sound: boolean,
-- }
--@doc: Options describes the required capabilities of a driver, or available
-- capabilities of a logo.
export type Options = {
	TwoD: boolean,
	ThreeD: boolean,
	Lighting: boolean,
	Terrain: boolean,
	Scripting: boolean,
	Sound: boolean,
}

type _DriverConfig = {
	Capabilities: Options,

	PrefadeTimeRange: NumberRange,
	FadeInTimeRange: NumberRange,
	UnskippableTimeRange: NumberRange,
	SkippableTimeRange: NumberRange,
	FadeOutTimeRange: NumberRange,
	PostfadeTimeRange: NumberRange,

	OverrideTimes: boolean,

	PrefadeTime: number,
	FadeInTime: number,
	UnskippableTime: number,
	SkippableTime: number,
	FadeOutTime: number,
	PostfadeTime: number,

	AssetFailureMode: string,
	EnableSkipping: boolean,
	BlankColor: Color3,
	OriginCFrame: CFrame,

	TwoDRenderer: Instance?,
	ThreeDRenderer: Instance?,
	SoundRenderer: Instance?,

	ContentQueue: ContentQueue.Queue,
}

--@sec: DriverConfig
--@def: type DriverConfig = {
-- 	-- Sets the capabilities of the driver.
-- 	Capabilities: Options?,
--
-- 	-- Specifies the allowed range for each logo's PrefadeTime.
-- 	PrefadeTimeRange: NumberRange?,
--
-- 	-- Specifies the allowed range for each logo's FadeInTime.
-- 	FadeInTimeRange: NumberRange?,
--
-- 	-- Specifies the allowed range for each logo's UnskippableTime.
-- 	UnskippableTimeRange: number?,
--
-- 	-- Specifies the allowed range for each logo's SkippableTime.
-- 	SkippableTimeRange: number?,
--
-- 	-- Specifies the allowed range for each logo's FadeOutTime.
-- 	FadeOutTimeRange: NumberRange?,
--
-- 	-- Specifies the allowed range for each logo's PostfadeTime.
-- 	PostfadeTimeRange: NumberRange?,
--
-- 	-- Allow logo to override configured timings.
-- 	OverrideTimes: boolean?,
--
-- 	-- Default time for prefade section.
-- 	PrefadeTime: number?,
--
-- 	-- Default time for fade-in section.
-- 	FadeInTime: number?,
--
-- 	-- Default time for unskippable display section.
-- 	UnskippableTime: number?,
--
-- 	-- Default time for skippable display section.
-- 	SkippableTime: number?,
--
-- 	-- Default time for fade-out section.
-- 	FadeOutTime: number?,
--
-- 	-- Default time for postfade section.
-- 	PostfadeTime: number?,
--
-- 	-- Queue used to preload content.
-- 	ContentQueue: ContentQueue.Queue?,
--
-- 	-- Whether logos can be skipped by the player. If false, then
-- 	-- SkippableTime is merged into UnskippableTime.
-- 	EnableSkipping: boolean?,
--
-- 	-- The color of the blanker.
-- 	BlankColor: Color3?,
--
-- 	-- The origin of the 3D environment.
-- 	OriginCFrame: CFrame?,
--
-- 	-- Container for 2D rendering. Defaults to local PlayerGui.
-- 	TwoDRenderer: Instance?,
--
-- 	-- Container for 3D rendering. Defaults to Workspace.
-- 	ThreeDRenderer: Instance?,
--
-- 	-- Container for sound rendering. Defaults to SoundService.
-- 	SoundRenderer: Instance?,
-- }
--@doc: Configures a [Driver][Driver].
export type DriverConfig = {
	Capabilities: Options?,

	PrefadeTimeRange: NumberRange?,
	FadeInTimeRange: NumberRange?,
	UnskippableTimeRange: number?,
	SkippableTimeRange: number?,
	FadeOutTimeRange: NumberRange?,
	PostfadeTimeRange: NumberRange?,

	OverrideTimes: boolean?,

	PrefadeTime: number?,
	FadeInTime: number?,
	UnskippableTime: number?,
	SkippableTime: number?,
	FadeOutTime: number?,
	PostfadeTime: number?,

	ContentQueue: ContentQueue.Queue?,
	AssetFailureMode: string?,
	EnableSkipping: boolean?,
	BlankColor: Color3?,
	OriginCFrame: CFrame?,

	TwoDRenderer: Instance?,
	ThreeDRenderer: Instance?,
	SoundRenderer: Instance?,
}

--@sec: Device
--@def: type Device = (driver: Driver) -> ()
--@doc: A Device receives a [Driver][Driver] to alter the content of a logo. It
-- is expected to be returned by the main module of a logo.
--
-- The device is called concurrently with the presentation of the logo, and may
-- yield.
--
-- A device must not have persisting side-effects. A device may only modify
-- instances that are provided by *driver*, and must not spawn threads that live
-- beyond the presentation of the logo.
export type Device = (driver: Driver) -> ()

--@sec: Driver
--@def: type Driver = {
-- 	-- Lists the capabilities provided by the driver.
-- 	Capabilities: Options,
--
-- 	-- The color of the blanker.
-- 	BlankColor: Color3,
--
-- 	-- The root of the 2D environment. Contains the 2D objects defined in
-- 	-- the logo. Will be nil if TwoD is not enabled.
-- 	Env2D: GuiObject?,
--
-- 	-- The root of the 3D environment. Contains the 3D objects defined in
-- 	-- the logo. Will be nil if ThreeD is not enabled.
-- 	Env3D: Model?,
--
-- 	-- A camera usable for the 3D environment. Will be nil if ThreeD is not
-- 	-- enabled.
-- 	Camera: Camera?,
--
-- 	-- The Lighting service for the 3D environment. Will be nil if ThreeD
-- 	-- or Lighting is not enabled.
-- 	Lighting: Lighting?,
--
-- 	-- The Terrain service for the 3D environment. Will be nil if ThreeD or
-- 	-- Terrain is not enabled.
-- 	Terrain: Terrain?,
--
-- 	-- The SoundService service for sound. Will be nil if Sound is not
-- 	-- enabled.
-- 	SoundService: SoundService?,
--
-- 	-- Describes the time lengths of each presentation section.
-- 	Timing: Timing,
--
-- 	-- Sets a callback to be called on every render frame of the logo.
-- 	-- Setting *callback* to nil unsets the callback.
-- 	OnStepped: (self: Driver, callback: FrameCallback?) -> (),
-- }
--@doc: Driver contains the state of a presented logo.
export type Driver = {
	Capabilities: Options,
	BlankColor: Color3,
	Env2D: GuiObject?,
	Env3D: Model?,
	Camera: Camera?,
	Lighting: Lighting?,
	Terrain: Terrain?,
	SoundService: SoundService?,
	Timing: Timing,
	OnStepped: (self: Driver, callback: FrameCallback?) -> (),
}

--@sec: FrameCallback
--@def: type FrameCallback = (driver: Driver, state: State) -> boolean?
--@doc: FrameCallback is called during the presentation of a logo. *state*
-- indicates the current state of the presentation.
--
-- If false is returned, then the driver will cancel the presentation and move
-- immediately to the next logo (defaults to true).
export type FrameCallback = (driver: Driver, state: State) -> boolean?

--@sec: Timing
--@def: type Timing = {
-- 	-- The amount of time of the fade-in section.
-- 	FadeIn: number,
--
-- 	-- The amount of time of the non-skippable portion of the display section.
-- 	Nonskippable: number,
--
-- 	-- The amount of time of the skippable portion of the display section.
-- 	Skippable: number,
--
-- 	-- The amount of time of the fade-out section.
-- 	FadeOut: number,
-- }
--@doc: Timing describes timing lengths of each presentation section.
export type Timing = {
	FadeIn: number,
	Nonskippable: number,
	Skippable: number,
	FadeOut: number,
}

--@sec: State
--@def: type State = {
-- 	-- The name of the current section.
-- 	Section: Section,
--
-- 	-- The amount of time elapsed since the start of the current section.
-- 	SectionProgress: number,
--
-- 	-- The amount of time elapsed since the start of the presentation.
-- 	OverallProgress: number,
--
-- 	-- The amount of time since the previous frame.
-- 	DeltaTime: number,
--
-- 	-- The time when the logo was skipped, since the start of the Skippable
-- 	-- section. Will be nil during unskippable sections, if the logo has not
-- 	-- been skipped, or if skipping is disabled.
-- 	SkipTime: number?,
-- }
--@doc: State provides information about a frame of a presentation.
export type State = {
	Section: Section,
	SectionProgress: number,
	OverallProgress: number,
	DeltaTime: number,
	SkipTime: number?,
}

--@sec: Section
--@def: type Section = string
--@doc: Section indicates a particular duration of time during the presentation
-- of a logo.
--
-- - `FadeIn`: When the blanker is transitioning to the logo.
-- - `Unskippable`: The unskippable portion of the logo display.
-- - `Skippable`: The skippable portion of the logo display. The logo can only
--   be skipped after this section has been entered. If the logo is skipped,
--   then the presentation will switch immediately to the FadeOut section.
-- - `FadeOut`: When the logo is transitioning to the blanker.
-- - `Postfade`: Emitted only once, to signal the end of the presentation.
export type Section = "FadeIn" | "Unskippable" | "Skippable" | "FadeOut" | "Postfade"

local function getattr(instance, attr, t)
	local value = instance:GetAttribute(attr)
	if type(t) == "function" then
		return t(value)
	elseif typeof(value) ~= t then
		return nil
	end
	return value
end

-- Return a copy with unsafe descendants removed.
local function cloneSanitized(instance)
	local copy = instance:Clone()
	for _, desc in ipairs(copy:GetDescendants()) do
		if desc:IsA("BaseScript") then
			desc.Parent = nil
		end
	end
	return copy
end

-- Clone only the root instance.
local function cloneRoot(instance)
	local copy = instance:Clone()
	for _, child in ipairs(copy:GetChildren()) do
		child.Parent = nil
	end
	return copy
end

-- Returns a list of descendant which inherit a class. Such descendants are
-- removed from the tree.
local function extractDescendants(instance, class)
	local found = {}
	for _, desc in ipairs(instance:GetDescendants()) do
		if desc:IsA(class) then
			table.insert(found, desc)
			desc.Parent = nil
		end
	end
	return found
end

-- Returns a list of descendant which inherit a class.
local function findDescendants(instance, class)
	local found = {}
	for _, desc in ipairs(instance:GetDescendants()) do
		if desc:IsA(class) then
			table.insert(found, desc)
		end
	end
	return found
end

-- Recursively constructs a copy of *parent* where non-ModuleScripts are
-- replaced by Folders. An instance that has no descendant ModuleScripts is
-- excluded. *main* is the reference main module within the tree. Returns the
-- copy of *parent*, and the copy of *main*.
local function buildModuleTree(parent, main)
	local parentCopy = nil
	local mainCopy = nil
	for _, child in ipairs(parent:GetChildren()) do
		if child.ClassName == "ModuleScript" then
			if parentCopy == nil then
				parentCopy = Instance.new("Folder")
				parentCopy.Name = parent.Name
			end
			local childCopy = child:Clone()
			childCopy.Parent = parentCopy
			if child == main then
				mainCopy = childCopy
			end
		else
			local childCopy, mainCheck = buildModuleTree(child, main)
			if childCopy then
				if parentCopy == nil then
					parentCopy = Instance.new("Folder")
					parentCopy.Name = parent.Name
				end
				childCopy.Parent = parentCopy
			end
			if mainCheck then
				mainCopy = mainCheck
			end
		end
	end
	return parentCopy, mainCopy
end

local function findSounds(logo, instance)
	local sounds = findDescendants(instance, "Sound")
	if #sounds > 0 then
		table.move(sounds, 1, #sounds, #logo.Sounds+1, logo.Sounds)
		logo.Options.Sound = true
	end
end

local function extractLogoData(logo, parent, root)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("PVInstance") then
			local copy = cloneSanitized(child)
			table.insert(logo.Env3DObjects, child)
			logo.Options.ThreeD = true
			findSounds(logo, copy)
		elseif child:IsA("GuiObject") then
			local copy = cloneSanitized(child)
			table.insert(logo.Env2DObjects, copy)
			logo.Options.TwoD = true
			findSounds(logo, copy)
		elseif child.ClassName == "Configuration" then
			if child.Name == "Camera" then
				if logo.Camera then
					continue
				end
				logo.Camera = cloneSanitized(child)
				findSounds(logo, logo.Camera)
				logo.Options.ThreeD = true
			elseif child.Name == "Lighting" then
				if logo.Lighting then
					continue
				end
				logo.Lighting = cloneSanitized(child)
				findSounds(logo, logo.Lighting)
				logo.Options.ThreeD = true
				logo.Options.Lighting = true
			elseif child.Name == "Terrain" then
				if logo.Terrain then
					continue
				end
				logo.Terrain = cloneSanitized(child)
				findSounds(logo, logo.Terrain)
				logo.TerrainRegions = extractDescendants(logo.Terrain, "TerrainRegion")
				logo.Options.ThreeD = true
				logo.Options.Terrain = true
			elseif child.Name == "SoundService" then
				if logo.SoundService then
					continue
				end
				logo.SoundService = cloneSanitized(child)
				findSounds(logo, logo.SoundService)
				logo.Options.Sound = true
			end
		elseif child.ClassName == "ModuleScript" and child.Name == "Main" then
			if logo.MainModule then
				continue
			end
			logo.ModuleTree, logo.MainModule = buildModuleTree(root, child)
			logo.Options.Scripting = true
		elseif child:IsA("Sound") then
			-- Orphan sound object.
			local copy = cloneRoot(child)
			table.insert(logo.Sounds, copy)
			if not logo.OrphanSounds[copy.Name] then
				logo.OrphanSounds[copy.Name] = copy
			end
			logo.Options.Sound = true
		elseif child:IsA("Folder") then
			-- Recurse into folders.
			extractLogoData(logo, child, root)
		end
	end
end

local defaultInstance = Instance.new("Folder")
local DefaultDriverConfig = table.freeze{
	Capabilities = table.freeze{
		TwoD      = true,
		ThreeD    = false,
		Lighting  = false,
		Terrain   = false,
		Scripting = true,
		Sound     = true,
	},

	OverrideTimes = false,

	PrefadeTimeRange    = NumberRange.new(0, 1),
	FadeInTimeRange     = NumberRange.new(0, 1),
	DisplayTimeRange    = NumberRange.new(0, 10),
	MinDisplayTimeRange = NumberRange.new(0, 10),
	FadeOutTimeRange    = NumberRange.new(0, 1),
	PostfadeTimeRange   = NumberRange.new(0, 1),

	PrefadeTime    = 0,
	FadeInTime     = 1,
	DisplayTime    = 3,
	MinDisplayTime = 1,
	FadeOutTime    = 1,
	PostfadeTime   = 0,

	AssetFailureMode = "continue",
	EnableSkipping   = false,
	BlankColor       = Color3.new(0, 0, 0),
	OriginCFrame     = CFrame.new(0, 0, 0),

	TwoDRenderer     = defaultInstance,
	ThreeDRenderer   = defaultInstance,
	SoundRenderer    = defaultInstance,

	ContentQueue     = nil,
}

local function merge(input, default)
	if type(input) ~= "table" then
		if type(default) == "table" then
			return table.clone(default)
		end
		return default
	end
	local output = {}
	for k, v in pairs(default) do
		if type(v) == "table" then
			output[k] = merge(input[k], v)
		elseif typeof(input[k]) == typeof(v) then
			output[k] = input[k]
		else
			output[k] = v
		end
	end
	return output
end

local function get(t, k)
	return t[k]
end

local function set(t, k, v)
	t[k] = v
end

-- Add each attribute in *config* to *set*.
local function unionAttributes(set, config)
	for attr in pairs(config:GetAttributes()) do
		set[attr] = true
	end
end

local function newStash(instance, logos)
	local attrSet = {}
	for _, logo in ipairs(logos) do
		local config = logo[instance.ClassName]
		if not config then
			continue
		end
		for attr in pairs(config:GetAttributes()) do
			attrSet[attr] = true
		end
	end

	local stashedChildren = instance:GetChildren()
	for _, child in ipairs(instance:GetChildren()) do
		child.Parent = nil
	end

	local stashedProperties = {}
	for attr in pairs(attrSet) do
		local ok, pvalue = pcall(get, instance, attr)
		if not ok or type(pvalue) == "function" or typeof(pvalue) == "RBXScriptSignal" then
			continue
		end
		stashedProperties[attr] = pvalue
	end

	local self = {Instance=instance}
	function self:Apply(config)
		for _, child in ipairs(instance:GetChildren()) do
			child.Parent = nil
		end
		for _, child in ipairs(config:GetChildren()) do
			child.Parent = instance
		end
		for attr, value in pairs(config:GetAttributes()) do
			local ok, pvalue = pcall(get, instance, attr)
			if not ok or type(pvalue) == "function" or typeof(pvalue) == "RBXScriptSignal" then
				continue
			end
			pcall(set, instance, attr, value)
		end
	end
	function self:Restore()
		for _, child in ipairs(instance:GetChildren()) do
			child.Parent = nil
		end
		for _, child in ipairs(stashedChildren) do
			child.Parent = instance
		end
		for prop, value in pairs(stashedProperties) do
			pcall(set, instance, prop, value)
		end
	end
	return self
end

-- Arguments are reversed.
local function sequencer(...)
	local states = {...}
	local threads = {}
	for _, state in ipairs(states) do
		threads[state] = {}
	end
	local current = nil

	-- Get current state.
	local function Current()
		return current
	end
	-- Enter next state.
	local function Next()
		current = table.remove(states)
		local list = threads[current]
		if list then
			threads[current] = nil
			for _, thread in ipairs(list) do
				task.spawn(thread)
			end
		end
	end
	-- Wait for state.
	local function WaitFor(id)
		local list = threads[id]
		if not list then
			return
		end
		table.insert(list, coroutine.running())
		coroutine.yield()
	end

	return Current, Next, WaitFor
end

local function cleanup(maid)
	local tasks = {}
	for _, task in pairs(maid) do
		table.insert(tasks, task)
	end
	table.clear(maid)
	for _, task in ipairs(tasks) do
		task()
	end
end

local function newInputMonitor()
	local maid = {}
	local received = false

	maid.inputBegan = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		received = true
	end)

	local self = {}
	function self:Received()
		return received
	end
	function self:Reset()
		received = false
	end
	function self:Destroy()
		for _, conn in pairs(maid) do
			conn:Disconnect()
		end
		table.clear(maid)
	end
	return self
end

--@sec: Logo.new
--@def: function Logo.new(...: Root): Sequence
--@doc: The **new** constructor returns a [Sequence][Sequence] from a list of
-- logo [Roots][Root].
function export.new(...: Root): Sequence
	local logos = {}
	local logoFromID = {}
	for _, root in pairs({...}) do
		if typeof(root) ~= "Instance" then
			continue
		end

		local logo = {
			Name = root.Name,
			PrefadeTime = getattr(root, "PrefadeTime", "number"),
			FadeInTime = getattr(root, "FadeInTime", "number"),
			DisplayTime = getattr(root, "DisplayTime", "number"),
			FadeOutTime = getattr(root, "FadeOutTime", "number"),
			PostfadeTime = getattr(root, "PostfadeTime", "number"),
			MinDisplayTime = getattr(root, "MinDisplayTime", "number"),
			AssetFailureMode = getattr(root, "AssetFailureMode", function(v)
				if type(v) ~= "string" then return nil end
				v = string.lower(v)
				if v == "skip" then
					return v
				end
				return "continue"
			end),
			Options = {
				TwoD = false,
				ThreeD = false,
				Lighting = false,
				Terrain = false,
				Sound = false,
				Scripting = false,
			},
			Env2DObjects = {},
			Camera = nil,
			Terrain = nil,
			TerrainRegions = {},
			Lighting = nil,
			Env3DObjects = {},
			Sounds = {},
			OrphanSounds = {},
			SoundService = nil,
			MainModule = nil,
			ModuleTree = nil,
		}

		extractLogoData(logo, root, root)
		table.freeze(logo.Options)
		if not logoFromID[logo.Name] then
			logoFromID[logo.Name] = logo
		end

		table.insert(logos, logo)
	end

	local sequence = {}
	function sequence:Options(id: string?): Options?
		if id ~= nil then
			local logo = logoFromID[id]
			if not logo then
				return nil
			end
			return logo.Options
		end
		local options = {}
		for _, logo in ipairs(logos) do
			for k, v in pairs(logo.Options) do
				options[k] = v or options[k] or false
			end
		end
		return options::Options
	end

	local ran = false
	function sequence:Run(input: DriverConfig): Monitor
		if ran then
			-- Sequence can only run once. Prepared objects have already been
			-- copied once, and will no longer be in an initialized state after
			-- the sequence has finished. The user can prepare a new sequence if
			-- they really need to run multiple times.
			error("sequence already ran", 2)
		end
		ran = true

		local config: _DriverConfig = merge(input, DefaultDriverConfig)

		local maid = {}

		-- Establish 2D renderer.
		local render2D
		if config.Capabilities.TwoD then
			render2D = config.TwoDRenderer
			if render2D == defaultInstance then
				-- Attempt to use local PlayerGui as default renderer.
				local Player = game:GetService("Players").LocalPlayer
				if Player then
					render2D = Player:FindFirstChildOfClass("PlayerGui")
				end
			end
			if not render2D then
				-- Disable if no renderer was found.
				config.Capabilities.TwoD = false
			end
		end

		-- Establish 2D environment.
		local backgroundScreen
		local env2DContainer
		local env2DTemplate
		local blankerContainer
		local blanker
		if config.Capabilities.TwoD then
			-- Insert background layer to block 3D viewport.
			backgroundScreen = Instance.new("ScreenGui")
			backgroundScreen.Name = "BackgroundScreen"
			backgroundScreen.DisplayOrder = 1
			backgroundScreen.IgnoreGuiInset = true
			backgroundScreen.ResetOnSpawn = false
			backgroundScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			local bg = Instance.new("Frame", backgroundScreen)
			bg.Name = "Background"
			-- GUI updates tend to lag behind window resizes, so the
			-- background is overscaled to block the edges when this
			-- happens.
			bg.Position = UDim2.fromScale(-0.25, -0.25)
			bg.Size = UDim2.fromScale(1.5, 1.5)
			bg.BackgroundColor3 = config.BlankColor
			table.insert(maid, function() backgroundScreen:Destroy() end)
			backgroundScreen.Parent = render2D

			-- Environment layer.
			env2DContainer = Instance.new("ScreenGui")
			env2DContainer.Name = "Env2DContainer"
			env2DContainer.DisplayOrder = 2
			env2DContainer.IgnoreGuiInset = true
			env2DContainer.ResetOnSpawn = false
			env2DContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			env2DTemplate = Instance.new("Frame")
			env2DTemplate.Name = "Env2D"
			env2DTemplate.Position = UDim2.fromScale(0, 0)
			env2DTemplate.Size = UDim2.fromScale(1, 1)
			env2DTemplate.BackgroundTransparency = 1
			table.insert(maid, function() env2DContainer:Destroy() end)
			env2DContainer.Parent = render2D

			-- Blanker layer.
			blankerContainer = Instance.new("ScreenGui")
			blankerContainer.Name = "BlankerScreen"
			blankerContainer.DisplayOrder = 3
			blankerContainer.IgnoreGuiInset = true
			blankerContainer.ResetOnSpawn = false
			blankerContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			blanker = Instance.new("Frame", blankerContainer)
			blanker.Name = "Blanker"
			-- Overscaled for same reason as background.
			blanker.Position = UDim2.fromScale(-0.25, -0.25)
			blanker.Size = UDim2.fromScale(1.5, 1.5)
			blanker.BackgroundColor3 = config.BlankColor
			blankerContainer.Parent = render2D
		end

		-- Establish 3D renderer.
		local render3D
		if config.Capabilities.ThreeD then
			render3D = config.ThreeDRenderer
			if render3D == defaultInstance then
				-- Use Workspace as default renderer.
				render3D = workspace
			end
			if not render3D then
				-- Disable if no renderer was found.
				config.Capabilities.ThreeD = false
			end
		end

		-- Establish 3D environment.
		local env3DTemplate
		local stashLighting
		local stashTerrain
		if config.Capabilities.ThreeD then
			-- Environment.
			env3DTemplate = Instance.new("Model")
			env3DTemplate.Name = "Env3D"

			local stashCamera = workspace.CurrentCamera
			table.insert(maid, function() workspace.CurrentCamera = stashCamera end)

			-- Lighting
			if config.Capabilities.Lighting then
				stashLighting = newStash(game:GetService("Lighting"), logos)
				table.insert(maid, function() stashLighting:Restore() end)
			end

			-- Terrain
			if config.Capabilities.Terrain then
				stashTerrain = newStash(workspace.Terrain, logos)
				table.insert(maid, function() stashTerrain:Restore() end)
				local intOrigin = Vector3int16.new(
					config.OriginCFrame.X/4,
					config.OriginCFrame.Y/4,
					config.OriginCFrame.Z/4
				)
				config.OriginCFrame = CFrame.new(
					intOrigin.X*4,
					intOrigin.Y*4,
					intOrigin.Z*4
				)
			end
		end

		-- Establish renderer for orphan sounds.
		local renderSound
		if config.Capabilities.Sound then
			renderSound = config.SoundRenderer
			if renderSound == defaultInstance then
				-- Use local SoundService as default renderer. It doesn't have
				-- to be this in particular (any local instance in the DataModel
				-- works), but it's a reasonable location.
				renderSound = game:GetService("SoundService")
			end
			if not renderSound then
				-- Disable if no renderer was found.
				config.Capabilities.Sound = false
			end
		end

		-- Establish sound environment.
		local stashSoundService
		if config.Capabilities.Sound then
			stashSoundService = newStash(game:GetService("SoundService"), logos)
			table.insert(maid, function() stashSoundService:Restore() end)
		else
			-- Disable sounds. The instances still exist, but they will not load
			-- any content or produce any sound.
			for _, logo in ipairs(logos) do
				for _, sound in ipairs(logo.Sounds) do
					sound.SoundId = ""
				end
			end
		end

		-- Calculate timing.
		for _, logo in ipairs(logos) do
			logo.PrefadeTime = not config.OverrideTimes and logo.PrefadeTime or config.PrefadeTime
			logo.FadeInTime = not config.OverrideTimes and logo.FadeInTime or config.FadeInTime
			logo.DisplayTime = not config.OverrideTimes and logo.DisplayTime or config.DisplayTime
			logo.MinDisplayTime = not config.OverrideTimes and logo.MinDisplayTime or config.MinDisplayTime
			logo.FadeOutTime = not config.OverrideTimes and logo.FadeOutTime or config.FadeOutTime
			logo.PostfadeTime = not config.OverrideTimes and logo.PostfadeTime or config.PostfadeTime

			config.MinDisplayTimeRange = NumberRange.new(
				math.clamp(config.MinDisplayTimeRange.Min, config.DisplayTimeRange.Min, logo.DisplayTime),
				math.clamp(config.MinDisplayTimeRange.Max, config.DisplayTimeRange.Min, logo.DisplayTime)
			)

			logo.PrefadeTime = math.clamp(logo.PrefadeTime, config.PrefadeTimeRange.Min, config.PrefadeTimeRange.Max)
			logo.FadeInTime = math.clamp(logo.FadeInTime, config.FadeInTimeRange.Min, config.FadeInTimeRange.Max)
			logo.DisplayTime = math.clamp(logo.DisplayTime, config.DisplayTimeRange.Min, config.DisplayTimeRange.Max)
			logo.MinDisplayTime = math.clamp(logo.MinDisplayTime, config.MinDisplayTimeRange.Min, config.MinDisplayTimeRange.Max)
			logo.FadeOutTime = math.clamp(logo.FadeOutTime, config.FadeOutTimeRange.Min, config.FadeOutTimeRange.Max)
			logo.PostfadeTime = math.clamp(logo.PostfadeTime, config.PostfadeTimeRange.Min, config.PostfadeTimeRange.Max)
		end
		-- Calculate timing margins.
		local lastPostfade = 0
		for _, logo in ipairs(logos) do
			logo.PrefadeTime = math.max(logo.PrefadeTime, lastPostfade)
			lastPostfade = logo.PostfadeTime
		end

		-- Begin preloading content.
		local queue = config.ContentQueue or ContentQueue.new()
		for i, logo in ipairs(logos) do
			local content = {}
			if config.Capabilities.TwoD then
				table.move(logo.Env2DObjects, 1, #logo.Env2DObjects, #content+1, content)
			end
			if config.Capabilities.ThreeD then
				table.move(logo.Env3DObjects, 1, #logo.Env3DObjects, #content+1, content)
				if logo.Camera then table.insert(content, logo.Camera) end
				if config.Capabilities.Terrain then
					if logo.Terrain then table.insert(content, logo.Terrain) end
				end
				if config.Capabilities.Lighting then
					if logo.Lighting then table.insert(content, logo.Lighting) end
				end
			end
			if config.Capabilities.Sound then
				if logo.SoundService then table.insert(content, logo.SoundService) end
				for _, sound in pairs(logo.OrphanSounds) do
					table.insert(content, sound)
				end
			end
			queue:Add(i, content)
			task.spawn(function()
				queue:WaitFor(i)
				print("CONTENT_LOADED",i,logo.Name)
			end)
		end

		-- Run logos.
		table.freeze(config.Capabilities)
		local canceled = false
		local waitingThreads: {thread}? = {}
		task.spawn(function()
			for i, logo in ipairs(logos) do
				local logoMaid = {}
				maid.logo = logoMaid

				-- Prepare driver.
				local driver = {
					Capabilities = config.Capabilities,
					BlankColor = config.BlankColor,
					Env2D = nil,
					Env3D = nil,
					Camera = nil,
					Lighting = if stashLighting then stashLighting.Instance else nil,
					Terrain = if stashTerrain then stashTerrain.Instance else nil,
					SoundService = if stashSoundService then stashSoundService.Instance else nil,
				}
				local enterNextState
				driver.CurrentState, enterNextState, driver.WaitForState = sequencer(
					-- Arguments are reverse-order.
					"PostfadeTime",
					"FadeOutTime",
					"DisplayTime",
					"FadeInTime",
					"PrefadeTime"
				)

				-- Move objects to correct locations.
				if config.Capabilities.TwoD then
					local env2D = env2DTemplate:Clone()
					for _, object in ipairs(logo.Env2DObjects) do
						object.Parent = env2D
					end
					env2D.Parent = env2DContainer
					driver.Env2D = env2D
					table.insert(logoMaid, function() env2D:Destroy() end)
				end
				backgroundScreen.Enabled = not logo.Options.ThreeD
				if config.Capabilities.ThreeD then
					local env3D = env3DTemplate:Clone()
					for _, object in ipairs(logo.Env3DObjects) do
						object.Parent = env3D
					end
					env3D:PivotTo(config.OriginCFrame)
					env3D.Parent = render3D
					table.insert(logoMaid, function() env3D:Destroy() end)
					driver.Env3D = env3D
					-- driver.Camera = logo.Camera or Instance.new("Camera")
					driver.Camera = Instance.new("Camera")
					driver.Camera.Name = "Env3DCamera"
					local cf = driver.Camera.CFrame * config.OriginCFrame
					local f = driver.Camera.Focus * config.OriginCFrame
					driver.Camera.CFrame = cf
					if driver.Camera.CameraSubject == nil then
						driver.Camera.Focus = f
					end
					driver.Camera.Parent = env3D
					if render3D == workspace then
						render3D.CurrentCamera = driver.Camera
					end
					table.insert(logoMaid, function() driver.Camera:Destroy() end)
					if config.Capabilities.Lighting and logo.Lighting then
						stashLighting:Apply(logo.Lighting)
					end
					if config.Capabilities.Terrain and logo.Terrain then
						stashTerrain:Apply(logo.Terrain)
						for _, region in ipairs(logo.TerrainRegions) do
							local corner = getattr(region, "Corner", "Vector3") or Vector3.zero
							corner = Vector3int16.new(
								corner.X + config.OriginCFrame.X/4,
								corner.Y + config.OriginCFrame.Y/4,
								corner.Z + config.OriginCFrame.Z/4
							)
							local pasteEmptyCells = getattr(region, "PasteEmptyCells", "boolean") or false
							stashTerrain.Instance:PasteRegion(region, corner, pasteEmptyCells)
						end
					end
				end
				if config.Capabilities.Sound and logo.SoundService then
					stashSoundService:Apply(logo.SoundService)
					for _, sound in pairs(logo.OrphanSounds) do
						sound.Parent = renderSound
					end
					table.insert(logoMaid, function()
						for _, sound in pairs(logo.OrphanSounds) do
							sound:Destroy()
						end
					end)
				end

				table.freeze(driver)

				-- Enter prefade.
				enterNextState()

				-- Run logo device.
				if config.Capabilities.Scripting then
					local ok, device = pcall(require, logo.MainModule)
					if ok then
						task.spawn(device, driver)
					end
				end

				-- Run prefade.
				task.wait(logo.PrefadeTime)
				if canceled then break end

				-- Wait for logo content to finish loading.
				task.delay(2, function()
					if queue:Has(i) then
						--TODO: Display loading indicator.
						print("LOADING...")
					end
				end)
				queue:WaitFor(i)
				if canceled then break end

				-- Enter fade-in.
				enterNextState()
				if blanker then
					local i = 0
					local n = logo.FadeInTime
					while i < n do
						local dt = Heartbeat()
						if canceled then break end
						blanker.BackgroundTransparency = i/n
						i += dt
					end
					blanker.BackgroundTransparency = 1
				else
					task.wait(logo.FadeInTime)
				end
				if canceled then break end

				-- Enter display.
				enterNextState()
				if config.EnableSkipping and logo.MinDisplayTime < logo.DisplayTime then
					local i = 0
					local n = logo.DisplayTime
					local minTime = logo.MinDisplayTime
					local inputMon = newInputMonitor()
					while i < n do
						local dt = Heartbeat()
						if canceled then break end
						if i >= minTime and inputMon:Received() then
							break
						end
						inputMon:Reset()
						i += dt
					end
					inputMon:Destroy()
				else
					task.wait(logo.DisplayTime)
				end
				if canceled then break end

				-- Wait for next logo content to finish loading.
				task.delay(2, function()
					if queue:Has(i+1) then
						--TODO: Display loading indicator.
						print("LOADING NEXT...")
					end
				end)
				queue:WaitFor(i+1)
				if canceled then break end

				-- Enter fade-out.
				enterNextState()
				if blanker then
					local i = 0
					local n = logo.FadeOutTime
					while i < n do
						local dt = Heartbeat()
						if canceled then break end
						blanker.BackgroundTransparency = 1-i/n
						i += dt
					end
					blanker.BackgroundTransparency = 0
				else
					task.wait(logo.FadeOutTime)
				end
				if canceled then break end

				-- Enter postfade.
				enterNextState()

				-- Clean up environments.
				cleanup(logoMaid)
				maid.logo = nil
			end

			-- Do final postfade.
			if not canceled then
				task.wait(lastPostfade)
			end

			-- Post-sequence clean-up.
			cleanup(maid)
			blanker.BackgroundTransparency = 0

			-- Resume waiting threads.
			local threads = waitingThreads
			waitingThreads = nil
			for _, thread in threads do
				task.spawn(thread)
			end
		end)

		local monitor = {}
		function monitor:ContentQueue()
			return queue
		end
		function monitor:Cancel()
			canceled = true
			if waitingThreads then
				table.insert(waitingThreads, coroutine.running())
				coroutine.yield()
			end
		end
		function monitor:Wait()
			if waitingThreads then
				table.insert(waitingThreads, coroutine.running())
				coroutine.yield()
			end
			queue:WaitFor()
		end
		function monitor:Finish(time: number?)
			self:Wait()
			task.spawn(function()
				local i = 0
				local n = time or config.FadeInTime
				while i < n do
					local dt = Heartbeat()
					blanker.BackgroundTransparency = i/n
					i += dt
				end
				blanker.BackgroundTransparency = 1
				blankerContainer:Destroy()
			end)
		end
		return monitor
	end

	return sequence
end

return table.freeze(export)
