# Sched
[Sched]: #user-content-sched

Implements a custom scheduler for managing threads.

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Sched][Sched]
	1. [Sched.driver][Sched.driver]
	2. [Sched.new][Sched.new]
2. [Scheduler][Scheduler]
	1. [Scheduler.Delay][Scheduler.Delay]
	2. [Scheduler.DelayCancel][Scheduler.DelayCancel]
	3. [Scheduler.SetBudget][Scheduler.SetBudget]
	4. [Scheduler.SetErrorHandler][Scheduler.SetErrorHandler]
	5. [Scheduler.SetMinWaitTime][Scheduler.SetMinWaitTime]
	6. [Scheduler.Spawn][Scheduler.Spawn]
	7. [Scheduler.Wait][Scheduler.Wait]
	8. [Scheduler.Yield][Scheduler.Yield]

</td></tr></tbody>
</table>

## Sched.driver
[Sched.driver]: #user-content-scheddriver
```
Sched.driver = {
	Heartbeat     = 0,
	Stepped       = 1,
	RenderStepped = 2,
}
```

Driver contains constants used to specify a Driver.

The following drivers are available:

Name          | Value | Description
--------------|-------|------------
Heartbeat     | 0     | Uses RunService.Heartbeat as the driver. This is the default.
Stepped       | 1     | Uses RunService.Stepped as the driver.
RenderStepped | 2     | Uses RunService.RenderStepped as the driver.

## Sched.new
[Sched.new]: #user-content-schednew
```
Sched.new(driver: Driver?): Scheduler
```

new returns a new Scheduler driven by *driver*, or Heartbeat if no
driver is specified.

# Scheduler
[Scheduler]: #user-content-scheduler
```
type Scheduler
```

Scheduler manages the yielding and resuming of threads in a queue.

## Scheduler.Delay
[Scheduler.Delay]: #user-content-schedulerdelay
```
Scheduler:Delay(duration: number, func: ()->())
```

Delay queues *func* to be called after waiting for *duration* seconds.
*duration* is affected by MinWaitTime.

## Scheduler.DelayCancel
[Scheduler.DelayCancel]: #user-content-schedulerdelaycancel
```
Scheduler:Delay(duration: number, func: ()->()): (cancel: ()->())
```

DelayCancel queues *func* to be called after waiting for *duration*
seconds. Returns a function that, when called, cancels the delayed call.
*duration* is affected by MinWaitTime.

## Scheduler.SetBudget
[Scheduler.SetBudget]: #user-content-schedulersetbudget
```
Scheduler:SetBudget(duration: number?)
```

SetBudget specifies the duration each iteration of the driver is allowed
to run, in seconds. Defaults to infinite duration.

When the budget is exceeded, the driver suspends, resuming where it left off
on the next iteration.

## Scheduler.SetErrorHandler
[Scheduler.SetErrorHandler]: #user-content-schedulerseterrorhandler
```
Scheduler:SetErrorHandler(handler: ((thread: thread, err: any) -> ())?)
```

SetErrorHandler sets a function that is called when a thread returns an
error. The first argument is the thread, which may be used with
debug.traceback to acquire a stack trace. The second argument is the error
value.

By default, no function is set, causing any errors to be discarded.

## Scheduler.SetMinWaitTime
[Scheduler.SetMinWaitTime]: #user-content-schedulersetminwaittime
```
Scheduler:SetMinWaitTime(duration: number?)
```

SetMinWaitTime specifies the minimum duration that threads are allowed
to yield, in seconds. Defaults to 0.

## Scheduler.Spawn
[Scheduler.Spawn]: #user-content-schedulerspawn
```
Scheduler:Spawn(func: ()->())
```

Spawn queues *func* to be called as soon as possible.

## Scheduler.Wait
[Scheduler.Wait]: #user-content-schedulerwait
```
Scheduler:Wait(duration: number)
```

Wait queues the running thread to be resumed after waiting for
*duration* seconds. *duration* is affected by MinWaitTime.

## Scheduler.Yield
[Scheduler.Yield]: #user-content-scheduleryield
```
Scheduler:Yield()
```

Yield queues the running thread to be resumed as soon as possible.

