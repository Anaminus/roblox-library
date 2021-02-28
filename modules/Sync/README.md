# Sync
[Sync]: #user-content-sync

Sync provides primitives for working with threads and events.

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Sync][Sync]
	1. [Sync.allSignals][Sync.allSignals]
	2. [Sync.anySignal][Sync.anySignal]
	3. [Sync.cond][Sync.cond]
	4. [Sync.event][Sync.event]
	5. [Sync.group][Sync.group]
	6. [Sync.mutex][Sync.mutex]
	7. [Sync.resume][Sync.resume]
2. [Cond][Cond]
	1. [Cond.Fire][Cond.Fire]
	2. [Cond.Wait][Cond.Wait]
3. [Connection][Connection]
	1. [Connection.Connected][Connection.Connected]
	2. [Connection.Disconnect][Connection.Disconnect]
	3. [Connection.IsConnected][Connection.IsConnected]
4. [Event][Event]
	1. [Event.Destroy][Event.Destroy]
	2. [Event.Event][Event.Event]
	3. [Event.Fire][Event.Fire]
	4. [Event.Signal][Event.Signal]
5. [Group][Group]
	1. [Group.Add][Group.Add]
	2. [Group.Done][Group.Done]
	3. [Group.Wait][Group.Wait]
6. [Mutex][Mutex]
	1. [Mutex.Lock][Mutex.Lock]
	2. [Mutex.Unlock][Mutex.Unlock]
	3. [Mutex.Wrap][Mutex.Wrap]
7. [Signal][Signal]
	1. [Signal.Connect][Signal.Connect]

</td></tr></tbody>
</table>

## Sync.allSignals
[Sync.allSignals]: #user-content-syncallsignals
```
Sync.allSignals(signals: ...Signal)
```

allSignals returns a Signal that fires after all of the given signals
have fired.

Must not be used with signals that fire upon connecting (e.g. RemoteEvent).

## Sync.anySignal
[Sync.anySignal]: #user-content-syncanysignal
```
Sync.anySignal(signals: ...Signal): Signal
```

anySignal returns a Signal that fires after any of the given signals
have fired.

Must not be used with signals that fire upon connecting (e.g. RemoteEvent).

## Sync.cond
[Sync.cond]: #user-content-synccond
```
Sync.cond(): Cond
```

cond returns a new Cond.

## Sync.event
[Sync.event]: #user-content-syncevent
```
Sync.event(ctor: ((event: Event) -> (...any))?, dtor: ((event: Event, args: ...any) -> ())?): Event
```

event returns a new Event.

*ctor* and *dtor* optionally define a constructor and destructor. When the
first listener is connected to the event, *ctor* is called. When the last
listener is disconnected from the event, *dtor* is called, receiving the
values returned by *ctor*.

## Sync.group
[Sync.group]: #user-content-syncgroup
```
Sync.group(counter: number?): Group
```

group returns a new Group object. *counter* is an optional initial value
of the group counter, defaulting to 0.

## Sync.mutex
[Sync.mutex]: #user-content-syncmutex
```
Sync.mutex(): Mutex
```

mutex returns a new mutex.

## Sync.resume
[Sync.resume]: #user-content-syncresume
```
Sync.resume(thread: thread, ...any)
```

resume resumes *thread* with the remaining arguments, returning no
values. If the thread returns an error, then the error is printed along with
a stack trace.

# Cond
[Cond]: #user-content-cond
```
type Cond
```

Cond blocks threads until a condition is met.

## Cond.Fire
[Cond.Fire]: #user-content-condfire
```
Cond:Fire(...any)
```

Fire causes resumes all blocked threads. Each argument is returned by
the call to Wait. Values are not copied.

## Cond.Wait
[Cond.Wait]: #user-content-condwait
```
Cond:Wait(): (...any)
```

Wait blocks the running thread until Fire is called. Returns the
arguments passed to Fire.

# Connection
[Connection]: #user-content-connection
```
type Connection
```

Connection represents the connection to an Event.

## Connection.Connected
[Connection.Connected]: #user-content-connectionconnected
```
Connection.Connected: bool
```

Connected returns whether the Connection is connected. Readonly.

The Connected field exists to be API-compatible with
RBXScriptConnections. The IsConnected method is the preferred way to
check the connection.

## Connection.Disconnect
[Connection.Disconnect]: #user-content-connectiondisconnect
```
Connection:Disconnect()
```

Disconnect disconnects the connection, causing the associated listener
to no longer be called when the Event fires. Does nothing if the Connection
is already disconnected.

## Connection.IsConnected
[Connection.IsConnected]: #user-content-connectionisconnected
```
Connection:IsConnected(): bool
```

IsConnected returns whether the Connection is connected.

# Event
[Event]: #user-content-event
```
type Event
```

Event is an implementation of the Roblox event pattern, similar to the
BindableEvent type.

Event does not include a Wait method in its implementation. See [Cond][Cond]
for equivalent behavior.

## Event.Destroy
[Event.Destroy]: #user-content-eventdestroy
```
Event:Destroy()
```

Destroy releases all resources used by the object. Listeners are
disconnected, and the event's destructor is invoked, if defined.

## Event.Event
[Event.Event]: #user-content-eventevent
```
Event.Event: Signal
```

Event returns the Signal associated with the event.

The Event field exists to be API-compatible with BindableEvents. The
Signal method is the preferred way to get the signal.

## Event.Fire
[Event.Fire]: #user-content-eventfire
```
Event:Fire(args: ...any)
```

Fire calls all listeners connected to the event. *args* are passed to
each listener. Values are not copied.

## Event.Signal
[Event.Signal]: #user-content-eventsignal
```
Event:Signal(): Signal
```

Signal returns the Signal associated with the event.

# Group
[Group]: #user-content-group
```
type Group
```

Group is used to wait for a collection of threads to finish.

## Group.Add
[Group.Add]: #user-content-groupadd
```
Group:Add(delta: number?)
```

Add increments the group counter by delta or 1. If the counter becomes
zero, all threads blocked by Wait are released. Throws an error if the
counter becomes negative.

## Group.Done
[Group.Done]: #user-content-groupdone
```
Group:Done()
```

Done decrements the group counter by one.

## Group.Wait
[Group.Wait]: #user-content-groupwait
```
Group:Wait()
```

Wait blocks until the group counter is zero.

# Mutex
[Mutex]: #user-content-mutex
```
type Mutex
```

Mutex is a mutual exclusion lock.

## Mutex.Lock
[Mutex.Lock]: #user-content-mutexlock
```
Mutex:Lock()
```

Lock locks the mutex. If the lock is already in use, then the calling
thread blocks until the lock is available.

## Mutex.Unlock
[Mutex.Unlock]: #user-content-mutexunlock
```
Mutex:Unlock()
```

Unlock unlocks the mutex. If threads are blocked by the mutex, then the
next blocked mutex will be resumed.

## Mutex.Wrap
[Mutex.Wrap]: #user-content-mutexwrap
```
Mutex:Wrap(func: (...any)->(...any)) -> (...any)->(...any)
```

Wrap returns a function that, when called, locks the mutex before *func*
is called, and unlocks it after *func* returns. The new function receives and
returns the same parameters as *func*.

# Signal
[Signal]: #user-content-signal
```
type Signal
```

Signal encapsulates the part of an Event that connects listeners.

## Signal.Connect
[Signal.Connect]: #user-content-signalconnect
```
Signal:Connect(listener: (...any) -> ()): Connection
```

Connect attaches *listener* to the Event, to be called when the Event
fires. *listener* receives the arguments passed to Event.Fire.

