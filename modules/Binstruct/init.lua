--!strict

--@sec: Binstruct
--@ord: -2
--@doc: Binstruct encodes and decodes binary structures.
--
-- Example:
-- ```lua
-- local Binstruct = require(script.Parent.Binstruct)
-- local z = Binstruct
--
-- local Float = z.float(32)
-- local String = z.str(8)
-- local Vector3 = z.struct(
--     "X" , Float,
--     "Y" , Float,
--     "Z" , Float
-- )
-- local CFrame = z.struct(
--     "Position" , Vector3,
--     "Rotation" , z.array(9, Float)
-- )
-- local brick = z.struct(
--     "Name"         , String,
--     "CFrame"       , CFrame,
--     "Size"         , Vector3,
--     "Color"        , z.byte(),
--     "Reflectance"  , z.uint(4),
--     "Transparency" , z.uint(4),
--     "CanCollide"   , z.bool(),
--     "Shape"        , z.uint(3),
--     "_"            , z.pad(4),
--     "Material"     , z.uint(6),
--     "_"            , z.pad(2)
-- )
--
-- local err, codec = Binstruct.new(brick)
-- if err ~= nil then
--     error(err)
-- end
-- print(codec:Decode("\8"..string.rep("A", 73)))
-- -- {
-- --     ["CFrame"] = {
-- --         ["Position"] = {
-- --             ["X"] = 12.078,
-- --             ["Y"] = 12.078,
-- --             ["Z"] = 12.078
-- --         },
-- --         ["Rotation"] = {
-- --             [1] = 12.078,
-- --             [2] = 12.078,
-- --             [3] = 12.078,
-- --             [4] = 12.078,
-- --             [5] = 12.078,
-- --             [6] = 12.078,
-- --             [7] = 12.078,
-- --             [8] = 12.078,
-- --             [9] = 12.078
-- --         }
-- --     },
-- --     ["CanCollide"] = true,
-- --     ["Color"] = 65,
-- --     ["Material"] = 1,
-- --     ["Name"] = "AAAAAAAA",
-- --     ["Reflectance"] = 1,
-- --     ["Shape"] = 0,
-- --     ["Size"] = {
-- --         ["X"] = 12.078,
-- --         ["Y"] = 12.078,
-- --         ["Z"] = 12.078
-- --     },
-- --     ["Transparency"] = 4
-- -- }
-- ```

local Bitbuf = require(script.Parent.Bitbuf)

local export = {}

-- Any value representing an error, where nil indicates the absence of an error.
export type error = any?

--@sec: Buffer
--@def: type Buffer = {
--     Fits: (self: Buffer, size: number) -> boolean,                      -- Used by all primitive types.
--     Index: (self: Buffer) -> number,                                    -- Used by align.
--     Len: (self: Buffer) -> number,                                      -- Used by align.
--     ReadAlign: (self: Buffer, size: number) -> (),                      -- Used by align.
--     ReadBool: (self: Buffer) -> boolean,                                -- Used by bool.
--     ReadByte: (self: Buffer) -> number,                                 -- Used by byte.
--     ReadBytes: (self: Buffer, size: number) -> string,                  -- Used by str.
--     ReadFixed: (self: Buffer, i: number, f: number) -> number,          -- Used by fixed.
--     ReadFloat: (self: Buffer, size: number) -> number,                  -- Used by float.
--     ReadInt: (self: Buffer, size: number) -> number,                    -- Used by int.
--     ReadPad: (self: Buffer, size: number) -> (),                        -- Used by pad and bool.
--     ReadUfixed: (self: Buffer, i: number, f: number) -> number,         -- Used by ufixed.
--     ReadUint: (self: Buffer, size: number) -> number,                   -- Used by uint and str.
--     WriteAlign: (self: Buffer, size: number) -> (),                     -- Used by align.
--     WriteBool: (self: Buffer, v: any?) -> (),                           -- Used by bool.
--     WriteByte: (self: Buffer, v: number) -> (),                         -- Used by byte.
--     WriteBytes: (self: Buffer, v: string) -> (),                        -- Used by str.
--     WriteFixed: (self: Buffer, i: number, f: number, v: number) -> (),  -- Used by fixed.
--     WriteFloat: (self: Buffer, size: number, v: number) -> (),          -- Used by float.
--     WriteInt: (self: Buffer, size: number, v: number) -> (),            -- Used by int.
--     WritePad: (self: Buffer, size: number) -> (),                       -- Used by pad and bool.
--     WriteUfixed: (self: Buffer, i: number, f: number, v: number) -> (), -- Used by ufixed.
--     WriteUint: (self: Buffer, size: number, v: number) -> (),           -- Used by uint and str.
-- }
--@doc: An interface representing a buffer of bits. This module uses Bitbuf by
-- default, but any bit buffer can be used by writing an intermediate interface
-- that translates between APIs.
export type Buffer = {
	Fits: (self: Buffer, size: number) -> boolean,                      -- Used by all primitive types.
	Index: (self: Buffer) -> number,                                    -- Used by align.
	Len: (self: Buffer) -> number,                                      -- Used by align.
	ReadAlign: (self: Buffer, size: number) -> (),                      -- Used by align.
	ReadBool: (self: Buffer) -> boolean,                                -- Used by bool.
	ReadByte: (self: Buffer) -> number,                                 -- Used by byte.
	ReadBytes: (self: Buffer, size: number) -> string,                  -- Used by str.
	ReadFixed: (self: Buffer, i: number, f: number) -> number,          -- Used by fixed.
	ReadFloat: (self: Buffer, size: number) -> number,                  -- Used by float.
	ReadInt: (self: Buffer, size: number) -> number,                    -- Used by int.
	ReadPad: (self: Buffer, size: number) -> (),                        -- Used by pad and bool.
	ReadUfixed: (self: Buffer, i: number, f: number) -> number,         -- Used by ufixed.
	ReadUint: (self: Buffer, size: number) -> number,                   -- Used by uint and str.
	WriteAlign: (self: Buffer, size: number) -> (),                     -- Used by align.
	WriteBool: (self: Buffer, v: any?) -> (),                           -- Used by bool.
	WriteByte: (self: Buffer, v: number) -> (),                         -- Used by byte.
	WriteBytes: (self: Buffer, v: string) -> (),                        -- Used by str.
	WriteFixed: (self: Buffer, i: number, f: number, v: number) -> (),  -- Used by fixed.
	WriteFloat: (self: Buffer, size: number, v: number) -> (),          -- Used by float.
	WriteInt: (self: Buffer, size: number, v: number) -> (),            -- Used by int.
	WritePad: (self: Buffer, size: number) -> (),                       -- Used by pad and bool.
	WriteUfixed: (self: Buffer, i: number, f: number, v: number) -> (), -- Used by ufixed.
	WriteUint: (self: Buffer, size: number, v: number) -> (),           -- Used by uint and str.
}

-- The state of the compiler.
type CompileState = {
	decode: Program, -- List of decoding instructions.
	encode: Program, -- List of encoding instructions.

	-- Tracks status of subroutines.
	-- - nil: Def does not have a subroutine. Instructions are generated
	--   unconditionally.
	-- - false: Def has subroutine that has not yet been generated. This will be
	--   observed during subroutine generation, causing instructions to be
	--   generated. Afterward, the state is set to true.
	-- - true: Def has subroutine that has been generated. Instead of generating
	--   instructions, a SUBR instruction is generated.
	subr: {[TypeDef]:true?},
	-- Stack of pointers currently being dereferenced. Used to detect
	-- self-referencing pointers. An error is returned when trying to deference
	-- a pointer that is currently being dereferenced.
	ptrs: {ptr},
}

-- An integer indicating the address of an instruction within a program.
type Addr = number

-- A sequential list of instructions.
type Program = {Instruction}

-- Maps the definition of a subroutine to the address of the subroutine. Within
-- a call instruction, the subroutine's TypeDef is used as a stub for its
-- address. Subrs is used to resolve the TypeDef into the actual address once
-- all subroutines have been generated.
type Subrs = {[TypeDef]: Addr}

-- Reference to a specific instruction.
type Opcode = string

-- A single operation. *param* is passed to the InstructionFunc corresponding to
-- *opcode*.
type Instruction = {
	opcode: Opcode,
	param: any,
}

