# ModuleReflector
[ModuleReflector]: #modulereflector

Enables tracking and indirect reloading of a set of ModuleScripts by
requiring virtual copies.

The [Reflector][Reflector] reflects a configured module and its dependencies.
These reflections can be required without caching, allowing the modules to be
"reloaded" any number of times without affecting the original. This is
accomplished by creating virtual copies of modules and requiring them
instead.

An option to reflect breakpoints is also available, allowing reflections to
be debugged as though they were the originals.

To enable reloading, a [callback][Config.Changed] can be configured to inform
the user when the Source of the module changes, or that of any of its
dependencies. Changes can be [accumulated][Config.ChangeWindow] over time to
avoid invoking the callback too often.

<table>
<thead><tr><th>Table of Contents</th></tr></thead>
<tbody><tr><td>

1. [ModuleReflector][ModuleReflector]
	1. [ModuleReflector.new][ModuleReflector.new]
2. [Config][Config]
	1. [Config.RootParent][Config.RootParent]
	2. [Config.Module][Config.Module]
	3. [Config.Prefix][Config.Prefix]
	4. [Config.Changed][Config.Changed]
	5. [Config.ChangeWindow][Config.ChangeWindow]
3. [Reflector][Reflector]
	1. [Reflector.Module][Reflector.Module]
	2. [Reflector.Require][Reflector.Require]
	3. [Reflector.Debug][Reflector.Debug]
	4. [Reflector.Release][Reflector.Release]
	5. [Reflector.Destroy][Reflector.Destroy]

</td></tr></tbody>
</table>

## ModuleReflector.new
[ModuleReflector.new]: #modulereflectornew
```
ModuleReflector.new(config: Config): Reflector
```

Returns a new [Reflector][Reflector].

# Config
[Config]: #config
```
type Config
```

Configures a [Reflector][Reflector].

## Config.RootParent
[Config.RootParent]: #configrootparent
```
Config.RootParent: Instance?
```

An optional Instance specifying where the virtual game tree will be
located. Defaults to the DataModel. Note that, if the RootParent is not
the DataModel, then the full path of the RootParent will be included in
stack traces.

## Config.Module
[Config.Module]: #configmodule
```
Config.Module: ModuleScript
```

The root module to reflect.

## Config.Prefix
[Config.Prefix]: #configprefix
```
Config.Prefix: string?
```

An optional prefix assigned as the Name of the root of the virtual
game tree.

## Config.Changed
[Config.Changed]: #configchanged
```
Config.Changed: (refl: Reflector) -> ()
```

Called when the Source of the root module or a dependency changes.
Receives the Reflector itself to enable easy reloading.

## Config.ChangeWindow
[Config.ChangeWindow]: #configchangewindow
```
Config.ChangeWindow: number?
```

Number of seconds to accumulate changes before calling
[Changed][Config.Changed]. Defaults to 1.

# Reflector
[Reflector]: #reflector
```
type Reflector
```

Reflects a configured module and its dependencies.

## Reflector.Module
[Reflector.Module]: #reflectormodule
```
Reflector.Module: ModuleScript
```

The root module being reflected. Read-only.

## Reflector.Require
[Reflector.Require]: #reflectorrequire
```
Reflector:Require(): (result: any, err: error)
```

Initializes a new reflection of the module and attempts to require
it, starting a new run.

On success, Require returns the result of requiring the module, and nil,
indicating no error occurred. This run becomes the active run, replacing
any previously active run.

On failure, the run is canceled, and Require returns nil and an error
indicating why the run failed. Any previously active run continues as
normal.

## Reflector.Debug
[Reflector.Debug]: #reflectordebug
```
Reflector:Debug(): (result: any, err: error)
```

Behaves the same as [Require][Reflector.Require], but enables
debugging by synchronizing breakpoints from modules to their reflections.

Due to security limitations, this method cannot be called by plugins.
However, it can be called by Studio's command bar. Recommended use of
this method is to expose it to the command bar through the _G table.

## Reflector.Release
[Reflector.Release]: #reflectorrelease
```
Reflector:Release()
```

Stops any active run, if present.

## Reflector.Destroy
[Reflector.Destroy]: #reflectordestroy
```
Reflector:Destroy()
```

Destroys the Reflector, stopping any active runs and decoupling from
the module.

