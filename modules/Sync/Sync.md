# Sync
[Sync]: #user-content-sync

Sync provides primitives for working with threads and signals.

## Sync.allSignals
[Sync.allSignals]: #user-content-syncallsignals
```
Sync.allSignals(signals: ...Event)
```

allSignals blocks until all of the given signals have fired.

Must not be used with signals that fire upon connecting (e.g. RemoteEvent).

## Sync.anySignal
[Sync.anySignal]: #user-content-syncanysignal
```
Sync.anySignal(signals: ...Event)
```

anySignal blocks until any of the given signals have fired.

Must not be used with signals that fire upon connecting (e.g. RemoteEvent).

## Sync.cond
[Sync.cond]: #user-content-synccond
```
Sync.cond(): Cond
```

cond returns a new Cond.

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

## Sync.signal
[Sync.signal]: #user-content-syncsignal
```
Sync.signal(ctor: ((signal: Signal) -> (...any))?, dtor: ((signal: Signal, args: ...any) -> ())?): Signal
```

signal returns a new Signal.

*ctor* and *dtor* optionally define a constructor and destructor. When the
first listener is connected to the signal, *ctor* is called. When the last
listener is disconnected from the signal, *dtor* is called, receiving the
values returned by *ctor*.

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

Connection represents the connection to a Signal.

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
to no longer be called when the Signal fires. Does nothing if the Connection
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

Event encapsulates the part of a Signal that can be listened on.

## Event.Connect
[Event.Connect]: #user-content-eventconnect
```
Event:Connect(listener: (...any) -> ()): Connection
```

Connect attaches *listener* to the Signal, to be called when the Signal
fires. *listener* receives the arguments passed to Signal.Fire.

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

Signal is an implementation of the Roblox signal pattern, similar to the
RBXScriptSignal type.

Signal does not include the Wait method in its implementation. See
[Cond][Types.Cond] for equivalent behavior.

## Signal.Destroy
[Signal.Destroy]: #user-content-signaldestroy
```
Signal:Destroy()
```

Destroy releases all resources used by the object. Listeners are
disconnected, and the signal's destructor is invoked, if defined.

## Signal.Event
[Signal.Event]: #user-content-signalevent
```
Signal.Event: Event
```

Event returns the Event associated with the signal.

The Event field exists to be API-compatible with BindableEvents. The
GetEvent method is the preferred way to get the event.

## Signal.Fire
[Signal.Fire]: #user-content-signalfire
```
Signal:Fire(args: ...any)
```

Fire calls all listeners connected to the signal. *args* are passed to
each listener. Values are not copied.

## Signal.GetEvent
[Signal.GetEvent]: #user-content-signalgetevent
```
Signal:GetEvent(): Event
```

GetEvent returns the Event associated with the signal.

