-- Example that encodes select properties of a BasePart in 7 bytes.

--[[ Schema:
	Position.X   : 8 bits
	Position.Y   : 8 bits
	Position.Z   : 8 bits
	Rotation     : 8 bits
	Size.X       : 4 bits
	Size.Y       : 4 bits
	Size.Z       : 4 bits
	Transparency : 4 bits
	Color.R      : 2 bits
	Color.G      : 2 bits
	Color.B      : 2 bits
	CanCollide   : 1 bit
	(reserved    : 1 bit)
	(total       : 56 bits, 7 bytes)
]]

local Block = {}

function Block.encode(buf, part)
	-- Encode position with each component as an integer between 0 and 255.
	buf:WriteUint(8, part.Position.X)
	buf:WriteUint(8, part.Position.Y)
	buf:WriteUint(8, part.Position.Z)

	-- Encode single-axis rotation with 8-bit precision.
	buf:WriteInt(8, part.Orientation.Y*2^7/180)

	-- Encode each size component with 4 bits.
	buf:WriteUint(4, part.Size.X)
	buf:WriteUint(4, part.Size.Y)
	buf:WriteUint(4, part.Size.Z)

	-- Encode transparency with 4 bits.
	buf:WriteUint(4, part.Transparency*2^4)

	-- Encode each color component with 2 bits.
	buf:WriteUint(2, part.Color.R*2^2)
	buf:WriteUint(2, part.Color.G*2^2)
	buf:WriteUint(2, part.Color.B*2^2)

	-- Encode CanCollide as 1 bit.
	buf:WriteBool(part.CanCollide)

	-- Ensure alignment to 1 byte.
	buf:WriteAlign(8)
end

function Block.decode(buf)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	part.Position = Vector3.new(
		buf:ReadUint(8),
		buf:ReadUint(8),
		buf:ReadUint(8)
	)

	part.Orientation = Vector3.new(0, buf:ReadInt(8, part.Orientation.Y*180/2^7), 0)

	part.Size = Vector3.new(
		buf:ReadUint(4),
		buf:ReadUint(4),
		buf:ReadUint(4)
	)

	part.Transparency = buf:ReadUint(4)/2^4

	part.Color = Color3.new(
		buf:ReadUint(2)/2^2,
		buf:ReadUint(2)/2^2,
		buf:ReadUint(2)/2^2
	)

	part.CanCollide = buf:ReadBool()

	buf:ReadAlign(8)

	return part
end

return Block
