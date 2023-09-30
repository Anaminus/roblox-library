# LiveBind
A plugin for creating living bindings to tags. Useful for applying modular
behaviors to instances as you develop.

## Bindings
A collection of useful bindings is available in the [bindings](bindings)
directory.

## Usage
Instances with the `LiveBind` tag become containers for **bindings**. Any child
ModuleScript is considered a binding.

When a binding has no syntax errors and returns a function, that function will
be called with any instance that has a tag matching the Name of the binding.

For example, consider a ModuleScript named `Greet`, that has the following
Source:

```lua
return function(context, instance)
	print("hello", instance)
	ctx:AssignEach(function()
		print("bye", instance)
	end)
end
```

With this, any instance that gains the `Greet` tag will cause `hello instance`
to be printed. Likewise, any instance that loses the `Greet` tag will cause `bye
instance` to be printed.

The function returned by the binding has the following signature:

```
(context: Scope.Context, instance: Instance) -> ()
```

That is, the second argument is the instance that gained the tag, and the first
argument is a [Scope context][context] that remains alive while the instance has
the tag. The context is used principally to manage and clean up behaviors
applied to the instance.

The binding may instead return a table with two fields:

```lua
{
	instance: (context: Scope.Context, instance: Instance) -> (),
	tag: (context: Scope.Context) -> ()?
}
```

The `instance` field is the same function as above. The `tag` field is an
optional function that receives a context. The lifetime of this context is
attached to the tag itself. That is, the function is called when the tag is
first used by any instance, and the context is destroyed when the tag is no
longer used by any instances.

## Installation
This plugin can be built with [Rojo][rojo].

```bash
cd roblox-library/plugins/LiveBind
rojo build --output /path/to/plugins/directory/LiveBind.rbxm
```

[context]: ../../modules/Scope/README.md#scopecontext
[rojo]: https://rojo.space/
