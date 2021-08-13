local T = {}

local function tassert(t, cond, msg, ...)
	if cond then
		return
	end
	msg = msg or "assertion failed!"
	t:Errorf(msg, ...)
end

function T.ExampleNew(require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()
	local disconnect = connect(print)
	fire("Hello, world!")
	--> Hello, world!
	disconnect()
	fire("Hello, world!")
	--> (no output)
end

function T.ExampleWait(require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()
	local wait = SignalFire.wait(connect)

	task.delay(1, fire, "Hello, world!")
	local result = wait()
	print(result)
	--> Hello, world!
end

function T.ExampleAny(require)
	local SignalFire = require()

	local connectA, fireA = SignalFire.new()
	local connectB, fireB = SignalFire.new()
	local connectC, fireC = SignalFire.new()

	task.delay(3, function() print("Fire A") fireA("A") end)
	task.delay(2, function() print("Fire B") fireB("B") end)
	task.delay(1, function() print("Fire C") fireC("C") end)

	local connect = SignalFire.any(connectA, connectB, connectC)
	connect(function(result)
		print("Fired by", result)
	end)
	--> Fired by C
end

function T.ExampleAll(require)
	local SignalFire = require()

	local connectA, fireA = SignalFire.new()
	local connectB, fireB = SignalFire.new()
	local connectC, fireC = SignalFire.new()

	task.delay(3, function() print("Fire A") fireA() end)
	task.delay(2, function() print("Fire B") fireB() end)
	task.delay(1, function() print("Fire C") fireC() end)

	local connect = SignalFire.all(connectA, connectB, connectC)
	SignalFire.wait(connect)()
	print("All signals have fired")
	--> Fire C
	--> Fire B
	--> Fire A
	--> All signals have fired
end

function T.ExampleWrap(require)
	local SignalFire = require()

	local bindable = Instance.new("BindableEvent")

	local connectA, fireA = SignalFire.new()
	local connectB = SignalFire.wrap(bindable.Event)
	local connectC, fireC = SignalFire.new()

	task.delay(3, function() print("Fire A") fireA() end)
	task.delay(2, function() print("Fire B") bindable:Fire() end)
	task.delay(1, function() print("Fire C") fireC() end)

	local connect = SignalFire.all(connectA, connectB, connectC)
	SignalFire.wait(connect)()
	print("All signals have fired")
	--> Fire C
	--> Fire B
	--> Fire A
	--> All signals have fired
end

local function assertConnector(t, connect, msg)
	tassert(t, type(connect) == "function", msg .. ": connector is a function")
	tassert(t, not pcall(connect, nil), msg .. ": must receive function or thread")
	local disconnect = connect(function()end)
	tassert(t, type(disconnect) == "function", msg .. ": disconnector for function is a function")
	disconnect()
	local disconnect = connect(coroutine.create(function()end))
	tassert(t, type(disconnect) == "function", msg .. ": disconnector for thread is a function")
	disconnect()
end

function T.TestSignal(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()
	assertConnector(t, connect, "connect")
	tassert(t, type(fire) == "function", "fire is a function")

	local value = 0
	local disconnect = connect(function(n)
		value += n
	end)
	tassert(t, type(disconnect) == "function", "disconnect is a function")
	fire(1)
	task.wait()
	tassert(t, value == 1, "fire invokes connected function")
	fire(5)
	task.wait()
	tassert(t, value == 6, "fire continues to invoke connected function")
	disconnect()
	fire(7)
	task.wait()
	tassert(t, value == 6, "disconnect breaks connection")
end

function T.TestSignalArguments(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()

	local a, b, c
	local disconnect = connect(function(x,y,z)
		a, b, c = x, y, z
	end)
	fire("a", "b", "c")
	task.wait()
	tassert(t, a == "a", "first argument is a")
	tassert(t, b == "b", "second argument is b")
	tassert(t, c == "c", "third argument is c")
	disconnect()

	local a, b, c = false, false, false
	local disconnect = connect(function(x,y,z)
		a, b, c = x, y, z
	end)
	fire("a", nil, 3)
	task.wait()
	tassert(t, a == "a", "first argument is a")
	tassert(t, b == nil, "second argument is nil")
	tassert(t, c == 3, "third argument is 3")
	disconnect()
end

function T.TestConnections(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()

	local a = 0
	local b = 0
	local c = 0

	local connA = connect(function(n) a += n end)
	local connB = connect(function(n) b += n end)
	local connC = connect(function(n) c += n end)

	tassert(t, a == 0, "a: expected 0, got %d", a)
	tassert(t, b == 0, "b: expected 0, got %d", b)
	tassert(t, c == 0, "c: expected 0, got %d", c)

	fire(1)
	task.wait()
	tassert(t, a == 1, "a: expected 1, got %d", a)
	tassert(t, b == 1, "b: expected 1, got %d", b)
	tassert(t, c == 1, "c: expected 1, got %d", c)

	fire(5)
	task.wait()
	tassert(t, a == 6, "a: expected 6, got %d", a)
	tassert(t, b == 6, "b: expected 6, got %d", b)
	tassert(t, c == 6, "c: expected 6, got %d", c)

	connB()

	fire(2)
	task.wait()
	tassert(t, a == 8, "a: expected 8, got %d", a)
	tassert(t, b == 6, "b: expected 6, got %d", b)
	tassert(t, c == 8, "c: expected 8, got %d", c)

	connA()

	fire(2)
	task.wait()
	tassert(t, a == 8, "a: expected 8, got %d", a)
	tassert(t, b == 6, "b: expected 6, got %d", b)
	tassert(t, c == 10, "c: expected 1, got %d0, c")

	connC()

	fire(2)
	task.wait()
	tassert(t, a == 8, "a: expected 8, got %d", a)
	tassert(t, b == 6, "b: expected 6, got %d", b)
	tassert(t, c == 10, "c: expected 10, got %d", c)
end

function T.TestSameListener(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()

	local value = 0
	local function listener(n)
		value += n
	end

	local connA = connect(listener)
	local connB = connect(listener)
	local connC = connect(listener)

	fire(1)
	task.wait()
	tassert(t, value == 3, "expected 3, got %d", value)

	fire(2)
	task.wait()
	tassert(t, value == 9, "expected 9, got %d", value)

	connA()

	fire(3)
	task.wait()
	tassert(t, value == 15, "expected 15, got %d", value)

	connC()

	fire(4)
	task.wait()
	tassert(t, value == 19, "expected 19, got %d", value)

	connB()

	fire(5)
	task.wait()
	tassert(t, value == 19, "expected 19, got %d", value)
end

function T.TestSignalIndependence(t, require)
	local SignalFire = require()

	local connect1, fire1 = SignalFire.new()
	local connect2, fire2 = SignalFire.new()

	local value1 = 0
	local value2 = 0

	connect1(function() value1 += 1 end)
	connect2(function() value2 += 1 end)

	fire1()
	task.wait()
	tassert(t, value1 == 1, "value1: expected 1, got %d", value1)
	tassert(t, value2 == 0, "value2: expected 0, got %d", value2)

	fire1()
	task.wait()
	tassert(t, value1 == 2, "value1: expected 2, got %d", value1)
	tassert(t, value2 == 0, "value2: expected 0, got %d", value2)

	fire2()
	task.wait()
	tassert(t, value1 == 2, "value1: expected 2, got %d", value1)
	tassert(t, value2 == 1, "value2: expected 1, got %d", value2)

	fire2()
	task.wait()
	tassert(t, value1 == 2, "value1: expected 2, got %d", value1)
	tassert(t, value2 == 2, "value2: expected 2, got %d", value2)
end

function T.TestSignalDependence(t, require)
	local SignalFire = require()

	local connect1, fire1 = SignalFire.new()
	local connect2, fire2 = SignalFire.new()

	local value = 0

	connect1(function() fire2() end)
	connect2(function() value += 1 end)

	fire1()
	task.wait()
	tassert(t, value == 1, "value: expected 1, got %d", value)

	fire1()
	task.wait()
	tassert(t, value == 2, "value: expected 2, got %d", value)

	fire2()
	task.wait()
	tassert(t, value == 3, "value: expected 3, got %d", value)
end

function T.TestAddedConnections(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()

	local value = 0
	local function listener()
		value += 1
		connect(listener)
	end
	connect(listener)

	fire()
	task.wait()
	tassert(t, value == 1, "value: expected 1, got %d", value)

	fire()
	task.wait()
	tassert(t, value == 3, "value: expected 3, got %d", value)

	fire()
	task.wait()
	tassert(t, value == 7, "value: expected 6, got %d", value)

	fire()
	task.wait()
	tassert(t, value == 15, "value: expected 10, got %d", value)
end


function T.TestRemoveConnectionA(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()
	local r
	local a, b, c, d, e
	a = connect(function() table.insert(r, "a") end)
	b = connect(function() table.insert(r, "b") end)
	c = connect(function() table.insert(r, "c") a() end)
	d = connect(function() table.insert(r, "d") end)
	e = connect(function() table.insert(r, "e") end)

	r = {}
	fire()
	task.wait()
	table.sort(r)
	tassert(t, table.concat(r) == "abcde", "expected abcde, got %q", table.concat(r))

	r = {}
	fire()
	task.wait()
	table.sort(r)
	tassert(t, table.concat(r) == "bcde", "expected bcde, got %q", table.concat(r))
end

function T.TestRemoveConnectionB(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()
	local r
	local a, b, c, d, e
	a = connect(function() table.insert(r, "a") end)
	b = connect(function() table.insert(r, "b") end)
	c = connect(function() table.insert(r, "c") b() end)
	d = connect(function() table.insert(r, "d") end)
	e = connect(function() table.insert(r, "e") end)

	r = {}
	fire()
	task.wait()
	table.sort(r)
	tassert(t, table.concat(r) == "abcde", "expected abcde, got %q", table.concat(r))

	r = {}
	fire()
	task.wait()
	table.sort(r)
	tassert(t, table.concat(r) == "acde", "expected acde, got %q", table.concat(r))
end

function T.TestRemoveConnectionC(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()
	local r
	local a, b, c, d, e
	a = connect(function() table.insert(r, "a") end)
	b = connect(function() table.insert(r, "b") end)
	c = connect(function() table.insert(r, "c") c() end)
	d = connect(function() table.insert(r, "d") end)
	e = connect(function() table.insert(r, "e") end)

	r = {}
	fire()
	task.wait()
	table.sort(r)
	tassert(t, table.concat(r) == "abcde", "expected abcde, got %q", table.concat(r))

	r = {}
	fire()
	task.wait()
	table.sort(r)
	tassert(t, table.concat(r) == "abde", "expected abde, got %q", table.concat(r))
end

function T.TestRemoveConnectionD(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()
	local r
	local a, b, c, d, e
	a = connect(function() table.insert(r, "a") end)
	b = connect(function() table.insert(r, "b") end)
	c = connect(function() table.insert(r, "c") d() end)
	d = connect(function() table.insert(r, "d") end)
	e = connect(function() table.insert(r, "e") end)

	r = {}
	fire()
	task.wait()
	table.sort(r)
	tassert(t, table.concat(r) == "abcde", "expected abcde, got %q", table.concat(r))

	r = {}
	fire()
	task.wait()
	table.sort(r)
	tassert(t, table.concat(r) == "abce", "expected abce, got %q", table.concat(r))
end

function T.TestRemoveConnectionE(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()
	local r
	local a, b, c, d, e
	a = connect(function() table.insert(r, "a") end)
	b = connect(function() table.insert(r, "b") end)
	c = connect(function() table.insert(r, "c") e() end)
	d = connect(function() table.insert(r, "d") end)
	e = connect(function() table.insert(r, "e") end)

	r = {}
	fire()
	task.wait()
	table.sort(r)
	tassert(t, table.concat(r) == "abcde", "expected abcde, got %q", table.concat(r))

	r = {}
	fire()
	task.wait()
	table.sort(r)
	tassert(t, table.concat(r) == "abcd", "expected abcd, got %q", table.concat(r))
end

function T.TestYieldingListeners(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()
	local v1, v2
	connect(function()
		task.wait()
		v1 = true
	end)
	connect(function()
		task.wait()
		v2 = true
	end)

	fire()
	task.wait(0.1)
	tassert(t, v1, "first listener called")
	tassert(t, v2, "second listener called")
end

function T.TestInfiniteYieldingListeners(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()
	local v1, v2
	connect(function()
		v1 = true
		coroutine.yield()
	end)
	connect(function()
		v2 = true
		coroutine.yield()
	end)

	fire()
	task.wait()
	tassert(t, v1, "first listener called")
	tassert(t, v2, "second listener called")
end

function T.TestWait(t, require)
	local SignalFire = require()

	local connect, fire = SignalFire.new()
	tassert(t, not pcall(SignalFire.wait, nil), "wait receives a function")
	tassert(t, not pcall(SignalFire.wait(function() return nil end)), "received function must return a function")
	local wait = SignalFire.wait(connect)

	task.delay(0.1, fire, "a", "b", "c")
	local a, b, c = wait()
	tassert(t, a, "a: expected a, got %s", a)
	tassert(t, b, "b: expected b, got %s", b)
	tassert(t, c, "c: expected c, got %s", c)
end

function T.TestAll(t, require)
	local SignalFire = require()

	tassert(t, not pcall(SignalFire.all, nil, nil, nil), "must receive only functions")
	tassert(t, not pcall(SignalFire.all, function()return nil end), "received functions must return function")
	assertConnector(t, SignalFire.all(), "connector of no signals")

	local connectA, fireA = SignalFire.new()
	local connectB, fireB = SignalFire.new()
	local connectC, fireC = SignalFire.new()
	local connect = SignalFire.all(connectA, connectB, connectC)
	local value = 0
	connect(function() value += 1 end)
	tassert(t, value == 0, "0: expected 0, got %d", value)
	fireA()
	task.wait()
	tassert(t, value == 0, "a1: expected 0, got %d", value)
	fireB()
	task.wait()
	tassert(t, value == 0, "b1: expected 0, got %d", value)
	fireC()
	task.wait()
	tassert(t, value == 1, "c1: expected 1, got %d", value)
	fireA()
	task.wait()
	tassert(t, value == 1, "a2: expected 1, got %d", value)
	fireB()
	task.wait()
	tassert(t, value == 1, "b2: expected 1, got %d", value)
	fireC()
	task.wait()
	tassert(t, value == 1, "c2: expected 1, got %d", value)

	local connectA, fireA = SignalFire.new()
	local connectB, fireB = SignalFire.new()
	local connectC, fireC = SignalFire.new()
	local connect = SignalFire.all(connectA, connectB, connectC)
	local value = 0
	connect(function() value += 1 end)
	tassert(t, value == 0, "AAA0: expected 0, got %d", value)
	fireA()
	fireA()
	fireA()
	task.wait()
	tassert(t, value == 0, "AAA1: expected 0, got %d", value)

	local connectA, fireA = SignalFire.new()
	local connectB, fireB = SignalFire.new()
	local connectC, fireC = SignalFire.new()
	local connect = SignalFire.all(connectA, connectB, connectC)
	local value = 0
	connect(function() value += 1 end)
	tassert(t, value == 0, "ABC0: expected 0, got %d", value)
	fireA()
	fireB()
	fireC()
	fireA()
	fireB()
	fireC()
	task.wait()
	tassert(t, value == 1, "ABC1: expected 1, got %d", value)
end


function T.TestAny(t, require)
	local SignalFire = require()

	tassert(t, not pcall(SignalFire.any, nil, nil, nil), "must receive only functions")
	tassert(t, not pcall(SignalFire.any, function()return nil end), "received functions must return function")
	assertConnector(t, SignalFire.any(), "connector of no signals")

	local connectA, fireA = SignalFire.new()
	local connectB, fireB = SignalFire.new()
	local connectC, fireC = SignalFire.new()
	local connect = SignalFire.any(connectA, connectB, connectC)
	local value = 0
	local result = ""
	connect(function(v)
		value += 1
		result = v
	end)
	tassert(t, value == 0, "0: expected 0, got %d", value)
	tassert(t, result == "", "0: expected none, got %q", result)
	fireA("A")
	task.wait()
	tassert(t, value == 1, "a1: expected 1, got %d", value)
	tassert(t, result == "A", "a1: expected A, got %q", result)
	fireA("A")
	task.wait()
	tassert(t, value == 1, "a2: expected 1, got %d", value)
	tassert(t, result == "A", "a2: expected A, got %q", result)
	fireB("B")
	task.wait()
	tassert(t, value == 1, "b: expected 1, got %d", value)
	tassert(t, result == "A", "b: expected A, got %q", result)
	fireC("C")
	task.wait()
	tassert(t, value == 1, "c: expected 1, got %d", value)
	tassert(t, result == "A", "c: expected A, got %q", result)

	local connectA, fireA = SignalFire.new()
	local connectB, fireB = SignalFire.new()
	local connectC, fireC = SignalFire.new()
	local connect = SignalFire.any(connectA, connectB, connectC)
	local value = 0
	local result = ""
	connect(function(v)
		value += 1
		result = v
	end)
	tassert(t, value == 0, "0: expected 0, got %d", value)
	tassert(t, result == "", "0: expected none, got %q", result)
	fireB("B")
	task.wait()
	tassert(t, value == 1, "b1: expected 1, got %d", value)
	tassert(t, result == "B", "b1: expected B, got %q", result)
	fireA("A")
	task.wait()
	tassert(t, value == 1, "a: expected 1, got %d", value)
	tassert(t, result == "B", "a: expected B, got %q", result)
	fireB("B")
	task.wait()
	tassert(t, value == 1, "b2: expected 1, got %d", value)
	tassert(t, result == "B", "b: expected B, got %q", result)
	fireC("C")
	task.wait()
	tassert(t, value == 1, "c: expected 1, got %d", value)
	tassert(t, result == "B", "c: expected B, got %q", result)

	local connectA, fireA = SignalFire.new()
	local connectB, fireB = SignalFire.new()
	local connectC, fireC = SignalFire.new()
	local connect = SignalFire.any(connectA, connectB, connectC)
	local value = 0
	local result = ""
	connect(function(v)
		value += 1
		result = v
	end)
	tassert(t, value == 0, "0: expected 0, got %d", value)
	tassert(t, result == "", "0: expected none, got %q", result)
	fireC("C")
	task.wait()
	tassert(t, value == 1, "c1: expected 1, got %d", value)
	tassert(t, result == "C", "c1: expected C, got %q", result)
	fireA("A")
	task.wait()
	tassert(t, value == 1, "a: expected 1, got %d", value)
	tassert(t, result == "C", "a: expected C, got %q", result)
	fireB("B")
	task.wait()
	tassert(t, value == 1, "b: expected 1, got %d", value)
	tassert(t, result == "C", "b: expected C, got %q", result)
	fireC("C")
	task.wait()
	tassert(t, value == 1, "c2: expected 1, got %d", value)
	tassert(t, result == "C", "c2: expected C, got %q", result)

	local connectA, fireA = SignalFire.new()
	local connectB, fireB = SignalFire.new()
	local connectC, fireC = SignalFire.new()
	local connect = SignalFire.any(connectA, connectB, connectC)
	local value = 0
	local result = ""
	connect(function(v)
		value += 1
		result = v
	end)
	tassert(t, value == 0, "0: expected 0, got %d", value)
	tassert(t, result == "", "0: expected none, got %q", result)
	fireB("B")
	fireA("A")
	task.wait()
	tassert(t, value == 1, "1: expected 1, got %d", value)
	tassert(t, result == "B", "1: expected B, got %q", result)
end

function T.TestWrap(t, require)
	local SignalFire = require()

	tassert(t, not pcall(SignalFire.wrap, nil), "wrap receives a RBXScriptSignal")

	local e = Instance.new("BindableEvent")
	local connect = SignalFire.wrap(e.Event)
	tassert(t, type(connect) == "function", "connect is a function")

	local value = 0
	local connA = connect(function(n)
		value += n
	end)
	tassert(t, type(connA) == "function", "disconnect is a function")
	local connB = connect(function(n)
		value += n
	end)

	e:Fire(1)
	task.wait()
	tassert(t, value == 2, "expected 2, got %d", value)
	connA()

	e:Fire(2)
	task.wait()
	tassert(t, value == 4, "expected 4, got %d", value)
	connB()

	e:Fire(3)
	task.wait()
	tassert(t, value == 4, "expected 4, got %d", value)
end

return T
