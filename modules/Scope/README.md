# Scope
[Scope]: #scope

The Scope module provides a means for scoping values, conveying
lifetime, and managing [tasks][Task].

Values set on a scope cascade downward to descendant scopes. Values can also
be subscribed to for observing changes.

The Scope class implements scoped values and provides lifetime management.

A Scope is not reusable. After the scope has been destroyed, all methods
become **inert**; any behavior becomes a no-op, and any returned objects are
also inert.

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Scope][Scope]
	1. [Scope.clean][Scope.clean]
	2. [Scope.wrap][Scope.wrap]
	3. [Scope.new][Scope.new]
	4. [Scope.Alive][Scope.Alive]
	5. [Scope.Context][Scope.Context]
	6. [Scope.Derive][Scope.Derive]
	7. [Scope.Destroy][Scope.Destroy]
	8. [Scope.Get][Scope.Get]
	9. [Scope.Set][Scope.Set]
	10. [Scope.Subscribe][Scope.Subscribe]
	11. [Scope.Wrap][Scope.Wrap]
2. [Context][Context]
	1. [Context.Alive][Context.Alive]
	2. [Context.Assign][Context.Assign]
	3. [Context.AssignEach][Context.AssignEach]
	4. [Context.Clean][Context.Clean]
	5. [Context.Connect][Context.Connect]
	6. [Context.Context][Context.Context]
	7. [Context.Derive][Context.Derive]
	8. [Context.Get][Context.Get]
	9. [Context.Subscribe][Context.Subscribe]
	10. [Context.Unassign][Context.Unassign]
3. [Subscription][Subscription]
4. [Task][Task]
5. [Unsubscriber][Unsubscriber]

</td></tr></tbody>
</table>

## Scope.clean
[Scope.clean]: #scopeclean
```
function Scope.clean(...: Task)
```

Cleans each argument. Does nothing for arguments that are not known
[Task][Task] types.

**Examples:**

```lua
Scope.clean(Instance.new("Part"))
```

## Scope.wrap
[Scope.wrap]: #scopewrap
```
function Scope.wrap(...: Task): () -> ()
```

Encapsulates the given tasks in a function that cleans them when called.

**Examples:**

```lua
local conn = RunService.Heartbeat:Connect(function(dt)
	print("delta time", dt)
end)
return Scope.wrap(conn)
```

## Scope.new
[Scope.new]: #scopenew
```
function Scope.new(): Scope
```

Returns a new instance of the Scope class.

**Examples:**

```lua
local scope = Scope.new()
```

## Scope.Alive
[Scope.Alive]: #scopealive
```
function Scope:Alive(): boolean
```

Returns false after the scope has been destroyed, and true otherwise.

**Examples:**

```lua
local scope = Scope.new()
print(scope:Alive()) --> true
scope:Destroy()
print(scope:Alive()) --> false
```

## Scope.Context
[Scope.Context]: #scopecontext
```
function Scope:Context(): Context
```

Returns a new [Context][Context] attached to the lifetime of the scope.

Returns an inert context if the scope is dead.

**Examples:**

```lua
local context = scope:Context()
```

## Scope.Derive
[Scope.Derive]: #scopederive
```
function Scope:Derive(): Scope
```

Creates a child scope. See [Context.Derive][Context.Derive].

**Examples:**

```lua
local childScope = parentScope:Derive()
```

## Scope.Destroy
[Scope.Destroy]: #scopedestroy
```
function Scope:Destroy()
```

Signals the end of the scope's lifetime. All descendant scopes are
destroyed, all subscriptions are unsubscribed, and tasks assigned to
associated contexts are cleaned. The scope, descendants, and contexts become
inert.

Does nothing if the scope is dead.

**Examples:**

```lua
scope:Destroy()
```

## Scope.Get
[Scope.Get]: #scopeget
```
function Scope:Get(key: any): any
```

Gets a scoped value. See [Context.Get][Context.Get].

**Examples:**

```lua
scope:Set("theme", Theme.new("Dark"))
print(scope:Get("theme")) --> Dark
```

## Scope.Set
[Scope.Set]: #scopeset
```
function Scope:Set(key: any, value: any)
```

Sets a value visible to the scope and its descendants. Setting a value
flows downward to child scopes, but not upward to parent scopes.

When setting, any subscriptions to *key* are called with *value*. Descendant
scopes are traversed recursively and their subscriptions called as well. A
descendant that overrides *key* with a non-nil value is not traversed.

