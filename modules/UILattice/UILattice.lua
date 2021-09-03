--@sec: UILattice
--@doc: The UILattice module provides an implementation of the **Lattice
-- algorithm**. The Lattice algorithm converts a [flexbox][flexbox]-like grid
-- structure to a static set of UDim2 positions and sizes.
--
-- A grid is defined as a list of **spans** for each axis. A span is a numeric
-- value with either a constant or fractional unit:
--
-- - `px`: A constant size in UDim.Offset units (pixels). For example, `4px`
--   indicates 4 pixels.
-- - `fr`: A fraction of the remaining non-constant span of the axis. The
--   calculated fraction is the value divided by the sum of all fr units on the
--   axis. So, if an axis contained `1fr`, `2fr`, `3fr`, and `1fr`, the total
--   space would be 7 fractional units, and the `2fr` would take up 2/7 of the
--   available fractional space.
--
-- The position and size of an object within the grid is defined in terms of its
-- **bounds**, or a rectangle of cells on the grid. For example, on a 3x3 grid,
-- the middle cell would have a bounds of ((1, 1), (2, 2)). If the bounds lies
-- partially outside the boundary of the grid, then the components are
-- constrained. If the bounds lies completely outside the grid, then the object
-- is not rendered (Visible is set to false).
--
-- The calculated positions and sizes of objects are static; the given bounds of
-- an object is reduced to a Position and Size UDim2, which makes resizing
-- inexpensive.
--
-- [flexbox]: https://en.wikipedia.org/wiki/Flexbox
local UILattice = {}

-- Constant tag and attribute names.
local DEFAULT_TAG      = "UILattice"
local ATTR_COLUMNS     = "UILatticeColumns"
local ATTR_ROWS        = "UILatticeRows"
local ATTR_CONSTRAINTS = "UILatticeConstraints"
local ATTR_BOUNDS      = "UILatticeBounds"

--@def: function parseUnit(content: string): (err: error, value: number?, unit: string?)
--@doc: parseUnit parses a single span from *content*. Valid formats are
-- `<number>px` and `<number>fr`. *value* and *unit* will be nil if an error is
-- returned.
local function parseUnit(value)
	if type(value) ~= "string" then
		return nil, nil, string.format("cannot parse %s as unit", type(value))
	end
	local n = string.match(value, "^(.*)px$")
	if n then
		n = tonumber(n)
		if n == nil then
			return nil, nil, "unit must begin with number"
		end
		return n, "px", nil
	end
	local n = string.match(value, "^(.*)fr$")
	if n then
		n = tonumber(n)
		if n == nil then
			return nil, nil, "unit must begin with number"
		end
		return n, "fr", nil
	end
	return nil, nil, "unit must end with 'px' or 'fr'"
end

--@def: function parseSpans(content: string): (err: error, values: {number}, units: {string})
--@doc: parseSpans parses a list of whitespace-separated units. If an error is
-- returned, a single span of "1fr" is also returned.
local function parseSpans(attr)
	if type(attr) ~= "string" then
		return {1}, {"fr"}, nil
	end
	local ns = {}
	local us = {}
	local i = 1
	for span in string.gmatch(attr, "%S+") do
		local n, u, err = parseUnit(span)
		if err then
			return {1}, {"fr"}, string.format("bad entry #%d: %s", i, err)
		end
		table.insert(ns, n)
		table.insert(us, u)
		i += 1
	end
	return ns, us, nil
end

