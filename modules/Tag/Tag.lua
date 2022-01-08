--@sec: Tag
--@ord: -1
--@doc: The Tag module enables the creation of instanceable symbol-like values.
--
-- There are 3 types of tags: [static][StaticTag], [class][ClassTag] and
-- [instance][InstanceTag].
local export = {}

local modeV = {__mode="v"}
local modeK = {__mode="k"}

local _TAG = setmetatable({}, modeV) -- [hash] = tag
local _HASH = setmetatable({}, modeK) -- [tag] = hash
local _TYPE = setmetatable({}, modeK) -- [tag] = type
local _KIND = setmetatable({}, modeK) -- [tag] = kind
local _KEY = setmetatable({}, modeK) -- [tag] = key

-- Populates the metatable of *proxy* with *template* by copying.
local function populate(proxy: any, template: {[any]: any}): any
	local mt = getmetatable(proxy)
	for k, v in pairs(template) do
		mt[k] = v
	end
	return proxy
end

-- Creates and initializes a new proxy value.
local function new(hash: string, type: string, template: {[any]: any}): any
	local self = _TAG[hash]
	if self then
		return self
	end
	self = newproxy(true)
	_TAG[hash] = self
	_HASH[self] = hash
	_TYPE[self] = type
	return populate(self, template)
end

--@sec: Tag.typeof
--@ord: -1
--@def: Tag.typeof(value: any): string?
--@doc: The **typeof** function returns the type of the value as a string, or
-- nil if the value is not known by the module. Known types are
-- [StaticTag][StaticTag], [ClassTag][ClassTag], and [InstanceTag][InstanceTag].
local function typeof(value: any): string?
	return _TYPE[value]
end
export.typeof = typeof

--@sec: StaticTag
--@doc: The **StaticTag** type is a tag with only a kind.
local StaticTag = {__index={}}

--@sec: Tag.static
--@ord: -1
--@def: Tag.static(kind: string): StaticTag
--@doc: The **static** constructor returns a [static tag][StaticTag] with *kind*
-- as the kind. *kind* must not contain null characters.
function export.static(kind: string): StaticTag
	assert(type(kind) == "string", "tag kind must be a string")
	assert(not string.match(kind, "\0"), "tag kind must not contain null characters")
	local self = new(kind, "StaticTag", StaticTag)
	_KIND[self] = kind
	return self
end

-- Returns a readable representation of the tag.
function StaticTag:__tostring(): string
	return "StaticTag<" .. _KIND[self] .. ">"
end

--@sec: StaticTag.Kind
--@def: StaticTag:Kind(): string
--@doc: The **Kind** method returns the kind of the tag.
function StaticTag.__index:Kind(): string
	return _KIND[self]
end

--@sec: ClassTag
--@doc: The **ClassTag** type is a tag of which
-- [instances][InstanceTag] can be [created][ClassTag.__call].
local ClassTag = {__index={}}

--@sec: Tag.class
--@ord: -1
--@def: Tag.class(kind: string): ClassTag
--@doc: The **class** constructor returns a [class tag][ClassTag] with *kind* as
--the kind. *kind* must not contain null characters.
function export.class(kind: string): ClassTag
	assert(type(kind) == "string", "tag kind must be a string")
	assert(not string.match(kind, "\0"), "tag kind must not contain null characters")
	local self = new(kind, "ClassTag", ClassTag)
	_KIND[self] = kind
	return self
end

-- Returns a readable representation of the tag.
function ClassTag:__tostring(): string
	return "ClassTag<" .. _KIND[self] .. ">"
end

--@sec: ClassTag.Kind
--@def: ClassTag:Kind(): string
--@doc: The **Kind** method returns the kind of the tag.
function ClassTag.__index:Kind(): string
	return _KIND[self]
end

--@sec: ClassTag.Has
--@def: ClassTag:Has(): string
--@doc: The **Has** method returns whether *tag* is an instance of the tag.
function ClassTag.__index:Has(tag: InstanceTag): boolean
	return _TYPE[tag] == "InstanceTag" and _KIND[tag] == _KIND[self]
end

--@sec: InstanceTag
--@doc: The **InstanceTag** type is a tag that is the instance of a [class
-- tag][ClassTag].
local InstanceTag = {__index={}}

--@sec: ClassTag.__call
--@def: ClassTag(key: string): InstanceTag
--@doc: Calling a ClassTag returns an [instance][InstanceTag] of the tag with
-- *key* as the key.
function ClassTag:__call(key: string): InstanceTag
	assert(type(key) == "string", "key must be a string")
	local instance = new(_KIND[self].."\0"..key, "InstanceTag", InstanceTag)
	_KIND[instance] = _KIND[self]
	_KEY[instance] = key
	return instance
end

-- Returns a readable representation of the tag.
function InstanceTag:__tostring(): string
	return string.format("InstanceTag<%s> %q", _KIND[self], _KEY[self])
end

--@sec: InstanceTag.Kind
--@def: InstanceTag:Kind(): string
--@doc: The **Kind** method returns the kind of the tag.
function InstanceTag.__index:Kind(): string
	return _KIND[self]
end

--@sec: InstanceTag.IsA
--@def: InstanceTag:IsA(): string
--@doc: The **IsA** method returns whether the tag is an instance of *tag*.
function InstanceTag.__index:IsA(tag: ClassTag): boolean
	return _TYPE[tag] == "ClassTag" and _KIND[self] == _KIND[tag]
end

--@sec: InstanceTag.Key
--@def: InstanceTag:Key(): string
--@doc: The **Key** method returns the key of the instance.
function InstanceTag.__index:Key(): string
	return _KEY[self]
end

export type StaticTag = typeof(populate(newproxy(true), StaticTag))
export type ClassTag = typeof(populate(newproxy(true), ClassTag))
export type InstanceTag = typeof(populate(newproxy(true), InstanceTag))

return export
