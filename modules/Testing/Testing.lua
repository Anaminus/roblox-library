--[[
Testing

	Enables automated testing and benchmarking.

SYNOPSIS

	local runner = Testing.Runner({
		Modules = {
			game.ServerScriptService.ModuleScript,
		},
		Scan = {
			game.ReplicatedStorage.Modules,
		},
		Output = print,
		Yield = wait,
	})
	local testResults = runner:Test()
	print(testResults)
	local benchResults = runner:Benchmark()
	print(benchResults)

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

	A Runner is used to run tests. The Runner scans the descendants of an
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

	A Runner is created with the Testing.Runner function. Runner receives a
	table that configures the modules to be tested. The "Scan" field contains
	instances that will be scanned for modules. The "Modules" field contains
	specific modules to be included directly.

		local Testing = require(game.ReplicatedStorage.Testing)
		local runner = Testing.Runner({
			Modules = {
				game.ServerScriptService.ModuleScript,
				game.ReplicatedStorage.Foobar,
			},
			Scan = {
				game.ReplicatedStorage.Modules,
				game.Workspace,
			},
		})

	The Test method of the Runner executes tests, returning a table containing
	the results. This table can be inspected, or converted to a string to be
	displayed in a human-readable format.

		local results = runner:Test()
		print(results)

	The Test method may receive a number of string patterns that filter the
	tests to be run. If a test name matches any of the provided patterns, then
	it is executed. If no patterns are provided, then all tests are executed.

		local results = runner:Test("TestPairs", "TestIPairs")
		local results = runner:Test("^TestI?Pairs$")

	----

	The Testing module also enables benchmarking. Within a test suite, each
	function that begins with "Benchmark" is considered a benchmark. Such
	functions receive a B object, which facilitates the state of the benchmark.
	A benchmark must run code B.N times. This number is adjusted during
	execution so that the code may be timed reliably.

		function T.BenchmarkPairs(b)
			for i = 1, b.N do
				for i, v in pairs({1,2,3}) do end
			end
		end

		function T.BenchmarkIPairs(b)
			for i = 1, b.N do
				for i, v in ipairs({1,2,3}) do end
			end
		end

	If a benchmark requires expensive setup or code that should otherwise not be
	measured, the timer can be reset:

		function T.BenchmarkAbs(b, require)
			local Math = require()
			b:ResetTimer()
			for i = 1, b.N do
				Math.Abs(-1)
			end
		end

	The Benchmark method of the Runner executes benchmarks. Like the Test
	method, it returns a table of results.

		local results = runner:Benchmark()
		print(results)

	Also like Test, it can receive a number of string patterns that filter the
	benchmarks to be run.

		local results = runner:Benchmark("BenchmarkPairs", "BenchmarkIPairs")
		local results = runner:Benchmark("^BenchmarkI?Pairs$")

API

	-- Runner returns a new Runner initialized with the given configuration.
	function Testing.Runner(config: Config): Runner

	-- Config configures a Runner.
	type Config = {

		-- ModuleScripts to be included in the test run.
		Modules: Array<Instance.ModuleScript>?,

		-- Instances whose descendants will be scanned for ModuleScripts to be
		-- included.
		Scan: Array<Instance.Instance>?,

		-- BenchmarkIterations sets the exact number of iterations each
		-- benchmark must run. If unspecified, the number of iterations is
		-- determined by BenchmarkDuration.
		BenchmarkIterations: number?,

		-- BenchmarkDuration determines how long a benchmark should run to make
		-- an accurate measurement. Defaults to 1 second. This value should be
		-- somewhat smaller than the script timeout duration.
		BenchmarkDuration: number?,

		-- Yield sets a function that is called between benchmarks. This
		-- function should yield back to the engine to prevent the runner from
		-- timing out.
		Yield: (() -> ())?,

		-- NoCopy requires actual ModuleScripts instead of copies.
		NoCopy: boolean,
	}

	-- Runner manages the state of a test run.
	type Runner = {

		-- Test runs tests for each module. If the name of a test matches any of
		-- the given string patterns, then it is executed. If no patterns are
		-- given, then all tests are executed.
		Test(patterns ...string): ModuleResults,

		-- Benchmark runs benchmarks for each module. If the name of a benchmark
		-- matches any of the given string patterns, then it is executed. If no
		-- patterns are given, then all benchmarks are executed.
		Benchmark(patterns ...string): ModuleResults,
	}

	-- ModuleResults describes the results of a test or benchmark run.
	type ModuleResults = {

		-- Formats the results as a human-readable string.
		__meta: {__tostring: (ModuleResults) -> string},

		-- Benchmark indicates whether the result is from a benchmark run.
		Benchmark: boolean,

		-- The list of results.
		[number]: ModuleResult,

		-- Modules contains the modules that have been scanned.
		Modules: Modules,

		-- Duration is the cumulative duration of all module tests.
		Duration: number,

		-- Failed indicates whether any modules failed.
		Failed: boolean,

		-- ResultOf returns the result corresponding to the given module, or nil
		-- if the module is not present in the results.
		ResultOf: (Instance.ModuleScript) -> ModuleResult?,
	}

	-- ModuleResult describes the test or benchmark results of a single module.
	type ModuleResult = {

		-- Formats the results as a human-readable string.
		__meta: {__tostring: (ModuleResult) -> string},

		-- Benchmark indicates whether the result is from a benchmark run.
		Benchmark: boolean,

		-- Module is the module being tested.
		Module: Instance.ModuleScript,

		-- Duration is the cumulative duration of all tests.
		Duration: number,

		-- Failed indicates whether any test failed, or an errored occurred.
		Failed: boolean,

		-- Error indicates whether an error occurred while loading the test
		-- module.
		Error: Error?,

		-- Results contains the Results of each test or benchmark.
		Results: Array<TestResult>|Array<BenchmarkResult>,
	}

	-- TestResult describes the result of a single test.
	type TestResult = {

		-- Formats the result as a human-readable string.
		__meta: {__tostring: (TestResult) -> string},

		-- Name is the name of the test.
		Name: string,

		-- Duration is how long the test took to run, in seconds.
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

	-- BenchmarkResult describes the result of a single benchmark.
	type BenchmarkResult = {

		-- Formats the result as a human-readable string.
		__meta: {__tostring: (TestResult) -> string},

		-- Name is the name of the benchmark.
		Name: string,

		-- Iterations is the number of times the benchmark ran.
		Iterations: number,

		-- Duration is how long the benchmark took to run, in seconds.
		Duration: number,

		-- Failed indicates whether the benchmark failed, or if an error
		-- occurred.
		Failed: boolean,

		-- Skipped indicates whether the benchmark was skipped.
		Skipped: boolean,

		-- Error indicates whether a hard error occurred while running the
		-- benchmark.
		Error: Error?,

		-- Log is the output of the benchmark.
		Log: string,
	}

	-- Modules contains the categorized results of a scan.
	type Modules = {

		-- Matched contains modules and their corresponding test suites.
		Matched: Array<ModuleTest>,

		-- UnmatchedModules contains modules that have no corresponding test
		-- suite.
		UnmatchedModules: Array<ModuleScript>,

		-- UnmatchedTests contains test suites that have no corresponding
		-- module.
		UnmatchedTests: Array<ModuleScript>,

		-- ShadowedModules contains modules whose names are shadowed by other
		-- modules.
		ShadowedModules: Array<ModuleScript>,

		-- ShadowedTests contains test suites whose names are shadowed by other
		-- test suites.
		ShadowedTests: Array<ModuleScript>,
	}

	-- ModuleTest contains a module paired with a test suite.
	type ModuleTest = {

		-- Module is the module to be tested.
		Module: ModuleScript,

		-- Test is the corresponding test suite.
		Test: ModuleScript,
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

	-- TB is the interface common to T and B.
	interface TB = {

		-- Cleanup registers a function to be called after the test completes.
		Cleanup: (f: ()->()) -> (),

		-- Error is equivalent to Log followed by Fail.
		Error: (args: ...any) -> (),

		-- Errorf is equivalent to Logf followed by Fail.
		Errorf: (format: string, args: ...any) -> (),

		-- Fail marks the function as having failed but continues execution.
		Fail: () -> (),

		-- FailNow marks the function as having failed and stops its execution.
		FailNow: () -> (),

		-- Failed reports whether the function has failed.
		Failed: () -> boolean,

		-- Fatal is equivalent to Log followed by FailNow.
		Fatal: (args: ...any) -> (),

		-- Fatalf is equivalent to Logf followed by FailNow.
		Fatalf: (format: string, args: ...any) -> (),

		-- Log records the given arguments in the log.
		Log: (args: ...any) -> (),

		-- Logf formats its arguments according to the format, and records the
		-- text in the log. A final newline is added if not provided.
		Logf: (format: string, args: ...any) -> (),

		-- Name returns the name of the running test.
		Name: () -> string,

		-- Skip is equivalent to Log followed by SkipNow.
		Skip: (args: ...any) -> (),

		-- SkipNow marks the test as having been skipped and stops its
		-- execution. If a test fails (see Error, Errorf, Fail) and is then
		-- skipped, it is still considered to have failed. Execution will
		-- continue at the next test.
		SkipNow: () -> (),

		-- Skipf is equivalent to Logf followed by SkipNow.
		Skipf: (format: string, args: ...any) -> (),

		-- Skipped reports whether the test was skipped.
		Skipped: () -> boolean,
	}

	-- T is passed to a Test function to manage the state of the test.
	type T implements TB = {

		-- Yield calls Config.Yield. Does nothing if unset.
		Yield: () -> (),
	}

	-- B is passed to a Benchmark function to manage the state of the benchmark.
	type B implements TB = {

		-- N is the number of iterations the benchmark should run. This is
		-- adjusted during execution so that the benchmark can be timed
		-- reliably.
		N: number,

		-- ResetTimer resets measurements of the benchmark. It does not affect
		-- whether the timer is running.
		ResetTimer: () -> (),

		-- StartTimer begins or resumes the timing of the benchmark. This is
		-- called automatically before running the benchmark.
		StartTimer: () -> (),

		-- StopTimer pauses the timing of the benchmark.
		StopTimer: () -> (),

		-- Yield calls Config.Yield. Does nothing if unset. The timer is stopped
		-- before yielding, and resumed afterwards.
		Yield: () -> (),
	}

]]

local Testing = {}

-- Suppress analysis warnings.
local debug_loadmodule = debug["loadmodule"]

-- Expected suffix of test modules.
local testModuleSuffix = ".test"
-- Expected prefix of test functions.
local testFuncPrefix = "Test"
-- Expected prefix of benchmark functions.
local benchFuncPrefix = "Benchmark"
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
			debug_loadmodule(Instance.new("ModuleScript"))
		end)
	end
end

local debugMan do
	local ok, err = pcall(function()
		local d = DebuggerManager()
		local _ = d.Name
		return d
	end)
	if ok then
		debugMan = err
	end
end

-- haltMarker is a non-error thrown by error() to halt a test's execution.
local haltMarker = {}

--[[

-- ScanResult describes a single result of a scan for module tests.
type ScanResult = {

	-- Module is the module to be tested. Subsequent entries are modules
	-- shadowed by the first entry. Zero entries means the test suite has no
	-- corresponding module.
	Module: Array<ModuleScript>,

	-- Test is the corresponding test suite. Subsequent entries are modules
	-- shadowed by the first entry. Zero entries means the module has no
	-- corresponding test.
	Test: Array<ModuleScript>,
}

]]

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
			if string.sub(name, -#testModuleSuffix) == testModuleSuffix then
				t = tests
				name = string.sub(name, 1, -#testModuleSuffix-1)
			else
				t = modules
			end
			if t[name] == nil then
				t[name] = {}
			end
			table.insert(t[name], child)
		end
	end
	local matched = {}
	for name, module in pairs(modules) do
		local test = tests[name]
		if test then
			table.insert(results, {Module = module, Test = test})
			matched[name] = true
		else
			table.insert(results, {Module = module, Test = {}})
		end
	end
	for name, test in pairs(tests) do
		if not matched[name] then
			table.insert(results, {Module = {}, Test = test})
		end
	end
	for _, child in ipairs(children) do
		scan(results, child)
	end
end

-- scanModule scans a module's siblings for a corresponding test module. Unlike
-- scan, the module will be selected even if it does not have the first unique
-- name.
local function scanModule(results, module)
	local instance = module.Parent
	local modules = {module}
	if instance == nil then
		table.insert(results, {Module = modules, Test = {}})
		return
	end
	local tests = {}
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("ModuleScript") and child ~= module then
			if child.Name == module.Name..testModuleSuffix then
				table.insert(tests, child)
			elseif child.Name == module.Name then
				table.insert(modules, child)
			end
		end
	end
	table.insert(results, {Module = modules, Test = tests})
end

-- getFullName returns the full name of an instance formatted as a Lua
-- expression.
local function getFullName(instance)
	local t = {}
	while instance and instance ~= game do
		table.insert(t, instance.Name)
		instance = instance.Parent
	end
	local s = ""
	local n = #t
	for i = n, 1, -1 do
		local name = t[i]
		if string.match(name, "^[A-Za-z_][A-Za-z0-9_]*$") then
			if i < n then
				s = s .. "."
			end
			s = s .. name
		else
			s = s .. string.gsub(string.format("[%q]", name), "\\\n", "\\n")
		end
	end
	return s
end

-- formatScanResults categorizes modules and removes duplicates. Results are
-- ordered by full name.
local function formatScanResults(results)
	local modules = {
		Matched = {},
		UnmatchedModules = {},
		UnmatchedTests = {},
		ShadowedModules = {},
		ShadowedTests = {},
	}

	-- Whether a module has been visited. Reused to cache module names for
	-- sorting.
	local visited = {}

	-- Visit matched modules.
	for _, result in ipairs(results) do
		local module = result.Module
		local test = result.Test
		if #module > 0 and #test > 0 then
			if not visited[module[1]] then
				visited[module[1]] = getFullName(module[1])
				table.insert(modules.Matched, {Module = module[1], Test = test[1]})
			end
		end
	end

	-- Visit unmatched modules.
	for _, result in ipairs(results) do
		local module = result.Module
		local test = result.Test
		if #module > 0 and #test == 0 then
			if not visited[module[1]] then
				visited[module[1]] = getFullName(module[1])
				table.insert(modules.UnmatchedModules, module[1])
			end
		elseif #module == 0 and #test > 0 then
			if not visited[test[1]] then
				visited[test[1]] = getFullName(test[1])
				table.insert(modules.UnmatchedTests, test[1])
			end
		end
	end

	-- Visit shadowed modules.
	for _, result in ipairs(results) do
		local module = result.Module
		for i = 2, #module do
			if not visited[module[i]] then
				visited[module[i]] = getFullName(module[i])
				table.insert(modules.ShadowedModules, module[i])
			end
		end
		local test = result.Test
		for i = 2, #test do
			if not visited[test[i]] then
				visited[test[i]] = getFullName(test[i])
				table.insert(modules.ShadowedTests, test[i])
			end
		end
	end

	-- Sort everything by full name.
	table.sort(modules.Matched, function(a, b)
		return visited[a.Module] < visited[b.Module]
	end)
	table.sort(modules.UnmatchedModules, function(a, b)
		return visited[a] < visited[b]
	end)
	table.sort(modules.UnmatchedTests, function(a, b)
		return visited[a] < visited[b]
	end)
	table.sort(modules.ShadowedModules, function(a, b)
		return visited[a] < visited[b]
	end)
	table.sort(modules.ShadowedTests, function(a, b)
		return visited[a] < visited[b]
	end)

	return modules
end

local function copyBreakpoints(original, copy)
	if not debugMan then
		return
	end
	local debugger
	for i, d in ipairs(debugMan:GetDebuggers()) do
		if d.Script == original then
			debugger = d
			break
		end
	end
	if not debugger then
		return
	end
	local breakpoints = debugger:GetBreakpoints()
	if #breakpoints == 0 then
		return
	end

	local debuggerCopy = debugMan:AddDebugger(copy)
	for _, b in ipairs(breakpoints) do
		local c = debuggerCopy:SetBreakpoint(b.Line, b.isContextDependentBreakpoint)
		c.Condition = b.Condition
		c.IsEnabled = b.IsEnabled
	end
end

-- cloneFull creates a copy of instance such that it shares the same full name
-- as instance. Each ancestor of instance is created as a Folder and given a
-- matching Name.
--
-- When debugging is enabled, if the instance is a script with breakpoints, they
-- are copied to the new script.
local function cloneFull(instance, nocopy)
	if nocopy then
		return instance
	end
	local copy = instance:Clone()
	copyBreakpoints(instance, copy)
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

-- validateMatchers validates test and benchmark pattern matchers.
local function validateMatchers(...)
	local patterns = {...}
	if #patterns == 0 then
		return true, nil
	end
	for i, pattern in ipairs(patterns) do
		local ok, err = pcall(string.match, "", pattern)
		if not ok then
			return false, "pattern " .. i .. ": " .. err
		end
	end
	return true, patterns
end

-- matchPatterns returns true if name matches any patterns.
local function matchPatterns(patterns, name)
	if not patterns then
		return true
	end
	for _, pattern in ipairs(patterns) do
		if string.match(name, pattern) then
			return true
		end
	end
	return false
end

-- formatRows formats a list of rows in columns.
local function formatRows(rows)
	local width = {}
	for _, row in ipairs(rows) do
		if type(row) == "table" then
			for i, cell in ipairs(row) do
				local n = #tostring(cell)
				local w = width[i]
				if w == nil or n > w then
					width[i] = n
				end
			end
		end
	end

	local s = {}
	for i, row in ipairs(rows) do
		if type(row) == "table" then
			for i, cell in ipairs(row) do
				local v = tostring(cell)
				if type(cell) == "string" then
					append(s, v, string.rep(" ", width[i] - #v))
				elseif type(cell) == "number" then
					append(s, string.rep(" ", width[i] - #v), v)
				end
				if i < #row then
					append(s, "\t")
				end
			end
		elseif type(row) == "string" then
			append(s, row)
		end
		if i < #rows then
			append(s, "\n")
		end
	end
	return table.concat(s)
end

local Error = {}
function Error:__tostring()
	if self.Cause then
		return string.format("%s: %s", self.Message, tostring(self.Cause))
	end
	return self.Message
end

local T = {__index={}}

local function newT(name)
	return new(T, {
		name = name,
		failed = false,
		skipped = false,
		log = {},
		deferred = {},
		yield = nil,
	})
end

local B = {__index={}}

local function newB(name, n, d)
	return new(B, {
		N = 0,

		name = name,
		failed = false,
		skipped = false,
		log = {},
		deferred = {},

		n = n or 0,
		d = d or 1,
		timing = false,
		startTime = 0,
		duration = 0,
		result = nil,
		benchFunc = nil,
		errHandler = nil,
		require = nil,
		epoch = 0,
		yield = nil,
	})
end

local TB = {__index={}}

function TB.__index:Cleanup(f)
	table.insert(self.deferred, f)
end

function TB.__index:cleanup()
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

function TB.__index:compileLog()
	return table.concat(self.log)
end

function TB.__index:Error(...)
	self:Log(...)
	self:Fail()
end

function TB.__index:Errorf(format, ...)
	self:Logf(format, ...)
	self:Fail()
end

function TB.__index:Fail()
	self.failed = true
end

function TB.__index:FailNow()
	self.failed = true
	error(haltMarker)
end

function TB.__index:Failed()
	return self.failed
end

function TB.__index:Fatal(...)
	self:Log(...)
	self:FailNow()
end

function TB.__index:Fatalf(format, ...)
	self:Logf(format, ...)
	self:FailNow()
end

function TB.__index:Log(...)
	local args = table.pack(...)
	for i = 1, args.n do
		table.insert(self.log, tostring(args[i]))
		table.insert(self.log, " ")
	end
	table.insert(self.log, "\n")
end

function TB.__index:Logf(format, ...)
	local s = string.format(format, ...)
	table.insert(self.log, s)
	if string.sub(s, -1, -1) ~= "\n" then
		table.insert(self.log, "\n")
	end
end

function TB.__index:Name()
	return self.name
end

function TB.__index:Skip(...)
	self:Log(...)
	self:SkipNow()
end

function TB.__index:SkipNow()
	self.skipped = true
	error(haltMarker)
end

function TB.__index:Skipf(format, ...)
	self:Logf(format, ...)
	self:SkipNow()
end

function TB.__index:Skipped()
	return self.skipped
end

for name, method in pairs(TB.__index) do
	T.__index[name] = method
end

for name, method in pairs(TB.__index) do
	B.__index[name] = method
end

function T.__index:Yield()
	if self.yield then
		self.yield()
	end
end

function B.__index:ResetTimer()
	if self.timing then
		self.startTime = os.clock()
	end
	self.duration = 0
end

function B.__index:StartTimer()
	if not self.timing then
		self.timing = true
		self.startTime = os.clock()
	end
end

function B.__index:StopTimer()
	if self.timing then
		self.duration = self.duration + (os.clock() - self.startTime)
		self.timing = false
	end
end

function B.__index:Yield()
	if self.yield then
		self:StopTimer()
		self.yield()
		self:StartTimer()
	end
end

function B.__index:runN(n)
	self.N = n
	self:ResetTimer()
	self:StartTimer()
	self.benchFunc(self, self.require)
	self:StopTimer()
end

function B.__index:run1()
	self.N = 1
	local ok, err = xpcall(self.benchFunc, self.errHandler, self, self.require)
	self.result.Duration = os.clock() - self.epoch
	self.result.Failed = self.failed
	self.result.Skipped = self.skipped

	if not ok and err.Cause ~= haltMarker then
		self.result.Failed = true
		self.result.Error = new(Error, {
			Message = "an error occurred",
			Cause = err.Cause,
			Trace = err.Trace,
		})
	end

	return not self.result.Failed and not self.result.Skipped
end

function B.__index:run()
	if self.n > 0 then
		self:runN(self.n)
	else
		local d = self.d
		local n = 1
		while not self.failed and self.duration < d and n < 1e9 do
			local last = n
			local goalS = d
			local prevIt = self.N
			local prevS = self.duration
			if prevS <= 0 then
				prevS = 1
			end
			n = math.floor(goalS * prevIt / prevS)
			n = math.floor(n + n/5)
			n = math.min(n, 100*last)
			n = math.max(n, last+1)
			n = math.min(n, 1e9)
			self:runN(n)
		end
	end
	self.result.Iterations = self.N
	self.result.Duration = self.duration
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local ModuleResults = {__index={}}
function ModuleResults:__tostring()
	local s = {}
	for _, module in ipairs(self.Modules.UnmatchedTests) do
		append(s, "warn: ", getFullName(module), ": no matching module\n")
	end
	for _, module in ipairs(self.Modules.ShadowedModules) do
		append(s, "warn: ", getFullName(module), ": shadowed name\n")
	end
	for _, module in ipairs(self.Modules.ShadowedTests) do
		append(s, "warn: ", getFullName(module), ": shadowed name\n")
	end
	for _, module in ipairs(self.Modules.UnmatchedModules) do
		append(s, "warn: ", getFullName(module), ": no tests\n")
	end
	if #self == 0 then
		append(s, "no tests")
	else
		for i, module in ipairs(self) do
			append(s, tostring(module))
			if i < #self then
				append(s, "\n")
			end
		end
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

local ModuleResult = {__index={}}
function ModuleResult:__tostring()
	local s = {}
	if not self.Failed then
		append(s, string.format("pass: %s " .. durationFormat, getFullName(self.Module), self.Duration))
		if not self.Benchmark then
			return table.concat(s)
		end
	else
		append(s, string.format("FAIL: %s " .. durationFormat, getFullName(self.Module), self.Duration))
		if self.Error ~= nil then
			append(s, "\n", indent("ERROR: " .. tostring(self.Error), 1, tabSize))
			if self.Error.Trace then
				append(s, "\n", indent(self.Error.Trace, 2, tabSize))
			end
			return table.concat(s)
		end
	end
	if self.Benchmark then
		append(s, "\n", indent(self:BenchmarkResults(), 1, tabSize))
	else
		for _, test in ipairs(self.Results) do
			append(s, "\n", indent(tostring(test), 1, tabSize))
		end
	end
	return table.concat(s)
end

function ModuleResult.__index:BenchmarkResults()
	if not self.Benchmark then
		return ""
	end
	local rows = {}
	local failed = {}
	for _, test in ipairs(self.Results) do
		if test.Failed then
			append(failed, tostring(test))
		else
			append(rows, {test.Name, test.Iterations, math.floor(test.Duration/test.Iterations*1e9), "ns/op"})
		end
	end
	table.sort(rows, function(a,b)
		if a[3] == b[3] then
			return a[1] < b[1]
		end
		return a[3] < b[3]
	end)
	local formattedRows = formatRows(rows)
	return formattedRows .. "\n" .. table.concat(failed)
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
	append(s, " ", string.format(durationFormat, self.Duration))
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

local BenchmarkResult = {}
function BenchmarkResult:__tostring()
	local s = {}
	if self.Failed or self.Skipped then
		if self.Failed then
			append(s, "FAIL: ", self.Name)
		end
		if self.Skipped then
			append(s, " (skipped)")
		end
		append(s, " ", string.format(durationFormat, self.Duration))
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
	append(s,
		self.Name,
		"\t", self.Iterations,
		string.format("\t%d ns/op", self.Duration/self.Iterations*1e9)
	)
	return table.concat(s)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local Runner = {__index={}}

function Testing.Runner(config)
	local self = {
		benchN = 0,
		benchD = 1,
		yield = nil,
		nocopy = false,
		modules = nil,
	}
	config = config or {}

	if type(config.BenchmarkIterations) == "number" then
		self.benchN = config.BenchmarkIterations
	end
	if type(config.BenchmarkDuration) == "number" then
		self.benchD = config.BenchmarkDuration
	end
	if type(config.Yield) == "function" then
		self.yield = config.Yield
	end
	if type(config.NoCopy) == "boolean" then
		self.nocopy = config.NoCopy
	end

	local modules = {}
	if type(config.Modules) == "table" then
		for _, module in ipairs(config.Modules) do
			scanModule(modules, module)
		end
	end
	if type(config.Scan) == "table" then
		for _, instance in ipairs(config.Scan) do
			scan(modules, instance)
		end
	end
	self.modules = formatScanResults(modules)

	return new(Runner, self)
end

function Runner.__index:Test(...)
	local ok, patterns = validateMatchers(...)
	if not ok then
		error("Test: " .. patterns, 2)
	end
	return self:run(
		patterns,
		testFuncPrefix,
		self.runTest
	)
end

function Runner.__index:Benchmark(...)
	local ok, patterns = validateMatchers(...)
	if not ok then
		error("Benchmark: " .. patterns, 2)
	end
	return self:run(
		patterns,
		benchFuncPrefix,
		self.runBench
	)
end

function Runner.__index:run(patterns, funcPrefix, method)
	local modulesFailed = false
	local results = {
		Modules = self.modules,
		Duration = 0,
		Failed = false,
		Benchmark = method == self.runBench,
	}

	local epoch = os.clock()
	for _, pair in ipairs(self.modules.Matched) do
		local moduleResult, funcs = self:loadModuleTest(pair.Module, pair.Test, patterns, funcPrefix)
		local moduleFailed = false
		if moduleResult.Okay then
			local epoch = os.clock()
			for i, func in ipairs(funcs) do
				local result = method(self, pair.Module, func.Func, func.Name)
				moduleFailed = moduleFailed or result.Failed
				table.insert(moduleResult.Results, result)
				if self.Output then
					self.Output(result)
				end
				if self.yield and i < #funcs then
					self.yield()
				end
			end
			moduleResult.Duration = os.clock() - epoch
		else
			moduleFailed = true
		end
		moduleResult.Failed = moduleFailed
		modulesFailed = modulesFailed or moduleFailed
		table.insert(results, moduleResult)
	end

	-- TODO: Exclude overhead by adding duration of each result?
	results.Duration = os.clock() - epoch
	results.Failed = modulesFailed

	return new(ModuleResults, results)
end

function Runner.__index:loadModuleTest(module, test, patterns, funcPrefix)
-- function Runner.__index:loadModuleTest(module: Module, test: Module): ModuleResult
	local moduleResult = new(ModuleResult, {
		Module = module,
		Duration = 0,
		Okay = true,
		Error = nil,
		Benchmark = funcPrefix == benchFuncPrefix,
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
		local require = debug_loadmodule(cloneFull(test, self.nocopy))
		epoch = os.clock()
		ok, tests = xpcall(require, errHandler)
	else
		-- If the module throws an error, it is emitted to output separately,
		-- and require throws a separate generic module error. Prefer loadmodule
		-- if possible.
		epoch = os.clock()
		ok, tests = xpcall(require, errHandler, cloneFull(test, self.nocopy))
	end
	if not ok then
		moduleResult.Duration = os.clock() - epoch
		moduleResult.Okay = false
		moduleResult.Error = new(Error, {
			Message = "test module errored while loading",
			Cause = tests.Cause,
			Trace = tests.Trace,
		})
		return moduleResult
	end
	if type(tests) ~= "table" then
		moduleResult.Duration = os.clock() - epoch
		moduleResult.Okay = false
		moduleResult.Error = new(Error, {
			Message = "test module returned non-table",
		})
		return moduleResult
	end

	local testFuncs = {}
	for name, func in pairs(tests) do
		if string.sub(name, 1, #funcPrefix) == funcPrefix and matchPatterns(patterns, name) then
			table.insert(testFuncs, {Name = name, Func = func})
		end
	end
	table.sort(testFuncs, function(a, b)
		return a.Name < b.Name
	end)

	return moduleResult, testFuncs
end

function Runner.__index:runTest(module, test, name)
-- type Test = (t: T, require: ()->(any)?) -> ()
-- function Runner.__index:runTest(module: Module, test: Test, name: string): TestResult
	local result = new(TestResult, {
		Name = name,
		Duration = 0,
		Failed = false,
		Skipped = false,
		Error = nil,
		Log = nil,
	})

	local cache = nil
	local function req()
		if cache ~= nil then
			return cache
		end
		if useLoadModule then
			cache = debug_loadmodule(cloneFull(module, self.nocopy))()
		else
			cache = require(cloneFull(module, self.nocopy))
		end
		return cache
	end

	local function errHandler(err)
		return {Cause = err, Trace = debug.traceback(nil, 2)}
	end

	local t = newT(name)
	local epoch = os.clock()
	t.yield = self.yield
	local ok, err = xpcall(test, errHandler, t, req)
	result.Duration = os.clock() - epoch
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

function Runner.__index:runBench(module, benchmark, name)
	local b = newB(name, self.benchN, self.benchD)
	b.yield = self.yield
	b.benchFunc = benchmark
	b.result = new(BenchmarkResult, {
		Name = name,
		Iterations = 0,
		Duration = 0,
		Failed = false,
		Skipped = false,
		Error = nil,
		Log = nil,
	})

	local cache = nil
	function b.require()
		if cache ~= nil then
			return cache
		end
		if useLoadModule then
			cache = debug_loadmodule(cloneFull(module, self.nocopy))()
		else
			cache = require(cloneFull(module, self.nocopy))
		end
		return cache
	end

	function b.errHandler(err)
		return {Cause = err, Trace = debug.traceback(nil, 2)}
	end

	b.epoch = os.clock()
	if b:run1() then
		b:run()
	end

	local ok, err, trace = b:cleanup()
	if not ok and b.result.Error == nil then
		if err ~= haltMarker then
			b.result.Failed = true
			b.result.Error = new(Error, {
				Message = "error during cleanup",
				Cause = err,
				Trace = trace,
			})
		end
	end

	b.result.Log = b:compileLog()
	return b.result
end

return Testing
