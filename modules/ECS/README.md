# ECS
[ECS]: #user-content-ecs

ESC is an implementation of the entity-component-system pattern.

## Synopsis
```lua
local world = ECS.newWorld()

world:DefineComponent("Component", 0)
world:DefineEntity("Entity", {Component=true})
world:DefineSystem("System", {"Component"}, function(world, entities)
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
```

## Description

### Worlds
All entities, components, and systems live within a "World". A new world can
be created with the newWorld function.
```lua
local world = ECS.newWorld()
```

A newly created world starts out in a "definition mode". At this point, all
the items of the world are defined using the DefineComponent, DefineEntity,
and DefineSystem methods.

### Components
DefineComponent defines a component by assigning a name to an initializer.
```lua
world:DefineComponent("Position", initializer)
```

The initializer determines the initial value of the component, which can be
any value except nil.
```lua
world:DefineComponent("Health", 100)
world:DefineComponent("PlayerInput", game:GetService("UserInputService"))
```

If the initializer is a table, it is deep-copied when a new entity is
created.
```lua
world:DefineComponent("Physics", {
	Position = Vector3.new(0, 0, 0),
	Velocity = Vector3.new(0, 0, 0),
	Speed = 16,
})
```

If the initializer is a function, its return value will become the initial
value. The function receives arguments that can be used configure the value
dynamically.
```lua
world:DefineComponent("Physics", function(x, y, z, speed)
	return {
		Position = Vector3.new(x, y, z),
		Velocity = Vector3.new(0, 0, 0),
		Speed = speed,
	}
end)
```

### Entity types
DefineEntity defines an entity *type*, which assigns a name to a set of
components. Later, actual entities can be created from this entity type.
```lua
world:DefineEntity("Hero", initializer)
```

The initializer determines the components of the entity. It is a table that
maps a component name to a configuration. If a value is a table, that table
is unpacked and passed as arguments to the component's initializer function,
if it has one.
```lua
world:DefineEntity("Hero", {
	Physics = {10, 0, 0, 16}, -- x, y, z, speed
})
```

If the component does not need to be configured, or if the configuration can
be ignored, a boolean can be used instead.
```lua
world:DefineEntity("Hero", {
	Physics = {10, 0, 0, 16},
	Health = true,
})
```

Similar to DefineComponent, the initializer can instead be a function that
returns the components, allowing them to be configured dynamically. Extra
arguments passed to CreateEntity are passed to the initializer.
```lua
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
```

Note that the initializer function *must* return components consistently.
That is, each key in the returned table must be the same between calls,
regardless of the received arguments. The values of the keys do not matter,
as long as they are truthy.

### Systems
DefineSystem defines a system by associating a name to a number of
components, and an updater function. The updater receives as arguments the
state of the world, a list of entities to traverse, as well as the extra
arguments passed to the Update method.
```lua
world:DefineSystem("Physics",
	{"Physics"},
	function(world, entities, deltaTime)
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
```

When the system is updated, only the entities that have all the specified
components are passed to the updater function.
```lua
world:DefineSystem("Input",
	{"Physics", "PlayerInput"},
	function(world, entities, deltaTime)
		for _, e in ipairs(entities) do
			local jump = e.PlayerInput:IsKeyDown(Enum.KeyCode.Space)
			local canJump = e.Physics.Position.Y <= 1e6
			if canJump and jump then
				e.Physics.Velocity = e.Physics.Velocity + Vector3.new(0, 50, 0)
			end
		end
	end,
)
```

### Initialization
Once the world is defined, it is initialized with the Init method. This
ensures that all definitions are valid, and prepares some optimizations.
```lua
world:Init()
```

Once initialized, entities can be created, and systems can be updated.

### Entities
A new entity is created with the CreateEntity method. The first argument is
the name of the entity type, and the remaining arguments are passed to the
entity type's initializer, if it exists. CreateEntity returns a value that
identifies the entity.
```lua
local hero = world:CreateEntity("Hero", 10, 0, 0)
local monster = world:CreateEntity("Monster", -10, 0, 0)
```

### Update and Upkeep

Systems are updated using the Update method. The first argument is the name
of the system to update, and the remaining arguments are passed to the
system's updater function.

The Upkeep method performs maintenance to keep things clean. This should
usually be called at the end of an update loop.
```lua
RunService:BindToRenderStepped("Update", 0, function(deltaTime)
	world:Update("Input", deltaTime)
	world:Update("Physics", deltaTime)
	world:Upkeep()
end)
```

### Destroying entities
Entities can be destroyed with the DestroyEntity method. The first argument
is the identifier of the entity to destroy.
```lua
world:DestroyEntity(monster)
```

Note that this does not destroy the entity immediately. Instead, the
destruction is deferred until the Upkeep method is called.

### Has, Get, and Set

The state of an entity can be accessed through the Has, Get, and Set
methods.

Has returns whether an entity exists, or whether an entity has a component.
```lua
print(world:Has(hero))                   --> true
print(world:Has(monster))                --> false

print(world:Has(hero, "Health"))         --> true
print(world:Has(monster, "PlayerInput")) --> false
```

