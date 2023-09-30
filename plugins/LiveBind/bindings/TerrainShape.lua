--[=[

TerrainShape

*NOTE: Clears existing terrain! This binding must be enabled by adding to it an
`Enabled` boolean attribute that is set to `true`.*

A BasePart with this tag will fill in terrain according to the material,
location, size, and shape of the part.

Supported shapes are:
- Block
- Ball
- Wedge
- Cylinder

An optional Depth attribute on the part sets how many studs the size of the
shape is inset by. For example, the Block shape is inset by 2 studs by default,
in order to get the terrain to align better with the shape's actual size.

]=]

local RunService = game:GetService("RunService")
local Terrain = workspace.Terrain

local defaultDepth = {
	[Enum.PartType.Block]    = 2,
	[Enum.PartType.Ball]     = 1,
	[Enum.PartType.Wedge]    = 2,
	[Enum.PartType.Cylinder] = 0,
}

local shapes = {}
local pending = true
local function update()
	pending = true
end

return {
	instance = function(ctx, shape)
		if not shape:IsA("BasePart") or shape == Terrain then
			return
		end

		table.insert(shapes, shape)
		ctx:AssignEach(function()
			local index = table.find(shapes, shape)
			if index then
				table.remove(shapes, index)
			end
		end)

		shape.Transparency = 1
		ctx:AssignEach(function()
			shape.Transparency = 0
		end)

		ctx:Connect(nil, shape:GetPropertyChangedSignal("CFrame"), update)
		ctx:Connect(nil, shape:GetPropertyChangedSignal("Size"), update)
		ctx:Connect(nil, shape:GetPropertyChangedSignal("Material"), update)
		ctx:Connect(nil, shape:GetAttributeChangedSignal("Depth"), update)
		if shape:IsA("Part") then
			ctx:Connect(nil, shape:GetPropertyChangedSignal("Shape"), update)
		end

		update()
		ctx:AssignEach(update)
	end,
	tag = function(ctx)
		ctx:AssignEach(function()
			Terrain:Clear()
		end)
		ctx:Connect(nil, RunService.Heartbeat, function()
			if not script:GetAttribute("Enabled") then return end
			if not pending then return end
			pending = false
			Terrain:Clear()
			for _, shape in shapes do
				local depthValue = shape:GetAttribute("Depth")
				if type(depthValue) ~= "number" then
					depthValue = nil
				end
				if shape:IsA("Part") then
					local depth = (depthValue or defaultDepth[shape.Shape] or 0)*2
					if shape.Shape == Enum.PartType.Ball then
						local size = shape.Size
						local radius = math.min(size.X,size.Y,size.Z)/2 - depth
						if radius > 0 then
							Terrain:FillBall(shape.Position, radius, shape.Material)
						end
						continue
					elseif shape.Shape == Enum.PartType.Wedge then
						local size = (shape.Size - Vector3.one*depth):Max(Vector3.zero)
						if size.X*size.Y*size.Z > 0 then
							Terrain:FillWedge(shape.CFrame, size, shape.Material)
						end
						continue
					elseif shape.Shape == Enum.PartType.Cylinder then
						local size = shape.Size
						local height = size.X - depth
						local radius = math.min(size.Y,size.Z)/2 - depth
						if height > 0 and radius > 0 then
							Terrain:FillCylinder(shape.CFrame*CFrame.Angles(0,0,math.pi/2), height, radius, shape.Material)
						end
						continue
					end
				end
				-- Default to Block shape.
				local depth = (depthValue or 0)*2
				local size = (shape.Size - Vector3.one*depth):Max(Vector3.zero)
				if size.X*size.Y*size.Z > 0 then
					Terrain:FillBlock(shape.CFrame, size, shape.Material)
				end
			end
		end)
	end,
}