-- The implementation of an instruction. Receives the registers of the executing
-- program, and the parameter of the instruction.
type InstructionFunc = (r: Registers, param: any) -> error

-- Definition of an instruction for each column.
type InstructionDef = {
	decode: InstructionFunc,
	encode: InstructionFunc?, -- If a non-function, it is copied from decode.
}

-- The state of an executing program.
type Registers = {
	PC     : number,       -- Program counter.
	BUFFER : Buffer,       -- Bit buffer.
	GLOBAL : {[any]: any}, -- A general-purpose per-execution table.
	STACK  : {Frame},      -- Stores frames.
	SUBR   : {Addr},       -- Stores call return addresses.
	F      : Frame,        -- Current frame.
}

-- A stack frame.
type Frame = {
	TABLE : {[any]: any}, -- The working table.
	KEY   : any,          -- A key pointing to a field in TABLE.
	N     : number,       -- Maximum counter value.
	H     : boolean,      -- Accumulated result of each hook.
}

--@sec: Field
--@def: {key: any?, value: TypeDef, hook: Hook?, global: any?}
--@doc: Defines the field of a struct or property of an instance.
--
-- *key* is the key used to index the field. If nil, the value will be
-- processed, but the field will not be assigned to when decoding. When
-- encoding, a `nil` value will be received, causing the zero value for the
-- field's type to be used.
--
-- *value* is the type of the field.
--
-- *hook* and *global* behave the same as in [TypeDefBase][TypeDefBase].
export type Field = {
	key: any?,      -- The name of the field.
	value: TypeDef, -- The type of the field.
	hook: Hook?,    -- A hook that applies to the field. The entire field is skipped if false is returned.
	global: any?,   -- If specified, the field's value is assigned to this key.
}

--@sec: TypeDef
--@def: type TypeDef = ptr | pad | align | const | bool | int | uint | byte | float | fixed | ufixed | str | union | struct | array | vector | instance
--@doc: TypeDef indicates the definition of one of a number of types.
export type TypeDef
	= ptr
	| pad
	| align
	| const
	| bool
	| int
	| uint
	| byte
	| float
	| fixed
	| ufixed
	| str
	| union
	| struct
	| array
	| vector
	| instance

--@sec: Hook
--@def: type Hook = (stack: (level: number)->any, global: table, h: boolean) -> (boolean, error?)
--@doc: Hook indicates whether a type is traversed. If it returns true, then the
-- type is traversed normally. If false is returned, then the type is skipped.
-- If an error is returned, the program halts, returning the error.
--
-- *stack* is used to index structures in the stack. *level* determines how far
-- down to index the stack. level 0 returns the current structure. Returns nil
-- if *level* is out of bounds.
--
-- *global* is the global table. This can be used to compare against globally
-- assigned values.
--
-- *h* is the accumulated result of each hook in the same scope. It will be true
-- only if no other hooks returned true.
export type Hook = (stack: (level: number)->any, global: {[any]:any}, h: boolean) -> (boolean, error)

--@sec: Calc
--@def: type Calc = (stack: (level: number)->any, global: table) -> (number, error?)
--@doc: Calc is used to calculate the length of a value dynamically.
--
-- *stack* is used to index structures in the stack. *level* determines how far
-- down to index the stack. level 0 returns the current structure. Returns nil
-- if *level* is out of bounds.
--
-- *global* is the global table. This can be used to compare against globally
-- assigned values.
export type Calc = (stack: (level: number)->any, global: {[any]:any}) -> (number, error)

--@sec: Expr
--@def: type Expr = (stack: (level: number)->any, global: table) -> (boolean, error?)
--@doc: Expr is used to evaluate the clause of a union. It is similar to
-- [Hook][Hook].
--
-- *stack* is used to index structures in the stack. *level* determines how far
-- down to index the stack. level 0 returns the current structure. Returns nil
-- if *level* is out of bounds.
--
-- *global* is the global table. This can be used to compare against globally
-- assigned values.
export type Expr = (stack: (level: number)->any, global: {[any]:any}) -> (boolean, error)

--@sec: Filter
--@def: type Filter = FilterFunc | FilterTable
--@doc: Filter applies to a [TypeDef][TypeDef] by transforming a value before
-- encoding, or after decoding.
export type Filter = FilterFunc | FilterTable

--@sec: FilterFunc
--@def: type FilterFunc = (value: any?, params: ...any) -> (any?, error?)
--@doc: FilterFunc transforms *value* by using a function. The function should
-- return the transformed *value*.
--
-- The *params* received depend on the type, but are usually the elements of the
-- [TypeDef][TypeDef].
--
-- A non-nil error causes the program to halt, returning the given value.
export type FilterFunc = (value: any?, ...any) -> (any?, error)

--@sec: FilterTable
--@def: type FilterTable = {[any] = any}
--@doc: FilterTable transforms a value by mapping the original value to the
-- transformed value.
export type FilterTable = {[any]: any}

-- Prepare a function that indexes stack. If level is 0, then tab is indexed.
local function stackFn(stack: {Frame}, tab: {[any]:any}): (number) -> any
	if #stack == 0 then
		-- Stack is empty; tab is root, which must be inaccessible. Therefore,
		-- no level will return a valid value.
		return function() return nil end
	end
	local n = #stack+1
	return function(level: number): any
		if level == 0 then
			return tab
		end
		local i = n-level
		if i > 1 then
			local top = stack[i]
			if top then
				return top.TABLE
			end
		end
		return nil
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Set of instructions definitions.
local INSTRUCTION: {[string]: InstructionDef} = {}

-- NOTE: When we want to jump to an instruction to execute, we want to jump to
-- the address *before* that instruction. This is because the program counter is
-- incremented unconditionally after each instruction is executed.

-- Get or set TABLE[KEY] from BUFFER.
INSTRUCTION.SET = {
	decode = function(R: Registers, fn: (Buffer) -> (any, error)): error
		local v, err = fn(R.BUFFER)
		if err ~= nil then
			return err
		end
		if R.F.KEY ~= nil then
			R.F.TABLE[R.F.KEY] = v
		end
		return nil
	end,
	encode = function(R: Registers, fn: (Buffer, any) -> error): error
		local err = fn(R.BUFFER, R.F.TABLE[R.F.KEY])
		return err
	end,
}

-- Call the parameter with BUFFER.
INSTRUCTION.CALL = {
	decode = function(R: Registers, fn: (Buffer) -> error): error
		local err = fn(R.BUFFER)
		return err
	end,
}

-- Scope into a structural value. Must not be followed by an instruction that
-- reads KEY.
INSTRUCTION.PUSH = {
	decode = function(R: Registers, fn: (Buffer) -> (any, error)): error
		-- *value* be a structural value to scope into.
		local v, err = fn(R.BUFFER)
		if err ~= nil then
			return err
		end
		table.insert(R.STACK, table.clone(R.F))
		R.F.TABLE = v
		R.F.H = true
		return nil
	end,
	encode = function(R: Registers, fn: (Buffer, any) -> (any, error)): error
		-- Result *value* must be a structural value to scope into.
		local v = R.F.TABLE[R.F.KEY]
		local v, err = fn(R.BUFFER, v)
		if err ~= nil then
			return err
		end
		table.insert(R.STACK, table.clone(R.F))
		R.F.TABLE = v
		R.F.H = true
		return nil
	end,
}

-- Create a new scope within the same structure.
INSTRUCTION.PUSHS = {
	decode = function(R: Registers): error
		table.insert(R.STACK, table.clone(R.F))
		R.F.H = true
		return nil
	end,
}

-- Create scope to capture a result into N.
INSTRUCTION.PUSHN = {
	decode = function(R: Registers): error
		table.insert(R.STACK, table.clone(R.F))
		R.F.TABLE = {}
		R.F.KEY = 1
		R.F.H = true
		return nil
	end,
	encode = function(R: Registers): error
		table.insert(R.STACK, table.clone(R.F))
		local t = R.F.TABLE[R.F.KEY]
		local size
		if type(t) == "table" then
			size = #t
		else
			size = 0
		end
		R.F.TABLE = {size}
		R.F.KEY = 1
		R.F.H = true
		return nil
	end,
}

-- Set KEY to the parameter.
INSTRUCTION.FIELD = {
	decode = function(R: Registers, v: any): error
		R.F.KEY = v
		return nil
	end,
}