Does nothing if the scope is dead.

**Examples:**

Keys can be set to values. The key does not need to be a string.

```lua
scope:Set("theme", Theme.new("Light"))
```

Setting to nil unsets the key. If the scope has an ancestor with the same
key, the scope will get the value from there instead.

```lua
local parentScope = Scope.new()
local lightTheme = Theme.new("Light")
parentScope:Set("theme", lightTheme)

local childScope = parentScope:Derive()
-- Value is inherited from parent scope.
print(childTheme:Get("theme")) --> Light

local darkTheme = Theme.new("Dark")
childScope:Set("theme", darkTheme)
-- Value is shadowed in child scope.
print(childTheme:Get("theme")) --> Dark

childScope:Set("theme", nil)
-- Value is unset, returning to the inherited value.
print(childTheme:Get("theme")) --> Light
```

## Scope.Subscribe
[Scope.Subscribe]: #scopesubscribe
```
function Scope:Subscribe(key: any, sub: Subscription): Unsubscriber
```

Subscribes to a value. See [Context.Subscribe][Context.Subscribe].

**Examples:**

```lua
-- Subscriber is called immediately.
scope:Subscribe("theme", function(theme)
	print("updated theme to", theme)
end)
--> updated theme to nil

-- Setting value observes the change.
scope:Set("theme", Theme.new("Light"))
--> updated theme to Light

-- Unsetting value still observes the change.
scope:Set("theme", nil)
--> updated theme to nil
```

## Scope.Wrap
[Scope.Wrap]: #scopewrap
```
function Scope:Wrap(): ()->()
```

Encapsulates the scope by returning a function that destroys the scope
when called.

Returns an inert function if the scope is dead.

**Examples:**

```lua
local task = scope:Wrap()
```

# Context
[Context]: #context
```
type Context
```

Encapsulates certain behaviors of a [Scope][Scope] and provides task
management.

Only readable behaviors of the scope can be accessed from the context. While
writable behaviors like [Set][Scope.Set] and [Destroy][Scope.Destroy] aren't
available, [Derive][Context.Derive] can be used to create a complete child
scope.

## Context.Alive
[Context.Alive]: #contextalive
```
function Context:Alive(): boolean
```

Returns false after the context has been destroyed, and true otherwise.
A context is destroyed when its associated [Scope][Scope] is destroyed.

**Examples:**

```lua
if context:Alive() then
	context:Connect("heartbeat", RunService.Heartbeat:Connect(function(dt)
		print("delta time", dt)
	end))
end
```

## Context.Assign
[Context.Assign]: #contextassign
```
function Context:Assign(name: any, task: Task?)
```

Performs an action depending on the type of *task*. If *task* is nil,
then the task assigned as *name* is cleaned, if present. Otherwise, *task* is
assigned to the context as *name*. If a different task (according to
rawequal) is already assigned as *name*, then it is cleaned.

If the context is dead, *task* is cleaned immediately.

**Examples:**

A task can be assigned under a referable name. The name does not have to be a
string.

```lua
context:Assign("part", Instance.new("Part"))
```

Setting an assigned task to nil unassigns it from the context and cleans it.

```lua
context:Assign("part", nil) -- Remove task and clean it.
```

Assigning a task with a name that is already assigned cleans the previous
task first.

```lua
context:Assign("part", Instance.new("Part"))
context:Assign("part", Instance.new("WedgePart"))
```

## Context.AssignEach
[Context.AssignEach]: #contextassigneach
```
function Context:AssignEach(...: Task)
```

Assigns each given argument as an unnamed task.

If the context is dead, the each task is cleaned immediately.

**Examples:**

```lua
context:AssignEach(Instance.new("Part"), Instance.new("Model"))
context:AssignEach(Instance.new("Frame"), Instance.new("TextButton"))
```

## Context.Clean
[Context.Clean]: #contextclean
```
function Context:Clean(...: any)
```

Receives a number of names, and cleans the task assigned to the context
for each name. Does nothing if the context is dead, and does nothing for
names that have no assigned task.

**Examples:**

```lua
context:Clean("heartbeat", "part")
```

## Context.Connect
[Context.Connect]: #contextconnect
```
function Context:Connect<T...>(name: any?, signal: RBXScriptSignal<T...>, listener: (T...) -> ())
```

