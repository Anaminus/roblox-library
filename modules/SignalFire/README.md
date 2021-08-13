# SignalFire
[SignalFire]: #user-content-signalfire

The SignalFire module provides a small implementation of the [observer
pattern][observer].

Notable differences from Roblox's Signal pattern:
- Everything is a function.
- Listeners may be threads as well as functions.
- Listeners are always deferred.
- Listeners are unordered. Relying on this was always a bad idea.
- After a signal is fired, every listener with a connection *at the time of
  firing* will be invoked.

[observer]: https://en.wikipedia.org/wiki/Observer_pattern

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [SignalFire][SignalFire]
	1. [SignalFire.new][SignalFire.new]
	2. [SignalFire.all][SignalFire.all]
	3. [SignalFire.any][SignalFire.any]
	4. [SignalFire.wait][SignalFire.wait]
	5. [SignalFire.wrap][SignalFire.wrap]
2. [Connector][Connector]
3. [Listener][Listener]
4. [Disconnector][Disconnector]
5. [Destroyer][Destroyer]
6. [Fire][Fire]

</td></tr></tbody>
</table>

## SignalFire.new
[SignalFire.new]: #user-content-signalfirenew
```
function SignalFire.new(): (Connector, Fire, Destroyer)
```

The **new** constructor returns a signal, represented by associated
[Connector][Connector], [Fire][Fire] and [Destroyer][Destroyer] functions.

## SignalFire.all
[SignalFire.all]: #user-content-signalfireall
```
function SignalFire.all(...: Connector): Connector
```

The **all** constructor returns the [Connector][Connector] of a signal
that fires after all of the signals associated with the given connectors have
fired. The signal fires up to one time.

## SignalFire.any
[SignalFire.any]: #user-content-signalfireany
```
function SignalFire.any(...: Connector): Connector
```

The **any** constructor returns the [Connector][Connector] of a signal
that fires after any of the signals associated with the given connectors have
fired. The signal passes the arguments of the first signal that fired it. The
signal fires up to one time.

## SignalFire.wait
[SignalFire.wait]: #user-content-signalfirewait
```
function SignalFire.wait(connect: Connector): (() -> (...any))
```

The **wait** constructor returns a function that, when called, yields
the running thread. The thread is resumed after the signal associated with
*connect* fires, returning the arguments passed through the signal.

## SignalFire.wrap
[SignalFire.wrap]: #user-content-signalfirewrap
```
function SignalFire.wrap(signal: RBXScriptSignal): Connector
```

The **wrap** constructor returns a [Connector][Connector] that wraps
*signal*. [Listeners][Listener] passed to the connector must be passable to
[RBXScriptSignal.Connect][Connect].

[Connect]: https://developer.roblox.com/en-us/api-reference/datatype/RBXScriptSignal#functions

# Connector
[Connector]: #user-content-connector
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
[Listener]: #user-content-listener
```
type Listener = (...any) -> () | thread
```

A **Listener** receives the arguments passed to a [Fire][Fire] function.

# Disconnector
[Disconnector]: #user-content-disconnector
```
type Disconnector = () -> ()
```

A **Disconnector** breaks the connection of a [Listener][Listener] to a
signal when called. Does nothing if the connection is already broken.

# Destroyer
[Destroyer]: #user-content-destroyer
```
type Destroyer = () -> ()
```

A **Destroyer** function destroys the signal by breaking all
connections. After the signal is destroyed, calling any associated function
does nothing.

# Fire
[Fire]: #user-content-fire
```
type Fire = (...any) -> ()
```

A **Fire** function invokes all of the [Listeners][Listener] connected
to the signal at the time Fire is called. Each given argument is passed to
each listener. Each function listener is called in its own separate thread.

The order in which listeners are invoked is **undefined**.

After the signal is destroyed, calling the function does nothing.

