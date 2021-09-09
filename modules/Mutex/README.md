# Mutex
[Mutex]: #user-content-mutex
```
function Mutex(): Mutex
```

Mutex is a mutual exclusion lock.

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Mutex][Mutex]
	1. [Mutex.Lock][Mutex.Lock]
	2. [Mutex.Unlock][Mutex.Unlock]
	3. [Mutex.Wrap][Mutex.Wrap]

</td></tr></tbody>
</table>

## Mutex.Lock
[Mutex.Lock]: #user-content-mutexlock
```
function Mutex:Lock()
```

Lock locks the mutex. If the lock is already in use, then the calling
thread is blocked until the lock is available.

## Mutex.Unlock
[Mutex.Unlock]: #user-content-mutexunlock
```
function Mutex:Unlock()
```

Unlock unlocks the mutex. If threads are blocked by the mutex, then the
next blocked thread will be resumed.

## Mutex.Wrap
[Mutex.Wrap]: #user-content-mutexwrap
```
function Mutex:Wrap(func: (...any)->(...any)): (...any)->(...any)
```

Wrap returns a function that, when called, locks the mutex before *func*
is called, and unlocks it after *func* returns. The new function receives and
returns the same parameters as *func*.