-- Scope out of a structural value.
INSTRUCTION.POP = {
	decode = function(R: Registers, fn: (any) -> (any, error)): error
		local v, err = fn(R.F.TABLE)
		if err ~= nil then
			return err
		end
		R.F = assert(table.remove(R.STACK), "pop empty stack")
		if R.F.KEY ~= nil then
			R.F.TABLE[R.F.KEY] = v
		end
		return nil
	end,
	encode = function(R: Registers): error
		R.F = assert(table.remove(R.STACK), "pop empty stack")
		return nil
	end,
}

-- Pop structureless scope.
INSTRUCTION.POPS = {
	decode = function(R: Registers): error
		R.F = assert(table.remove(R.STACK), "pop empty stack")
		return nil
	end,
}

-- Get result of TABLE[KEY], pop the scope, load the result to N.
INSTRUCTION.POPN = {
	decode = function(R: Registers): error
		local size = R.F.TABLE[R.F.KEY]
		if type(size) == "number" then
			size = math.floor(size)
		else
			size = 0
		end
		R.F = assert(table.remove(R.STACK), "pop empty stack")
		R.F.N = size
		return nil
	end,
}

-- Initialize a loop using the current terminator.
INSTRUCTION.FOR = {
	decode = function(R: Registers, params: {addr:Addr}): error
		R.PC = params.addr - 1
		R.F.KEY = 0
		return nil
	end,
}

-- Initialize a loop with a constant terminator.
INSTRUCTION.FORC = {
	decode = function(R: Registers, params: {addr:Addr, size:number}): error
		R.PC = params.addr - 1
		R.F.KEY = 0
		if params.size >= 1 then
			R.F.N = params.size
			return nil
		end
		R.F.N = 0
		return nil
	end,
}

-- Initialize a loop with a dynamic terminator, determined by a field in the
-- parent structure.
INSTRUCTION.FORF = {
	decode = function(R: Registers, params: {addr:Addr, field:any, level:number}): error
		R.PC = params.addr - 1
		R.F.KEY = 0
		local level = #R.STACK-params.level+1
		if level > 1 then
			local top = R.STACK[level]
			if top then
				local parent = top.TABLE
				if parent then
					local v = parent[params.field]
					if type(v) == "number" then
						R.F.N = v
						return nil
					end
				end
			end
		end
		R.F.N = 0
		return nil
	end,
}

-- Initialize a loop with a calculated terminator.
INSTRUCTION.FORX = {
	decode = function(R: Registers, params: {addr:Addr, calc:Calc}): error
		R.PC = params.addr - 1
		R.F.KEY = 0
		local r, err = params.calc(stackFn(R.STACK, R.F.TABLE), R.GLOBAL)
		if err ~= nil then
			return err
		end
		if type(r) == "number" then
			R.F.N = r
			return nil
		end
		R.F.N = 0
		return nil
	end,
}

-- Jump to loop start if KEY is less than N.
INSTRUCTION.JMPN = {
	decode = function(R: Registers, addr: Addr): error
		if R.F.KEY < R.F.N then
			R.F.KEY += 1
			R.PC = addr
		end
		return nil
	end,
}

-- Call hook, jump to addr if false is returned.
INSTRUCTION.HOOK = {
	decode = function(R: Registers, params: {addr:Addr, hook:Hook}): error
		local r, err = params.hook(stackFn(R.STACK, R.F.TABLE), R.GLOBAL, R.F.H)
		if err ~= nil then
			return err
		end
		R.F.H = R.F.H and not r
		if not r then
			R.PC = params.addr
		end
		return nil
	end,
}

-- Jump to exit address if not H, else call expr, jump to addr if false is
-- returned.
INSTRUCTION.EXPR = {
	decode = function(R: Registers, params: {addr:Addr, exitaddr:Addr, expr:Expr}): error
		if not R.F.H then
			R.PC = params.exitaddr
			return nil
		end
		local r, err = params.expr(stackFn(R.STACK, R.F.TABLE), R.GLOBAL)
		if err ~= nil then
			return err
		end
		R.F.H = R.F.H and not r
		if not r then
			R.PC = params.addr
		end
		return nil
	end,
}

-- Unconditional expression. Jump to exit address if not H, else do nothing.
INSTRUCTION.UXPR = {
	decode = function(R: Registers, params: {exitaddr:Addr}): error
		if not R.F.H then
			R.PC = params.exitaddr
			return nil
		end
		R.F.H = false
		return nil
	end,
}

-- Set global value.
INSTRUCTION.GLOBAL = {
	decode = function(R: Registers, key: any): error
		if R.F.KEY ~= nil then
			R.GLOBAL[key] = R.F.TABLE[R.F.KEY]
		end
		return nil
	end,
}

-- Unconditional jump.
INSTRUCTION.JMP = {
	decode = function(R: Registers, params: {addr:Addr, hook:Hook}): error
		R.PC = params.addr
		return nil
	end,
}

-- Invoke subroutine.
INSTRUCTION.SUBR = {
	decode = function(R: Registers, addr: Addr): error
		table.insert(R.SUBR, R.PC)
		R.PC = addr
		return nil
	end,
}