Get returns the value of an entity's component, or nil if it does not exist.
```lua
print(world:Get(hero, "Health"))    --> 100
print(world:Get(monster, "Health")) --> nil
```

Set sets the value of an entity's component, and returns whether it
succeeded.
```lua
print(world:Set(hero, "Health", 50))    --> true
print(world:Set(monster, "Health", 50)) --> false
```

Has, Get, and Set should not be used from within a system updater. Instead,
a system should be created to observe and mutate state directly.

### Handles
For convenience, the Handle method creates an object-like interface to an
entity. The entity may or may not exist.
```lua
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
```

Handles should be used only for interfacing with external code outside the
world.

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [ECS][ECS]
	1. [ECS.newWorld][ECS.newWorld]
2. [ComponentDef][ComponentDef]
3. [DynComponentDef][DynComponentDef]
4. [DynEntityDef][DynEntityDef]
5. [Entity][Entity]
6. [EntityDef][EntityDef]
7. [Handle][Handle]
	1. [Handle.\__call][Handle.__call]
	2. [Handle.\__index][Handle.__index]
	3. [Handle.\__newindex][Handle.__newindex]
8. [ID][ID]
9. [Name][Name]
10. [Updater][Updater]
11. [World][World]
	1. [World.CreateEntity][World.CreateEntity]
	2. [World.DefineComponent][World.DefineComponent]
	3. [World.DefineEntity][World.DefineEntity]
	4. [World.DefineSystem][World.DefineSystem]
	5. [World.DestroyEntity][World.DestroyEntity]
	6. [World.Get][World.Get]
	7. [World.Handle][World.Handle]
	8. [World.Has][World.Has]
	9. [World.Init][World.Init]
	10. [World.Set][World.Set]
	11. [World.Update][World.Update]
	12. [World.Upkeep][World.Upkeep]
12. [WorldState][WorldState]
	1. [WorldState.Entity][WorldState.Entity]

</td></tr></tbody>
</table>

## ECS.newWorld
[ECS.newWorld]: #user-content-ecsnewworld
```
ECS.newWorld(): World
```

newWorld returns a new World.

# ComponentDef
[ComponentDef]: #user-content-componentdef
```
type ComponentDef = any
```

ComponentDef determines the value of a component.

# DynComponentDef
[DynComponentDef]: #user-content-dyncomponentdef
```
type DynComponentDef = function(args: ...any): (component: ComponentDef)
```

DynComponentDef defines the value of a component dynamically.

*args* are the arguments received from an EntityDef, and are used to
initialize the returned value. The returned value must not be retained.

# DynEntityDef
[DynEntityDef]: #user-content-dynentitydef
```
type DynEntityDef = function(args: ...any): (entity: EntityDef)
```

DynEntityDef defines the components of an entity type and initializes
the components dynamically.

*args* are received from World.CreateEntity, and are used to initialize the
values to be passed to a component's DynComponentDef.

The components of the returned EntityDef must be consistent between calls,
regardless of the arguments passed. The returned value must not be retained.

# Entity
[Entity]: #user-content-entity
```
type Entity = {
	[1]: ID,     -- The entity's identifier.
	[Name]: any, -- Maps a component name to the component's value.
}
```

Entity represents the state of a single entity.

# EntityDef
[EntityDef]: #user-content-entitydef
```
type EntityDef = Dictionary<string, ({[number]: any, n: number?}|boolean)>
```

EntityDef defines and initializes the components of an entity type.

Each key specifies the name of a component. These components do not need to
be defined until the world is initialized.

Each value is a packed list of arguments to be passed to the component's
DynComponentDef, if possible. The value may also be a boolean, which can be
used if the component is not initialized dynamically, or if no arguments need
to be passed. A value of false causes the component to *not* be defined.

# Handle
[Handle]: #user-content-handle
```
type Handle = {
	ID: ID,       -- ID is the entity's identifier.
	World: World, -- World is the associated World of the entity.
}
```

Handle is a reference to an entity within a World. The entity may or may
not exist.

## Handle.\__call
[Handle.__call]: #user-content-handle__call
```
Handle(component: Name?): boolean
```

Returns whether the entity exists, or whether the entity has the
component. Behaves the same as World.Has.

## Handle.\__index
[Handle.__index]: #user-content-handle__index
```
Handle[Name]: any
```

Returns the value of the entity's component. Behaves the same as
World.Get.

## Handle.\__newindex
[Handle.__newindex]: #user-content-handle__newindex
```
Handle[Name] = any
```

Sets the value of the entity's component. Behaves the same as World.Set.

# ID
[ID]: #user-content-id
```
type ID = _entity_id_
```

ID uniquely identifies an entity in a particular World. It is valid for
the ID to be passed to methods of the world in which the entity was created.
It is also valid for the ID to be compared for equality with another ID
created in the same World.

# Name
[Name]: #user-content-name
```
type Name = string
```