--@def: function buildAxis(values: {number}, units: {string}): (lines: {UDim}, sumConst: number)
--@doc: buildAxis converts a list of spans represented by *values* and *units*
-- to a list of UDim values. *values* and *units* are assumed to be equal in
-- length.
--
-- *lines* contains locations of separation points between each cell in
-- ascending order. *sumConst* is the total of the constant-sized space.
local function buildAxis(ns, us)
	local sumConst = 0
	local sumFract = 0
	for i, n in ipairs(ns) do
		if us[i] == "px" then
			sumConst += n
		elseif us[i] == "fr" then
			sumFract += n
		end
	end
	local norm = 0
	if sumFract == 0 then
		sumFract = 1
		norm = 1
	end

	local lines = table.create(#ns + norm + 1, nil)
	local L = 0        -- Sum of px units encountered
	local R = sumConst -- Sum of px units not encountered
	local N = 0        -- Sum of fr units encountered
	local T = sumFract -- Sum of fr units
	for i, n in ipairs(ns) do
		lines[i] = UDim.new(N/T, L - (R+L)*(N/T))
		if us[i] == "px" then
			L += n
			R -= n
		elseif us[i] == "fr" then
			N += n
		end
	end
	if norm > 0 then
		lines[#ns+1] = UDim.new(N/T, L - (R+L)*(N/T))
		N += 1
	end
	lines[#ns+1+norm] = UDim.new(N/T, L - (R+L)*(N/T))
	return lines, sumConst
end

--@def: function reflowCell(child: GuiObject, cols: {UDim}, rows: {UDim})
--@doc: reflowCell updates the position, size, and visbility of *child*
-- according to *cols*, *rows* and the ATTR_BOUNDS attribute of *child*.
local function reflowCell(child, cols, rows)
	local rect = child:GetAttribute(ATTR_BOUNDS)
	if typeof(rect) == "Vector2" then
		rect = Rect.new(rect, rect + Vector2.new(1, 1))
	elseif typeof(rect) ~= "Rect" then
		child.Visible = false
		return
	end
	local x0, y0, x1, y1 = rect.Min.X, rect.Min.Y, rect.Max.X, rect.Max.Y
	if x1 < 0 or y1 < 0 or x0 >= #cols or y0 >= #rows then
		child.Visible = false
		return
	end
	x0 = math.max(x0, 0)
	y0 = math.max(y0, 0)
	x1 = math.min(x1, #cols-1)
	y1 = math.min(y1, #rows-1)
	local pos = UDim2.new(cols[x0+1], rows[y0+1])
	child.Position = pos
	child.Size = UDim2.new(cols[x1+1], rows[y1+1]) - pos
	child.Visible = true
end

--@def: function updateConstraints(parent: Instance, min: Vector2)
--@doc: updateConstraints updates the size constrains of *parent*, which is
-- assumed to be a UILattice container.
local function updateConstraints(parent, min)
	local constraints = parent:GetAttribute(ATTR_CONSTRAINTS)
	local constrainer = parent:FindFirstChildOfClass("UISizeConstraint")
	if typeof(constraints) == "Rect" then
		if constrainer == nil then
			constrainer = Instance.new("UISizeConstraint", parent)
		end
		constrainer.MinSize = constraints.Min + min
		constrainer.MaxSize = constraints.Max + min
	else
		if constrainer == nil then
			return
		end
		constrainer.MinSize = Vector2.new(0, 0)
		constrainer.MaxSize = Vector2.new(math.huge, math.huge)
	end
end

--@sec: UILattice.update
--@ord: 1
--@def: function UILattice.update(parent: Instance): Instance
--@doc: The update function uses the Lattice algorithm to update the child
-- GuiObjects of *parent*, using configured attributes.
--
-- On the parent, the following attributes are recognized:
-- - `UILatticeColumns: string`: A whitespace-separated list of spans that
--   determines the span of each column. For example, `4px 1fr 4px`. If a
--   non-string, defaults to "1fr".
-- - `UILatticeRows: string`: A whitespace-separated list of spans that
--   determines the span of each row. For example, `4px 1fr 4px`. If a
--   non-string, defaults to "1fr".
-- - `UILatticeConstraints: Rect`: If a Rect, specifies the minimum and maximum
--   constraints of the *fractional space* for each axis. This is applied by
--   configuring the first child of *parent* that is a UISizeConstraint, which
--   will be created if not found.
--
-- On child GuiObjects, the following attributes are recognized:
-- - `UILatticeBounds: Rect | Vector2`: Sets the position and size of the child,
--   in cell coordinates. If a Rect, specifies the lower and upper bounds. If a
--   Vector2, specifies the position, while the size is set to 1 on both axes.
--   Any other type causes Visible to be set to false.
function UILattice.update(parent)
	assert(typeof(parent) == "Instance", "instance expected for parent")

	local coln, colu, err = parseSpans(parent:GetAttribute(ATTR_COLUMNS))
	if err ~= nil then
		error(string.format("parse columns: %s", err), 2)
	end
	local rown, rowu, err = parseSpans(parent:GetAttribute(ATTR_ROWS))
	if err ~= nil then
		error(string.format("parse rows: %s", err), 2)
	end
	local cols, colmin = buildAxis(coln, colu)
	local rows, rowmin = buildAxis(rown, rowu)

	updateConstraints(parent, Vector2.new(colmin, rowmin))

	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("GuiObject") then
			continue
		end
		reflowCell(child, cols, rows)
	end
	return parent
end

--@sec: UILattice.new
--@ord: 2
--@def: function UILattice.new(parent: Instance?): (parent: Instance, disconnect: () -> ())
--@doc: The new constructor begins monitoring *parent* for changes, then
-- automatically updates according to [UILattice.update][UILattice.update]. If
-- *parent* is unspecified, then a Frame instance is created with reasonable
-- defaults.
--
-- *disconnect*, when called, causes monitoring to stop, and used resources to
-- be released.
local function new(parent)
	assert(parent == nil or typeof(parent) == "Instance", "instance or nil expected for parent")

	if parent == nil then
		parent = Instance.new("Frame")
		parent.Name = "UILattice"
		parent.Position = UDim2.fromScale(0, 0)
		parent.Size = UDim2.fromScale(1, 1)
		parent:SetAttribute(ATTR_COLUMNS, "1fr")
		parent:SetAttribute(ATTR_ROWS, "1fr")
		parent:SetAttribute(ATTR_CONSTRAINTS, Rect.new(
			Vector2.new(0, 0),
			Vector2.new(math.huge, math.huge)
		))
	end

	local maid = {}
	local cols, colmin = {}, 0
	local rows, rowmin = {}, 0

	local function reflowAll()
		for _, child in ipairs(parent:GetChildren()) do
			if not child:IsA("GuiObject") then
				continue
			end
			reflowCell(child, cols, rows)
		end
	end

	local function updateColumns()
		local coln, colu = parseSpans(parent:GetAttribute(ATTR_COLUMNS))
		cols, colmin = buildAxis(coln, colu)
		updateConstraints(parent, Vector2.new(colmin, rowmin))
		reflowAll()
	end

	local function updateRows()
		local rown, rowu = parseSpans(parent:GetAttribute(ATTR_ROWS))
		rows, rowmin = buildAxis(rown, rowu)
		updateConstraints(parent, Vector2.new(colmin, rowmin))
		reflowAll()
	end

	local function childAdded(child)
		if not child:IsA("GuiObject") then
			return
		end
		maid[child] = child:GetAttributeChangedSignal(ATTR_BOUNDS):Connect(function()
			reflowCell(child, cols, rows)
		end)
		reflowCell(child, cols, rows)
	end

	local function childRemoved(child)
		local connection = maid[child]
		connection:Disconnect()
		maid[child] = nil
	end

	maid.attrColumns = parent:GetAttributeChangedSignal(ATTR_COLUMNS):Connect(updateColumns)
	maid.attrRows = parent:GetAttributeChangedSignal(ATTR_ROWS):Connect(updateRows)
	maid.attrConstraints = parent:GetAttributeChangedSignal(ATTR_CONSTRAINTS):Connect(function()
		updateConstraints(parent, Vector2.new(colmin, rowmin))
	end)
	maid.childAdded = parent.ChildAdded:Connect(childAdded)
	maid.childRemoved = parent.ChildRemoved:Connect(childRemoved)

	updateColumns()
	updateRows()
	for i, child in ipairs(parent:GetChildren()) do
		childAdded(child)
	end

	local function disconnect()
		for k, conn in pairs(maid) do
			conn:Disconnect()
			maid[k] = nil
		end
	end

	return parent, disconnect
end
UILattice.new = new

--@sec: UILattice.bind
--@ord: 3
--@def: function UILattice.bind(tag: string?): () -> ()
--@doc: The bind function begins monitoring the *tag* instance tag. While an
-- instance is tagged with *tag*, it behaves as though it were passed to
-- [UILattice.new][UILattice.new]. If unspecified, *tag* defaults to
-- "UILattice".
--
-- The returned function, when called, causes monitoring to stop, and unbinds
-- any bound instances.
function UILattice.bind(tag)
	assert(tag == nil or type(tag) == "string", "string or nil expected for tag")
	if not tag then
		tag = DEFAULT_TAG
	end

	local maid = {}
	local function objectAdded(object)
		local _, disconnect = new(object)
		maid[object] = disconnect
	end
	local function objectRemoved(object)
		local disconnect = maid[object]
		disconnect()
		maid[object] = nil
	end
	local CollectionService = game:GetService("CollectionService")
	maid.added = CollectionService:GetInstanceAddedSignal(tag):Connect(objectAdded)
	maid.removed = CollectionService:GetInstanceRemovedSignal(tag):Connect(objectRemoved)
	for _, object in ipairs(CollectionService:GetTagged(tag)) do
		objectAdded(object)
	end

	return function()
		for k, conn in pairs(maid) do
			if type(conn) == "function" then
				conn()
			else
				conn:Disconnect()
			end
			maid[k] = nil
		end
	end
end

return UILattice
