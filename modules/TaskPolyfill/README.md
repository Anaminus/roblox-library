# TaskPolyfill
[TaskPolyfill]: #taskpolyfill

Provides a compatiblity shim for Roblox's task library by implementing a
scheduler.

Example usage:

```lua
local TaskPolyfill = require("TaskPolyfill")

local scheduler = TaskPolyfill.new()
scheduler:SetErrorHandler(function(thread: thread?, err: any)
	print("ERROR:", err)
	if thread then
		print(debug.traceback(thread))
	end
end)

local task = scheduler:Library()

task.defer(function()
	task.delay(1.25, function()
		local function a()
			error("errored")
		end
		a()
	end)
	print("A", task.wait(1))
	print("B", task.wait(0.5))
	print("C", task.wait(0.75))
end)

print("BEGIN SCHEDULER")
local i = 0
while scheduler:Step(i/60) do
	i += 1
end
print("END SCHEDULER", i/60)

--> BEGIN SCHEDULER
--> A	1
--> ERROR:	script:16: errored
--> script:16 function a
--> script:18
-->
--> B	0.5
--> C	0.75
--> END SCHEDULER	2.25
```

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [TaskPolyfill][TaskPolyfill]
	1. [TaskPolyfill.new][TaskPolyfill.new]
2. [Scheduler][Scheduler]
	1. [Scheduler.Library][Scheduler.Library]
	2. [Scheduler.SetErrorHandler][Scheduler.SetErrorHandler]
	3. [Scheduler.Step][Scheduler.Step]
3. [ErrorHandler][ErrorHandler]
4. [TaskLibrary][TaskLibrary]

</td></tr></tbody>
</table>

## TaskPolyfill.new
[TaskPolyfill.new]: #taskpolyfillnew
```
TaskPolyfill.new(): Scheduler
```

Returns a new [Scheduler][Scheduler].

# Scheduler
[Scheduler]: #scheduler
```
type Scheduler
```

Schedules threads for the purpose of emulating Roblox's task library.

## Scheduler.Library
[Scheduler.Library]: #schedulerlibrary
```
function Scheduler:Library(): TaskLibrary
```

Returns a new [TaskLibrary][TaskLibrary] that uses the scheduler to
manage threads.

The desynchronize and synchronize functions are not implemented; calling them
does nothing.

## Scheduler.SetErrorHandler
[Scheduler.SetErrorHandler]: #schedulerseterrorhandler
```
Scheduler:SetErrorHandler(handler: ErrorHandler?)
```

SetErrorHandler sets an [ErrorHandler][ErrorHandler] that is called when
a thread produces an error.

By default, no function is set, causing any errors to be discarded.

## Scheduler.Step
[Scheduler.Step]: #schedulerstep
```
function Scheduler:Step(time: number): boolean
```

Performs one frame of the scheduler. *time* is the current time. Returns
true if the scheduler is managing any threads.

Examples of usage:

```lua
-- Drive scheduler using Roblox APIs.
task.spawn(function()
	while true do
		sheduler:Step(os.clock())
		RunService.Heartbeat:Wait()
	end
end)
```

```lua
-- One-off simulation of clock running at 60 FPS.
local i = 0
while scheduler:Step(i/60) do
	i += 1
end
```

# ErrorHandler
[ErrorHandler]: #errorhandler
```
type ErrorHandler = (thread: thread?, err: any) -> ()
```

Called when a thread managed by a [Scheduler][Scheduler] produces an
error. *thread* is the thread that produced the error, which can be passed to
debug.traceback to acquire a stack trace of the error. *thread* will be nil
if the error originated from the scheduler. *err* is the produced error.

# TaskLibrary
[TaskLibrary]: #tasklibrary
```
type TaskLibrary = {
	cancel: (thread) -> (),
	defer: <A..., R...>(((A...) -> (R...)) | thread, A...) -> thread,
	delay: <A..., R...>(number?, ((A...) -> (R...)) | thread, A...) -> thread,
	desynchronize: () -> (),
	spawn: <A..., R...>(((A...) -> (R...)) | thread, A...) -> thread,
	synchronize: () -> (),
	wait: (number?) -> number,
}
```

A drop-in replacement of Roblox's task library.