-- Return from subroutine.
INSTRUCTION.RET = {
	decode = function(R: Registers): error
		R.PC = assert(table.remove(R.SUBR), "return from root routine")
		return nil
	end,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Set of value types. Each key is a type name. Each value is a function that
-- receives an instruction list, followed by TypeDef parameters. The `append`
-- function should be used to append instructions to the list.
local TYPES: {[string]: (CompileState, any)->error} = {}

-- Maps a type to a function that receives a TypeDef and returns a list of the
-- definition's inner types.
local GRAPH: {[string]: (any)->{TypeDef}} = {}

-- Appends to *list* the instruction corresponding to *opcode*. Each remaining
-- argument corresponds to an argument to be passed to the corresponding
-- instruction column. Returns the address of the appended instruction.
local function append(state: CompileState, opcode: string, columns: {decode:any, encode:any}?)
	if columns then
		table.insert(state.decode, {opcode=opcode, param=columns.decode})
		table.insert(state.encode, {opcode=opcode, param=columns.encode})
	else
		table.insert(state.decode, {opcode=opcode})
		table.insert(state.encode, {opcode=opcode})
	end
	return #state.decode
end

-- Sets the "addr" field of the parameter of each column of the instruction at
-- *addr* to the address of the the last instruction. Expects each column
-- parameter to be a table. Does nothing if *addr* is nil.
local function setJump(state: CompileState, addr: Addr?)
	if addr ~= nil then
		state.decode[addr].param.addr = #state.decode
		state.encode[addr].param.addr = #state.encode
	end
end

-- Sets the "exitaddr" field of the parameter of each column of the instruction
-- at *addr* to the address of the the last instruction. Expects each column
-- parameter to be a table. Does nothing if *addr* is nil.
local function setExitJump(state: CompileState, addr: Addr?)
	if addr ~= nil then
		state.decode[addr].param.exitaddr = #state.decode
		state.encode[addr].param.exitaddr = #state.encode
	end
end

-- Appends a JMP instruction with no target set.
local function prepareJump(state: CompileState): Addr
	return append(state, "JMP", {
		decode = {addr=nil},
		encode = {addr=nil},
	})
end

-- If hook is not nil, appends a HOOK instruction with no target set.
local function prepareHook(state: CompileState, hook: Hook?): Addr?
	if hook == nil then
		return nil
	end
	return append(state, "HOOK", {
		decode = {addr=nil, hook=hook},
		encode = {addr=nil, hook=hook},
	})
end

-- Appends an expression instruction with no target set by emitting EXPR if expr
-- is a Expr, or UXPR if expr is true.
local function prepareExpr(state: CompileState, expr: Expr|true): Addr?
	if expr == true then
		return append(state, "UXPR", {
			decode = {exitaddr=nil},
			encode = {exitaddr=nil},
		})
	else
		return append(state, "EXPR", {
			decode = {addr=nil, exitaddr=nil, expr=expr},
			encode = {addr=nil, exitaddr=nil, expr=expr},
		})
	end
end

-- If *global* is not nil, appends a GLOBAL instruction.
local function appendGlobal(state: CompileState, global: any?)
	if global == nil then
		return
	end
	append(state, "GLOBAL", {
		decode = global,
		encode = global,
	})
end

-- Used in place of no filter.
local function nop(v: any, ...): (any, error)
	return v, nil
end

-- Normalizes a Filter into a FilterFunc.
local function normalizeFilter(filter: Filter?): FilterFunc
	if filter == nil then
		return nop
	elseif type(filter) == "table" then
		return function(v: any, ...:any)
			return filter[v]
		end
	else
		return filter
	end
end

local EOF: error = "end of buffer"

-- Registers a function with a name, for debugging.
local debugNameRegistry: {[any]: string} = setmetatable({}, {__mode="k"})::any
local function NAME<T>(func: T, name: string, ...: any): T
	local args = table.pack(...)
	for i = 1, args.n do
		args[i] = tostring(args[i])
	end
	debugNameRegistry[func] = name .. "(" .. table.concat(args,",") .. ")"
	return func
end
local function NAMEOF<T>(func: T): string
	return debugNameRegistry[func] or "<function>"
end

-- Transposes each pair of arguments into a table with a key and a value.
local function fieldPairs(...: any): {Field}
	local args = table.pack(...)
	local fields = table.create(args.n/2)
	for i = 1, args.n, 2 do
		table.insert(fields, {key=args[i], value=args[i+1]})
	end
	return fields
end

local parseDef

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--@sec: TypeDefBase
--@def: type TypeDefBase = {hook: Hook?, decode: Filter?, encode: Filter?, global: any?}
--@doc: TypeDefBase defines fields common to most [TypeDef][TypeDef] types.
--
-- *hook* determines whether the type should be used.
--
-- *decode* transforms the value after decoding, while *encode* transforms the
-- value before encoding.
--
-- If *global* is not nil, then the type's value is added to a globally
-- accessible table under the given key.

--BUG: Instead of type `X & TypeDefBase`, fields are included literally due to
--problems with type checking.
export type TypeDefBase = {
	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: ptr
--@def: type ptr = {type: "ptr", value: TypeDef?}
--@doc: A ptr is a TypeDef that resolve to another type definition. The purpose
-- is to allow definitions to use a type before it is defined. When compiling,
-- an error is thrown if the the ptr points to nothing, or if it is
-- self-referring.
export type ptr = {
	type: "ptr",
	value: TypeDef?,
}

--@sec: Binstruct.ptr
--@def: Binstruct.ptr(value: TypeDef?): ptr
--@doc: Constructs a [ptr][ptr] that points to *value*.
function export.ptr(value: TypeDef?): ptr
	return {type="ptr", value=value}
end

--@sec: pad
--@def: type pad = {type: "pad", size: number} & TypeDefBase
--@doc: Specifies only bit padding, and does not read or write any value
-- (filters are ignored). *size* is the number of bits to pad with.
export type pad = {
	type: "pad",
	size: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.pad
--@def: Binstruct.pad(size: number): pad
--@doc: Constructs a [pad][pad] of *size* bits.
function export.pad(size: number): pad
	return {type="pad", size=size}
end

TYPES["pad"] = function(state: CompileState, def: pad): error
	local size = def.size
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end

	if not size or size <= 0 then
		return nil
	end
	append(state, "FIELD")
	append(state, "CALL", {
		decode = NAME(function(buf: Buffer): error
			if not buf:Fits(size) then return EOF end
			buf:ReadPad(size)
			return nil
		end, "pad", size),
		encode = NAME(function(buf: Buffer): error
			buf:WritePad(size)
			return nil
		end, "pad", size),
	})
	return nil
end

--@sec: align
--@def: type align = {type: "align", size: number} & TypeDefBase
--@doc: Pads with bits until the buffer is aligned to the number of bits
-- indicated by *size*. Does not read or write any value (filters are ignored).
export type align = {
	type: "align",
	size: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.align
--@def: Binstruct.align(size: number): align
--@doc: Constructs an [align][align] that aligns to *size* bits.
function export.align(size: number): align
	return {type="align", size=size}
end

TYPES["align"] = function(state: CompileState, def: align): error
	local size = def.size
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end

	if not size or size <= 0 then
		return nil
	end
	append(state, "FIELD")
	append(state, "CALL", {
		decode = NAME(function(buf: Buffer): error
			local i = buf:Index()
			if math.floor(math.ceil(i/size)*size - i) > buf:Len() - i then
				return EOF
			end
			buf:ReadAlign(size)
			return nil
		end, "align", size),
		encode = NAME(function(buf: Buffer): error
			buf:WriteAlign(size)
			return nil
		end, "align", size),
	})
	return nil
end

--@sec: const
--@def: type const = {type: "const", value: any?} & TypeDefBase
--@doc: A constant value. *value* is the value, which is neither encoded nor
-- decoded.
export type const = {
	type: "const",
	value: any?,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.const
--@def: Binstruct.const(value: any?): const
--@doc: Constructs a [const][const] with *value*.
function export.const(value: any?): const
	return {type="const", value=value}
end

TYPES["const"] = function(state: CompileState, def: const): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local value = def.value

	append(state, "SET", {
		decode = NAME(function(buf: Buffer): (any, error)
			local v = value
			local v, err = dfilter(v, value)
			return v, err
		end, "const", tostring(value)),
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			local _, err = efilter(v, value)
			return err
		end, "const", tostring(value)),
	})
	return nil
end

--@sec: bool
--@def: type bool = {type: "bool", size: number?} & TypeDefBase
--@doc: A boolean value. *size* is the number of bits used to represent the
-- value, defaulting to 1.
--
-- *size* is passed to filters as additional arguments.
--
-- The zero for this type is `false`.
export type bool = {
	type: "bool",
	size: number?,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.bool
--@def: Binstruct.bool(size: number?): bool
--@doc: Constructs a [bool][bool] of *size* bits, defaulting to 1.
function export.bool(size: number?): bool
	return {type="bool", size=size}
end

TYPES["bool"] = function(state: CompileState, def: bool): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end

	size = size or 1
	local decode
	local encode
	if size == 1 then
		decode = NAME(function(buf: Buffer)
			if not buf:Fits(1) then return nil, EOF end
			local v = buf:ReadBool()
			local v, err = dfilter(v, size)
			return v, err
		end, "bool")
		encode = NAME(function(buf: Buffer, v: any)
			if v == nil then v = false end
			local v, err = efilter(v, size)
			if err ~= nil then
				return err
			end
			buf:WriteBool(v)
			return nil
		end, "bool")
	elseif size then
		decode = NAME(function(buf: Buffer): (any, error)
			if not buf:Fits(size) then return nil, EOF end
			local v = buf:ReadBool()
			buf:ReadPad(size-1)
			local v, err = dfilter(v, size)
			return v, err
		end, "bool_wide", size)
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			if v == nil then v = false end
			local v, err = efilter(v, size)
			if err ~= nil then
				return err
			end
			buf:WriteBool(v)
			buf:WritePad(size-1)
			return nil
		end, "bool_wide", size)
	end

	append(state, "SET", {decode=decode, encode=encode})
	return nil
end

--@sec: uint
--@def: type uint = {type: "uint", size: number} & TypeDefBase
--@doc: An unsigned integer. *size* is the number of bits used to represent the
-- value.
--
-- *size* is passed to filters as additional arguments.
--
-- The zero for this type is `0`.
export type uint = {
	type: "uint",
	size: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.uint
--@def: Binstruct.uint(size: number): uint
--@doc: Constructs a [uint][uint] of *size* bits.
function export.uint(size: number): uint
	return {type="uint", size=size}
end

TYPES["uint"] = function(state: CompileState, def: uint): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	if type(size) ~= "number" then
		return "size must be a number"
	end

	append(state, "SET", {
		decode = NAME(function(buf: Buffer): (any, error)
			if not buf:Fits(size) then return nil, EOF end
			local v = buf:ReadUint(size)
			local v, err = dfilter(v, size)
			return v, err
		end, "uint", size),
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			if v == nil then v = 0 end
			local v, err = efilter(v, size)
			if err ~= nil then
				return err
			end
			if type(v) ~= "number" then
				return string.format("number expected, got %s", typeof(v))
			else
				buf:WriteUint(size, v)
			end
			return nil
		end, "uint", size),
	})
	return nil
end

--@sec: int
--@def: type int = {type: "int", size: number} & TypeDefBase
--@doc: A signed integer. *size* is the number of bits used to represent the
-- value.
--
-- *size* is passed to filters as additional arguments.
--
-- The zero for this type is `0`.
export type int = {
	type: "int",
	size: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.int
--@def: Binstruct.int(size: number): int
--@doc: Constructs an [int][int] of *size* bits.
function export.int(size: number): int
	return {type="int", size=size}
end

TYPES["int"] = function(state: CompileState, def: int): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	if type(size) ~= "number" then
		return "size must be a number"
	end

	append(state, "SET", {
		decode = NAME(function(buf: Buffer): (any, error)
			if not buf:Fits(size) then return nil, EOF end
			local v = buf:ReadInt(size)
			local v, err = dfilter(v, size)
			return v, err
		end, "int", size),
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			if v == nil then v = 0 end
			local v, err = efilter(v, size)
			if err ~= nil then
				return err
			end
			if type(v) ~= "number" then
				return string.format("number expected, got %s", typeof(v))
			else
				buf:WriteInt(size, v)
			end
			return nil
		end, "int", size),
	})
	return nil
end

--@sec: byte
--@def: type byte = {type: "byte"} & TypeDefBase
--@doc: Shorthand for a [uint][uint] of size 8.
export type byte = {
	type: "byte",

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.byte
--@def: Binstruct.byte(): byte
--@doc: Constructs a [byte][byte].
function export.byte(): byte
	return {type="byte"}
end

TYPES["byte"] = function(state: CompileState, def: byte): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)

	append(state, "SET", {
		decode = NAME(function(buf: Buffer): (any, error)
			if not buf:Fits(8) then return nil, EOF end
			local v = buf:ReadByte()
			local v, err = dfilter(v)
			return v, err
		end, "byte"),
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			if v == nil then v = 0 end
			local v, err = efilter(v)
			if err ~= nil then
				return err
			end
			if type(v) ~= "number" then
				return string.format("number expected, got %s", typeof(v))
			else
				buf:WriteByte(v)
			end
			return nil
		end, "byte"),
	})
	return nil
end

--@sec: float
--@def: type float = {type: "float", size: number?} & TypeDefBase
--@doc: A floating-point number. *size is the number of bits used to represent
-- the value, and must be 32 or 64. Defaults to 64.
--
-- *size* is passed to filters as additional arguments.
--
-- The zero for this type is `0`.
export type float = {
	type: "float",
	size: number?,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.float
--@def: Binstruct.float(size: number): float
--@doc: Constructs a [float][float] of *size* bits.
function export.float(size: number): float
	return {type="float", size=size}
end

TYPES["float"] = function(state: CompileState, def: float): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end
	local size = size or 64

	append(state, "SET", {
		decode = NAME(function(buf: Buffer): (any, error)
			if not buf:Fits(size) then return nil, EOF end
			local v = buf:ReadFloat(size)
			local v, err = dfilter(v, size)
			return v, err
		end, "float", size),
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			if v == nil then v = 0 end
			local v, err = efilter(v, size)
			if err ~= nil then
				return err
			end
			if type(v) ~= "number" then
				return string.format("number expected, got %s", typeof(v))
			else
				buf:WriteFloat(size, v)
			end
			return nil
		end, "float", size),
	})
	return nil
end

--@sec: ufixed
--@def: type ufixed = {type: "ufixed", i: number, f: number} & TypeDefBase
--@doc: An unsigned fixed-point number. *i* is the number of bits used to
-- represent the integer part, and *f* is the number of bits used to represent
-- the fractional part.
--
-- *i* and *f* are passed to filters as additional arguments.
--
-- The zero for this type is `0`.
export type ufixed = {
	type: "ufixed",
	i: number,
	f: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.ufixed
--@def: Binstruct.ufixed(i: number, f: number): ufixed
--@doc: Constructs a [ufixed][ufixed] with *i* bits for the integer part, and
-- *f* bits for the fractional part.
function export.ufixed(i: number, f: number): ufixed
	return {type="ufixed", i=i, f=f}
end

TYPES["ufixed"] = function(state: CompileState, def: ufixed): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local i = def.i
	local f = def.f
	if type(i) ~= "number" then
		return "integer part must be a number"
	end
	if type(f) ~= "number" then
		return "fractional part must be a number"
	end

	append(state, "SET", {
		decode = NAME(function(buf: Buffer): (any, error)
			if not buf:Fits(i+f) then return nil, EOF end
			local v = buf:ReadUfixed(i, f)
			local v, err = dfilter(v, i, f)
			return v, err
		end, "ufixed", i, f),
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			if v == nil then v = 0 end
			local v, err = efilter(v, i, f)
			if err ~= nil then
				return err
			end
			if type(v) ~= "number" then
				return string.format("number expected, got %s", typeof(v))
			else
				buf:WriteUfixed(i, f, v)
			end
			return nil
		end, "ufixed", i, f),
	})
	return nil
end

--@sec: fixed
--@def: type fixed = {type: "fixed", i: number, f: number} & TypeDefBase
--@doc: A signed fixed-point number. *i* is the number of bits used to represent
-- the integer part. *f* is the number of bits used to represent the fractional
-- part.
--
-- *i* and *f* are passed to filters as additional arguments.
--
-- The zero for this type is `0`.
export type fixed = {
	type: "fixed",
	i: number,
	f: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.fixed
--@def: Binstruct.fixed(i: number, f: number): fixed
--@doc: Constructs a [fixed][fixed] of *i* bits for the integer part, and *f*
-- bits for the fractional part.
function export.fixed(i: number, f: number): fixed
	return {type="fixed", i=i, f=f}
end

TYPES["fixed"] = function(state: CompileState, def: fixed): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local i = def.i
	local f = def.f
	if type(i) ~= "number" then
		return "integer part must be a number"
	end
	if type(f) ~= "number" then
		return "fractional part must be a number"
	end

	append(state, "SET", {
		decode = NAME(function(buf: Buffer): (any, error)
			if not buf:Fits(i+f) then return nil, EOF end
			local v = buf:ReadFixed(i, f)
			local v, err = dfilter(v, i, f)
			return v, err
		end, "fixed", i, f),
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			if v == nil then v = 0 end
			local v, err = efilter(v, i, f)
			if err ~= nil then
				return err
			end
			if type(v) ~= "number" then
				return string.format("number expected, got %s", typeof(v))
			else
				buf:WriteFixed(i, f, v)
			end
			return nil
		end, "fixed", i, f),
	})
	return nil
end

--@sec: str
--@def: type str = {type: "str", size: number} & TypeDefBase
--@doc: A sequence of characters. Encoded as an unsigned integer indicating the
-- length of the string, followed by the raw bytes of the string. *size* is the
-- number of bits used to represent the length.
--
-- *size* is passed to filters as additional arguments.
--
-- The zero for this type is the empty string.
export type str = {
	type: "str",
	size: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.str
--@def: Binstruct.str(size: number): str
--@doc: Constructs a [str][str] with a length occupying *size* bits.
function export.str(size: number): str
	return {type="str", size=size}
end

TYPES["str"] = function(state: CompileState, def: str): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	if type(size) ~= "number" then
		return "size must be a number"
	end

	append(state, "SET", {
		decode = NAME(function(buf: Buffer): (any, error)
			if not buf:Fits(size) then return nil, EOF end
			local len = buf:ReadUint(size)
			if not buf:Fits(len) then return nil, EOF end
			local v = buf:ReadBytes(len)
			local v, err = dfilter(v, size)
			return v, err
		end, "str", size),
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			if v == nil then v = "" end
			local v, err = efilter(v, size)
			if err ~= nil then
				return err
			end
			if type(v) ~= "string" then
				return string.format("string expected, got %s", typeof(v))
			else
				buf:WriteUint(size, #v)
				buf:WriteBytes(v)
			end
			return nil
		end, "str", size),
	})
	return nil
end

--@sec: Clause
--@def: type Clause = {expr: Expr|true, value: TypeDef?, global: any?}
--@doc: One element of a [union][union].
--
-- When traversing a union, each *expr* is evaluated in the same way as an
-- if-statement: the first clause that evaluates to true is selected. Specifying
-- `true` as *expr* is similar to an "else" clause.
--
-- If the clause is selected, then *value* is used as the value. *global*
-- behaves the same as in [TypeDefBase][TypeDefBase].
export type Clause = {
	expr: Expr|true,
	value: TypeDef?,
	global: any?,
}

--@sec: union
--@def: type union = {type: "union", clauses: {Clause}} & TypeDefBase
--@doc: One of several types, where each [Clause][Clause] is evaluated to select
-- a single type.
export type union = {
	type: "union",
	clauses: {Clause},

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.union
--@def: Binstruct.union(...any): union
--@doc: Constructs a [union][union] where each pair of arguments forms a
-- [Clause][Clause]. The first in a pair sets the "expr" field, while the second
-- sets the "value" field.
function export.union(...: any): union
	local n = select("#", ...)
	local clauses = table.create(n/2)
	for i = 1, n, 2 do
		local expr, def = select(i, ...)
		if expr ~= true and type(expr) ~= "function" then
			error(string.format("bad argument #%d: expected Expr function or true for first in argument pair, got %s", i, typeof(expr)), 2)
		end
		if def ~= nil and type(def) ~= "table" then
			error(string.format("bad argument #%d: expected TypeDef table or nil for second in argument pair, got %s", i+1, typeof(expr)), 2)
		end
		table.insert(clauses, {expr=expr, value=def})
	end
	return {type="union", clauses=clauses}
end

TYPES["union"] = function(state: CompileState, def: union): error
	append(state, "PUSHS")
	local expraddrs = table.create(#def.clauses)
	for i, clause in ipairs(def.clauses) do
		if type(clause) ~= "table" then
			continue
		end
		if clause.expr ~= true and type(clause.expr) ~= "function" then
			return string.format("union[%d]: expr must be a function or true", i)
		end
		local expraddr = prepareExpr(state, clause.expr)
		table.insert(expraddrs, expraddr)
		if clause.value then
			local err = parseDef(clause.value, state)
			if err ~= nil then
				return string.format("union[%d]: %s", i, tostring(err))
			end
		end
		appendGlobal(state, clause.global)
		if clause.expr ~= true then
			setJump(state, expraddr)
		end
	end
	for _, expraddr in expraddrs do
		setExitJump(state, expraddr)
	end
	append(state, "POPS")
	return nil
end

GRAPH["union"] = function(def: union): {TypeDef}
	local types = table.create(#def.clauses)
	for _, clause in ipairs(def.clauses) do
		if type(clause) ~= "table" then
			continue
		end
		if type(clause.value) ~= "table" then
			continue
		end
		table.insert(types, clause.value)
	end
	return types
end

--@sec: struct
--@def: type struct = {type: "struct", fields: {Field}} & TypeDefBase
--@doc: A set of named fields. *fields* defines an ordered list of
-- [Fields][Field] of the struct.
--
-- The zero for this type is an empty struct.
export type struct = {
	type: "struct",
	fields: {Field},

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.struct
--@def: Binstruct.struct(...: any): struct
--@doc: Constructs a [struct][struct] out of the arguments. Arguments form
-- key-value pairs to set the "fields" of the struct, where the key sets the
-- "key" of a [Field][Field], and the value sets the "value" of the field.
function export.struct(...: any): struct
	return {type="struct", fields=fieldPairs(...)}
end

TYPES["struct"] = function(state: CompileState, def: struct): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)

	append(state, "PUSH", {
		decode = NAME(function(buf: Buffer): (any, error)
			return {}, nil
		end, "struct"),
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			if v == nil then v = {} end
			local v, err = efilter(v)
			return v, err
		end, "struct"),
	})
	for _, field in ipairs(def.fields) do
		if type(field) == "table" then
			local key = field.key
			if field.hook ~= nil and type(field.hook) ~= "function" then
				return string.format("field %q: hook must be a function", tostring(key))
			end

			local hookaddr = prepareHook(state, field.hook)
			append(state, "FIELD", {decode=key, encode=key})
			local err = parseDef(field.value, state)
			if err ~= nil then
				return string.format("field %q: %s", tostring(key), tostring(err))
			end
			appendGlobal(state, field.global)
			setJump(state, hookaddr)
		end
	end
	append(state, "POP", {
		decode = NAME(function(v: any): (any, error)
			local v, err = dfilter(v)
			return v, err
		end, "struct"),
	})
	return nil
end

GRAPH["struct"] = function(def: struct): {TypeDef}
	local types = table.create(#def.fields)
	for _, field in ipairs(def.fields) do
		if type(field) ~= "table" then
			continue
		end
		table.insert(types, field.value)
	end
	return types
end

--@sec: array
--@def: type array = {type: "array", size: number|TypeDef, value: TypeDef} & TypeDefBase
--@doc: A constant-size list of unnamed elements.
--
-- *size* specifies the number of elements, which can be an constant integer. If
-- a [TypeDef][TypeDef] is specified instead, then a value of that type will be
-- encoded or decoded, and used as the length. The value must evaluate to a
-- numeric type.
--
-- *value* is the type of each element in the array.
--
-- *size* is passed to filters as additional arguments.
--
-- The zero for this type is an empty array.
export type array = {
	type: "array",
	size: number|TypeDef,
	value: TypeDef,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.array
--@def: Binstruct.array(size: number|TypeDef, value: TypeDef): array
--@doc: Constructs an [array][array] of *size* elements of type *value*.
function export.array(size: number|TypeDef, value: TypeDef): array
	return {type="array", size=size, value=value}
end

TYPES["array"] = function(state: CompileState, def: array): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	local vtype = def.value
	if type(size) == "number" then
		if size <= 0 then
			-- Array is constantly empty.
			return nil
		end
		append(state, "PUSH", {
			decode = NAME(function(buf: Buffer): (any, error)
				return {}, nil
			end, "array"),
			encode = NAME(function(buf: Buffer, v: any): (any, error)
				if v == nil then v = {} end
				local v, err = efilter(v, size)
				return v, err
			end, "array"),
		})
		local params = {addr=nil, size=size}
		local jumpaddr = append(state, "FORC", {decode=params, encode=params})
		local err = parseDef(vtype, state)
		if err ~= nil then
			return string.format("array[%d]: %s", size, tostring(err))
		end
		append(state, "JMPN", {decode=jumpaddr, encode=jumpaddr})
		setJump(state, jumpaddr)
		append(state, "POP", {
			decode = NAME(function(v: any): (any, error)
				local v, err = dfilter(v, size)
				return v, err
			end, "array"),
		})
	elseif type(size) == "table" then
		append(state, "PUSHN")
		local err = parseDef(size, state)
		if err ~= nil then
			return string.format("array[...]: size: %s", tostring(err))
		end
		append(state, "POPN")
		append(state, "PUSH", {
			decode = NAME(function(buf: Buffer): (any, error)
				return {}, nil
			end, "array"),
			encode = NAME(function(buf: Buffer, v: any): (any, error)
				if v == nil then v = {} end
				local v, err = efilter(v, size)
				return v, err
			end, "array"),
		})
		local params = {addr=nil}
		local jumpaddr = append(state, "FOR", {decode=params, encode=params})
		local err = parseDef(vtype, state)
		if err ~= nil then
			return string.format("array[...]: value: %s", tostring(err))
		end
		append(state, "JMPN", {decode=jumpaddr, encode=jumpaddr})
		setJump(state, jumpaddr)
		append(state, "POP", {
			decode = NAME(function(v: any): (any, error)
				local v, err = dfilter(v, size)
				return v, err
			end, "array"),
		})
	else
		return "size must be a number or TypeDef"
	end
	return nil
end

GRAPH["array"] = function(def: array): {TypeDef}
	if type(def.value) ~= "table" then
		return {}
	end
	local types = {}
	if type(def.size) == "table" then
		table.insert(types, def.size)
	end
	table.insert(types, def.value)
	return types
end

--@sec: vector
--@def: type vector = {type: "vector", size: any, value: TypeDef, level: number?} & TypeDefBase
--@doc: A dynamically sized list of unnamed elements.
--
-- *size* indicates the key of a field in the parent struct from which the size
-- is determined. Evaluates to 0 if this field cannot be determined or is a
-- non-number.
--
-- *value* is the type of each element in the vector.
--
-- If *level* is specified, then it indicates the ancestor structure that is
-- index by *size*. If *level* is less than 1 or greater than the number of
-- ancestors, then *size* evaluates to 0. Defaults to 1, indicating the parent
-- structure.
--
-- *size* is passed to filters as additional arguments.
--
-- The zero for this type is an empty vector.
export type vector = {
	type: "vector",
	size: any,
	value: TypeDef,
	level: number?,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.vector
--@def: Binstruct.vector(size: any, value: TypeDef, level: number?): vector
--@doc: Constructs a [vector][vector] that uses *size* as the "size", *value* as
-- the "value", and *level* as the "level".
function export.vector(size: any, value: TypeDef, level: number?): vector
	return {type="vector", size=size, value=value, level=level}
end

TYPES["vector"] = function(state: CompileState, def: vector): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	local vtype = def.value
	if size == nil then
		return "vector size cannot be nil"
	end

	append(state, "PUSH", {
		decode = NAME(function(buf: Buffer): (any, error)
			return {}, nil
		end, "vector"),
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			if v == nil then v = {} end
			local v, err = efilter(v, size)
			return v, err
		end, "vector"),
	})
	local level = def.level or 1
	if level < 0 then
		level = 0
	end
	local jumpaddr
	if type(size) == "function" then
		local params = {addr=nil, calc=size}
		jumpaddr = append(state, "FORX", {decode=params, encode=params})
	else
		local params = {addr=nil, size=size, level=level}
		jumpaddr = append(state, "FORF", {decode=params, encode=params})
	end
	local err = parseDef(vtype, state)
	if err ~= nil then
		return string.format("vector[%s]: %s", tostring(size), tostring(err))
	end
	append(state, "JMPN", {decode=jumpaddr, encode=jumpaddr})
	setJump(state, jumpaddr)
	append(state, "POP", {
		decode = NAME(function(v: any): (any, error)
			local v, err = dfilter(v, size)
			return v, err
		end, "vector"),
	})
	return nil
end

GRAPH["vector"] = function(def: vector): {TypeDef}
	if type(def.value) ~= "table" then
		return {}
	end
	return {def.value}
end

--@sec: instance
--@def: type instance = {type: "instance", class: string, properties: {Field}} & TypeDefBase
--@doc: A Roblox instance. *class* is the name of a Roblox class. Each
-- [Field][Field] of *properties* defines the properties of the instance.
--
-- *class* is passed to filters as additional arguments.
--
-- The zero for this type is a new instance of the class.
export type instance = {
	type: "instance",
	class: string,
	properties: {Field},

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

--@sec: Binstruct.instance
--@def: Binstruct.instance(class: string, ...: any): instance
--@doc: Constructs an [instance][instance] of the given class with properties
-- defined by the remaining arguments. Arguments form key-value pairs to set the
-- "properties" of the instance, where the key sets the "key" of a
-- [Field][Field], and the value sets the "value" of the field.
function export.instance(class: string, ...: any): instance
	return {type="instance", class=class, properties=fieldPairs(...)}
end

TYPES["instance"] = function(state: CompileState, def: instance): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local class = def.class
	if type(class) ~= "string" then
		return "class must be a string"
	end

	append(state, "PUSH", {
		decode = NAME(function(buf: Buffer): (any, error)
			return Instance.new(class::any), nil
		end, "instance"),
		encode = NAME(function(buf: Buffer, v: any): (any, error)
			if v == nil then v = Instance.new(class::any) end
			local v, err = efilter(v, class)
			return v, err
		end, "instance"),
	})
	for i, property in ipairs(def.properties) do
		if type(property) == "table" then
			local name = property.key
			append(state, "FIELD", {decode=name, encode=name})
			local err = parseDef(property.value, state)
			if err ~= nil then
				return string.format("property %q: %s", tostring(name), tostring(err))
			end
		end
	end
	append(state, "POP", {
		decode = NAME(function(v: any): (any, error)
			local v, err = dfilter(v, class)
			return v, err
		end, "instance"),
	})
	return nil
end

GRAPH["instance"] = function(def: instance): {TypeDef}
	local types = table.create(#def.properties)
	for _, property in ipairs(def.properties) do
		if type(property) ~= "table" then
			continue
		end
		table.insert(types, property.value)
	end
	return types
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Parses *def*, generating instructions to be added to *state*. If *subr* is
-- true, then it indicates that a subroutine is being generated, and forces
-- instructions to be generated rather than calling the subroutine associated
-- with the definition.
function parseDef(def: TypeDef, state: CompileState, subr: boolean?): error
	if type(def) ~= "table" then
		return "type definition must be a table"
	end
	if def.type == "ptr" then
		for _, ptr in state.ptrs do
			if def == ptr then
				return "attempt to dereference a dereferenced pointer"
			end
		end
		table.insert(state.ptrs, def)
		if type(def.value) ~= "table" then
			return "referent must be a TypeDef"
		end
		local err = parseDef(def.value, state, subr)
		if err ~= nil then
			return err
		end
		table.remove(state.ptrs)
		return nil
	end

	if not subr and state.subr[def] then
		-- Definition has an associated subroutine, so call it instead of
		-- generating instructions directly. Parameters are resolved into actual
		-- addresses later.
		append(state, "SUBR", {decode=def, encode=def})
		return
	end

	local valueType = TYPES[def.type]
	if not valueType then
		return string.format("unknown type %q", tostring(def.type))
	end
	if def.hook ~= nil and type(def.hook) ~= "function" then
		return "hook must be a function"
	end
	local decode = def.decode
	if decode ~= nil and type(decode) ~= "function" and type(decode) ~= "table" then
		return "decode filter must be a function or table"
	end
	local encode = def.encode
	if encode ~= nil and type(encode) ~= "function" and type(encode) ~= "table" then
		return "encode filter must be a function or table"
	end
	local fields = table.clone(def)
	;(fields::any).decode = normalizeFilter(decode)
	;(fields::any).encode = normalizeFilter(encode)

	local hookaddr = prepareHook(state, fields.hook)
	local err = valueType(state, fields)
	if err ~= nil then
		return err
	end
	appendGlobal(state, def.global)
	setJump(state, hookaddr)
	return nil
end

-- Counts the number of times TypeDefs are traversed.
type Graph = {
	index: number, -- Used to determine the next index.
	map: {[TypeDef]: {
		index: number, -- Tracks traversal order so that subroutines are always generated in the same order.
		count: number, -- The number of times the mapped TypeDef is traversed.
	}},
	ptrs: {ptr}, -- Tracks dereferenced pointers so that self-references aren't counted more than once.
}

-- Traverse type definitions to build graph of definition usage.
local function buildGraph(graph: Graph, def: TypeDef)
	if def.type == "ptr" and type(def.value) == "table" then
		for _, ptr in graph.ptrs do
			if def == ptr then
				return
			end
		end
		table.insert(graph.ptrs, def)
		buildGraph(graph, def.value)
		table.remove(graph.ptrs)
	end
	if graph.map[def] then
		graph.map[def].count += 1
		return
	else
		local index = graph.index + 1
		graph.index = index
		graph.map[def] = {index=index, count=1}
	end
	local graphFunc = GRAPH[def.type]
	if graphFunc then
		for _, sub in graphFunc(def) do
			buildGraph(graph, sub)
		end
	end
end

-- Build list of TypeDefs for which subroutines will be generated. Only TypeDefs
-- that are used more than once are written as subroutines. Returns an ordered
-- list of TypeDefs that should be used as subroutines, followed by an unordered
-- set of TypeDefs that are subroutines.
local function buildSubroutines(graph: Graph): ({TypeDef}, {[TypeDef]:true})
	local subr: {TypeDef} = {}
	local is: {[TypeDef]:true} = {}
	for def, data in graph.map do
		if data.count > 1 then
			-- Insert def at index, retaining traversal order.
			subr[data.index] = def
			is[def] = true
		else
			-- Insert stub instead.
			subr[data.index] = false
		end
	end
	-- Filter out stubs.
	local i, n = 1, graph.index
	while i <= n do
		if subr[i] then
			i += 1
		else
			table.remove(subr, i)
			n -= 1
		end
	end
	-- List now contains only defs used more than once, sorted by traversal
	-- order.
	return subr, is
end

-- Generates section of instructions containing a subroutine for each given
-- definition.
local function generateSubroutines(state: CompileState, defs: {TypeDef}): (Subrs, error)
	if #defs == 0 then
		return {}, nil
	end
	-- Insert JMP instruction at start of program to jump over subroutines.
	local jumpaddr = prepareJump(state)
	local subrs = {}
	for _, def in defs do
		-- Remember addresses of subroutines.
		subrs[def] = #state.decode
		-- Generate subroutine body.
		local err = parseDef(def, state, true)
		if err then
			return subrs, err
		end
		append(state, "RET")
	end
	setJump(state, jumpaddr)
	return subrs, nil
end

-- SUBR parameters are stubbed with the TypeDef. Uses *subrs* to resolve into
-- actual addresses.
local function resolveSubroutineAddresses(state: CompileState, subrs: Subrs)
	for i = 1, #state.decode do
		local dinstr = state.decode[i]
		local einstr = state.encode[i]
		if dinstr.opcode == "SUBR" then
			local addr = assert(subrs[dinstr.param], "invalid decoder SUBR parameter")
			dinstr.param = addr
		end
		if einstr.opcode == "SUBR" then
			local addr = assert(subrs[einstr.param], "invalid encoder SUBR parameter")
			einstr.param = addr
		end
	end
end

--@sec: Codec
--@ord: -1
--@def: type Codec
--@doc: Codec contains instructions for encoding and decoding binary data.
local Codec = {__index={}}

export type Codec = {
	Decode: (self: Codec, buffer: string) -> (error, any),
	Encode: (self: Codec, data: any) -> (error, string),
	DecodeBuffer: (self: Codec, buffer: Buffer) -> (error, any),
	EncodeBuffer: (self: Codec, data: any, buffer: Buffer) -> (error, Buffer?),
}

--@sec: Binstruct.compile
--@ord: -1
--@def: Binstruct.compile(def: TypeDef): (err: error, codec: Codec)
--@doc: Returns a [Codec][Codec] compiled from the given definition.
function export.compile(def: TypeDef): (error, Codec?)
	assert(type(def) == "table", "table expected")

	local graph: Graph = {index=0, map={}, ptrs={}}
	buildGraph(graph, def)
	local subrs, issubr = buildSubroutines(graph)

	local state: CompileState = {
		decode = {},
		encode = {},
		subr = issubr,
		ptrs = {},
	}

	local subrs, err = generateSubroutines(state, subrs)
	if err ~= nil then
		return err, nil
	end

	local err = parseDef(def, state)
	if err ~= nil then
		return err, nil
	end

	resolveSubroutineAddresses(state, subrs)

	local self = {
		decode = state.decode,
		encode = state.encode,
	}
	return nil, setmetatable(self, Codec)::any
end

--@sec: Binstruct.mustCompile
--@ord: -1
--@def: Binstruct.mustCompile(def: TypeDef): Codec
--@doc: Returns a [Codec][Codec] compiled from the given definition. If an error
-- occurs, it is thrown.
function export.mustCompile(def: TypeDef): Codec
	local err, codec = export.compile(def)
	if err ~= nil then
		error(err, 2)
	end
	assert(codec, "missing codec")
	return codec
end

-- Transposes instruction definitions into opcodes per column.
local InstructionSets = {
	decode = {},
	encode = {},
}
for opcode, data in INSTRUCTION do
	InstructionSets.decode[opcode] = data.decode
	if type(data.encode) ~= "function" then
		InstructionSets.encode[opcode] = data.decode
	else
		InstructionSets.encode[opcode] = data.encode
	end
end

-- Executes the instructions of *program* using *instructions*. *buffer* is the
-- bit buffer to use. *data* is the data on which to operate.
local function execute(program: Program, instructions: {[Opcode]: InstructionFunc}, buffer: Buffer, data: any): (error, any)
	-- Initialize registers.
	local R = {
		PC = 1,
		BUFFER = buffer,
		GLOBAL = {},
		STACK = {},
		SUBR = {},
		F = {
			-- A table and key is required, so initialize as an array with one
			-- element.
			TABLE = {data},
			KEY = 1,
			N = 0,
			H = true,
		},
	}

	-- Execute the program.
	local err = nil
	local PN = #program
	while R.PC <= PN and err == nil do
		local instr = program[R.PC]
		local opcode = instr.opcode
		local exec = instructions[opcode]
		assert(exec, "unknown opcode")
		err = exec(R, instr.param)
		R.PC += 1
	end

	if err then
		-- Unwind stack to display index where the error occurred.
		local stack = table.create(#R.STACK-1)
		for i = 2, #R.STACK do
			stack[i-1] = "["..tostring(R.STACK[i].KEY).."]"
		end
		err = string.format("root%s: %s", table.concat(stack), err)
		return err, nil
	end

	return nil, R.F.TABLE[R.F.KEY]
end

--@sec: Codec.Decode
--@def: Codec:Decode(buffer: string): (error, any)
--@doc: Decode decodes a binary string into a value according to the codec.
-- Returns the decoded value.
function Codec.__index:Decode(buffer: string): (error, any)
	assert(type(buffer) == "string", "string expected")
	local buf = Bitbuf.fromString(buffer)
	return execute(self.decode, InstructionSets.decode, buf, nil)
end

--@sec: Codec.Encode
--@def: Codec:Encode(data: any): (error, string)
--@doc: Encode encodes a value into a binary string according to the codec.
-- Returns the encoded string.
function Codec.__index:Encode(data: any): (error, string)
	local buf = Bitbuf.new()
	local err = execute(self.encode, InstructionSets.encode, buf, data)
	if err then
		return err, ""
	end
	return nil, buf:String()
end

--@sec: Codec.DecodeBuffer
--@def: Codec:DecodeBuffer(buffer: Buffer): (error, any)
--@doc: DecodeBuffer decodes a binary string into a value according to the
-- codec. *buffer* is the buffer to read from. Returns the decoded value.
function Codec.__index:DecodeBuffer(buffer: Buffer): (error, any)
	return execute(self.decode, InstructionSets.decode, buffer, nil)
end

--@sec: Codec.EncodeBuffer
--@def: Codec:EncodeBuffer(data: any, buffer: Buffer?): (error, Buffer)
--@doc: EncodeBuffer encodes a value into a binary string according to the
-- codec. *buffer* is an optional Buffer to write to. Returns the Buffer with
-- the written data.
function Codec.__index:EncodeBuffer(data: any, buffer: Buffer): (error, Buffer?)
	local buf: Buffer
	if buffer == nil then
		buf = Bitbuf.new()
	else
		buf = buffer
	end
	local err, _ = execute(self.encode, InstructionSets.encode, buf, data)
	if err then
		return err, nil
	end
	return nil, buf
end

-- Human-readable representation of an instruction parameter.
local function formatArg(arg: any): string
	if type(arg) == "function" then
		return NAMEOF(arg)
	elseif type(arg) == "string" then
		return string.format("%q", arg)
	elseif type(arg) == "table" then
		local sorted = {}
		for k in arg do
			table.insert(sorted, k)
		end
		table.sort(sorted, function(a,b)
			return tostring(a) < tostring(b)
		end)
		local s = table.create(#sorted)
		for i, k in sorted do
			s[i] = k.."="..formatArg(arg[k])
		end
		return "{"..table.concat(s, ", ").."}"
	elseif arg == nil then
		return ""
	end
	return tostring(arg)
end

-- Returns a human-readable representation of the instructions of the codec.
function Codec.__index:Dump(): string
	local pn = #self.decode
	local rows = table.create(pn)
	local width = table.create(3, 0)
	for addr = 1, pn do
		local opcode = self.decode[addr].opcode
		local decode = self.decode[addr].param
		local encode = self.encode[addr].param
		local cols: {any} = {addr, opcode, decode, encode}
		if #cols[2] > width[1] then
			width[1] = #cols[2]
		end
		cols[3] = formatArg(cols[3])
		if #cols[3] > width[2] then
			width[2] = #cols[3]
		end
		cols[4] = formatArg(cols[4])
		if #cols[4] > width[3] then
			width[3] = #cols[4]
		end
		table.insert(rows, cols)
	end
	local fmt = "%0" .. math.ceil(math.log(pn+1, 10)) .. "d: " ..
		"%-" .. width[1] .. "s" ..
		" ( %-" .. width[2] .. "s" ..
		" | %-" .. width[3] .. "s" ..
		" )"
	local out = table.create(#rows)
	for i, cols in rows do
		out[i] = string.format(fmt, table.unpack(cols))
	end
	return table.concat(out, "\n")
end

return table.freeze(export)
