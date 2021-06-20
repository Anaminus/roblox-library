# Maid
[Maid]: #user-content-maid

Maid manages tasks. A task is a value that represents the active state
of some procedure or object. Finishing a task causes the procedure or object
to be finalized. How this occurs depends on the type:

- `() -> error?`: The function is called. If an error is returned, it is
  propagated to the caller as a [TaskError][TaskError].
- `RBXScriptConnection`: The Disconnect method is called.
- `Instance`: The Parent property is set to nil.
- `Maid`: The FinishAll method is called. If an error is returned, it is
  propagated to the caller as a [TaskError][TaskError].
- `table` (no metatable): Each element is finalized.

Unknown task types are held by the maid until finished, but are otherwise
ignored.

A task that yields is treated as an error. Additionally, an error occurs if a
maid tries to finalize a task while already finalizing a task.

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Maid][Maid]
	1. [Maid.new][Maid.new]
	2. [Maid.finish][Maid.finish]
	3. [Maid.is][Maid.is]
	4. [Maid.Finish][Maid.Finish]
	5. [Maid.FinishAll][Maid.FinishAll]
	6. [Maid.Skip][Maid.Skip]
	7. [Maid.Task][Maid.Task]
	8. [Maid.TaskEach][Maid.TaskEach]
	9. [Maid.\__newindex][Maid.\__newindex]
2. [Errors][Errors]
3. [TaskError][TaskError]

</td></tr></tbody>
</table>

## Maid.new
[Maid.new]: #user-content-maidnew
```
Maid.new(): Maid
```

new returns a new Maid instance.

## Maid.finish
[Maid.finish]: #user-content-maidfinish
```
Maid.finish(task: any): error
```

finish completes the given task. *task* is any value that can be
assigned to a Maid. Returns an error if the task failed. If the task throws
an error, then finish makes no attempt to catch it.

## Maid.is
[Maid.is]: #user-content-maidis
```
Maid.is(v: any): boolean
```

is returns whether *v* is an instance of Maid.

## Maid.Finish
[Maid.Finish]: #user-content-maidfinish
```
Maid:Finish(...: string): (errs: Errors?)
```

Finish completes the tasks of the given names. Names with no assigned
task are ignored. Returns a [TaskError][TaskError] for each task that yields
or errors, or nil if all tasks finished successfully.

## Maid.FinishAll
[Maid.FinishAll]: #user-content-maidfinishall
```
Maid:FinishAll(): (errs: Errors?)
```

FinishAll completes all assigned tasks. Returns a [TaskError][TaskError]
for each task that yields or errors, or nil if all tasks finished
successfully.

## Maid.Skip
[Maid.Skip]: #user-content-maidskip
```
Maid:Skip(...: string)
```

Skip removes the tasks of the given names without completing them. Names
with no assigned task are ignored.

## Maid.Task
[Maid.Task]: #user-content-maidtask
```
Maid:Task(name: string, task: any?): (err: error?)
```

Task assigns *task* to the maid with the given name. If *task* is nil,
and the maid has task *name*, then the task is completed. Returns a
[TaskError][TaskError] if the completed task yielded or errored.

*name* is not allowed to begin with an underscore.

## Maid.TaskEach
[Maid.TaskEach]: #user-content-maidtaskeach
```
Maid:TaskEach(...: any)
```

TaskEach assigns each argument as an unnamed task.

## Maid.\__newindex
[Maid.\__newindex]: #user-content-maid__newindex
```
Maid[name: string] = (task: any?)
```

Alias for Task. If an error occurs, it is thrown.

# Errors
[Errors]: #user-content-errors
```
type Errors = {error}
```

Errors is a list of errors.

# TaskError
[TaskError]: #user-content-taskerror
```
type TaskError = {Name: string|number, Err: error}
```

TaskError indicates an error that occurred from the completion of a
task. The Name field is the name of the task that errored. The type will be a
number if the task was unnamed. The Err field is the underlying error that
occurred.

