--[[
Testing

	Enables automated testing.

SYNOPSIS

	local runner = Testing.Test({
		Modules = {
			game.ServerScriptService.ModuleScript,
		},
		Scan = {
			game.ReplicatedStorage.Modules,
		},
	})
	local results = runner:Run()
	print(results)

DESCRIPTION

	To write a test suite for a ModuleScript, create a sibling ModuleScript with
	the same name, and append the ".test" suffix. The test module should return
	a table of named functions. Each function that begins with "Test" will be
	executed:

		local T = {}

		function T.TestFoo()
		end

		function T.TestBar()
		end

		-- Not executed.
		function T.ExampleFoo()
		end

		return T

	Tests are run through a test runner. The runner scans the descendants of an
	instance for ModuleScripts to test. When a ModuleScript named "Foobar" has a
	sibling ModuleScript named "Foobar.test", Foobar.test is assumed to be used
	to test Foobar. Only the first unique name of a ModuleScript is selected as
	a module, and only the first sibling matching the name is selected as a test
	suite.

	For each module, the corresponding test suite is loaded, and each test
	function is executed. A test function receives a T object, which facilitates
	the results of the test. It also receives a require function, which can be
	used to require the module being tested. For example:

		function T.TestAbs(t, require)
			local Math = require()
			local v = Math.Abs(-1)
			if v ~= 1 then
				t.Errorf("Math.Abs(-1) returned %d, expected 1", v)
			end
		end

	A test runner is created with the Testing.Test function. Test receives a
	table that configures the modules to be tested. The "Scan" field contains
	instances that will be scanned for modules. The "Modules" field contains
	specific modules to be included directly.

		local Testing = require(game.ReplicatedStorage.Testing)
		local runner = Testing.Test({
			Modules = {
				game.ServerScriptService.ModuleScript,
				game.ReplicatedStorage.Foobar,
			},
			Scan = {
				game.ReplicatedStorage.Modules,
				game.Workspace,
			},
		})

	The Run method of the runner executes all tests, returning a table
	containing the results. This table can be inspected, or converted to a
	string to be displayed in a human-readable format.

		local results = runner:Run()
		print(results)

API

	-- Test returns a new TestRunner initialized with the given configuration.
	function Testing.Test(config: TestConfig): TestRunner

	-- TestConfig configures a TestRunner.
	type TestConfig = {

		-- ModuleScripts to be included in the test run.
		Modules: Array<Instance.ModuleScript>,

		-- Instances whose descendants will be scanned for ModuleScripts to be
		-- included.
		Scan: Array<Instance.Instance>,
	}

	-- TestRunner manages the state of a test run.
	type TestRunner = {

		-- Run runs tests for each module. Tests are run only once; multiple
		-- calls return the same results.
		Run(): ModuleResults,
	}

	-- ModuleResults describes the results of a full test run.
	type ModuleResults = {

		-- Formats the results as a human-readable string.
		__meta: {__tostring: (ModuleResults) -> string},

		-- The list of results.
		[number]: ModuleResult,

		-- Duration is the cumulative duration of all module tests.
		Duration: number,

		-- Failed indicates whether any modules failed.
		Failed: boolean,

		-- ResultOf returns the result corresponding to the given module, or nil
		-- if the module is not present in the results.
		ResultOf: (Instance.ModuleScript) -> ModuleResult?,
	}

	-- ModuleResult describes the test results of a single module.
	type ModuleResult = {

		-- Formats the results as a human-readable string.
		__meta: {__tostring: (ModuleResult) -> string},

		-- The module being tested.
		Module: Instance.ModuleScript,

		-- Duration is the cumulative duration of all tests.
		Duration: number,

		-- Failed indicates whether any test failed, or an errored occurred.
		Failed: boolean,

		-- Error indicates whether an error occurred while loading the test
		-- module.
		Error: Error?,

		-- Results contains the Results of each test.
		Results: Array<TestResult>,
	}

	-- TestResult describes the result of a single test.
	type TestResult = {

		-- Formats the result as a human-readable string.
		__meta: {__tostring: (TestResult) -> string},

		-- Name is the name of the test.
		Name: string,

		-- Duration is the duration of the test.
		Duration: number,

		-- Failed indicates whether the test failed, or if an error occurred.
		Failed: boolean,

		-- Skipped indicates whether the test was skipped.
		Skipped: boolean,

		-- Error indicates whether a hard error occurred while running the test.
		Error: Error?,

		-- Log is the output of the test.
		Log: string,
	}

	-- Error describes an error with a possible underlying cause.
	type Error = {

		-- Formats the error as a string.
		__meta: {__tostring: (Error) -> string},

		-- Message is a string describing the error.
		Message: string,

		-- Cause is a possible underlying cause of the error.
		Cause: any?,

		-- Trace is a stack trace of the cause, if present.
		Trace: string?,
	}

	-- Tests is returned by a test module containing the tests to run for an
	-- associated module.
	type Tests = Dictionary<string, Test>

	-- Test is an individual test. If a test has an associated module, calling
	-- require will load and return the result of the module, which is cached
	-- for subsequent calls to require. require will be nil if there is no
	-- associated module.
	type Test = (t: T, require: Require?) -> ()

	-- Require returns the results of a required module.
	type Require = () -> any

	-- T is passed to a Test function to manage the state of the test.
	type T = {

		-- Cleanup registers a function to be called after the test completes.
		Cleanup: (f: ()->()) -> ()

		-- Error is equivalent to Log followed by Fail.
		Error: (args: ...any) -> ()

		-- Errorf is equivalent to Logf followed by Fail.
		Errorf: (format: string, args: ...any) -> ()

		-- Fail marks the function as having failed but continues execution.
		Fail: () -> ()

		-- FailNow marks the function as having failed and stops its execution.
		FailNow: () -> ()

		-- Failed reports whether the function has failed.
		Failed: () -> boolean

		-- Fatal is equivalent to Log followed by FailNow.
		Fatal: (args: ...any) -> ()

		-- Fatalf is equivalent to Logf followed by FailNow.
		Fatalf: (format: string, args: ...any) -> ()

		-- Log records the given arguments in the log.
		Log: (args: ...any) -> ()

		-- Logf formats its arguments according to the format, and records the
		-- text in the log. A final newline is added if not provided.
		Logf: (format: string, args: ...any) -> ()

		-- Name returns the name of the running test.
		Name: () -> string

		-- Skip is equivalent to Log followed by SkipNow.
		Skip: (args: ...any) -> ()

		-- SkipNow marks the test as having been skipped and stops its
		-- execution. If a test fails (see Error, Errorf, Fail) and is then
		-- skipped, it is still considered to have failed. Execution will
		-- continue at the next test.
		SkipNow: () -> ()

		-- Skipf is equivalent to Logf followed by SkipNow.
		Skipf: (format: string, args: ...any) -> ()

		-- Skipped reports whether the test was skipped.
		Skipped: () -> boolean
	}

]]

