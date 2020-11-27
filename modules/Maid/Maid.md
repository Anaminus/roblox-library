# Maid
[Maid]: #user-content-maid

Maid manages tasks. A task is a value that represents the active state
of some procedure or object. Finishing a task causes the procedure or object
to be finalized. How this occurs depends on the type:

- **function**: The function is called with no arguments.
- **RBXScriptConnection**: The Disconnect method is called.
- **Instance**: The Destroy method is called.
- **Maid**: The FinishAll method is called.

Unknown task types are held by the maid until finished, but are otherwise
ignored.

A task that yields is treated as an error.

## Maid.is
[Maid.is]: #user-content-maidis
```
Maid.is(v: any): boolean
```

is returns whether *v* is an instance of Maid.

## Maid.new
[Maid.new]: #user-content-maidnew
```
Maid.new(): Maid
```

new returns a new Maid instance.

## Maid.Finish
[Maid.Finish]: #user-content-maidfinish
```
Maid:Finish(...string): (errs: {string}?)
```

Finish completes the tasks of the given names. Names with no assigned
task are ignored. Returns an error for each task that yields or errors, or
nil if all tasks finished successfully.

## Maid.FinishAll
[Maid.FinishAll]: #user-content-maidfinishall
```
Maid:FinishAll(): (errs: {string}?)
```

FinishAll completes all assigned tasks. Returns an error for each task
that yields or errors, or nil if all tasks finished successfully.

## Maid.Task
[Maid.Task]: #user-content-maidtask
```
Maid:Task(name: string, task: any?): (err: string?)
```

Task assigns *task* to the maid with the given name. If *task* is nil,
and the maid has task *name*, then the task is completed. Returns an error if
the task yielded or errored.

## Maid.TaskEach
[Maid.TaskEach]: #user-content-maidtaskeach
```
Maid:TaskEach(...any)
```

TaskEach assigns each argument as an unnamed task.

## Maid.\__newindex
[Maid.\__newindex]: #user-content-maidnewindex
```
Maid[name: string] = (task: any?)
```

Alias for Task. If an error occurs, it is thrown.

