--@sec: Tag
--@ord: -1
--@doc: The Tag module enables the creation of instanceable symbol-like values.
--
-- There are 4 types of tags: [empty][EmptyTag], [static][StaticTag],
-- [class][ClassTag], and [instance][InstanceTag].
--
-- A tag can have multiple kinds. These kinds can be composed by adding or
-- subtracting tags from each other. There are several rules based on the types
-- of the operands:
-- - Adding EmptyTag with another tag returns the other tag.
--     - `Tag + Empty == Tag`
--     - `Empty + Tag == Tag`
-- - Adding StaticTags, ClassTags, and InstanceTags produces the union of the
--   kinds of the tags. The type of the result will be the operand type with the
--   highest priority (from highest to lowest): InstanceTag (also inherits the
--   key), ClassTag, StaticTag.
-- - Adding two InstanceTags throws an error.
-- - Subtracting EmptyTag from a tag returns that tag.
--     - `Tag - Empty == Tag`
-- - Subtracting a tag from EmptyTag returns EmptyTag.
--     - `Empty - Tag == Empty`
-- - Subtracting StaticTags, ClassTags, and InstanceTags produces the complement
--   of the kinds of the tags. The type of the result will the type of the left
--   operand (the key is inherited for InstanceTags).
-- - If the complement of the two operands is the empty set, then EmptyTag is
--   returned.
-- - Subtracting two InstanceTags throws an error.

local export = {}

-- Kind is a string representing a kind of tag. Must contain no null characters.
type Kind = string

-- Hash is a string hashed from a tag type, set of Kinds, and optional key
-- string.
--
-- Without key:
--
--     tKindA\0KindB\0etc
--
-- With key:
--
--     tKindA\0KindB\0etc\0\0Key
--
-- `t` is the tag type.
--
--    `s` for StaticTag.
--    `c` for ClassTag and InstanceTag.
type Hash = string

type Set = {[Kind]: boolean}

-- Returns union of two sets.
local function union(a: Set, b: Set): Set
	local c = {}
	for k in pairs(a) do
		c[k] = true
	end
	for k in pairs(b) do
		c[k] = true
	end
	return table.freeze(c)
end

-- Returns complement of sets a and b, and whether set is empty.
local function complement(a: Set, b: Set): (Set, boolean)
	local c = {}
	for k in pairs(a) do
		c[k] = true
	end
	for k in pairs(b) do
		c[k] = nil
	end
	return table.freeze(c), next(c) == nil
end

local function hash_kind(t: string, kind: Kind): Hash
	return t .. kind
end

local function hash_kinds(t: string, kinds: Set): string
	local hash = {}
	for k in pairs(kinds) do
		table.insert(hash, k)
	end
	table.sort(hash)
	return t .. table.concat(hash, "\0")
end

local function hash_kinds_key(t: string, kinds: Set, key: string): string
	local hash = {}
	for k in pairs(kinds) do
		table.insert(hash, k)
	end
	table.sort(hash)
	table.insert(hash, "")
	table.insert(hash, key)
	return t .. table.concat(hash, "\0")
end

local function hash_prekinds_key(kinds: Hash, key: string): Hash
	return kinds .. "\0\0" .. key
end

local modeV = {__mode="v"}
local modeK = {__mode="k"}

local _TAG = setmetatable({}, modeV) -- [hash] = tag
local _HASH = setmetatable({}, modeK) -- [tag] = hash
local _TYPE = setmetatable({}, modeK) -- [tag] = type
local _KINDS = setmetatable({}, modeK) -- [tag] = kind
local _KEY = setmetatable({}, modeK) -- [tag] = key

-- Populates the metatable of *proxy* with *template* by copying.
local function populate(proxy: any, template: {[any]: any}): Tag
	local mt = getmetatable(proxy)
	for k, v in pairs(template) do
		mt[k] = v
	end
	return proxy
end

-- Creates and initializes a new proxy value.
local function new(hash: string, template: {[any]: any}): any
	local self = _TAG[hash]
	if self then
		return self
	end
	self = newproxy(true)
	_TAG[hash] = self
	_HASH[self] = hash
	_TYPE[self] = template.__type
	return populate(self, template)
end

