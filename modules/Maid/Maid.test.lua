local T = {}

function T.TestNew(t, require)
	local Maid = require()
	if not Maid.is(Maid.new()) then
		T:Error("value returned by new is not a Maid")
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

function T.TestMaid_Task(t, require)
	local Maid = require()
	local maid = Maid.new()

	testFinalizers(t, Maid,
		function(name, value)
			maid:Task(name, value)
		end,
		function(name)
			maid:Task(name, nil)
		end
	)

	-- Test overwrite.
	local value = 0
	maid:Task("Field", function() value += 1 end)
	if value ~= 0 then
		t:Errorf("overwrite: expected 0, got %d", value)
	end
	maid:Task("Field", function() value += 2 end)
	if value ~= 1 then
		t:Errorf("overwrite: expected 1, got %d", value)
	end
	maid:Task("Field", nil)
	if value ~= 3 then
		t:Errorf("overwrite: expected 3, got %d", value)
	end
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
end

function T.TestMaid_TaskEach(t, require)
	local Maid = require()
	local maid = Maid.new()

	local n = 0
	local function f()
		n += 1
	end
	maid:TaskEach(f,f,f,f,f,f,f,f)
	maid:FinishAll()
	if n ~= 8 then
		t:Errorf("expected 8 finished tasks, got %d", n)
	end
end

function T.TestMaid_Skip(t, require)
	local Maid = require()
	local maid = Maid.new()

	local s = {}
	maid:Task("A", function() table.insert(s, "A") end)
	maid:Task("B", function() table.insert(s, "B") end)
	maid:Task("C", function() table.insert(s, "C") end)
	maid:Task("D", function() table.insert(s, "D") end)
	maid:Task("E", function() table.insert(s, "E") end)
	maid:Task("F", function() table.insert(s, "F") end)
	maid:Task("G", function() table.insert(s, "G") end)
	maid:Task("H", function() table.insert(s, "H") end)
	maid:Skip("A","C","E","G")
	maid:FinishAll()
	table.sort(s)
	local result = table.concat(s)
	if result ~= "BDFH" then
		t:Errorf("expected BDFH, got %s", result)
	end
end

function T.TestMaid_Finish(t, require)
	local Maid = require()
	local maid = Maid.new()

	local s = {}
	maid:Task("A", function() table.insert(s, "A") end)
	maid:Task("B", function() table.insert(s, "B") end)
	maid:Task("C", function() table.insert(s, "C") end)
	maid:Task("D", function() table.insert(s, "D") end)
	maid:Task("E", function() table.insert(s, "E") end)
	maid:Task("F", function() table.insert(s, "F") end)
	maid:Task("G", function() table.insert(s, "G") end)
	maid:Task("H", function() table.insert(s, "H") end)
	maid:Finish("A","C","E","G")
	table.sort(s)
	local result = table.concat(s)
	if result ~= "ACEG" then
		t:Errorf("expected ACEG, got %s", result)
	end
end

function T.TestMaid_FinishAll(t, require)
	local Maid = require()
	local maid = Maid.new()

	local s = {}
	maid:Task("A", function() table.insert(s, "A") end)
	maid:Task("B", function() table.insert(s, "B") end)
	maid:Task("C", function() table.insert(s, "C") end)
	maid:Task("D", function() table.insert(s, "D") end)
	maid:TaskEach(function() table.insert(s, "E") end)
	maid:TaskEach(function() table.insert(s, "F") end)
	maid:TaskEach(function() table.insert(s, "G") end)
	maid:TaskEach(function() table.insert(s, "H") end)
	maid:FinishAll()
	table.sort(s)
	local result = table.concat(s)
	if result ~= "ABCDEFGH" then
		t:Errorf("expected ABCDEFGH, got %s", result)
	end
end

function T.TestMultipleErrors(t, require)
	local Maid = require()
	local maid = Maid.new()

	local sub = Maid.new()
	sub:TaskEach(
		function() error("E") end,
		function() error("F") end,
		function() error("G") end,
		function() error("H") end
	)
	maid.A = function() error("A") end
	maid.B = function() error("B") end
	maid.C = function() error("C") end
	maid.D = function() error("D") end
	maid.sub = sub

	local errs = maid:FinishAll()
	t:Log(errs)
	if errs == nil then
		t:Errorf("expected errors")
	elseif #errs ~= 5 then
		t:Errorf("expected 5 errors, got %d", #errs)
	end
end

function T.TestNoErrors(t, require)
	local Maid = require()
	local maid = Maid.new()

	local errs = maid:FinishAll()
	if errs ~= nil then
		t:Errorf("expected no errors, got %s", errs)
	end
end

function T.TestYieldError(t, require)
	local Maid = require()
	local maid = Maid.new()

	maid.wait = function() wait(1) end
	local errs = maid:FinishAll()
	t:Log(errs)
	if errs == nil then
		t:Errorf("expected errors")
	elseif #errs ~= 1 then
		t:Errorf("expected 1 error, got %d", #errs)
	end
end

function T.TestSelfFinalError(t, require)
	local Maid = require()
	local maid = Maid.new()

	function maid.A()
		maid.B = nil
	end
	function maid.B()
	end
	local errs = maid:Finish("A")
	t:Log(errs)
	if errs == nil then
		t:Errorf("expected errors")
	elseif #errs ~= 1 then
		t:Errorf("expected 1 error, got %d", #errs)
	end
end

function T.TestFinish(t, require)
	local Maid = require()

	local tasks = {}
	testFinalizers(t, Maid,
		function(name, value)
			tasks[name] = value
		end,
		function(name)
			Maid.finish(tasks[name])
		end
	)
end

function T.TestSelfReference(t, require)
	local Maid = require()

	local maid = Maid.new()
	maid:TaskEach(maid)
	maid:FinishAll()

	if #maid._tasks > 0 then
		t:Errorf("expected no tasks")
	end
end

function T.TestMutual(t, require)
	local Maid = require()

	local maidA = Maid.new()
	local maidB = Maid.new()
	maidA:TaskEach(maidB)
	maidB:TaskEach(maidA)
	maidA:FinishAll()
	if #maidA._tasks > 0 or #maidB._tasks > 0 then
		t:Errorf("expected no tasks")
	end

	local maidA = Maid.new()
	local maidB = Maid.new()
	maidA:TaskEach(maidB)
	maidB:TaskEach(maidA)
	maidB:FinishAll()
	if #maidA._tasks > 0 or #maidB._tasks > 0 then
		t:Errorf("expected no tasks")
	end

	local finished = 0
	local maidA = Maid.new()
	local maidB = Maid.new()
	local maidC = Maid.new()
	maidA:TaskEach(maidB)
	maidB:TaskEach(maidA)
	maidB:TaskEach(maidC)
	maidC:TaskEach(function() finished += 1 end)
	maidB:FinishAll()
	if #maidA._tasks > 0 or #maidB._tasks > 0 then
		t:Errorf("expected no tasks")
	end
	if finished ~= 1 then
		t:Errorf("expected finish")
	end
end

function T.TestRebound(t, require)
	local Maid = require()

	local maid = Maid.new()
	local function rebound()
		maid:TaskEach(rebound)
	end
	rebound()
	maid:FinishAll()
	if #maid._tasks ~= 1 then
		t:Errorf("expected one task")
	end
	maid:FinishAll()
	if #maid._tasks ~= 1 then
		t:Errorf("expected one task")
	end
end

return T
