-- Synchronizes the breakpoints of one ModuleScript to another.
--
-- Plugins cannot access the DebuggerManager, so they cannot use
-- BreakpointSyncer directly. Instead, it is recommended to expose the required
-- behavior to the command bar via _G.

local Maid = require(script.Parent.Parent.Maid)

local export = {}

export type Syncer = {
	Destroy: (self: Syncer) -> (),
}

local function linkDebuggers(source: ScriptDebugger?, target: ScriptDebugger?): Maid.Task
	if source ~= nil and target ~= nil then
		local function addBreakpoint(sourceBreakpoint: DebuggerBreakpoint)
			target:SetBreakpoint(
				sourceBreakpoint.Line,
				sourceBreakpoint.isContextDependentBreakpoint
			)
		end
		local function removeBreakpoint(sourceBreakpoint: DebuggerBreakpoint)
			-- SetBreakpoint retrieves existing breakpoints.
			target:SetBreakpoint(
				sourceBreakpoint.Line,
				sourceBreakpoint.isContextDependentBreakpoint
			):Destroy()
			-- No way to unset a breakpoint except to remove it from the
			-- debugger. Can't set its Parent, but it can be destroyed. *shrug*
		end

		local conns = {
			source.BreakpointAdded:Connect(addBreakpoint::any),
			source.BreakpointRemoved:Connect(removeBreakpoint::any),
		}
		for _, breakpoint in source:GetBreakpoints() do
			addBreakpoint(breakpoint::DebuggerBreakpoint)
		end

		return conns
	end
	return nil
end

function export.new(source: ModuleScript, target: ModuleScript): Syncer
	assert(typeof(source) == "Instance" and source:IsA("ModuleScript"), "source must be a ModuleScript")
	assert(typeof(target) == "Instance" and target:IsA("ModuleScript"), "target must be a ModuleScript")

	local rootMaid = Maid.new()

	local self = {}

	local sourceDebugger: ScriptDebugger? = nil
	local targetDebugger: ScriptDebugger? = nil
	local function tryLinking()
		rootMaid.linkDebuggers = linkDebuggers(sourceDebugger, targetDebugger)
	end

	local function addDebugger(debugger: ScriptDebugger)
		if debugger.Script == source then
			sourceDebugger = debugger
			tryLinking()
		elseif debugger.Script == target then
			targetDebugger = debugger
			tryLinking()
		end
	end

	local function removeDebugger(debugger: ScriptDebugger)
		if debugger.Script == source then
			sourceDebugger = nil
			tryLinking()
		elseif debugger.Script == target then
			targetDebugger = nil
			tryLinking()
		end
	end

	local manager: DebuggerManager = DebuggerManager()
	rootMaid._ = manager.DebuggerAdded:Connect(addDebugger::any)
	rootMaid._ = manager.DebuggerRemoved:Connect(removeDebugger::any)
	for _, debugger in manager:GetDebuggers() do
		addDebugger(debugger::ScriptDebugger)
	end

	function self:Destroy()
		rootMaid:Destroy()
	end

	return table.freeze(self)
end

return table.freeze(export)
