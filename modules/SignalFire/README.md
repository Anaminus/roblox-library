# SignalFire
[SignalFire]: #signalfire

The SignalFire module provides a small implementation of the [observer
pattern][observer].

Notable differences from Roblox's Signal pattern:
- Everything is a function.
- Listeners may be threads as well as functions.
- Listeners are always deferred.
- Listeners are unordered.
- After a signal is fired, only every listener with a connection *at the time
  of firing* will be invoked.

[observer]: https://en.wikipedia.org/wiki/Observer_pattern

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [SignalFire][SignalFire]
	1. [SignalFire.new][SignalFire.new]
	2. [SignalFire.bindable][SignalFire.bindable]
	3. [SignalFire.all][SignalFire.all]
	4. [SignalFire.any][SignalFire.any]
	5. [SignalFire.limit][SignalFire.limit]
	6. [SignalFire.wait][SignalFire.wait]
	7. [SignalFire.wrap][SignalFire.wrap]
2. [Connector][Connector]
3. [Listener][Listener]
4. [Disconnector][Disconnector]
5. [Fire][Fire]
6. [Destroyer][Destroyer]
7. [Bindable][Bindable]
8. [Signal][Signal]
9. [Connection][Connection]

</td></tr></tbody>
</table>

## SignalFire.new
[SignalFire.new]: #signalfirenew
```
function SignalFire.new(): (Connector, Fire, Destroyer)
```

The **new** constructor returns a signal, represented by associated
[Connector][Connector], [Fire][Fire] and [Destroyer][Destroyer] functions.

## SignalFire.bindable
[SignalFire.bindable]: #signalfirebindable

The **bindable** constructor returns a new [Bindable][Bindable],
implemented using the functions from [SignalFire.new][SignalFire.new].

## SignalFire.all
[SignalFire.all]: #signalfireall
```
function SignalFire.all(...: Connector): (Connector, Destroyer)
```

The **all** function returns the [Connector][Connector] and
[Destroyer][Destroyer] of a signal that fires after all of the signals
associated with the given connectors have fired. The signal will fire up to
one time.

## SignalFire.any
[SignalFire.any]: #signalfireany
```
function SignalFire.any(...: Connector): (Connector, Destroyer)
```

The **any** function returns the [Connector][Connector] and
[Destroyer][Destroyer] of a signal that fires after any of the signals
associated with the given connectors have fired. The signal passes the
arguments of the first signal that fired it. The signal will fire until
destroyed.

## SignalFire.limit
[SignalFire.limit]: #signalfirelimit
```
function SignalFire.limit(connect: Connector, limit: number?): Connector
```

The **limit** function wraps *connect*, returning a
[Connector][Connector] that will cause its connected [Listeners][Listener] to
be fired only up to *limit* times. The limit defaults to 1.

## SignalFire.wait
[SignalFire.wait]: #signalfirewait
```
function SignalFire.wait(connect: Connector): (() -> (...any))
```

The **wait** function returns a function that, when called, yields the
running thread. The thread is resumed after the signal associated with
*connect* fires, returning the arguments passed through the signal.

## SignalFire.wrap
[SignalFire.wrap]: #signalfirewrap
```
function SignalFire.wrap(signal: RBXScriptSignal): Connector
```

The **wrap** function returns a [Connector][Connector] that wraps
*signal*. If the connector is passed a thread as a [Listener][Listener], it
is connected via a function that calls task.defer with the thread and the
received arguments.

# Connector
[Connector]: #connector
```
type Connector = (listener: Listener) -> Disconnector
```

A **Connector** creates a connection of [*listener*][Listener] to the
signal. The returned [Disconnector][Disconnector] breaks this connection when
called.

The same listener may be connected multiple times, and will be called for
each number of times it is connected.

After the signal is destroyed, calling the function does nothing except
return a disconnector, which also does nothing when called.

# Listener
[Listener]: #listener
```
type Listener = (...any) -> () | thread
```

A **Listener** receives the arguments passed to a [Fire][Fire] function.

# Disconnector
[Disconnector]: #disconnector
```
type Disconnector = () -> ()
```

A **Disconnector** breaks the connection of a [Listener][Listener] to a
signal when called. Does nothing if the connection is already broken.

# Fire
[Fire]: #fire
```
type Fire = (arguments: ...any) -> ()
```

A **Fire** function invokes all of the [Listeners][Listener] connected
to the signal at the time Fire is called. Each given argument is passed to
each listener. Each function listener is called in its own separate thread.

The order in which listeners are invoked is **undefined**.

After the signal is destroyed, calling this function throws an error.

# Destroyer
[Destroyer]: #destroyer
```
type Destroyer = () -> ()
```

A **Destroyer** function destroys the signal by breaking all
connections. After the signal is destroyed, calling the [Fire][Fire] or
Destroyer functions will throw an error. The [Connector][Connector] function
will do nothing but return a disconnector, which will also do nothing.

# Bindable
[Bindable]: #bindable
```
type Bindable = {
	Event   : Signal,
	Fire    : (self: Bindable, ...any) -> (),
	Destroy : (self: Bindable) -> (),
}
```

A **Bindable** implements the principle interface of
[BindableEvent][BindableEvent].

[BindableEvent]: https://developer.roblox.com/en-us/api-reference/class/BindableEvent

# Signal
[Signal]: #signal
```
type Signal = {
	Connect : (self: Signal, listener: Listener) -> (Connection),
	Wait    : (self: Signal) -> (...any),
}
```

A **Signal** implements the same interface as
[RBXScriptSignal][RBXScriptSignal]. Not to be confused with the signal
represented by an associated [Connector][Connector], [Fire][Fire] and
[Destroyer][Destroyer].

[RBXScriptSignal]: https://developer.roblox.com/en-us/api-reference/datatype/RBXScriptSignal

# Connection
[Connection]: #connection
```
type Connection = {
	IsConnected : boolean,
	Disconnect  : (self: Connection) -> (),
}
```

A **Connection** implements the same interface as
[RBXScriptConnection][RBXScriptConnection].

[RBXScriptConnection]: https://developer.roblox.com/en-us/api-reference/datatype/RBXScriptConnection

