# Maid
[Maid]: #maid

The Maid module provides methods to manage tasks. A **task** is any
value that encapsulates the finalization of some procedure or state.
"Cleaning" a task invokes it, causing the procedure or state to be finalized.

All tasks have the following contract when cleaning:

- A task must not produce an error.
- A task must not yield.
- A task must finalize only once; cleaning an already cleaned task should be
  a no-op.
- A task must not cause the production of more tasks.

### Maid class

The **Maid** class is used to manage tasks more conveniently. Tasks can be
assigned to a maid to be cleaned later.

A task can be assigned to a maid as "named" or "unnamed". With a named task:

- The name can be any non-nil value.
- A named task can be individually cleaned.
- A named task can be individually unassigned from the maid without cleaning
  it.

Unnamed tasks can only be cleaned by destroying the maid.

Any value can be assigned to a maid. Even if a task is not a known task type,
the maid will still hold on to the value. This might be used to hold off
garbage collection of a value that otherwise has only weak references.

A maid is not reusable; after a maid has been destroyed, any tasks assigned
to the maid are cleaned immediately.

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Maid][Maid]
	1. [Maid.clean][Maid.clean]
	2. [Maid.wrap][Maid.wrap]
	3. [Maid.new][Maid.new]
	4. [Maid.Alive][Maid.Alive]
	5. [Maid.Assign][Maid.Assign]
	6. [Maid.AssignEach][Maid.AssignEach]
	7. [Maid.Clean][Maid.Clean]
	8. [Maid.Connect][Maid.Connect]
	9. [Maid.Destroy][Maid.Destroy]
	10. [Maid.Unassign][Maid.Unassign]
	11. [Maid.Wrap][Maid.Wrap]
	12. [Maid.__newindex][Maid.__newindex]

</td></tr></tbody>
</table>

## Maid.clean
[Maid.clean]: #maidclean
```
function Maid.clean(...: Task)
```

The **clean** function cleans each argument. Does nothing for arguments
that are not known task types. The following types are handled:

- `function`: The function is called.
- `thread`: The thread is canceled with `task.cancel`.
- `RBXScriptConnection`: The Disconnect method is called.
- `Instance`: The Destroy method is called.
- `table` without metatable: The value of each entry is cleaned. This applies
  recursively, and such tables are cleaned only once. The table is cleared
  unless it is frozen.
- `table` with metatable and Destroy function: Destroy is called as a method.

## Maid.wrap
[Maid.wrap]: #maidwrap
```
function Maid.wrap(...: Task): () -> ()
```

The **wrap** function encapsulates the given tasks in a function that
cleans them when called.

**Example:**
```lua
local conn = RunService.Heartbeat:Connect(function(dt)
	print("delta time", dt)
end)
return Maid.wrap(conn)
```

## Maid.new
[Maid.new]: #maidnew
```
function Maid.new(): Maid
```

The **new** constructor returns a new instance of the Maid class.

**Example:**
```lua
local maid = Maid.new()
```

## Maid.Alive
[Maid.Alive]: #maidalive
```
function Maid:Alive(): boolean
```

The **Alive** method returns false when the maid is destroyed, and true
otherwise.

**Example:**
```lua
if maid:Alive() then
	maid.heartbeat = RunService.Heartbeat:Connect(function(dt)
		print("delta time", dt)
	end)
end
```

## Maid.Assign
[Maid.Assign]: #maidassign
```
function Maid:Assign(name: any, task: Task?)
```

The **Assign** method performs an action depending on the type of
*task*. If *task* is nil, then the task assigned as *name* is cleaned, if
present. Otherwise, *task* is assigned to the maid as *name*. If a different
task (according to rawequal) is already assigned as *name*, then it is
cleaned.

If the maid is destroyed, *task* is cleaned immediately.

**Examples:**
```lua
maid:Assign("part", Instance.new("Part"))
```

Setting an assigned task to nil unassigns it from the maid and cleans it.

```lua
maid:Assign("part", nil) -- Remove task and clean it.
```

Assigning a task with a name that is already assigned cleans the previous
task first.

```lua
maid:Assign("part", Instance.new("Part"))
maid:Assign("part", Instance.new("WedgePart"))
```

## Maid.AssignEach
[Maid.AssignEach]: #maidassigneach
```
function Maid:AssignEach(...: Task)
```

The **AssignEach** method assigns each given argument as an unnamed
task.

If the maid is destroyed, the each task is cleaned immediately.

## Maid.Clean
[Maid.Clean]: #maidclean
```
function Maid:Clean(...: any)
```

The **Clean** method receives a number of names, and cleans the task
assigned to the maid for each name. Does nothing if the maid is destroyed,
and does nothing for names that have no assigned task.

## Maid.Connect
[Maid.Connect]: #maidconnect
```
function Maid:Connect(name: any?, signal: RBXScriptSignal, listener: () -> ())
```

The **Connect** method connects *listener* to *signal*, then assigns the
resulting connection to the maid as *name*. If *name* is nil, then the
connection is assigned as an unnamed task instead. Does nothing if the maid
is destroyed.

Connect is the preferred method when using maids to manage signals, primarily
to resolve problems concerning the assignment to a destroyed maid:
- Slightly more efficient than regular assignment, since the connection of
  the signal is never made.
- Certain signals can have side-effects when connecting, so avoiding the
  connection entirely is more correct.

**Example:**
```lua
maid:Connect("heartbeat", RunService.Heartbeat, function(dt)
	print("delta time", dt)
end)
```

## Maid.Destroy
[Maid.Destroy]: #maiddestroy
```
function Maid:Destroy()
```

The **Destroy** method cleans all tasks currently assigned to the maid.
Does nothing if the maid is destroyed.

**Example:**
```lua
maid:Destroy()
```

## Maid.Unassign
[Maid.Unassign]: #maidunassign
```
function Maid:Unassign(name: any): Task
```

The **Unassign** method removes the task assigned to the maid as *name*,
returning the task. Returns nil if no task is assigned as *name*, or if the
maid is Destroyed.

## Maid.Wrap
[Maid.Wrap]: #maidwrap
```
function Maid:Wrap(): () -> ()
```

The **Wrap** method encapsulates the maid by returning a function that
cleans the maid when called.

**Example:**
```lua
return maid:Wrap()
```

## Maid.__newindex
[Maid.__newindex]: #maid__newindex
```
Maid[any] = Task?
```

Assigns a task according to the [Assign][Maid.Assign] method, where the
index is the name, and the value is the task. If the index is a string that
is a single underscore, then the task is assigned according to
[AssignEach][Maid.AssignEach] instead.

Tasks can be assigned to the maid like a table:

```lua
maid.foo = task -- Assign task as "foo".
```

Setting an assigned task to nil unassigns it from the maid and cleans it:

```lua
maid.foo = nil -- Remove task and clean it.
```

Assigning a task with a name that is already assigned cleans the previous
task first:

```lua
maid.foo = task      -- Assign task as "foo".
maid.foo = otherTask -- Remove task, clean it, and assign otherTask as "foo".
```

Assigning to the special `_` index assigns an unnamed task (to explicitly
assign as `_`, use the [Assign][Maid.Assign] method).

```lua
maid._ = task      -- Assign task.
maid._ = otherTask -- Assign otherTask.
```

**Note**: Tasks assigned to the maid cannot be indexed:

```lua
print(maid.foo)
--> ERROR: cannot index maid with "foo"
```

