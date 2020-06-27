# Command Bar Utility Plugins
Modular utilities for use in Studio's command bar.

Each file that is included under Studio's plugin folder will run as a plugin.
Files can be included selectively to enable only the desired utlities.

Most of the plugins put APIs in the _G table, which can then be accessed from
the command bar. Including [c.lua](c.lua) and then calling `_G.c()` will load
everything in `_G` into the command bar's environment, enabling more convenient
access.