--@sec: Tag.typeof
--@ord: -1
--@def: Tag.typeof(value: any): string?
--@doc: The **typeof** function returns the type of the value as a string, or
-- nil if the value is not known by the module. Known types are
-- [EmptyTag][EmptyTag], [StaticTag][StaticTag], [ClassTag][ClassTag], and
-- [InstanceTag][InstanceTag].
function export.typeof(value: any): string?
	return _TYPE[value]
end

--@sec: EmptyTag
--@doc: The **EmptyTag** type is the tag with no kind. It is returned by
-- operations that produce the empty set of kinds.
local EmptyTag = {
	__type = "EmptyTag",
	__metatable = "The metatable is locked",
	__index = {},
}

--@sec: Tag.empty
--@ord: -1
--@def: Tag.empty: EmptyTag
--@doc: The **empty** constant contains the [empty tag][EmptyTag].
local Empty = newproxy(true)
_TYPE[Empty] = "EmptyTag"
export.empty = Empty

-- Returns a readable representation of the tag.
function EmptyTag:__tostring(): string
	return "EmptyTag"
end

--@sec: EmptyTag.Is
--@ord: -1
--@def: EmptyTag:Is(tag: Tag): boolean
--@doc: The **Is** method returns true only if *tag* is EmptyTag.
function EmptyTag.__index:Is(tag: Tag): boolean
	return tag == self
end

--@sec: EmptyTag.Has
--@ord: -1
--@def: EmptyTag:Has(tag: Tag): boolean
--@doc: The **Has** method returns true only if *tag* is EmptyTag.
function EmptyTag.__index:Has(tag: Tag): boolean
	return tag == self
end

-- Converts a Set to a string with ordered elements.
local function list_kinds(kinds: Set): string
	local list = {}
	for kind in pairs(kinds) do
		table.insert(list, kind)
	end
	table.sort(list)
	return table.concat(list, ",")
end

--@sec: StaticTag
--@doc: The **StaticTag** type is a tag that cannot be instanced.
local StaticTag = {
	__type = "StaticTag",
	__metatable = "The metatable is locked",
	__index = {},
}

--@sec: Tag.static
--@ord: -1
--@def: Tag.static(kind: string): StaticTag
--@doc: The **static** constructor returns a [static tag][StaticTag] with *kind*
-- as the kind. *kind* must not contain null characters.
function export.static(kind: string): StaticTag
	assert(type(kind) == "string", "tag kind must be a string")
	assert(not string.match(kind, "\0"), "tag kind must not contain null characters")
	local self = new(hash_kind("s", kind), StaticTag)
	_KINDS[self] = table.freeze({[kind]=true})
	return self
end

-- Returns a readable representation of the tag.
function StaticTag:__tostring(): string
	return "StaticTag<" .. list_kinds(_KINDS[self]) .. ">"
end

--@sec: StaticTag.Is
--@ord: -1
--@def: StaticTag:Is(tag: Tag): boolean
--@doc: The **Is** method returns true if the tag has all kinds from *tag*.
function StaticTag.__index:Is(tag: Tag): boolean
	if not _KINDS[tag] then
		return false
	end
	local kinds = _KINDS[self]
	for kind in pairs(_KINDS[tag]) do
		if not kinds[kind] then
			return false
		end
	end
	return true
end

--@sec: StaticTag.Has
--@ord: -1
--@def: StaticTag:Has(tag: Tag): boolean
--@doc: The **Has** method returns true if the tag has any kind from *tag*.
function StaticTag.__index:Has(tag: Tag): boolean
	if not _KINDS[tag] then
		return false
	end
	local kinds = _KINDS[self]
	for kind in pairs(_KINDS[tag]) do
		if kinds[kind] then
			return true
		end
	end
	return false
end

--@sec: ClassTag
--@doc: The **ClassTag** type is a tag of which
-- [instances][InstanceTag] can be [created][ClassTag.__call].
local ClassTag = {
	__type = "ClassTag",
	__metatable = "The metatable is locked",
	__index = {},
}

--@sec: Tag.class
--@ord: -1
--@def: Tag.class(kind: string): ClassTag
--@doc: The **class** constructor returns a [class tag][ClassTag] with *kind* as
--the kind. *kind* must not contain null characters.
function export.class(kind: string): ClassTag
	assert(type(kind) == "string", "tag kind must be a string")
	assert(not string.match(kind, "\0"), "tag kind must not contain null characters")
	local self = new(hash_kind("c", kind), ClassTag)
	_KINDS[self] = table.freeze({[kind]=true})
	return self
end

