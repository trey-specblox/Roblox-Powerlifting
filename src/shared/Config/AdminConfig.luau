--!strict
--[[
	AdminConfig
	Shared / Config

	What the admin panel offers (user 2026-11-06: testing on a phone means joining the real
	game). Who may use it is NOT here: that list is on the server only (AdminService). A
	coin button's amount is read by the server from here by the button's id; a client only
	ever sends the id, so it can't ask for any other amount.
]]

local AdminConfig = {}

export type CoinButton = {
	id: string,
	label: string,
	amount: number,
}

AdminConfig.CoinButtons = {
	{ id = "Coins1000", label = "+1,000", amount = 1000 },
	{ id = "Coins10000", label = "+10,000", amount = 10000 },
	{ id = "Coins100000", label = "+100,000", amount = 100000 },
} :: { CoinButton }

-- The ADMIN tab on the left edge, from the middle of the screen: above the MEETS tab.
AdminConfig.TabOffsetY = -218

return AdminConfig
