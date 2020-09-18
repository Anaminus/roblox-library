# Style guide
This document describes the style and conventions of writing Lua code in Roblox.
It has several influences:

- https://roblox.github.io/lua-style-guide/
- https://golang.org/doc/effective_go.html

The opinions expressed in this guide are decisively and irrefutably correct.

# Fonts
Do yourself a favor and use a monospace font. I shouldn't even have to mention
this, but some people...

# Syntax

## Spacing
Tabs are used for indentation. One tab per level.

```lua
for i = 1, 100 do
	if i%3 == 0 then
		print(i)
	end
end
```

Only indentation space is allowed to be the leading space of a line, unless
within a string or comment.

Spaces are used for alignment.

```lua
local a       = 1
local group   = 2
local of      = 3
local numbers = 4
```

Two lines may be aligned as long as they have the same level of indentation.

```lua
-- Allowed
local list = {
	a       = 1,
	list    = 2,
	of      = 3,
	numbers = 4,
}

-- Not allowed!
local list = {
	a             = 1,
	list          = 2,
	of            = 3,
	values        = 4,
	also          = {  -- One level
		including = 5, -- Two levels
		a         = 6,
		nested    = 7,
		table     = 8,
	},
}

-- Much better.
local list = {
	a      = 1,
	list   = 2,
	of     = 3,
	values = 4,
	also   = {  -- One level
		including = 5, -- Two levels
		a         = 6,
		nested    = 7,
		table     = 8,
	},
}
```

Alignment space must never be leading space, or adjacent to indentation space.

```lua
if youHavePoorTaste then
	youWouldThinkThisIsFine(but,
	                        you,
	                        should,
	                        be,
	                        ashamed)
end
```

Lines must never have trailing space.

```lua
print("I can't even get this example to have trailing space because my editor")
print("removes it when saving.")
```

Multiple line breaks should be used to separate groups of code. Double-breaking
every single line is lunacy. Some people...

## Line width
Lines should generally be kept under 80 characters. This isn't a hard limit, but
long lines should be wrapped when possible.

When function arguments are wrapped, there should be one line per argument:

```lua
print(
	a,
	bunch,
	of,
	arguments
)
```

Expressions are wrapped by splitting them onto multiple lines without
indentation:

```lua
if conditionA and
conditionB and
conditionC then
	doThing()
end
```

...is what I'd like to say. Unfortunately, most editors and formatters seem to
throw a fit unless such expressions are formatted *with* indentation:

```lua
if conditionA and
	conditionB and
	conditionC then
	doThing()
end
```

This is stupid and unreadable, but often can't be helped. Oh well.

## Comments
Generally, comments should form complete sentences.

```lua
-- This is a good comment.

-- this one is not so great
```

For single-line comments, a space should follow each `--` delimiter. Comments
without a space indicate some kind of directive.

```lua
-- Fish are friends, not food.
--TODO: Fry up some fish.
```

A comment should usually appear on the line directly before the related code.

```lua
-- This comment is related to the following statement.
if this then
	that() -- This is okay, but should be brief.
end
```

Comments should be wrapped to 80 characters. Multiple single-line comments is
preferred. The `--` delimiter is retained for paragraph breaks when the whole
comment meant to be a part of one unit.

```lua
-- Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod
-- tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
-- quis nostrud did you even read this exercitation ullamco laboris nisi ut
-- aliquip ex ea commodo consequat.
--
-- Duis aute irure dolor in kumquat in voluptate velit esse cillum dolore eu
-- fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt
-- in culpa qui officia deserunt mollit anim id est laborum.
```

Block comments should be reserved for bulk, top-level documentation.

```lua
--[[

Pretend there's a bunch of documentation here.

]]
```

## Naming conventions
The following naming styles are used throughout this document:
- `UpperCamelCase`: Each word is capitalized, with no separating characters.
- `lowerCamelCase`: First word is lowercase, subsequent words are capitalized,
  with no separating characters.
- `alllowercase`: All letters are lowercase, with no separating characters.

Names should generally adhere to the Lua variable naming scheme, even in places
where any characters are allowed:
- First character can be a lower- or upper-case letter, or an underscore.
- Subsequent characters can be a lower- or upper-case letter, the digits 0
  through 9, or an underscore.

That is, names should match the following Lua string pattern:

	[A-Za-z_][0-9A-Za-z_]*