-- Returns a readable representation of the tag.
function ClassTag:__tostring(): string
	return "ClassTag<" .. list_kinds(_KINDS[self]) .. ">"
end

--@sec: ClassTag.Is
--@ord: -1
--@def: ClassTag:Is(tag: Tag): boolean
--@doc: The **Is** method returns true if the tag is all kinds from *tag*.
function ClassTag.__index:Is(tag: Tag): boolean
	if not _KINDS[tag] then
		return false
	end
	local kinds = _KINDS[self]
	for kind in pairs(_KINDS[tag]) do
		if not kinds[kind] then
			return false
		end
	end
	return true
end

--@sec: ClassTag.Has
--@ord: -1
--@def: ClassTag:Has(tag: Tag): boolean
--@doc: The **Has** method returns true if the tag has any kind from *tag*.
function ClassTag.__index:Has(tag: Tag): boolean
	if not _KINDS[tag] then
		return false
	end
	local kinds = _KINDS[self]
	for kind in pairs(_KINDS[tag]) do
		if kinds[kind] then
			return true
		end
	end
	return false
end

--@sec: InstanceTag
--@doc: The **InstanceTag** type is a tag that is the instance of a [class
-- tag][ClassTag]. Instances have a "key", which is an arbitrary string.
local InstanceTag = {
	__type = "InstanceTag",
	__metatable = "The metatable is locked",
	__index = {},
}

--@sec: ClassTag.__call
--@def: ClassTag(key: string): InstanceTag
--@doc: Calling a ClassTag returns an [instance][InstanceTag] of the tag with
-- *key* as the key.
function ClassTag:__call(key: string): InstanceTag
	assert(type(key) == "string", "key must be a string")
	local instance = new(hash_prekinds_key(_HASH[self], key), InstanceTag)
	_KINDS[instance] = _KINDS[self]
	_KEY[instance] = key
	return instance
end

-- Returns a readable representation of the tag.
function InstanceTag:__tostring(): string
	return string.format("InstanceTag<%s> %q", list_kinds(_KINDS[self]), _KEY[self])
end

--@sec: InstanceTag.Is
--@ord: -1
--@def: InstanceTag:Is(tag: Tag): boolean
--@doc: The **Is** method returns true if the tag has all kinds from *tag*.
function InstanceTag.__index:Is(tag: Tag): boolean
	if not _KINDS[tag] then
		return false
	end
	local kinds = _KINDS[self]
	for kind in pairs(_KINDS[tag]) do
		if not kinds[kind] then
			return false
		end
	end
	return true
end

--@sec: InstanceTag.Has
--@ord: -1
--@def: InstanceTag:Has(tag: Tag): boolean
--@doc: The **Has** method returns true if the tag has any kind from *tag*.
function InstanceTag.__index:Has(tag: Tag): boolean
	if not _KINDS[tag] then
		return false
	end
	local kinds = _KINDS[self]
	for kind in pairs(_KINDS[tag]) do
		if kinds[kind] then
			return true
		end
	end
	return false
end

--@sec: InstanceTag.Key
--@def: InstanceTag:Key(): string
--@doc: The **Key** method returns the key of the instance.
function InstanceTag.__index:Key(): string
	return _KEY[self]
end

local function add_static(a, b)
	local kinds = union(_KINDS[a], _KINDS[b])
	local tag = new(hash_kinds("s", kinds), StaticTag)
	_KINDS[tag] = kinds
	return tag
end

local function add_class(a, b)
	local kinds = union(_KINDS[a], _KINDS[b])
	local tag = new(hash_kinds("c", kinds), ClassTag)
	_KINDS[tag] = kinds
	return tag
end

local function add_instance(a, b)
	local kinds = union(_KINDS[a], _KINDS[b])
	local key = _KEY[a]
	local tag = new(hash_kinds_key("c", kinds, key), InstanceTag)
	_KINDS[tag] = kinds
	_KEY[tag] = key
	return tag
end

