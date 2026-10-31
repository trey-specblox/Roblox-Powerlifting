--!strict
--[[
	TeleportConfig
	Shared / Config

	The places the TELEPORT menu can take a player (user 2026-10-30: "a
	teleport button on the left, where you can tp to any place"). The client
	shows the list; the server (TeleportService) decides whether a teleport is
	allowed and works out where to stand. A new place is one more line here.

	Each place says where it is in ONE of these ways:
		room   a room of the Starter Gym (its invisible "Room_<name>" region in
		       Workspace.StarterGym.Rooms): a few steps inside its door, facing in
		point  a fixed spot on the gym floor, facing `face`
		tag    standing on the first part with this CollectionService tag
		venue  into the Local meet venue (LocalMeetService, as through its doors)
]]

local TeleportConfig = {}

export type Destination = {
	id: string,
	label: string,
	group: string,
	room: string?,
	point: Vector3?,
	face: Vector3?,
	tag: string?,
	venue: boolean?,
}

-- The menu's sections, in order.
TeleportConfig.Groups = { "MAIN AREAS" }

-- The Local meet venue's place (also what a record attempt's WATCH button asks for).
TeleportConfig.LocalMeetId = "LocalMeet"

-- Only the main areas (user 2026-10-30: "Too much areas to tp ... only lobby, Shop, Mock meet desk, and Local meet area").
TeleportConfig.Destinations = {
	{ id = "Lobby", label = "LOBBY", group = "MAIN AREAS", room = "Lobby" },
	{ id = "Shop", label = "SHOP", group = "MAIN AREAS", room = "Shop" },
	{ id = "MockMeet", label = "MOCK MEET DESK", group = "MAIN AREAS", room = "MockMeet" },
	{ id = "LocalMeet", label = "LOCAL MEET", group = "MAIN AREAS", venue = true },
} :: { Destination }

-- Seconds between two teleports of one player.
TeleportConfig.CooldownSeconds = 2
-- How far inside a room's door a player lands (studs).
TeleportConfig.RoomInsetStuds = 6

-- The place with this id, or nil.
function TeleportConfig.find(id: string): Destination?
	for _, destination in ipairs(TeleportConfig.Destinations) do
		if destination.id == id then
			return destination
		end
	end
	return nil
end

return TeleportConfig
