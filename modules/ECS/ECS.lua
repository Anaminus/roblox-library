--[[
ECS

	An implementation of the entity-component-system pattern.

SYNOPSIS

	local world = ECS.NewWorld()

	world:DefineComponent("Component", 0)
	world:DefineEntity("Entity", {Component=true})
	world:DefineSystem("System", {"Component"}, function(entities)
		for _, e in ipairs(entities) do
			e.Component = e.Component + 1
			if e.Component >= 100 then
				world:DestroyEntity(e[1])
			end
		end
	end)

	world:Init()

	local id = world:CreateEntity("Entity")
	print(world:Get(id, "Component"))
	world:Set(id, "Component", 42)
	print(world:Has(id))
	print(world:Has(id, "Component"))

	local handle = world:Handle(id)
	print(handle.Component)
	handle.Component = 42
	print(handle())
	print(handle("Component"))

	while world:Has(id) do
		world:Update("System")
		world:Upkeep()
	end

DESCRIPTION

	All entities, components, and systems live within a "World". A new world can
	be created with the NewWorld function.

		local world = ECS.NewWorld()

	A newly created world starts out in a "definition mode". At this point, all
	the items of the world are defined using the DefineComponent, DefineEntity,
	and DefineSystem methods.

	----

	DefineComponent defines a component by assigning a name to an initializer.

		world:DefineComponent("Position", initializer)

	The initializer determines the initial value of the component, which can be
	any value except nil.

		world:DefineComponent("Health", 100)
		world:DefineComponent("PlayerInput", game:GetService("UserInputService"))

	If the initializer is a table, it is deep-copied when a new entity is
	created.

		world:DefineComponent("Physics", {
			Position = Vector3.new(0, 0, 0),
			Velocity = Vector3.new(0, 0, 0),
			Speed = 16,
		})

	If the initializer is a function, its return value will become the initial
	value. The function receives arguments that can be used configure the value
	dynamically.

		world:DefineComponent("Physics", function(x, y, z, speed)
			return {
				Position = Vector3.new(x, y, z),
				Velocity = Vector3.new(0, 0, 0),
				Speed = speed,
			}
		end)

	----

	DefineEntity defines an entity *type*, which assigns a name to a set of
	components. Later, actual entities can be created from this entity type.

		world:DefineEntity("Hero", initializer)

	The initializer determines the components of the entity. It is a table that
	maps a component name to a configuration. If a value is a table, that table
	is unpacked and passed as arguments to the component's initializer function,
	if it has one.

		world:DefineEntity("Hero", {
			Physics = {10, 0, 0, 16}, -- x, y, z, speed
		})

	If the component does not need to be configured, or if the configuration can
	be ignored, a boolean can be used instead.

		world:DefineEntity("Hero", {
			Physics = {10, 0, 0, 16},
			Health = true,
		})

	Similar to DefineComponent, the initializer can instead be a function that
	returns the components, allowing them to be configured dynamically. Extra
	arguments passed to CreateEntity are passed to the initializer.

		world:DefineEntity("Hero", function(x, y, z)
			return {
				Physics = {x, y, z, 16},
				Health = true,
				PlayerInput = true,
			}
		end)

		world:DefineEntity("Monster", function(x, y, z)
			return {
				Physics = {x, y, z, 12},
				Health = true,
			}
		end)

	Note that the initializer function *must* return components consistently.
	That is, each key in the returned table must be the same between calls,
	regardless of the received arguments. The values of the keys do not matter,
	as long as they are truthy.

	----

	DefineSystem defines a system by associating a name to a number of
	components, and updater function. The updater receives a list of entities to
	traverse, as well as the extra arguments passed to the Update method.

		world:DefineSystem("Physics",
			{"Physics"},
			function(entities, deltaTime)
				for _, e in ipairs(entities) do
					local phy = e.Physics

					local gravity = Vector3.new(0, -9.81, 0)
					phy.Velocity = phy.Velocity + gravity*deltaTime

					local pos = phy.Position + phy.Velocity*deltaTime
					local inGround = pos.Y < 0
					if inGround then
						pos = pos * Vector3.new(1, 0, 1)
					end
					phy.Position = pos
				end
			end,
		)

	When the system is updated, only the entities that have all the specified
	components are passed to the updater function.

		world:DefineSystem("Input",
			{"Physics", "PlayerInput"},
			function(entities, deltaTime)
				for _, e in ipairs(entities) do
					local jump = e.PlayerInput:IsKeyDown(Enum.KeyCode.Space)
					local canJump = e.Physics.Position.Y <= 1e6
					if canJump and jump then
						e.Physics.Velocity = e.Physics.Velocity + Vector3.new(0, 50, 0)
					end
				end
			end,
		)

	----

	Once the world is defined, it is initialized with the Init method. This
	ensures that all definitions are valid, and prepares some optimizations.

		world:Init()

	Once initialized, entities can be created, and systems can be updated.

	----

	A new entity is created with the CreateEntity method. The first argument is
	the name of the entity type, and the remaining arguments are passed to the
	entity type's initializer, if it exists. CreateEntity returns a value that
	identifies the entity.

		local hero = world:CreateEntity("Hero", 10, 0, 0)
		local monster = world:CreateEntity("Monster", -10, 0, 0)

	----

	Systems are updated using the Update method. The first argument is the name
	of the system to update, and the remaining arguments are passed to the
	system's updater function.

	The Upkeep method performs maintenance to keep things clean. This should
	usually be called at the end of an update loop.

		RunService:BindToRenderStepped("Update", 0, function(deltaTime)
			world:Update("Input", deltaTime)
			world:Update("Physics", deltaTime)
			world:Upkeep()
		end)

	----

	Entities can be destroyed with the DestroyEntity method. The first argument
	is the identifier of the entity to destroy.

		world:DestroyEntity(monster)

	Note that this does not destroy the entity immediately. Instead, the
	destruction is deferred until the Upkeep method is called.

	----

	The state of an entity can be accessed through the Has, Get, and Set
	methods.

	Has returns whether an entity exists, or whether an entity has a component.

		print(world:Has(hero))                   --> true
		print(world:Has(monster))                --> false

		print(world:Has(hero, "Health"))         --> true
		print(world:Has(monster, "PlayerInput")) --> false

	Get returns the value of an entity's component, or nil if it does not exist.

		print(world:Get(hero, "Health"))    --> 100
		print(world:Get(monster, "Health")) --> nil

	Set sets the value of an entity's component, and returns whether it
	succeeded.

		print(world:Set(hero, "Health", 50))    --> true
		print(world:Set(monster, "Health", 50)) --> false

	Using Set from within a system should be avoided. Instead, a system should
	be created to update the value directly.

	----

	For convenience, the Handle method creates an object-like interface to an
	entity. The entity may or may not exist.

		local handle = world:Handle(hero)
		print(handle())                   --> true
		print(handle("Health"))           --> true
		print(handle.Health)              --> 100
		handle.Health = 50                --> (okay)

		local handle = world:Handle(monster)
		print(handle())                   --> false
		print(handle("Health"))           --> false
		print(handle.Health)              --> nil
		handle.Health = 50                --> (does nothing)

	Handles should be used only for interfacing with external code outside the
	world.

API

	-- Name is a string that must be a valid Lua identifier.
	type Name = string

	-- NewWorld returns a new World.
	function ECS.NewWorld(): World

	-- World is a collection of entities, components, and systems.
	type World

	-- DefineSystem defines a system in the world.
	--
	-- *name* is the name of the system, which must be unique.
	--
	-- *components* is a list of names of the components that the system applies
	-- to. These components do not need to be defined until the world is
	-- initialized.
	--
	-- *update* is the function called when the system updates.
	--
	-- Throws an error after the world is initialized.
	function World:DefineSystem(name: Name, components: Array<string>, update: Updater)

	-- Updater is passed to World.DefineSystem, and is called when the
	-- associated system updates.
	--
	-- *entities* is the unordered list of entities to be traversed by the
	-- system. *entities* and its content must not be retained.
	--
	-- *args* are the arguments that were passed to the World.Update function.
	type Updater = function(entities: Array<Entity>, args: ...any)

	-- Entity represents the state of a single entity.
	type Entity = {

		-- The entity's identifier.
		[1]: ID,

		-- Maps a component name to the component's value.
		[Name]: any,
	}

	-- ID uniquely identifies an entity in a particular World. It is valid for
	-- the ID to be passed to methods of the world in which the entity was
	-- created. It is also valid for the ID to be compared for equality with
	-- another ID created in the same World.
	type ID = _entity_id_

	-- DefineComponent defines a component in the world.
	--
	-- *name* is the name of the component, which must be unique.
	--
	-- *def* is the definition of the component's value. If the value is a
	-- table, then it is deep-copied when initialized. Keys are not copied, and
	-- the table is assumed to be non-circular. The metatable is also matched,
	-- if possible.
	--
	-- *def* cannot be nil. To create a nil value, use a DynComponentDef that
	-- returns nil.
	--
	-- Throws an error after the world is initialized.
	function World:DefineComponent(name: Name, def: DynComponentDef|ComponentDef)

	-- ComponentDef determines the value of a component.
	type ComponentDef = any

	-- DynComponentDef defines the value of a component dynamically.
	--
	-- *args* are the arguments received from an EntityDef, and are used to
	-- initialize the returned value. The returned value must not be retained.
	type DynComponentDef = function(args: ...any): (component: ComponentDef)

	-- DefineEntity defines an entity type in the world. An entity type
	-- predeclares the components of an entity, enabling optimized entity
	-- creation and traversal.
	--
	-- *name* is the name of the entity type, which must be unique.
	--
	-- *def* is the definition of the entity type's components.
	--
	-- Throws an error after the world is initialized.
	function World:DefineEntity(name: Name, def: DynEntityDef|EntityDef)

	-- EntityDef defines and initializes the components of an entity type.
	--
	-- Each key specifies the name of a component. These components do not need
	-- to be defined until the world is initialized.
	--
	-- Each value is a packed list of arguments to be passed to the component's
	-- DynComponentDef, if possible. The value may also be a boolean, which can
	-- be used if the component is not initialized dynamically, or if no
	-- arguments need to be passed. A value of false causes the component to
	-- *not* be defined.
	type EntityDef = Dictionary<string, ({[number]: any, n: number?}|boolean)>

	-- DynEntityDef defines the components of an entity type and initializes the
	-- components dynamically.
	--
	-- *args* are received from World.CreateEntity, and are used to initialize
	-- the values to be passed to a component's DynComponentDef.
	--
	-- The components of the returned EntityDef must be consistent between
	-- calls, regardless of the arguments passed. The returned value must not be
	-- retained.
	type DynEntityDef = function(args: ...any): (entity: EntityDef)

	-- Init initializes the world. After initialization, entity types,
	-- components, and systems can no longer be defined, entities can be created
	-- an destroyed, and systems can be updated.
	--
	-- Throws an error if the world was already initialized.
	function World:Init()

	-- CreateEntity creates a new entity in the world.
	--
	-- *name* is the name of a defined entity type.
	--
	-- *args* are the arguments to be passed to the entity type's DynEntityDef,
	-- if possible.
	--
	-- Returns an ID that uniquely identifies the entity.
	--
	-- Throws an error before the world is initialized.
	function World:CreateEntity(name: Name, args: ...any): (entity: ID)

	-- Update updates a system.
	--
	-- *system* is the name of the system to update.
	--
	-- *args* are the arguments to be passed to the system's Updater function.
	--
	-- Throws an error before the world is initialized.
	function World:Update(system: Name, args: ...any)

	-- DestroyEntity marks a number of entities to be removed from the world.
	--
	-- Throws an error before the world is initialized.
	function World:DestroyEntity(entity: ...ID)

	-- Upkeep performs maintenance. This should be called at an appropriate time
	-- during the update cycle. The following actions are performed:
	--
	-- - Entities marked for destruction are removed from the world.
	--
	-- Throws an error before the world is initialized.
	function World:Upkeep()

	-- Has returns whether the entity of the given ID exists in the world. If
	-- *component* is specified, Has returns whether the entity has the
	-- component. Returns false if the world is not initialized.
	function World:Has(entity: ID, component: Name?): boolean

	-- Get returns the value of an entity's component. Returns nil if the entity
	-- does not have the component, the entity does not exist in the world, or
	-- the world is not initialized.
	function World:Get(entity: ID, component: Name): any?

	-- Set sets the value of an entity's component, returning true on success.
	-- Returns false if the entity does not have the component, the entity does
	-- not exist in the world, or the world is not initialized.
	function World:Set(entity: ID, component: Name, value: any): boolean

	-- Handle returns a Handle that refers to the entity. The entity may or may
	-- not exist.
	function World:Handle(entity: ID): Handle

	-- Handle is a reference to an entity within a World. The entity may or may
	-- not exist.
	type Handle = {

		-- ID is the entity's identifier.
		ID: ID,

		-- World is the associated World of the entity.
		World: World,
	}

	-- Returns the value of the entity's component. Behaves the same as
	-- World.Get.
	Handle[component]

	-- Sets the value of the entity's component. Behaves the same as World.Set.
	Handle[component] = value

	-- Returns whether the entity exists. Behaves the same as World.Has.
	Handle()

	-- Returns whether the entity has the component. Behaves the same as
	-- World.Has.
	Handle(component)

]]

