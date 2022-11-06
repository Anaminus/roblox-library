--!strict

--@sec: Binstruct
--@ord: -1
--@doc: Binstruct encodes and decodes binary structures.
--
-- Example:
-- ```lua
-- local Float = {"float", 32}
-- local String = {"string", 8}
-- local Vector3 = {"struct",
-- 	{"X" , Float},
-- 	{"Y" , Float},
-- 	{"Z" , Float},
-- }
-- local CFrame = {"struct",
-- 	{"Position" , Vector3},
-- 	{"Rotation" , {"array", 9, Float}},
-- }
-- local brick = {"struct",
-- 	{"Name"         , String},
-- 	{"CFrame"       , CFrame},
-- 	{"Size"         , Vector3},
-- 	{"Color"        , {"byte"}},
-- 	{"Reflectance"  , {"uint", 4}},
-- 	{"Transparency" , {"uint", 4}},
-- 	{"CanCollide"   , {"bool"}},
-- 	{"Shape"        , {"uint", 3}},
-- 	{"_"            , {"pad", 4}},
-- 	{"Material"     , {"uint", 6}},
-- 	{"_"            , {"pad", 2}},
-- }
--
-- local err, codec = Binstruct.new(brick)
-- if err ~= nil then
-- 	t:Fatalf(err)
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

--@sec: TypeDef
--@def: type TypeDef = {
-- 	encode = Filter?,
-- 	decode = Filter?,
-- 	hook   = Hook?,
-- 	[1]: string,
-- 	...,
-- }
--@doc: TypeDef is a table where the first element indicates a type that
-- determines the remaining structure of the table.
--
-- Additionally, the following optional named fields can be specified:
-- - `encode`: A filter that transforms a structural value before encoding.
-- - `decode`: A filter that transforms a structural value after decoding.
-- - `hook`: A function that determines whether the type should be used.
-- - `global`: A key that adds the type's value to a globally accessible table.
--
-- Within a decode filter, only the top-level value is structural; components of
-- the value will have already been transformed (if defined to do so). Likewise,
-- an encode filter should return a value that itself is structural, but
-- contains transformed components as expected by the component's type
-- definition. Each component's definition will eventually transform the
-- component itself, so the outer definition must avoid making transformations
-- on the component.
--
-- A hook indicates whether the type will be handled. If it returns true, then
-- the type is handled normally. If false is returned, then the type is skipped.
--
-- Specifying a global key causes the value of a non-skipped type to be assigned
-- to the global table, which may then be accessed by the remainder of the
-- codec. Values are assigned in the order they are traversed.
--
-- When a type encodes the value `nil`, the zero-value for the type is used.
--
-- The following types are defined:
--
--     {"pad", number}
--         Padding. Does not read or write any value (filters are ignored). The
--         parameter is the number of bits to pad with.
--
--     {"align", number}
--         Pad until the buffer is aligned to the number of bits indicated by
--         the parameter. Does not read or write any value (filters are
--         ignored).
--
--     {"const", any?}
--         A constant value. The parameter is the value. This type is neither
--         encoded nor decoded.
--
--     {"bool", number?}
--         A boolean. The parameter is *size*, or the number of bits used to
--         represent the value, defaulting to 1.
--
--         *size* is passed to filters as additional arguments.
--
--         The zero for this type is `false`.
--
--     {"int", number}
--         A signed integer. The parameter is *size*, or the number of bits used
--         to represent the value.
--
--         *size* is passed to filters as additional arguments.
--
--         The zero for this type is `0`.
--
--     {"uint", number}
--         An unsigned integer. The parameter is *size*, or the number of bits
--         used to represent the value.
--
--         *size* is passed to filters as additional arguments.
--
--         The zero for this type is `0`.
--
--     {"byte"}
--         Shorthand for `{"uint", 8}`.
--
--     {"float", number?}
--         A floating-point number. The parameter is *size*, or the number of
--         bits used to represent the value, and must be 32 or 64. Defaults to
--         64.
--
--         *size* is passed to filters as additional arguments.
--
--         The zero for this type is `0`.
--
--     {"fixed", number, number}
--         A signed fixed-point number. The first parameter is *i*, or the
--         number of bits used to represent the integer part. The second
--         parameter is *f*, or the number of bits used to represent the
--         fractional part.
--
--         *i* and *f* are passed to filters as additional arguments.
--
--         The zero for this type is `0`.
--
--     {"ufixed", number, number}
--         An unsigned fixed-point number. The first parameter is *i*, or the
--         number of bits used to represent the integer part. The second
--         parameter is *f*, or the number of bits used to represent the
--         fractional part.
--
--         *i* and *f* are passed to filters as additional arguments.
--
--         The zero for this type is `0`.
--
--     {"string", number}
--         A sequence of characters. Encoded as an unsigned integer indicating
--         the length of the string, followed by the raw bytes of the string.
--         The parameter is *size*, or the number of bits used to represent the
--         length.
--
--         *size* is passed to filters as additional arguments.
--
--         The zero for this type is the empty string.
--
--     {"union", ...TypeDef}
--
--         One of several types. Hooks can be used to select a single type.
--
--     {"struct", ...{any?, TypeDef}}
--         A set of named fields. Each parameter is a table defining a field of
--         the struct.
--
--         The first element of a field definition is the key used to index the
--         field. If nil, the value will be processed, but the field will not be
--         assigned to when decoding. When encoding, a `nil` value will be
--         received, so the zero-value of the field's type will be used.
--
--         The second element of a field definition is the type of the field.
--
--         A field definition may also specify a "hook" field, which is
--         described above. If the hook returns false, then the field is
--         skipped.
--
--         A field definition may also specify a "global" field, which is
--         described above. A non-nil global field assigns the field's value to
--         the specified global key.
--
--         The zero for this type is an empty struct.
--
--     {"array", number, TypeDef}
--         A constant-size list of unnamed fields.
--
--         The first parameter is the *size* of the array, indicating a constant
--         size.
--
--         The second parameter is the type of each element in the array.
--
--         *size* is passed to filters as additional arguments.
--
--         The zero for this type is an empty array.
--
--     {"vector", any, TypeDef, level: number?}
--         A dynamically sized list of unnamed fields.
--
--         The first parameter is the *size* of the vector, which indicates the
--         key of a field in the parent struct from which the size is
--         determined. Evaluates to 0 if this field cannot be determined or is a
--         non-number.
--
--         The second parameter is the type of each element in the vector.
--
--         If the *level* field is specified, then it indicates the ancestor
--         structure where *size* will be searched. If *level* is less than 1 or
--         greater than the number of ancestors, then *size* evaluates to 0.
--         Defaults to 1, indicating the parent structure.
--
--         *size* is passed to filters as additional arguments.
--
--         The zero for this type is an empty vector.
--
--     {"instance", string, ...{any?, TypeDef}}
--         A Roblox instance. The first parameter is *class*, or the name of a
--         Roblox class. Each remaining parameter is a table defining a property
--         of the instance.
--
--         The first element of a property definition is the name used to index
--         the property. If nil, the value will be processed, but the field will
--         not be assigned to when decoding. When encoding, a `nil` value will
--         be received, so the zero-value of the field's type will be used.
--
--         The second element of a property definition is the type of the
--         property.
--
--         *class* is passed to filters as additional arguments.
--
--         The zero for this type is a new instance of the class.

--@sec: Filter
--@def: type Filter = FilterFunc | FilterTable
--@doc: Filter applies to a TypeDef by transforming a value before encoding, or
-- after decoding.

--@sec: FilterFunc
--@def: type FilterFunc = (value: any?, params: ...any) -> (any?, error?)
--@doc: FilterFunc transforms *value* by using a function. The function should
-- return the transformed *value*.
--
-- The *params* received depend on the type, but are usually the elements of the
-- TypeDef.
--
-- A non-nil error causes the program to halt, returning the given value.

--@sec: FilterTable
--@def: type FilterTable = {[any] = any}
--@doc: FilterTable transforms a value by mapping the original value to the
-- transformed value.

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

local Bitbuf = require(script.Parent.Bitbuf)

export type error = any?

export type Buffer = Bitbuf.Buffer

type Table = {
	decode: Program,
	encode: Program,

	-- Track status of subroutines.
	-- - nil: Def does not have a subroutine. Instructions are generated
	--   unconditionally.
	-- - false: Def has subroutine that has not yet been generated. This will be
	--   observed during subroutine generation, causing instructions to be
	--   generated. Afterward, the state is set to true.
	-- - true: Def has subroutine that has been generated. Instead of generating
	--   instructions, a SUBR instruction is generated.
	_subr: {[TypeDef]:true?},
	-- Stack of pointers currently being dereferenced. Used to detect
	-- self-referencing pointers. An error is returned when trying to deference
	-- a pointer that is currently being deferenced.
	_ptrs: {ptr},
}
type Subrs = {[TypeDef]: Addr}
type Addr = number
type Program = {[Addr]: Instruction}

type Instruction = {
	opcode: string,
	param: any,
}

type Registers = {
	PC     : number,       -- Program counter.
	BUFFER : Buffer,       -- Bit buffer.
	GLOBAL : {[any]: any}, -- A general-purpose per-execution table.
	STACK  : {Frame},      -- Stores frames.
	SUBR   : {Addr},       -- Stores call return addresses.
	F      : Frame,        -- Current frame.
}

type Frame = {
	TABLE : {[any]: any}, -- The working table.
	KEY   : any,          -- A key pointing to a field in TABLE.
	N     : number,       -- Maximum counter value.
	H     : boolean,      -- Accumulated result of each hook.
}

type Field = {
	key: any?,
	value: TypeDef,
	hook: Hook?,
	global: any?,
}

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

export type Hook = (stack: (level: number)->any, global: {[any]:any}, h: boolean) -> (boolean, error)
export type Calc = (stack: (level: number)->any, global: {[any]:any}) -> (number, error)
export type Filter = FilterFunc | FilterTable
export type FilterFunc = (value: any?, ...any) -> (any?, error)
export type FilterTable = {[any]: any}

local export = {}

type insts = {
	decode: (Registers, ...any) -> error,
	encode: ((Registers, ...any)-> error)?,
}

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
-- Set of instructions. Each key is an opcode. Each value is a table, where the
-- "op" field indicates the value of the instruction op. The "decode" and
-- "encode" fields specify the columns of the instruction. Each column is a
-- function of the form `(registers, parameter): error`. If "encode" is a
-- non-function, then it is copied from "decode".
local INSTRUCTION: {[string]: insts} = {}

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
	decode = function(R: Registers, params: {addr:Addr, exitaddr:Addr, expr:Calc}): error
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
local TYPES: {[string]: (Table, any)->error} = {}

-- Maps a type to a function that recieves a TypeDef and returns a list of the
-- definition's inner types.
local GRAPH: {[string]: (any)->{TypeDef}} = {}

-- Appends to *list* the instruction corresponding to *opcode*. Each remaining
-- argument corresponds to an argument to be passed to the corresponding
-- instruction column. Returns the address of the appended instruction.
local function append(program: Table, opcode: string, columns: {decode:any, encode:any}?)
	if columns then
		table.insert(program.decode, {opcode=opcode, param=columns.decode})
		table.insert(program.encode, {opcode=opcode, param=columns.encode})
	else
		table.insert(program.decode, {opcode=opcode})
		table.insert(program.encode, {opcode=opcode})
	end
	return #program.decode
end

-- Sets the first element of each column of the instruction at *addr* to the
-- address of the the last instruction. Expects each column argument to be a
-- table.
local function setJump(program: Table, addr: Addr?)
	if addr ~= nil then
		program.decode[addr].param.addr = #program.decode
		program.encode[addr].param.addr = #program.encode
	end
end

local function setExitJump(program: Table, addr: Addr?)
	if addr ~= nil then
		program.decode[addr].param.exitaddr = #program.decode
		program.encode[addr].param.exitaddr = #program.encode
	end
end

local function prepareJump(program: Table): Addr
	return append(program, "JMP", {
		decode = {addr=nil},
		encode = {addr=nil},
	})
end

local function prepareHook(program: Table, hook: Hook?): Addr?
	if hook == nil then
		return nil
	end
	return append(program, "HOOK", {
		decode = {addr=nil, hook=hook},
		encode = {addr=nil, hook=hook},
	})
end

-- Prepare an expression instruction. Emits EXPR if expr is a Calc, or UXPR if
-- expr is true.
local function prepareExpr(program: Table, expr: Calc|true): Addr?
	if expr == true then
		return append(program, "UXPR", {
			decode = {exitaddr=nil},
			encode = {exitaddr=nil},
		})
	else
		return append(program, "EXPR", {
			decode = {addr=nil, exitaddr=nil, expr=expr},
			encode = {addr=nil, exitaddr=nil, expr=expr},
		})
	end
end

local function appendGlobal(program: Table, global: any?)
	if global == nil then
		return
	end
	append(program, "GLOBAL", {
		decode = global,
		encode = global,
	})
end

local function nop(v: any, ...): (any, error)
	return v, nil
end

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

-- Register a function with a name, for debugging.
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

export type ptr = {
	type: "ptr",
	value: TypeDef?,
}

function export.ptr(value: TypeDef?): ptr
	return {type="ptr", value=value}
end

export type pad = {
	type: "pad",
	size: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.pad(size: number): pad
	return {type="pad", size=size}
end

TYPES["pad"] = function(program: Table, def: pad): error
	local size = def.size
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end

	if not size or size <= 0 then
		return nil
	end
	append(program, "FIELD")
	append(program, "CALL", {
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

export type align = {
	type: "align",
	size: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.align(size: number): align
	return {type="align", size=size}
end

TYPES["align"] = function(program: Table, def: align): error
	local size = def.size
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end

	if not size or size <= 0 then
		return nil
	end
	append(program, "FIELD")
	append(program, "CALL", {
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

export type const = {
	type: "const",
	value: any?,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.const(value: any?): const
	return {type="const", value=value}
end

TYPES["const"] = function(program: Table, def: const): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local value = def.value

	append(program, "SET", {
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

export type bool = {
	type: "bool",
	size: number?,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.bool(size: number?): bool
	return {type="bool", size=size}
end

TYPES["bool"] = function(program: Table, def: bool): error
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

	append(program, "SET", {decode=decode, encode=encode})
	return nil
end

export type uint = {
	type: "uint",
	size: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.uint(size: number): uint
	return {type="uint", size=size}
end

TYPES["uint"] = function(program: Table, def: uint): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	if type(size) ~= "number" then
		return "size must be a number"
	end

	append(program, "SET", {
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

export type int = {
	type: "int",
	size: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.int(size: number): int
	return {type="int", size=size}
end

TYPES["int"] = function(program: Table, def: int): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	if type(size) ~= "number" then
		return "size must be a number"
	end

	append(program, "SET", {
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

export type byte = {
	type: "byte",

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.byte(): byte
	return {type="byte"}
end

TYPES["byte"] = function(program: Table, def: byte): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)

	append(program, "SET", {
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

export type float = {
	type: "float",
	size: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.float(size: number): float
	return {type="float", size=size}
end

TYPES["float"] = function(program: Table, def: float): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	if size ~= nil and type(size) ~= "number" then
		return "size must be a number or nil"
	end
	size = size or 64

	append(program, "SET", {
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

export type ufixed = {
	type: "ufixed",
	i: number,
	f: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.ufixed(i: number, f: number): ufixed
	return {type="ufixed", i=i, f=f}
end

TYPES["ufixed"] = function(program: Table, def: ufixed): error
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

	append(program, "SET", {
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

export type fixed = {
	type: "fixed",
	i: number,
	f: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.fixed(i: number, f: number): fixed
	return {type="fixed", i=i, f=f}
end

TYPES["fixed"] = function(program: Table, def: fixed): error
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

	append(program, "SET", {
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

export type str = {
	type: "str",
	size: number,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.str(size: number): str
	return {type="str", size=size}
end

TYPES["str"] = function(program: Table, def: str): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	if type(size) ~= "number" then
		return "size must be a number"
	end

	append(program, "SET", {
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

export type Clause = {
	expr: Calc|true,
	value: TypeDef?,
	global: any?,
}

export type union = {
	type: "union",
	clauses: {Clause},

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

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

TYPES["union"] = function(program: Table, def: union): error
	append(program, "PUSHS")
	local expraddrs = table.create(#def.clauses)
	for i, clause in ipairs(def.clauses) do
		if type(clause) ~= "table" then
			continue
		end
		if clause.expr ~= true and type(clause.expr) ~= "function" then
			return string.format("union[%d]: expr must be a function or true", i)
		end
		local expraddr = prepareExpr(program, clause.expr)
		table.insert(expraddrs, expraddr)
		if clause.value then
			local err = parseDef(clause.value, program)
			if err ~= nil then
				return string.format("union[%d]: %s", i, tostring(err))
			end
		end
		appendGlobal(program, clause.global)
		if clause.expr ~= true then
			setJump(program, expraddr)
		end
	end
	for _, expraddr in expraddrs do
		setExitJump(program, expraddr)
	end
	append(program, "POPS")
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

export type struct = {
	type: "struct",
	fields: {Field},

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.struct(...: any): struct
	return {type="struct", fields=fieldPairs(...)}
end

TYPES["struct"] = function(program: Table, def: struct): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)

	append(program, "PUSH", {
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

			local hookaddr = prepareHook(program, field.hook)
			append(program, "FIELD", {decode=key, encode=key})
			local err = parseDef(field.value, program)
			if err ~= nil then
				return string.format("field %q: %s", tostring(key), tostring(err))
			end
			appendGlobal(program, field.global)
			setJump(program, hookaddr)
		end
	end
	append(program, "POP", {
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

export type array = {
	type: "array",
	size: number|TypeDef,
	value: TypeDef,

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.array(size: number|TypeDef, value: TypeDef): array
	return {type="array", size=size, value=value}
end

TYPES["array"] = function(program: Table, def: array): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	local vtype = def.value
	if type(size) == "number" then
		if size <= 0 then
			-- Array is constantly empty.
			return nil
		end
		append(program, "PUSH", {
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
		local jumpaddr = append(program, "FORC", {decode=params, encode=params})
		local err = parseDef(vtype, program)
		if err ~= nil then
			return string.format("array[%d]: %s", size, tostring(err))
		end
		append(program, "JMPN", {decode=jumpaddr, encode=jumpaddr})
		setJump(program, jumpaddr)
		append(program, "POP", {
			decode = NAME(function(v: any): (any, error)
				local v, err = dfilter(v, size)
				return v, err
			end, "array"),
		})
	elseif type(size) == "table" then
		append(program, "PUSHN")
		local err = parseDef(size, program)
		if err ~= nil then
			return string.format("array[...]: size: %s", tostring(err))
		end
		append(program, "POPN")
		append(program, "PUSH", {
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
		local jumpaddr = append(program, "FOR", {decode=params, encode=params})
		local err = parseDef(vtype, program)
		if err ~= nil then
			return string.format("array[...]: value: %s", tostring(err))
		end
		append(program, "JMPN", {decode=jumpaddr, encode=jumpaddr})
		setJump(program, jumpaddr)
		append(program, "POP", {
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

function export.vector(size: any, value: TypeDef, level: number?): vector
	return {type="vector", size=size, value=value, level=level}
end

TYPES["vector"] = function(program: Table, def: vector): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local size = def.size
	local vtype = def.value
	if size == nil then
		return "vector size cannot be nil"
	end

	append(program, "PUSH", {
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
		jumpaddr = append(program, "FORX", {decode=params, encode=params})
	else
		local params = {addr=nil, size=size, level=level}
		jumpaddr = append(program, "FORF", {decode=params, encode=params})
	end
	local err = parseDef(vtype, program)
	if err ~= nil then
		return string.format("vector[%s]: %s", tostring(size), tostring(err))
	end
	append(program, "JMPN", {decode=jumpaddr, encode=jumpaddr})
	setJump(program, jumpaddr)
	append(program, "POP", {
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

export type instance = {
	type: "instance",
	class: string,
	properties: {Field},

	hook: Hook?,
	decode: Filter?,
	encode: Filter?,
	global: any?,
}

function export.instance(class: string, ...: any): instance
	return {type="instance", class=class, properties=fieldPairs(...)}
end

TYPES["instance"] = function(program: Table, def: instance): error
	local dfilter = normalizeFilter(def.decode)
	local efilter = normalizeFilter(def.encode)
	local class = def.class
	if type(class) ~= "string" then
		return "class must be a string"
	end

	append(program, "PUSH", {
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
			append(program, "FIELD", {decode=name, encode=name})
			local err = parseDef(property.value, program)
			if err ~= nil then
				return string.format("property %q: %s", tostring(name), tostring(err))
			end
		end
	end
	append(program, "POP", {
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

function parseDef(def: TypeDef, programTable: Table, subr: boolean?): error
	if type(def) ~= "table" then
		return "type definition must be a table"
	end
	if def.type == "ptr" then
		for _, ptr in programTable._ptrs do
			if def == ptr then
				return "attempt to dereference a dereferenced pointer"
			end
		end
		table.insert(programTable._ptrs, def)
		if type(def.value) ~= "table" then
			return "referent must be a TypeDef"
		end
		local err = parseDef(def.value, programTable, subr)
		if err ~= nil then
			return err
		end
		table.remove(programTable._ptrs)
		return nil
	end

	if not subr and programTable._subr[def] then
		-- Definition has an associated subroutine, so call it instead of
		-- generating instructions directly. Parameters are resolved into actual
		-- addresses later.
		append(programTable, "SUBR", {decode=def, encode=def})
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

	local hookaddr = prepareHook(programTable, fields.hook)
	local err = valueType(programTable, fields)
	if err ~= nil then
		return err
	end
	appendGlobal(programTable, def.global)
	setJump(programTable, hookaddr)
	return nil
end

-- Counts the number of times a TypeDef is traversed.
type Graph = {
	index: number,
	map: {[TypeDef]: {index: number, count: number}},
	ptrs: {ptr},
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

-- Build list of definitions for which subroutines will be generated.
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

local function generateSubroutines(programTable: Table, defs: {TypeDef}): (Subrs, error)
	if #defs == 0 then
		return {}, nil
	end
	-- Insert JMP instruction at start of program to jump over subroutines.
	local jumpaddr = prepareJump(programTable)
	local subrs = {}
	for _, def in defs do
		-- Remember addresses of subroutines.
		subrs[def] = #programTable.decode
		-- Generate subroutine body.
		local err = parseDef(def, programTable, true)
		if err then
			return subrs, err
		end
		append(programTable, "RET")
	end
	setJump(programTable, jumpaddr)
	return subrs, nil
end

-- SUBR parameters are stubbed with the TypeDef. Use *subrs* to resolve into
-- actual addresses.
local function resolveSubroutineAddresses(programTable: Table, subrs: Subrs)
	for i = 1, #programTable.decode do
		local dinstr = programTable.decode[i]
		local einstr = programTable.encode[i]
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
--@def: type Codec
--@doc: Codec contains instructions for encoding and decoding binary data.
local Codec = {__index={}}

export type Codec = typeof(Codec)

--@sec: Binstruct.new
--@def: Binstruct.new(def: TypeDef): (err: error, codec: Codec)
--@doc: new constructs a Codec from the given definition.
function export.new(def: TypeDef): (error, Codec?)
	assert(type(def) == "table", "table expected")

	local graph: Graph = {index=0, map={}, ptrs={}}
	buildGraph(graph, def)
	local subrs, issubr = buildSubroutines(graph)

	local programTable: Table = {
		decode = {},
		encode = {},
		_subr = issubr,
		_ptrs = {},
	}

	local subrs, err = generateSubroutines(programTable, subrs)
	if err ~= nil then
		return err, nil
	end

	local err = parseDef(def, programTable)
	if err ~= nil then
		return err, nil
	end
	programTable._subr = nil::any
	programTable._ptrs = nil::any

	resolveSubroutineAddresses(programTable, subrs)

	local self = {programTable = programTable}
	return nil, setmetatable(self, Codec)::any
end

local instructionSets = {
	decode = {},
	encode = {},
}
for opcode, data in INSTRUCTION do
	if type(data.encode) ~= "function" then
		data.encode = data.decode
	end
	local decode = data.decode
	local encode = data.encode
	if type(encode) ~= "function" then
		encode = decode
	end
	instructionSets.decode[opcode] = decode
	instructionSets.encode[opcode] = encode
end

-- Executes the instructions in *program*. *k* selects the instruction argument
-- column. *buffer* is the bit buffer to use. *data* is the data on which to
-- operate.
local function execute(pt: Table, k: "decode"|"encode", buffer: Buffer, data: any): (error, any)

	-- Registers.
	local R = {
		PC = 1,
		BUFFER = buffer,
		GLOBAL = {},
		STACK = {},
		SUBR = {},
		F = {
			TABLE = {data},
			KEY = 1,
			N = 0,
			H = true,
		},
	}

	local program = pt[k]
	local instructions = instructionSets[k]
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
	return execute(self.programTable, "decode", buf, nil)
end

--@sec: Codec.Encode
--@def: Codec:Encode(data: any): (error, string)
--@doc: Encode encodes a value into a binary string according to the codec.
-- Returns the encoded string.
function Codec.__index:Encode(data: any): (error, string)
	local buf = Bitbuf.new()
	local err = execute(self.programTable, "encode", buf, data)
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
	assert(Bitbuf.isBuffer(buffer), "buffer expected")
	return execute(self.programTable, "decode", buffer, nil)
end

--@sec: Codec.EncodeBuffer
--@def: Codec:EncodeBuffer(data: any, buffer: Buffer?): (error, Buffer)
--@doc: EncodeBuffer encodes a value into a binary string according to the
-- codec. *buffer* is an optional Buffer to write to. Returns the Buffer with
-- the written data.
function Codec.__index:EncodeBuffer(data: any, buffer: Buffer): (error, Buffer?)
	local buf
	if buffer == nil then
		buf = Bitbuf.new()
	elseif Bitbuf.isBuffer(buffer) then
		buf = buffer
	else
		error(string.format("Buffer expected, got %s", typeof(buffer)), 3)
	end
	local err, _ = execute(self.programTable, "encode", buf, data)
	if err then
		return err, nil
	end
	return nil, buf
end

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

-- Prints a human-readable representation of the instructions of the codec.
function Codec.__index:Dump(): string
	local pn = #self.programTable.decode
	local rows = table.create(pn)
	local width = table.create(3, 0)
	for addr = 1, pn do
		local opcode = self.programTable.decode[addr].opcode
		local decode = self.programTable.decode[addr].param
		local encode = self.programTable.encode[addr].param
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