local Testing = {}

-- Expected suffix of test modules.
local testModuleSuffix = ".test"
-- Expected prefix of test functions.
local testFuncPrefix = "Test"
-- Length of indentation in formatted results. <0 uses tabs instead.
local tabSize = -1
-- Format of durations in formatted results.
local durationFormat = "(%0.2fs)"

-- Whether debug.loadmodule should be used. loadmodule is preferred over require
-- because it does not emit unrecoverable errors. It also does not cache the
-- returned value, allowing the same module to be required once for each test.
local useLoadModule = true
do
	local ok
	ok, useLoadModule = pcall(function()
		return settings():GetFFlag("EnableModule")
	end)
	if not ok then
		useLoadModule = pcall(function()
			debug.loadmodule(Instance.new("ModuleScript"))
		end)
	end
end

-- haltMarker is a non-error thrown by error() to halt a test's execution.
local haltMarker = {}

-- scan performs a recursive scan of instance, adding found test objects to
-- results.
local function scan(results, instance)
	local modules = {}
	local tests = {}
	local children = instance:GetChildren()
	for _, child in ipairs(children) do
		if child:IsA("ModuleScript") then
			local t
			local name = child.Name
			if name:sub(-#testModuleSuffix) == testModuleSuffix then
				t = tests
				name = name:sub(1, -#testModuleSuffix-1)
			else
				t = modules
			end
			if t[name] == nil then
				t[name] = child
			end
		end
	end
	for name, module in pairs(modules) do
		local test = tests[name]
		if test then
			table.insert(results, {
				Module = module,
				Test = test,
			})
		end
	end
	for _, child in ipairs(children) do
		scan(results, child)
	end
end

-- scanModule scans a module's siblings for a corresponding test module.
local function scanModule(results, module)
	local instance = module.Parent
	if instance == nil then
		return
	end
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name == module.Name..testModuleSuffix then
			table.insert(results, {
				Module = module,
				Test = child,
			})
			return
		end
	end
end

-- cloneFull creates a copy of instance that shares the same full name as
-- instance. Each ancestor of instance is created as a Folder and given a
-- matching Name.
local function cloneFull(instance)
	local copy = instance:Clone()
	local c = copy
	local parent = instance.Parent
	while parent and parent ~= game do
		local p = Instance.new("Folder")
		p.Name = parent.Name
		c.Parent = p
		c = p
		parent = parent.Parent
	end
	return copy
end

-- indent applies n levels of of indentation to s. spaces indicates how many
-- spaces to use for each level. If spaces is <0 or nil, then tabs are used
-- instead.
local function indent(s, n, spaces)
	local tab
	if spaces and spaces >= 0 then
		tab = string.rep(string.rep(" ", spaces), n)
	else
		tab = string.rep("\t", n)
	end
	return tab .. (string.gsub(s, "\n", "\n" .. tab))
end

-- append inserts each remaining argument into t.
local function append(t, ...)
	local args = {...}
	for i = 1, select("#", ...) do
		table.insert(t, args[i])
	end
end

-- new sets mt as the metatable of t.
local function new(mt, t)
	return setmetatable(t or {}, mt)
end

local Error = {}
function Error:__tostring()
	if self.Cause then
		return string.format("%s: %s", self.Message, tostring(self.Cause))
	end
	return self.Message
end

local T = {__index={}}

local TestRunner = {__index={}}

function Testing.Test(config)
	local self = {
		modules = {},
		results = nil,
	}
	config = config or {}
	for _, module in ipairs(config.Modules or {}) do
		scanModule(self.modules, module)
	end
	for _, instance in ipairs(config.Scan or {}) do
		scan(self.modules, instance)
	end
	table.sort(self.modules, function(a, b)
		return a.Module:GetFullName() < b.Module:GetFullName()
	end)
	return new(TestRunner, self)
end

local ModuleResults = {__index={}}
function ModuleResults:__tostring()
	local s = {}
	for _, module in ipairs(self) do
		append(s, tostring(module), "\n")
	end
	return table.concat(s)
end

function ModuleResults.__index:ResultOf(module)
	for _, result in ipairs(self) do
		if result.Module == module then
			return result
		end
	end
	return nil
end

local ModuleResult = {}
function ModuleResult:__tostring()
	local s = {}
	if not self.Failed then
		append(s, string.format("pass: %s " .. durationFormat, self.Module:GetFullName(), self.Duration))
		return table.concat(s)
	end
	append(s, string.format("FAIL: %s " .. durationFormat, self.Module:GetFullName(), self.Duration))
	if self.Error ~= nil then
		append(s, "\n", indent("ERROR: " .. tostring(self.Error), 1, tabSize))
		if self.Error.Trace then
			append(s, "\n", indent(self.Error.Trace, 2, tabSize))
		end
		return table.concat(s)
	end
	for _, test in ipairs(self.Results) do
		append(s, "\n", indent(tostring(test), 1, tabSize))
	end
	return table.concat(s)
end

local TestResult = {}
function TestResult:__tostring()
	local s = {}
	if self.Failed then
		append(s, "FAIL: ", self.Name)
	else
		append(s, "pass: ", self.Name)
	end
	if self.Skipped then
		append(s, " (skipped)")
	end
	append(s, string.format(" " .. durationFormat, self.Duration))
	if self.Log ~= "" then
		append(s, "\n")
		append(s, indent(self.Log, 1, tabSize))
	end
	if self.Error ~= nil then
		append(s, "\n", indent("ERROR: " .. tostring(self.Error), 1, tabSize))
		if self.Error.Trace then
			append(s, "\n", indent(self.Error.Trace, 2, tabSize))
		end
	end
	return table.concat(s)
end

function TestRunner.__index:Run()
-- function TestRunner.__index:Run(): ModuleResults
	if self.results then
		return self.results
	end

	local failed = false
	local results = {
		Duration = 0,
		Failed = false,
	}
	local epoch = tick()
	for _, pair in ipairs(self.modules) do
		local result = self:runModuleTest(pair.Module, pair.Test)
		failed = failed or result.Failed
		table.insert(results, result)
	end

	-- TODO: Exclude overhead by adding duration of each result?
	results.Duration = tick() - epoch
	results.Failed = failed

	results = new(ModuleResults, results)
	self.results = results
	return results
end

function TestRunner.__index:runModuleTest(module, test)
-- function TestRunner.__index:runModuleTest(module: Module, test: Module): ModuleResult
	local moduleResult = new(ModuleResult, {
		Module = module,
		Duration = 0,
		Okay = false,
		Error = nil,
		Results = {},
	})

	local function errHandler(err)
		return {Cause = err, Trace = debug.traceback(nil, 2)}
	end

	local ok, tests
	local epoch
	-- A copy of the module is required in an isolated tree. Generally, a module
	-- shouldn't expect to be in a particular location. Instead, that
	-- information should be passed to the module.
	if useLoadModule then
		-- loadmodule does not cache results, but it's only ever used once
		-- anyway.
		local require = debug.loadmodule(cloneFull(test))
		epoch = tick()
		ok, tests = xpcall(require, errHandler)
	else
		-- If the module throws an error, it is emitted to output separately,
		-- and require throws a separate generic module error. Prefer loadmodule
		-- if possible.
		epoch = tick()
		ok, tests = xpcall(require, errHandler, cloneFull(test))
	end
	if not ok then
		moduleResult.Duration = tick() - epoch
		moduleResult.Okay = false
		moduleResult.Error = new(Error, {
			Message = "test module errored while loading",
			Cause = tests.Cause,
			Trace = tests.Trace,
		})
		return moduleResult
	end
	if type(tests) ~= "table" then
		moduleResult.Duration = tick() - epoch
		moduleResult.Okay = false
		moduleResult.Error = new(Error, {
			Message = "test module returned non-table",
		})
		return moduleResult
	end

	local testNames = {}
	for name in pairs(tests) do
		table.insert(testNames, name)
	end
	table.sort(testNames)

	local failed = false
	epoch = tick()
	for _, name in ipairs(testNames) do
		if string.sub(name, 1, 4) == testFuncPrefix then
			local testResult = self:runTest(module, tests[name], name)
			failed = failed or testResult.Failed
			table.insert(moduleResult.Results, testResult)
		end
	end

	moduleResult.Duration = tick() - epoch
	moduleResult.Failed = failed

	return moduleResult
end

function TestRunner.__index:runTest(module, test, name)
-- type Test = (t: T, require: ()->(any)?) -> ()
-- function TestRunner.__index:runTest(module: Module, test: Test, name: string): TestResult
	local result = new(TestResult, {
		Name = name,
		Duration = 0,
		Failed = false,
		Skipped = false,
		Error = nil,
		Log = nil,
	})

	local cache = nil
	local function require()
		if cache ~= nil then
			return cache
		end
		if useLoadModule then
			cache = debug.loadmodule(cloneFull(module))()
		else
			cache = require(cloneFull(module))
		end
		return cache
	end

	local function errHandler(err)
		return {Cause = err, Trace = debug.traceback(nil, 2)}
	end

	local t = newT(name)
	local epoch = tick()
	local ok, err = xpcall(test, errHandler, t, require)
	result.Duration = tick() - epoch
	result.Failed = t.failed
	result.Skipped = t.skipped

	if not ok and err.Cause ~= haltMarker then
		result.Failed = true
		result.Error = new(Error, {
			Message = "an error occurred",
			Cause = err.Cause,
			Trace = err.Trace,
		})
	end

	local ok, err, trace = t:cleanup()
	if not ok and result.Error == nil then
		if err ~= haltMarker then
			result.Failed = true
			result.Error = new(Error, {
				Message = "error during cleanup",
				Cause = err,
				Trace = trace,
			})
		end
	end

	result.Log = t:compileLog()
	return result
end

-- newT returns a new T.
function newT(name)
	return new(T, {
		name = name,
		ran = false,
		failed = false,
		skipped = false,
		done = false,
		log = {},
		deferred = {},
	})
end

function T.__index:Cleanup(f)
--function T.__index:Cleanup(f: ()->())
	table.insert(self.deferred, f)
end

function T.__index:cleanup()
	while true do
		local f = table.remove(self.deferred)
		if not f then
			break
		end
		local trace
		local ok, err = xpcall(f, function(err)
			trace = debug.traceback(nil, 2)
		end)
		if not ok then
			return false, err, trace
		end
	end
	return true, nil, nil
end

function T.__index:compileLog()
	return table.concat(self.log)
end

-- Error is equivalent to Log followed by Fail.
function T.__index:Error(...)
	self:Log(...)
	self:Fail()
end

function T.__index:Errorf(format, ...)
	self:Logf(format, ...)
	self:Fail()
end

function T.__index:Fail()
	self.failed = true
end

function T.__index:FailNow()
	self.failed = true
	error(haltMarker)
end

function T.__index:Failed()
	return self.failed
end

function T.__index:Fatal(...)
	self:Log(...)
	self:FailNow()
end

function T.__index:Fatalf(format, ...)
	self:Logf(format, ...)
	self:FailNow()
end

function T.__index:Log(...)
	local args = table.pack(...)
	for i = 1, args.n do
		table.insert(self.log, tostring(args[i]))
		table.insert(self.log, " ")
	end
	table.insert(self.log, "\n")
end

function T.__index:Logf(format, ...)
	local s = string.format(format, ...)
	table.insert(self.log, s)
	if string.sub(s, -1, -1) ~= "\n" then
		table.insert(self.log, "\n")
	end
end

function T.__index:Name()
	return self.name
end

function T.__index:Skip(...)
	self:Log(...)
	self:SkipNow()
end

function T.__index:SkipNow()
	self.skipped = true
	error(haltMarker)
end

function T.__index:Skipf(format, ...)
	self:Logf(format, ...)
	self:SkipNow()
end

function T.__index:Skipped()
	return self.skipped
end

return Testing
