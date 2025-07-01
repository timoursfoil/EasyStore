-- Made by TimoursFoil234


local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local EasyStore = require(ServerScriptService.Data.EasyStore)

local function Leaderstats(player:Player) -- Creates leaderstats with the Gold value.
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
	EasyStore:LoadProfile(player) -- Loads the players profile
	Leaderstats(player) -- Create leaderstats for player
	task.wait(2)
	while true do
		local gold = EasyStore:Get(player, "Gold") -- Gets the Gold value
		EasyStore:Set(player, "Gold", gold + 10) -- Adds 10 to the gold value. (Use :Increment as a better way)
		Leaderstats(player) -- Updates leaderstats
		task.wait(2)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	EasyStore:Release(player) -- Releases the players profile on leave
end)
game:BindToClose(function()
	EasyStore:ReleaseAll() -- Releases all profiles on game Close
end)