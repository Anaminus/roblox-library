--[[ Sched

DESCRIPTION

	Implements a custom scheduler for managing threads.

SYNOPSIS

	Sched = require(...)
	driver = Sched.Driver.Heartbeat
	driver = Sched.Driver.Stepped
	driver = Sched.Driver.RenderStepped
	scheduler = Sched.New(driver)
	scheduler:SetErrorHandler(handler)
	scheduler:SetMinWaitTime(duration)
	scheduler:SetBudget(duration)
	scheduler:Delay(duration, func)
	cancel = scheduler:DelayCancel(duration, func)
	scheduler:Spawn(func)
	scheduler:Wait(duration)
	scheduler:Yield()

API

	Sched.Driver: {[string]: Driver}

		Driver contains constants used to specify a Driver.

	Sched.Driver.Heartbeat: Driver

		Heartbeat uses RunService.Heartbeat as the driver. This is the
		default.

	Sched.Driver.Stepped: Driver

		Stepped uses RunService.Stepped as the driver.

	Sched.Driver.RenderStepped: Driver

		RenderStepped uses RunService.RenderStepped as the driver.

	Sched.New(driver: Driver?) => (scheduler: Scheduler)

		New returns a new Scheduler driven by the specified driver, or Heartbeat
		if no driver is specified.

	Scheduler:SetErrorHandler(handler: ErrorHandler)

		SetErrorHandler sets a function that is called when a thread returns an
		error. The first argument is the thread, which may be used with
		debug.traceback to acquire a stack trace. The second argument is the
		error message.

		By default, no function is set, causing any errors to be discarded.

	Scheduler:SetMinWaitTime(duration: number?)

		SetMinWaitTime specifies the minimum duration that threads are allowed
		to yield, in seconds. Defaults to 0.

	Scheduler:SetBudget(duration: number?)

		SetBudget specifies the duration each iteration of the driver is allowed
		to run, in seconds. Defaults to infinite duration.

		When the budget is exceeded, the driver suspends, resuming where it left
		off on the next iteration.

	Scheduler:Delay(duration: number, func: Function)

		Delay queues `func` to be called after waiting for `duration` seconds.
		`duration` is affected by MinWaitTime.

	Scheduler:DelayCancel(duration: number, func: Function) => (cancel: Function)

		DelayCancel queues `func` to be called after waiting for `duration`
		seconds. Returns a function that, when called, cancels the delayed call.
		`duration` is affected by MinWaitTime.

	Scheduler:Spawn(func: Function)

		Spawn queues `func` to be called as soon as possible.

	Scheduler:Wait(duration: number)

		Wait queues the running thread to be resumed after waiting for
		`duration` seconds. `duration` is affected by MinWaitTime.

	Scheduler:Yield()

		Yield queues the running thread to be resumed as soon as possible.

	type ErrorHandler = (thread: thread, err: string) => ()

		ErrorHandler is used to handle an error that occurred within a thread.
		`thread` is the thread that returned the error, which may be used with
		debug.traceback to acquire a stack trace. `err` is the error message.

	type Function = () => ()

		Function is a generic function that receives no parameters and returns
		no values.

]]
