--[[
Services

	Quickly access services.

DESCRIPTION

	Each accessible service is available as:

		_G[ServiceName]

	Where `ServiceName` is the ClassName of the service. A name is trimmed to
	exclude the trailing "Service" if possible.

EXAMPLES

	print(_G.Workspace) -- Workspace
	print(_G.Players)   -- Players
	print(_G.Lighting)  -- Lighting
	print(_G.Run)       -- RunService
	print(_G.Http)      -- HttpService
	print(_G.UserInput) -- UserInputService

]]

for _, service in ipairs(game:GetChildren()) do
	local ok, service = pcall(function(service)
		return game:GetService(service.ClassName)
	end, service)
	if ok and service then
		local name = service.ClassName
		if name:match("Service$") then
			name = name:sub(1, #name-7)
		end
		_G[name] = service
	end
end
