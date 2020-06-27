--[[
Dump _G

	Load the _G table into the current environment to access values more
	directly.

API

	-- Load _G into the current environment.
	_G.c()

Examples

	-- Selection plugin without dump.
	_G.s[1]:Destroy()

	-- Selection plugin with dump.
	_G.c()
	s[1]:Destroy()

]]

function _G.c()
	local env = getfenv(2)
	for k, v in pairs(_G) do
		env[k] = v
	end
end
