--[[
	Step6D2a_CheckWatchSync  (Step 6D.2a, TEMPORARY Command Bar script)

	READ-ONLY. Changes nothing. Run in Studio EDIT mode (not Play), with Rojo
	connected. Shows whether Studio's copies of the watcher match the files on
	disk, i.e. whether Rojo actually delivered them:
	  - how many GymRackWatchProbe scripts exist, and where;
	  - for each: class, Enabled, RunContext, and the ENABLED line in its source;
	  - whether the client display module exists and the client entry starts it.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function enabledLine(source: string): string
	return string.match(source, "\nlocal ENABLED = [%w]+") and (string.match(source, "\nlocal ENABLED = ([%w]+)") :: string)
		or "(no ENABLED line found)"
end

local lines = { "[6D.2a sync check]" }

local probes = {}
for _, d in ipairs(game:GetDescendants()) do
	if d.Name == "GymRackWatchProbe" then
		table.insert(probes, d)
	end
end
table.insert(lines, string.format("  GymRackWatchProbe copies found: %d (expected 1)", #probes))
for _, probe in ipairs(probes) do
	local detail = probe:GetFullName() .. " (" .. probe.ClassName .. ")"
	if probe:IsA("Script") then
		detail ..= string.format(", Enabled = %s, RunContext = %s, source says ENABLED = %s",
			tostring(probe.Enabled), tostring(probe.RunContext.Name), enabledLine((probe :: any).Source))
	end
	table.insert(lines, "    " .. detail)
end

local server = ServerScriptService:FindFirstChild("Server")
local dev = server and server:FindFirstChild("Dev")
table.insert(lines, "  ServerScriptService.Server.Dev exists: " .. tostring(dev ~= nil))

local client = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	and StarterPlayer.StarterPlayerScripts:FindFirstChild("Client")
local clientDev = client and client:FindFirstChild("Dev")
table.insert(lines, "  client display module GymRackWatchDisplay exists: "
	.. tostring(clientDev ~= nil and clientDev:FindFirstChild("GymRackWatchDisplay") ~= nil))
if client and client:IsA("LocalScript") then
	table.insert(lines, "  client entry starts the display: "
		.. tostring(string.find((client :: any).Source, "GymRackWatchDisplay.start()", 1, true) ~= nil))
else
	table.insert(lines, "  client entry StarterPlayerScripts.Client not found as a LocalScript")
end

print(table.concat(lines, "\n"))
