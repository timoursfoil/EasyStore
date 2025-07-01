-- Made by TimoursFoil234


local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local EasyStore = require(ServerScriptService.Data.EasyStore)

local function Leaderstats(player:Player)
	local profile = EasyStore:GetProfileofPlayer(player)
	local oldleader = player:FindFirstChild("leaderstats")
	if oldleader then
		oldleader:Destroy()
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gold = Instance.new("NumberValue")
	gold.Value = profile.Data.Gold
	gold.Name = "Gold"
	gold.Parent = leaderstats
end

Players.PlayerAdded:Connect(function(player)
	EasyStore:LoadProfile(player)
	Leaderstats(player)
	task.wait(2)
	while true do
		local gold = EasyStore:Get(player, "Gold")
		EasyStore:Set(player, "Gold", gold + 10)
		Leaderstats(player)
		task.wait(2)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	EasyStore:Release(player)
end)
game:BindToClose(function()
	EasyStore:ReleaseAll()
end)