local function add_tags(a: Tag, b: Tag): Tag
	local ta = _TYPE[a]
	local tb = _TYPE[b]
	if ta == "EmptyTag" then
		if tb == "EmptyTag" then
			return Empty
		elseif tb == "StaticTag" or
			tb == "ClassTag" or
			tb == "InstanceTag" then
			return b
		else
			error("addition of tag and non-tag", 2)
		end
	elseif ta == "StaticTag" then
		if tb == "EmptyTag" then
			return a
		elseif tb == "StaticTag" then
			return add_static(a, b)
		elseif tb == "ClassTag" then
			return add_class(a, b)
		elseif tb == "InstanceTag" then
			return add_instance(b, a)
		else
			error("addition of tag and non-tag", 2)
		end
	elseif ta == "ClassTag" then
		if tb == "EmptyTag" then
			return a
		elseif tb == "StaticTag" then
			return add_class(a, b)
		elseif tb == "ClassTag" then
			return add_class(a, b)
		elseif tb == "InstanceTag" then
			return add_instance(b, a)
		else
			error("addition of tag and non-tag", 2)
		end
	elseif ta == "InstanceTag" then
		if tb == "EmptyTag" then
			return a
		elseif tb == "StaticTag" then
			return add_instance(a, b)
		elseif tb == "ClassTag" then
			return add_instance(a, b)
		elseif tb == "InstanceTag" then
			error("addition of InstanceTag and InstanceTag", 2)
		else
			error("addition of tag and non-tag", 2)
		end
	else
		error("addition of non-tag and tag", 2)
	end
end

local function sub_static(a, b)
	local kinds, empty = complement(_KINDS[a], _KINDS[b])
	if empty then
		return Empty
	end
	local tag = new(hash_kinds("s", kinds), StaticTag)
	_KINDS[tag] = kinds
	return tag
end

local function sub_class(a, b)
	local kinds, empty = complement(_KINDS[a], _KINDS[b])
	if empty then
		return Empty
	end
	local tag = new(hash_kinds("c", kinds), ClassTag)
	_KINDS[tag] = kinds
	return tag
end

local function sub_instance(a, b)
	local kinds, empty = complement(_KINDS[a], _KINDS[b])
	if empty then
		return Empty
	end
	local key = _KEY[a]
	local tag = new(hash_kinds_key("c", kinds, key), InstanceTag)
	_KINDS[tag] = kinds
	_KEY[tag] = key
	return tag
end

local function sub_tags(a: Tag, b: Tag): Tag
	local ta = _TYPE[a]
	local tb = _TYPE[b]
	if ta == "EmptyTag" then
		if tb == "EmptyTag" or
			tb == "StaticTag" or
			tb == "ClassTag" or
			tb == "InstanceTag" then
			return Empty
		else
			error("subtraction of tag and non-tag", 2)
		end
	elseif ta == "StaticTag" then
		if tb == "EmptyTag" then
			return a
		elseif tb == "StaticTag" or
			tb == "ClassTag" or
			tb == "InstanceTag" then
				return sub_static(a, b)
		else
			error("subtraction of tag and non-tag", 2)
		end
	elseif ta == "ClassTag" then
		if tb == "EmptyTag" then
			return a
		elseif tb == "StaticTag" or
			tb == "ClassTag" or
			tb == "InstanceTag" then
			return sub_class(a, b)
		else
			error("subtraction of tag and non-tag", 2)
		end
	elseif ta == "InstanceTag" then
		if tb == "EmptyTag" then
			return a
		elseif tb == "StaticTag" or
			tb == "ClassTag" then
			return sub_instance(a, b)
		elseif tb == "InstanceTag" then
			error("subtraction of InstanceTag and InstanceTag", 2)
		else
			error("subtraction of tag and non-tag", 2)
		end
	else
		error("subtraction of non-tag and tag", 2)
	end
end

EmptyTag.__add = add_tags
EmptyTag.__sub = sub_tags
populate(Empty, EmptyTag)

StaticTag.__add = add_tags
StaticTag.__sub = sub_tags

ClassTag.__add = add_tags
ClassTag.__sub = sub_tags

InstanceTag.__add = add_tags
InstanceTag.__sub = sub_tags

export type Tag = typeof(setmetatable({
	Is = function(self: Tag, tag: Tag): boolean return false end,
	has = function(self: Tag, tag: Tag): boolean return false end,
}, {
	__add = function(a: Tag, b: Tag): Tag return Empty end,
	__sub = function(a: Tag, b: Tag): Tag return Empty end,
}))

export type EmptyTag = typeof(Empty)
export type StaticTag = typeof(populate(newproxy(true), StaticTag))
export type ClassTag = typeof(populate(newproxy(true), ClassTag))
export type InstanceTag = typeof(populate(newproxy(true), InstanceTag))

return table.freeze(export)
