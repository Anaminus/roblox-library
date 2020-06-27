--[[
Geometry

	Part manipulation and guidelines.

DESCRIPTION

	Valid selections can be BaseParts, Attachments, and Models that have a
	PrimaryPart set.

API

	-- Arcs the selection n times. The 1st selection is the circle origin. The
	-- 2nd and 3rd selections specify the arc of the circle. The remaining
	-- selections are duplicated n times around the Y axis of the origin.
	--
	-- If *select* is true, then the remaining selections will be set to the
	-- last set of duplicated objects.
	_G.arc(n: number, select: boolean)

	-- Clears the Attachments from the selection and all descendants.
	_G.clatt()

	-- Draws a line from the 1st selection to the 2nd selection as a Part with a
	-- thickness of twice the current grid size.
	_G.line()

	-- Virtual geometry is non-physical geometry that may be used for things
	-- like guidelines.

	-- Draws a line from the 1st selection to the 2nd selection as virtual
	-- geometry.
	_G.gline(color: Color3?, thickness: number?)

	-- Clears all virtual geometry.
	_G.gclear()

]]

local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local StudioService = game:GetService("StudioService")
local StarterGui = game:GetService("StarterGui")

local function getCFrame(v)
	if typeof(v) ~= "Instance" then return nil end
	if v:IsA("Attachment") then
		return v.WorldCFrame
	elseif v:IsA("Model") then
		return v.PrimaryPart.CFrame
	elseif v:IsA("BasePart") then
		return v.CFrame
	end
	return nil
end

local function setCFrame(v, cf)
	if typeof(v) ~= "Instance" then return nil end
	if v:IsA("Attachment") then
		v.WorldCFrame = cf
	elseif v:IsA("Model") then
		v:SetPrimaryPartCFrame(cf)
	elseif v:IsA("BasePart") then
		v.CFrame = cf
	end
end

function _G.arc(n, select)
	if n == 0 then return end
	local s = Selection:Get()
	local o = s[1]
	local p0 = s[2]
	local p1 = s[3]
	s = {unpack(s, 4)}
	if not o then warn("missing origin") return end
	if not p0 then warn("missing first point") return end
	if not p1 then warn("missing second point") return end
	if #s == 0 then warn("missing objects") return end


	local ocf = getCFrame(o); if not o then warn("no cframe from origin") return end
	local p0cf = getCFrame(p0); if not p0 then warn("no cframe from first point") return end
	local p1cf = getCFrame(p1); if not p1 then warn("no cframe from second point") return end

	do
		local ss = {}
		for _, v in ipairs(s) do
			if v:IsA("BasePart") and v ~= workspace.Terrain
			or v:IsA("Attachement")
			or v:IsA("Model") and v.PrimaryPart and v ~= workspace then
				table.insert(ss, v)
			end
		end
		s = ss
	end

	local base = table.create(#s)
	for i, v in ipairs(s) do
		base[i] = getCFrame(v)
	end

	local Y = Vector3.new(0,1,0)
	local j0cf = ocf*CFrame.new(ocf:Inverse()*p0cf.Position*Y)
	local j1cf = ocf*CFrame.new(ocf:Inverse()*p1cf.Position*Y)
	local x = (p0cf.Position-j0cf.Position).Unit
	local y = (p1cf.Position-j1cf.Position).Unit
	local angle = math.acos(x:Dot(y))
	print(angle)

	local next = {o, p0, p1}
	for i = n < 0 and -1 or 1, n, n < 0 and -1 or 1 do
		for j, v in ipairs(s) do
			local a = CFrame.Angles(0, angle * i, 0)
			local c = v:Clone()
			setCFrame(c, ocf*a*(ocf:Inverse()*base[j]))
			c.Parent = v.Parent
			if select and i == n then
				next[j+3] = c
			end
		end
	end
	if select then
		Selection:Set(next)
	end
	ChangeHistoryService:SetWaypoint("Generated arc")
end

function _G.clatt()
	for _, v in ipairs(Selection:Get()) do
		for _, v in ipairs(v:GetDescendants()) do
			if v:IsA("Attachment") then
				v:Destroy()
			end
		end
	end
	ChangeHistoryService:SetWaypoint("Clear attachments")
end

function _G.line()
	local s = Selection:Get()
	local a = getCFrame(s[1])
	local b = getCFrame(s[2])
	if not a then return end
	if not b then return end

	local w = StudioService.GridSize*2

	local line = Instance.new("Part")
	line.Name = "Line"
	line.Size = Vector3.new(w,w,(a.Position-b.Position).magnitude)
	line.CFrame = CFrame.new((a.Position+b.Position)/2,b.Position)
	line.Anchored = true
	line.CanCollide = false
	line.TopSurface = Enum.SurfaceType.Smooth
	line.BottomSurface = Enum.SurfaceType.Smooth
	line.Parent = workspace
end

local gcont = StarterGui:FindFirstChild("_VirtualGeometry")
if gcont == nil then
	gcont = Instance.new("Folder")
	gcont.Name = "_VirtualGeometry"
end
function _G.gline(color, thickness)
	local s = Selection:Get()
	local a = getCFrame(s[1])
	local b = getCFrame(s[2])
	if not a then return end
	if not b then return end

	local line = Instance.new("LineHandleAdornment")
	line.Length = (a.Position-b.Position).magnitude
	line.CFrame = CFrame.new(a.Position,b.Position)
	line.Color3 = color or Color3.new(1,0,0)
	line.Thickness = thickness or 4
	line.Adornee = workspace.Terrain
	line.Parent = gcont

	if gcont.Parent == nil then
		gcont.Parent = StarterGui
	end
end

function _G.gclear()
	gcont.Parent = nil
	gcont:ClearAllChildren()
end