### Lua names
Lua has its own naming conventions. Generally, everything is `alllowercase`.

#### Library names
The name of a library follows the Lua convention of `alllowercase`.

#### Library keys
Keys within a library table depend on the origin.

The Lua convention is `alllowercase`, so the Lua standard libraries, as well as
extensions to them, should be `alllowercase`.

The Roblox convention for library keys is `lowerCamelCase` when the value is a
function or primitive. When the value is some object, the key can match the name
of the object (e.g. "CFrame" matches the name of the CFrame type, being
`UpperCamelCase`).

Global names are treated as keys to a "base" library. Extensions here use the
Roblox convention for library keys.

### Roblox names
Conventions used by Roblox, over which the user can have no influence.

#### Class names
For the names of its classes, Roblox has the convention of `UpperCamelCase`.

#### Member names
For the names of class members, Roblox has the convention of `UpperCamelCase`.

Historically, member names were sometimes `lowerCamelCase`. These were converted
to `UpperCamelCase`, but have a `lowerCamelCase` counterpart for
backward-compatibility. The `lowerCamelCase` versions of members are deprecated,
and should absolutely be avoided.

#### Type names
For the names of types (e.g. `CFrame`, `Vector3`, `UDim2`), Roblox has the
convention of `UpperCamelCase`.

Certain primitive types (e.g. `bool`, `int`, `string`), deriving from C++ data
types, are lowercase.

#### Acronyms
The Roblox convention for acronyms is uppercase for the first letter as
appropriate, while the remaining letters are lowercase (e.g. "HttpService"
instead of "HTTPService").

#### Suffix for yielding methods
Some methods on instance can cause the running thread to yield. This is usually
indicated by a "Async" suffix on the name of the method. This convention is
confusing and inconsistent, so it should basically be ignored.

> It's "async" as in it allows other threads to run, asynchronously, with the
> calling thread. Not "async" as in the method runs asynchronously with the
> calling thread.

### User names
Conventions for how the user writes names.

#### General variables
General variables are `lowerCamelCase`.

The descriptiveness of a variable should depend on its scope. Short-range
variables should be short (e.g. `i` for a loop index), and long-range variables
should be long (e.g. `playerData` for script-wide variable).

#### Acronyms
The convention for user acronyms is to match the case of all letters to the
first letter. For example, "HTTPService" or "httpService", instead of
"HttpService".

#### Instance names
For instances that could be referred to (e.g. acquired via FindFirstChild), the
Name property should be `UpperCamelCase`.

ModuleScripts may have an associated instance, indicated by the Name matching
that of the ModuleScript, followed by a dot (`.`), then some variable. For
example, an associated unit test module for the "Base64" module may be named
"Base64.test".

Otherwise, a Name may contain any character at the user's convenience (e.g.
numbers and underscores for instances in bulk).

#### Service variables
The name of a variable pointing to a service should be the ClassName of the
service. Because class names are `UpperCamelCase`, so are these variables.

#### Object names
The name of a custom class should follow the Roblox convention of
`UpperCamelCase`.

#### Object member names
The names of members within a custom class depend on the visibility of the
member. Private members are `lowerCamelCase`, while public members are
`UpperCamelCase`.

#### ModuleScript variables
The name of a variable pointing to a required module should be the name of the
ModuleScript. Because instances are `UpperCamelCase`, so are ModuleScripts, and
therefore, so are these variables.

Third-party modules may not follow these conventions. These should just be
rewritten so that they are correct.

#### ModuleScript keys
The name of keys within a required module depend on the returned value.

A singleton object should follow the object member name convention of
`UpperCamelCase`.

A library-like module should follow the Roblox library key convention of
`lowerCamelCase`.

# Patterns

## Child indexing
An instance allows a child to be acquired by indexing the instance with its
name:

```lua
child = Instance.Child
```

***USE OF THIS FEATURE IS FORBIDDEN.***

- `instance[x]` will select a member of the instance before selecting a child. A
  class can have members added to it at any point in the future, so this feature
  is not forward-compatible.
- It cannot be guaranteed that a child exists when expected. `instance[x]` will
  throw an error if no child with the Name `x` exists by assuming `x` is a
  non-*member*.

Instead, use methods like FindFirstChild that allow the existence of the child
to be verified before use.

