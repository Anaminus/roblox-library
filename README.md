# Roblox library
This repository contains various modules, scripts, and snippets for use on
Roblox. Maybe you'll find something useful.

It is expected that code will be taken and adapted to suit the user's needs. As
such, files are not versioned, and APIs can change at any time. To find previous
revisions of a file, search the commit history.

Code in this repository is in the [public domain](UNLICENSE). Contributions will
not be accepted, but suggestions are welcome.

## Directories
Files within this repository are divided into a number of directories.

### documents
Contains non-script files of interest.

### modules
Each subdirectory contains the source code of a [ModuleScript][ModuleScript].
May also contain a few other files:
- A README file describing the API of the module, generated from the module
  source using [qdoc][qdoc].
- A `.test.lua` file that tests the module using the [Testing][Testing] module.
  Test runners may be generated automatically with the
  [test.rbxmk.lua](modules/test.rbxmk.lua) script.

A module may require another module in this repository. This is done by assuming
the two modules are siblings (`require(script.Parent.Module)`). Such lines may
have to be adjusted as needed.

Modules are not necessarily production ready.

### plugins
Each subdirectory contains a plugin for use in Roblox Studio. A plugin here can
be installed by copying the subdirectory to Studio's configured plugins folder.

### snippets
Contains shorter snippets of code that may be incorporated into the source of a
larger script.

[qdoc]: https://github.com/Anaminus/qdoc
[rbxmk]: https://github.com/Anaminus/rbxmk
[ModuleScript]: https://developer.roblox.com/en-us/api-reference/class/ModuleScript
[Testing]: modules/Testing