-- Returns whether s is a string that is an identifer.
local function isname(s)
	return type(s) == "string" and string.match(s, "^[A-Za-z_][0-9A-Za-z_]*$")
end

local function errorf(format, ...)
	return error(string.format(format, ...), 3)
end

-- Returns a deep copy of a simple table. Keys are not copied. Assumed to be
-- non-circular. Matches the same metatable if possible.
local function copy(t)
	local c = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			c[k] = copy(v)
		else
			c[k] = v
		end
	end
	local mt = getmetatable(t)
	if type(mt) == "table" then
		setmetatable(c, mt)
	end
	return c
end

-- Removes the first occurrence of v from unordered list t.
local function fastremove(t, v)
	local i = table.find(t, v)
	if i then
		t[i] = t[#t]
		t[#t] = nil
	end
end

local ECS = {}

local World = {__index={}}

function ECS.NewWorld()
	local self = {
		nextID = nil,
		systems = {},     -- {[Name]: {components: Array<Name>, update: Updater}}
		iterators = {},   -- {[Name]: Array<Entity>}
		components = {},  -- {[Name]: DynComponentDef|ComponentDef}
		entityTypes = {}, -- {[Name}: {def: DynEntityDef|EntityDef, systems: Array<Name>}, components: Set<Name>}
		entities = {},    -- {[ID]: Entity}
		entityComps = {}, -- {[ID]: Set<Name>}
		marked = {},      -- Array<Entity>,
	}
	return setmetatable(self, World)
end

function World.__index:DefineSystem(name, components, update)
	if self.nextID then
		error("cannot define system after world is initialized", 2)
	end
	if not isname(name) then
		error("argument #1 must be a name", 2)
	end
	if self.systems[name] ~= nil then
		errorf("system %q already defined", name)
	end
	if type(components) ~= "table" then
		errorf("argument #2 must be a table")
	end
	if type(update) ~= "function" then
		errorf("argument #3 must be a function")
	end
	for i, component in ipairs(components) do
		if not isname(component) then
			errorf("component #%d of argument #2 must is not a valid name", i)
		end
	end
	local comps = table.create(#components)
	for i, component in ipairs(components) do
		comps[i] = component
	end
	self.systems[name] = {
		components = comps,
		update = update,
	}
	self.iterators[name] = {}
end

function World.__index:DefineComponent(name, def)
	if self.nextID then
		errorf("cannot define component after world is initialized")
	end
	if not isname(name) then
		errorf("argument #1 must be a name")
	end
	if self.components[name] ~= nil then
		errorf("component %q already defined", name)
	end
	if def == nil then
		errorf("argument #2 cannot be nil")
	end
	self.components[name] = def
end

function World.__index:DefineEntity(name, def)
	if self.nextID then
		errorf("cannot define entity after world is initialized")
	end
	if not isname(name) then
		errorf("argument #1 must be a name")
	end
	if self.entityTypes[name] ~= nil then
		errorf("entity %q already defined", name)
	end
	self.entityTypes[name] = {
		def = def,
		-- List of systems that see this entity type.
		systems = {},
		components = {},
	}
end

function World.__index:Init()
	if self.nextID then
		errorf("world already initialized")
	end

	-- Accumulate all errors that occur.
	local errors = {}

	-- Make sure components are defined.
	for name, system in pairs(self.systems) do
		for _, component in ipairs(system.components) do
			if not self.components[component] then
				table.insert(errors, string.format("system %q requires undefined component %q", name, component))
			end
		end
	end

	for name, entity in pairs(self.entityTypes) do
		-- Verify that entity definition is correct.
		local def = entity.def
		if type(def) == "function" then
			def = def()
		end
		if type(def) ~= "table" then
			table.insert(errors, string.format("entity definition for %q is not a table", name))
		end
		-- Make sure components are defined.
		for component, ok in pairs(def) do
			if isname(component) and ok then
				if self.components[component] then
					entity.components[component] = true
				else
					table.insert(errors, string.format("entity %q requires undefined component %q", name, component))
				end
			end
		end
		-- Find systems that match the entity type.
		for name, system in pairs(self.systems) do
			local okay = true
			for _, component in ipairs(system.components) do
				if not def[component] then
					okay = false
					break
				end
			end
			if okay then
				table.insert(entity.systems, name)
			end
		end
	end

	-- Throw all errors at once.
	if #errors > 0 then
		error(table.concat(errors, "\n"), 2)
	end

	-- Mark world as initialized.
	self.nextID = 0
end

function World.__index:CreateEntity(name, ...)
	if not self.nextID then
		errorf("cannot create entity before world is initialized")
	end
	local entityType = self.entityTypes[name]
	if entityType == nil then
		errorf("no definition for entity %q", name)
	end
	local def = entityType.def
	if type(def) == "function" then
		def = def(...)
	end
	if type(def) ~= "table" then
		errorf("entity definition for %q is not a table", name)
	end

	local id = self.nextID
	self.nextID = id + 1
	local state = {id}
	for name, args in pairs(def) do
		local component = self.components[name]
		if component and args then
			if type(component) == "function" then
				if type(args) == "table" then
					-- Pass content of args as arguments.
					component = component(table.unpack(args, 1, args.n or #args))
				else
					-- args is used only to indicate presence, and is not
					-- passed.
					component = component()
				end
			elseif type(component) == "table" then
				-- Static table; make a simple copy.
				component = copy(component)
			end
			state[name] = component
		end
	end
	for _, system in ipairs(entityType.systems) do
		table.insert(self.iterators[system], state)
	end
	self.entities[id] = state
	self.entityComps[id] = entityType.components
	return id
end

function World.__index:DestroyEntity(entity)
	if type(entity) == "number" then
		table.insert(self.marked, entity)
	end
end

function World.__index:Upkeep()
	local marked = self.marked
	for i, id in ipairs(self.marked) do
		marked[i] = nil
		for _, entities in pairs(self.iterators) do
			fastremove(entities, id)
		end
		self.entities[id] = nil
		self.entityComps[id] = nil
	end
end

function World.__index:Update(name, ...)
	local system = self.systems[name]
	if not system then
		errorf("system %q is not defined", name)
	end
	system.update(self.iterators[name], ...)
end

function World.__index:Has(id, component)
	local components = self.entityComps[id]
	if components == nil then
		return false
	end
	if component and not components[component] then
		return false
	end
	return true
end

function World.__index:Get(id, component)
	local components = self.entityComps[id]
	if components == nil then
		return nil
	end
	if not components[component] then
		return nil
	end
	local entity = self.entities[id]
	if entity == nil then
		return nil
	end
	return entity[component]
end

function World.__index:Set(id, component, value)
	local components = self.entityComps[id]
	if components == nil then
		return false
	end
	if not components[component] then
		return false
	end
	local entity = self.entities[id]
	if entity == nil then
		return false
	end
	entity[component] = value
	return true
end

local Handle = {}

function World.__index:Handle(id)
	local handle = {
		ID = id,
		World = self,
	}
	return setmetatable(handle, Handle)
end

function Handle:__call(component)
	return self.World:Has(self.ID, component)
end

function Handle:__index(k)
	return self.World:Get(self.ID, k)
end

function Handle:__newindex(k, v)
	self.World:Set(self.ID, k, v)
end

return ECS