## Prefer guarantees
The game tree is a playground for scripts. There is no concept of ownership over
instances, so scripts must be defensive when operating on them. The user should
prefer the options where an instance is guaranteed to be what is expected. For
example:

- Use `FindFirstChild` to get the child of an instance.
- Use `GetService` to get a service.
- To get a Player instance, use `Players.PlayerAdded`, which is guaranteed to be
  of the Player class. Keep a reference to it.
- To get a character, use `Player.Character`, which is guaranteed to be either
  the player's character model, or nil if it doesn't exist.
- `Workspace.CurrentCamera` is guaranteed to point to the active Camera.
- When creating instances from scratch with `Instance.new`, keep references to
  the ones that will be used.
- Globals like `game` and `workspace` are guaranteed to exist, and are safe to
  use.

An instance freshly created from `Instance.new` has the unique property that no
other scripts are able to acquire a reference to it. At this point, the current
script effectively has "ownership" over the instance.

This fact should be utilized as much as possible. Configure the state of the
instance now, while nothing else will affect it. If the instance will be used
later, retain a reference to it.

Once the instance is passed to another script, or added to the game tree, this
ownership is lost; anything can happen to the instance. The user should expect
nothing from the instance from that point onward; any information received from
the instance should be verified as necessary.

## Custom classes
There are a variety of ways to design custom classes in Lua. This section
describes the preferred method.

When defining a class, the Roblox Style Guide prefers using self-referencing
metatables. This enables certain conveniences when writing classes, but reduces
clarity, making the code more difficult to reason about. It also has
side-effects, like instances of the class having its constructors as members.

This style guide recommends a flattened approach, where the `__index` metamethod
is a separate table that is referred to directly:

```lua
local Class = {__index={}}

function Class.__index:Name()
	return self.name
end
```

This makes it more clear what is being defined. It is also more consistent with
other metamethods:

```lua
function Class:__tostring()
	return self.name
end
```

## Definition
When defining a class, begin with the metatable. The variable name should match
the name of the class, if possible.

```lua
local Class = {}
```

If the class will have methods, the `__index` metamethod can be included here:

```lua
local Class = {__index={}}
```

### Constructors
Next, define the constructors. Constructors should be defined depending on how
they are used. If the constructor is exported by the module, then it can be
defined that way directly:

```lua
function Module.Class()
end
```

Or, if the class must be constructed later within the module, use a local
function. The primary constructor should be named `new<class>`:

```lua
local function newClass()
end
Module.Class = newClass
```

The structure of a constructor has a common flow.

- Create the state of the instance, assigned to the `self` variable.
- Initialize the fields of the instance.
- Set the metatable.
- Perform any behavioral initialization.
- Return the instance.

For example:

```lua
local function newClass(name)
	-- Create state.
	local self = {
		-- Initialize fields.
		name = name,
	}

	-- Further field initialization.
	self.foo = "bar"

	-- Set the metatable.
	setmetatable(self, Class)

	-- Further behavioral initialization.
	self:initState()

	-- Finish.
	return self
end
```

Not all steps may be needed, so the structure can be abbreviated as desired. For
example, if the instance only needs to initialize fields:

```lua
local function newClass(name)
	return setmetatable({name = name}, Class)
end
```

### Methods
After the constructors, the methods of the class are defined. This is done by
defining a function within the `__index` table using the method syntax:

```lua
function Class.__index:Name()
	return self.name
end
```

Metamethods may also be defined here:

```lua
function Class:__tostring()
	return self.name
end
```

### Encapsulation

#### Member visibility
As described in the Naming conventions section, private members are lowercase,
while public members are uppercase. Private members are not a part of the
class's public API, and should only be accessed by the script that defined the
class.

In practice, true encapsulation cannot be enforced without greatly increasing
the cost of instances, so it is instead enforced by discipline of the user.

#### Getters and setters
Using `__index` and `__newindex` for getters and setters is often too
complicated and expensive to setup and use. A more simple pattern for this is to
use methods.

For example, a class may have the private field "name".

```lua
local function newClass(name)
	return setmetatable({name = name}, Class)
end
```

To get the field, the "Name" method is defined. It is preferred to omit the
"Get" prefix when possible:

```lua
function Class.__index:Name()
	return self.name
end
```

To set the field, the "SetName" method is defined:

```lua
function Class.__index:SetName(value)
	self.name = value
end
```
