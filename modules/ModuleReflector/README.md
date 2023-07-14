# ModuleReflector
[ModuleReflector]: #modulereflector

Enables tracking and indirect reloading of a set of ModuleScripts by
requiring virtual copies.

The [Reflector][Reflector] reflects a configured module and its dependencies.
These reflections can be required without caching, allowing the modules to be
"reloaded" any number of times without affecting the original. This is
accomplished by creating virtual copies of modules and requiring them
instead.

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
	1. [Config.Module][Config.Module]
	2. [Config.Prefix][Config.Prefix]
	3. [Config.Changed][Config.Changed]
	4. [Config.ChangeWindow][Config.ChangeWindow]
3. [Reflector][Reflector]
	1. [Reflector.Module][Reflector.Module]
	2. [Reflector.Require][Reflector.Require]
	3. [Reflector.Release][Reflector.Release]
	4. [Reflector.Destroy][Reflector.Destroy]

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

