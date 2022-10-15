local T = {}

local function tassert(t, cond, msg, ...)
	if not cond then
		t:Errorf(msg, ...)
	end
end

local finalizerTests = {
	instance = function(t, name, attach, detach)
		local object = Instance.new("IntValue")
		local parent = Instance.new("Folder")

		attach(name, object)
		object.Parent = parent
		if object.Parent ~= parent then
			t:Error("instance was not parented")
		end
		object.Parent = nil

		detach(name)
		if object.Parent ~= nil then
			t:Error("instance was not dissolved")
		end
	end,
	connection = function(t, name, attach, detach)
		local object = Instance.new("IntValue")
		local value = 0
		object.Value = value
		local conn = object.Changed:Connect(function()
			value = object.Value
		end)

		attach(name, conn)
		object.Value += 1
		if value ~= object.Value then
			t:Error("listener was not connected")
		end

		detach(name)
		object.Value += 1
		if value == object.Value then
			t:Error("listener was not disconnected")
		end
	end,
	func = function(t, name, attach, detach)
		local value = false
		attach(name, function()
			value = true
		end)
		detach(name)
		if not value then
			t:Error("function was not called")
		end
	end,
	maid = function(t, name, attach, detach, Maid)
		local maid = Maid.new()
		local value = false
		function maid.func()
			value = true
		end

		attach(name, maid)
		detach(name)
		if not value then
			t:Error("maid was not finalized")
		end
	end,
	table = function(t, name, attach, detach, Maid)
		local tab = {}
		tab.tab = tab
		tab.a = {{1,2,tab,3}}
		local value = false
		function tab.func()
			value = true
		end

		attach(name, tab)
		detach(name)
		if not value then
			t:Error("table was not finalized")
		end
	end,
}

function testFinalizers(t, Maid, attach, detach)
	for name, f in pairs(finalizerTests) do
		f(t, name, attach, detach, Maid)
	end
end

function T.TestClean(t, require)
	local Maid = require()

	local tasks = {}
	testFinalizers(t, Maid,
		function(name, value)
			tasks[name] = value
		end,
		function(name)
			Maid.clean(tasks[name])
		end
	)
end

function T.TestWrap(t, require)
	local Maid = require()

	local tasks = {}
	testFinalizers(t, Maid,
		function(name, value)
			tasks[name] = Maid.wrap(value)
		end,
		function(name)
			tasks[name]()
		end
	)
end

function T.TestMaid_Alive(t, require)
	local Maid = require()

	local maid = Maid.new()
	tassert(t, maid:Alive(), "new maid is not alive")
	maid:Destroy()
	tassert(t, not maid:Alive(), "destroyed maid is alive")
end

function T.TestMaid_Assign(t, require)
	local Maid = require()
	local maid = Maid.new()

	testFinalizers(t, Maid,
		function(name, value)
			maid:Assign(name, value)
		end,
		function(name)
			maid:Assign(name, nil)
		end
	)

	-- Test overwrite.
	local value = 0
	maid:Assign("Field", function() value += 1 end)
	tassert(t, value == 0, "overwrite: expected 0, got %d", value)
	maid:Assign("Field", function() value += 2 end)
	tassert(t, value == 1, "overwrite: expected 1, got %d", value)
	maid:Destroy()
	tassert(t, value == 3, "overwrite: expected 3, got %d", value)

	-- Test destroy.
	maid:Assign("Field", function() value += 1 end)
	tassert(t, value == 4, "destroy: expected 4, got %d", value)

	-- Test equal overwrite.
	value = 0
	local function f() value += 1 end
	maid = Maid.new()
	maid:Assign("Field", f)
	maid:Assign("Field", f)
	tassert(t, value == 0, "equal: expected 0, got %d", value)
end

function T.TestMaid_AssignEach(t, require)
	local Maid = require()
	local maid = Maid.new()

	local n = 0
	local function a() n += 1 end
	local function b() n += 1 end
	local function c() n += 1 end
	maid:AssignEach(a, b, c)
	maid:Destroy()
	tassert(t, n == 3, "expected 3 cleaned tasks, got %d", n)

	-- Test destroy.
	maid:AssignEach(a, b, c)
	tassert(t, n == 6, "expected 6 cleaned tasks, got %d", n)
end

function T.TestMaid_Clean(t, require)
	local Maid = require()
	local maid = Maid.new()

	local s = {}
	maid:Assign("A", function() table.insert(s, "A") end)
	maid:Assign("B", function() table.insert(s, "B") end)
	maid:Assign("C", function() table.insert(s, "C") end)
	maid:Assign("D", function() table.insert(s, "D") end)
	maid:Assign("E", function() table.insert(s, "E") end)
	maid:Assign("F", function() table.insert(s, "F") end)
	maid:Assign("G", function() table.insert(s, "G") end)
	maid:Assign("H", function() table.insert(s, "H") end)
	maid:Clean("A","C","E","G")
	table.sort(s)
	local result = table.concat(s)
	tassert(t, result == "ACEG", "expected ACEG, got %s", result)

	-- Must clean once.
	maid:Clean("A","C","E","G")
	table.sort(s)
	result = table.concat(s)
	tassert(t, result == "ACEG", "expected ACEG, got %s", result)
end