Connects *listener* to *signal*, then assigns the resulting connection
to the context as *name*. If *name* is nil, then the connection is assigned
as an unnamed task instead. Does nothing if the context is dead.

Connect is the preferred method when using contexts to manage signals,
primarily to resolve problems concerning the assignment to a dead context:

- Slightly more efficient than regular assignment, since the connection of
  the signal is never made.
- Certain signals can have side-effects when connecting, so avoiding the
  connection entirely is more correct.

**Examples:**

```lua
context:Connect("heartbeat", RunService.Heartbeat, function(dt)
	print("delta time", dt)
end)
```

## Context.Context
[Context.Context]: #contextcontext
```
function Context:Context(): Context
```

Returns a new [Context][Context] attached to the lifetime of the
context's scope.

Returns an inert context if the context is dead.

**Examples:**

```lua
local otherContext = context:Context()
```

## Context.Derive
[Context.Derive]: #contextderive
```
function Context:Derive(): Scope
```

Creates a child [Scope][Scope] whose lifetime is attached to the
context's associated scope.

Returns an inert scope if the context is dead.

**Examples:**

```lua
local childScope = parentContext:Derive()
```

## Context.Get
[Context.Get]: #contextget
```
function Context:Get(key: any): any
```

Returns the value currently assigned to *key* from the associated scope.
If the value is nil, then Get will attempt to retrieve recursively from
ancestor scopes, if available.

Returns nil if the context is dead.

**Examples:**

```lua
context:Set("theme", Theme.new("Dark"))
print(context:Get("theme")) --> Dark
```

## Context.Subscribe
[Context.Subscribe]: #contextsubscribe
```
function Context:Subscribe(key: any, sub: Subscription): ()->()
```

Subscribes to *key* from the associated scope, calling *sub* initially
and when the value assigned to *key* changes. Returns a function that
unsubscribes when called.

While the value of *key* is nil, the subscription will observe changes to the
nearest existing *key* from ancestor scopes.

Does nothing and returns an inert function if the context is dead.

**Examples:**

```lua
-- Subscriber is called immediately.
context:Subscribe("theme", function(theme)
	print("updated theme to", theme)
end)
--> updated theme to nil

-- Setting value observes the change.
context:Set("theme", Theme.new("Light"))
--> updated theme to Light

-- Unsetting value still observes the change.
context:Set("theme", nil)
--> updated theme to nil
```

## Context.Unassign
[Context.Unassign]: #contextunassign
```
function Context:Unassign(name: any): Task?
```

Removes the task assigned to the context as *name*, returning the task
without cleaning it. Returns nil if no task is assigned as *name*, or if the
context is dead.

**Examples:**

```lua
context:Assign("part", Instance.new("Part"))
local part = context:Unassign("part")
```

# Subscription
[Subscription]: #subscription
```
type Subscription = (value: any) -> ()
```

Passed to [Subscribe][Context.Subscribe] to observe a scoped value.

**Examples:**

```lua
local function subscription(value: any)
	print("changed", value)
end
context:Subscribe("Foobar", subscription)
```

# Task
[Task]: #task
```
type Task = any
```

A **task** is any value that encapsulates the finalization of some
procedure or state. "Cleaning" a task invokes it, causing the procedure or
state to be finalized.

All tasks must conform to the following contract when cleaning:

- A task must not produce an error.
- A task must not yield.
- A task must finalize only once; cleaning an already cleaned task should be
  a no-op.
- A task must not cause the production of more tasks.

When cleaning, certain known types are handled in specific ways. The
following types are known:

- `function`: The function is called.
- `thread`: The thread is canceled with `task.cancel`.
- `RBXScriptConnection`: The Disconnect method is called.
- `Instance`: The Destroy method is called.
- `table` without metatable: The value of each entry is cleaned. This applies
  recursively, and such tables are cleaned only once. The table is cleared
  unless it is frozen.
- `table` with metatable and Destroy function: Destroy is called as a method.

Other types are merely held onto until cleaned.

Any manner of finalization can be supported by wrapping it in a function.

**Examples:**

```lua
-- Destroys the instance.
Scope.clean(Instance.new("Part"))
```

# Unsubscriber
[Unsubscriber]: #unsubscriber
```
type Unsubscriber = () -> ()
```

Unsubscribes a [subscription][Context.Subscribe] when called.

**Examples:**

```lua
local unsubscriber = context:Subscribe("Foobar", function subscription(value: any)
	print("changed", value)
end)
unsubscriber()
```

