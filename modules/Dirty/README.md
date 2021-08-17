# Dirty
[Dirty]: #user-content-dirty

The **Dirty** module detects changes to an instance tree.

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [Dirty][Dirty]
	1. [Dirty.monitor][Dirty.monitor]

</td></tr></tbody>
</table>

## Dirty.monitor
[Dirty.monitor]: #user-content-dirtymonitor
```
function Dirty.monitor(root: Instance, window: number, callback: () -> ()): (disconnect: () -> ())
```

The **monitor** function begins monitoring *root* for changes. After a
change occurs, the monitor will wait *window* seconds before invoking
*callback*. During this time, other changes will not cause *callback* to be
invoked. That is, *callback* will not be invoked more frequently than
*window*.

If *window* is less than or equal to 0, then every change will invoke
*callback* immediately.

Calling *disconnect* will cause monitoring to stop and release any resources.