function T.TestMaid_Connect(t, require)
	local Maid = require()

	local maid = Maid.new()
	local toggle = Instance.new("BoolValue")
	local value = 0
	local function listener()
		value += 1
	end

	-- Test connection.
	value = 0
	maid:Connect("conn", toggle.Changed, listener)
	toggle.Value = not toggle.Value
	tassert(t, value == 1, "expected 1, got %d", value)

	-- Test cleanup.
	value = 2
	maid.conn = nil
	toggle.Value = not toggle.Value
	tassert(t, value == 2, "expected 2, got %d", value)

	-- Test override.
	value = 3
	maid.conn = listener
	maid:Connect("conn", toggle.Changed, listener)
	tassert(t, value == 4, "expected 4, got %d", value)
	maid.conn = nil

	-- Test unnamed.
	value = 5
	maid:Connect(nil, toggle.Changed, listener)
	toggle.Value = not toggle.Value
	tassert(t, value == 6, "expected 6, got %d", value)

	-- Test destroy.
	value = 7
	maid:Destroy()
	toggle.Value = not toggle.Value
	tassert(t, value == 7, "expected 7, got %d", value)
end

function T.TestMaid_Destroy(t, require)
	local Maid = require()
	local maid = Maid.new()

	local s = {}
	maid:Assign("A", function() table.insert(s, "A") end)
	maid:Assign("B", function() table.insert(s, "B") end)
	maid:Assign("C", function() table.insert(s, "C") end)
	maid:Assign("D", function() table.insert(s, "D") end)
	maid:AssignEach(function() table.insert(s, "E") end)
	maid:AssignEach(function() table.insert(s, "F") end)
	maid:AssignEach(function() table.insert(s, "G") end)
	maid:AssignEach(function() table.insert(s, "H") end)
	maid:Destroy()
	table.sort(s)
	local result = table.concat(s)
	tassert(t, result == "ABCDEFGH", "expected ABCDEFGH, got %s", result)

	-- Must be no-op.
	maid:Destroy()
end

function T.TestMaid_Unassign(t, require)
	local Maid = require()
	local maid = Maid.new()

	local s = {}
	local a = function() table.insert(s, "A") end
	maid:Assign("A", a)
	maid:Assign("B", function() table.insert(s, "B") end)
	maid:Assign("C", function() table.insert(s, "C") end)
	maid:Assign("D", function() table.insert(s, "D") end)
	maid:Assign("E", function() table.insert(s, "E") end)
	maid:Assign("F", function() table.insert(s, "F") end)
	maid:Assign("G", function() table.insert(s, "G") end)
	maid:Assign("H", function() table.insert(s, "H") end)
	tassert(t, maid:Unassign("A") == a, "expected task from Unassign")
	tassert(t, maid:Unassign("A") == nil, "expected nil from Unassign")
	maid:Unassign("C")
	maid:Unassign("E")
	maid:Unassign("G")
	maid:Destroy()
	table.sort(s)
	local result = table.concat(s)
	tassert(t, result == "BDFH", "expected BDFH, got %s", result)
end

function T.TestMaid_Wrap(t, require)
	local Maid = require()

	local tasks = {}
	testFinalizers(t, Maid,
		function(name, value)
			local maid = Maid.new()
			maid._ = value
			tasks[name] = maid:Wrap()
		end,
		function(name)
			tasks[name]()
		end
	)
end

function T.TestMaid_Newindex(t, require)
	local Maid = require()
	local maid = Maid.new()

	testFinalizers(t, Maid,
		function(name, value)
			maid[name] = value
		end,
		function(name)
			maid[name] = nil
		end
	)

	-- Test underscore.
	local n = 0
	maid._ = function() n += 1 end
	maid._ = function() n += 1 end
	maid._ = function() n += 1 end
	maid:Destroy()
	tassert(t, n == 3, "underscore: expected 3 cleaned tasks, got %d", n)

	-- Test destroy.
	maid.task = function() n += 1 end
	tassert(t, n == 4, "destroy: expected 4 cleaned tasks, got %d", n)
	maid._ = function() n += 1 end
	tassert(t, n == 5, "destroy underscore: expected 5 cleaned tasks, got %d", n)
end

function T.TestSelfFinalError(t, require)
	local Maid = require()
	local maid = Maid.new()

	function maid.A()
		maid.B = nil
	end
	function maid.B()
	end
	maid:Clean("A")
end

function T.TestSelfReference(t, require)
	local Maid = require()

	local maid = Maid.new()
	maid:AssignEach(maid)
	maid:Destroy()

	if maid._unnamedTasks then
		t:Errorf("expected no tasks")
	end
end

function T.TestMutual(t, require)
	local Maid = require()

	local maidA = Maid.new()
	local maidB = Maid.new()
	maidA:AssignEach(maidB)
	maidB:AssignEach(maidA)
	maidA:Destroy()
	if maidA._unnamedTasks or maidB._unnamedTasks then
		t:Errorf("expected no tasks")
	end

	maidA = Maid.new()
	maidB = Maid.new()
	maidA:AssignEach(maidB)
	maidB:AssignEach(maidA)
	maidB:Destroy()
	if maidA._unnamedTasks or maidB._unnamedTasks then
		t:Errorf("expected no tasks")
	end

	local cleaned = 0
	maidA = Maid.new()
	maidB = Maid.new()
	local maidC = Maid.new()
	maidA:AssignEach(maidB)
	maidB:AssignEach(maidA)
	maidB:AssignEach(maidC)
	maidC:AssignEach(function() cleaned += 1 end)
	maidB:Destroy()
	if maidA._unnamedTasks or maidB._unnamedTasks then
		t:Errorf("expected no tasks")
	end
	if cleaned ~= 1 then
		t:Errorf("expected clean")
	end
end

function T.TestRebound(t, require)
	local Maid = require()

	local maid = Maid.new()
	local n = 10
	local function rebound()
		n -= 1
		if n <= 0 then return end
		maid:AssignEach(rebound)
	end
	rebound()
	maid:Destroy()
	if maid._unnamedTasks then
		t:Errorf("expected no tasks")
	end
end

return T