Name is a string that must be a valid Lua identifier.

# Updater
[Updater]: #user-content-updater
```
type Updater = (world: WorldState, entities: Array<Entity>, args: ...any) -> ()
```

Updater is passed to World.DefineSystem, and is called when the
associated system updates.

*world* is a WorldState that encapsulates the state of the World that ran the
updater. The updater should avoid mutating entities retrieved from *world*.
Instead, a system should be created to update such entities.

*entities* is the unordered list of entities to be traversed by the system.
*entities* and its content must not be retained.

*args* are the arguments that were passed to the World.Update function.

# World
[World]: #user-content-world
```
type World
```

World is a collection of entities, components, and systems.

## World.CreateEntity
[World.CreateEntity]: #user-content-worldcreateentity
```
World:CreateEntity(name: Name, args: ...any): (entity: ID)
```

CreateEntity creates a new entity in the world.

*name* is the name of a defined entity type.

*args* are the arguments to be passed to the entity type's DynEntityDef, if
possible.

Returns an ID that uniquely identifies the entity.

Throws an error before the world is initialized.

## World.DefineComponent
[World.DefineComponent]: #user-content-worlddefinecomponent
```
World:DefineComponent(name: Name, def: DynComponentDef|ComponentDef)
```

DefineComponent defines a component in the world.

*name* is the name of the component, which must be unique.

*def* is the definition of the component's value, determining the initial
value when an entity is created. If *def* is a table that does not have a
metatable, then it is deep-copied when initialized. Otherwise, *def* is
passed directly. When copying, keys are copied by reference, and the table is
assumed to be non-circular.

*def* cannot be nil. To create a nil value, use a DynComponentDef that
returns nil. More generally, the returned value of DynComponentDef is not
interpreted any further, so it can be used for absolute control over the
initial value.

Throws an error after the world is initialized.

## World.DefineEntity
[World.DefineEntity]: #user-content-worlddefineentity
```
World:DefineEntity(name: Name, def: DynEntityDef|EntityDef)
```

DefineEntity defines an entity type in the world. An entity type
predeclares the components of an entity, enabling optimized entity creation
and traversal.

*name* is the name of the entity type, which must be unique.

*def* is the definition of the entity type's components.

Throws an error after the world is initialized.

## World.DefineSystem
[World.DefineSystem]: #user-content-worlddefinesystem
```
World:DefineSystem(name: Name, components: Array<string>, update: Updater)
```

DefineSystem defines a system in the world.

*name* is the name of the system, which must be unique.

*components* is a list of names of the components that the system applies to.
These components do not need to be defined until the world is initialized.

*update* is the function called when the system updates.

Throws an error after the world is initialized.

## World.DestroyEntity
[World.DestroyEntity]: #user-content-worlddestroyentity
```
World:DestroyEntity(entity: ...ID)
```

DestroyEntity marks a number of entities to be removed from the world.

Throws an error before the world is initialized.

## World.Get
[World.Get]: #user-content-worldget
```
World:Get(entity: ID, component: Name): any?
```

Get returns the value of an entity's component. Returns nil if the
entity does not have the component, the entity does not exist in the world,
or the world is not initialized.

## World.Handle
[World.Handle]: #user-content-worldhandle
```
World:Handle(entity: ID): Handle
```

Handle returns a Handle that refers to the entity. The entity may or may
not exist.

## World.Has
[World.Has]: #user-content-worldhas
```
World:Has(entity: ID, component: Name?): boolean
```

Has returns whether the entity of the given ID exists in the world. If
*component* is specified, Has returns whether the entity has the component.
Returns false if the world is not initialized.

## World.Init
[World.Init]: #user-content-worldinit
```
function World:Init()
```

Init initializes the world. After initialization, entity types,
components, and systems can no longer be defined, entities can be created and
destroyed, and systems can be updated.

Throws an error if the world was already initialized.

## World.Set
[World.Set]: #user-content-worldset
```
World:Set(entity: ID, component: Name, value: any): boolean
```

Set sets the value of an entity's component, returning true on success.
Returns false if the entity does not have the component, the entity does not
exist in the world, or the world is not initialized.

## World.Update
[World.Update]: #user-content-worldupdate
```
World:Update(system: Name, args: ...any)
```

Update updates a system.

*system* is the name of the system to update.

*args* are the arguments to be passed to the system's Updater function.

Throws an error before the world is initialized.

## World.Upkeep
[World.Upkeep]: #user-content-worldupkeep
```
World:Upkeep()
```

Upkeep performs maintenance. This should be called at an appropriate
time during the update cycle. The following actions are performed:

- Entities marked for destruction are removed from the world.

Throws an error before the world is initialized.

# WorldState
[WorldState]: #user-content-worldstate
```
type WorldState
```

WorldState encapsulates the state of a World.

## WorldState.Entity
[WorldState.Entity]: #user-content-worldstateentity
```
WorldState:Entity(target: ID): Entity?
```

Entity returns the state of the entity of the given identifier. Returns
nil if the entity does not exist.

