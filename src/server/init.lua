------------------------------- EasyStore - A Roblox Datastore Manager by TimoursFoil234 --------------------------------------------------------------------------------------------------------
--[[
	---HOW TO USE---
	Put this somewhere in ServerScriptService
	Make sure it has the "Template" module as a child
	Make sure the template is set up correctly
	Make sure you have the correct permissions to use datastores
	You can change the settings below
	You can use the module by doing require(game.ServerScriptService.EasyStore)
	
	---NOTE---
	Updates will be released at random intervals lol
	If an update breaks older saves/is not backwards-compatible, then please DM me @timoursfoil on discord.

	Comes with the basic Functions -
	:Set(player, path, new) -- put in a player object, the path to it (ex: "Gold"), and the new value (50)
	:UpdateInventory(player, itemname, data) -- put in a player, an item name, and its data.
	:Increment(player, path, toAdd) -- Adds the amount (ex: 5) to the path (ex: "Gold")
	Also comes with the internal functions:
	LoadProfile: Loads the players profile into the module
	SaveProfile: Saves it
	AutosaveProfile: Autosaves the profile every interval
	Release: Lets go of the profile (and saves it)
	Unlock: Unlocks the profile from this server (makes sure other servers cannot update it at the same time)
	ReleaseAll: Releases all profiles
	GetProfileFromPlayer: Returns the profile of the player (or creates if not existing)
	WipeProfile: Debug to manually wipe a profile from the store.
	IsLocked: Debug to check if a profile is locked and its locked values.
	Get: Returns the value (or table) of the specified path of the specified player
	HasProfile: Returns if the profile is loaded and is not removing.
	SetDirty: Sets the profile to "Dirty" so that it can be saved

	Customizables:
	DatastoreName: Datastore to write to
	Key: The string and then the players userid (ex: UserId_986060364, UserId_ is the key)
	Template: The template script for data (automatically the child ModuleScript)

	Optionals:
	KickIfLocked: Kicks the player if they try to join while another server/session has their data
	Autosaves: Autosaves the profile
	Autosave_Interval: Intervals (in seconds) between each profile autosave if there is Autosaving
	LockTimeout: If a server incorrectly shutdowns/fails to unlock profile, it will take that much time before another server can access it
	Retry_Attempts: Attempts to retry loading/saving a profile
	Retry_Delay: Delay in seconds between each retry to load/save
	DeeperPathing: Used in the Get/Set functions, so instead of going "Gold", it is "Data.Gold"
	PrintRetries: Print the retries between each attempt to load data

	Should not change (but still there):
	LockProfiles: If the server can lock profiles (to stop data overwrite and corruption)
	SaveOnLeave: Autosaves the profile on player leaving (:Release call)
	CreateOnSave: When you save a profile, if it doesnt exist then it auto-creates it.
	HandleRemovingProfiles: If a player is leaving while data is being written, stops errors from being thrown due to their data being not there.
]]

-- Customizables
local DatastoreName = "EasyStore" -- The store that it writes to
local Key = "UserId_" -- Player key to write to
local Template = require(script.Template) -- Template of data




-- Optional
local KickifLocked = true -- Kicks the player if they try to join while another server has data
local Autosaves = false -- Autosaves the players profile, off to save data write limits
local Autosave_Interval = 600 -- Interval for autosaving (if it is true)
local LockTimeout = 300 -- Timeout if a server shutdowns incorrectly and doesnt release
local Retry_Attempts = 5 -- Retries for locks
local Retry_Delay = 5 -- Delay of seconds between each retry
local DeeperPathing = false -- If true, then when using :Get and :Set, you have to specify Data to change data, and you can change other things aswell
local PrintRetries = true -- Prints retries to the console

-- Should really not change
local LockProfiles = true -- Locks profiles between servers so they dont overlap.
local SaveOnLeave = true -- Saves the profile on release/leave
local CreateOnSave = true -- Creates a profile if you try to save a non-existant one
local HandleRemovingProfiles = true -- Automatically throws out calls if the profile is being removed while a data change is called.


-- Services
local DatastoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")


-- Datastore to write to
local Store = DatastoreService:GetDataStore(DatastoreName) -- Creates the store

local EasyStore = {} -- For functions
EasyStore.Loaded = {} -- Loaded profiles
EasyStore.AutosaveThreads = {} -- Autosaving profiles
EasyStore.Releasing = {} -- Profiles being released

function EasyStore:Set(player:Player, path, new) -- Sets the value to the new one
	local profile = EasyStore:GetProfileofPlayer(player)

	if not DeeperPathing then
		if profile.Data[path] then
			self.Loaded[player].Data[path] = new
		end
	else
		if profile[path] then
			self.Loaded[player][path] = new
		end
	end
	EasyStore:SetDirty(player)
	return true
end
function EasyStore:UpdateInventory(player:Player, itemName, data) -- Updates the inventory
	local profile = EasyStore:GetProfileofPlayer(player)
	
	self.Loaded[player].Data.Inventory[itemName] = data
	
	EasyStore:SetDirty(player)
end
function EasyStore:Increment(player:Player, path, toAdd)
	local profile = EasyStore:GetProfileofPlayer(player)

	if not DeeperPathing then
		if profile.Data[path] then
			self.Loaded[player].Data[path] += toAdd
		end
	else
		if profile[path] then
			self.Loaded[player][path] += toAdd
		end
	end

	EasyStore:SetDirty(player)
	return true
end


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------INTERNAL FUNCTIONS----------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Helper function to wait for request budget
local function waitForRequestBudget(requestType:Enum.DataStoreRequestType) -- waits until you can request that
	while DatastoreService:GetRequestBudgetForRequestType(requestType) < 1 do
		RunService.Heartbeat:Wait()
	end
end

local function generateSpecialID()
	return Http:GenerateGUID() -- genereates a new value
end

local function deepClone(original) -- clones the table deeply
	local clone = {}
	for k, v in pairs(original) do
		clone[k] = typeof(v) == "table" and deepClone(v) or v
	end
	return clone
end




local function New() -- new profile
	return {
	FirstLoad = os.time(),
	LastLoad = os.time(),
	Data = deepClone(Template),
	SessionLock = {
		Locked = false,
		Timestamp = os.time(),
		Server = game.JobId
	},
	Dirty = false,
	SpecialID = generateSpecialID()
	}
end

function EasyStore:AutosaveProfile(player: Player) -- autosaving
	if self.AutosaveThreads[player] then return end

	self.AutosaveThreads[player] = true
	task.spawn(function()
		while self.Loaded[player] do
			task.wait(Autosave_Interval)
			self:SaveProfile(player)
		end
		self.AutosaveThreads[player] = nil
	end)
end

function EasyStore:LoadProfile(player: Player) -- Load profile
	
	local attempts = 0
	local success, result

	while attempts < Retry_Attempts do
		waitForRequestBudget(Enum.DataStoreRequestType.UpdateAsync)
		success, result = pcall(function()
			return Store:UpdateAsync(Key .. player.UserId, function(oldData)
			
				if not oldData then
					return New()
				end
				
				if LockProfiles then
					if oldData and oldData.SessionLock and oldData.SessionLock.Locked then
					local lockTime = oldData.SessionLock.Timestamp
							if os.time() - lockTime < LockTimeout then
								return nil
							end
					end
				end




				local data = oldData or New()
				data.LastLoad = os.time()
				data.FirstLoad = data.FirstLoad or os.time()
				data.SessionLock = {
					Locked = false,
					Timestamp = os.time(),
					Server = game.JobId,
				}
				return data
			end)
		end)

		if success and result ~= nil then
			
			self.Loaded[player] = {
				FirstLoad = result.FirstLoad,
				LastLoad = result.LastLoad,
				SessionLock = {
					Locked = false,
					Timestamp = os.time(),
					Server = game.JobId,
				},
				Data = result.Data or {},
				Dirty = false,
			}
			
			if Autosaves then
				EasyStore:AutosaveProfile(player)
			end
			
			print("{EasyStore} Loaded profile for: " ..tostring(player.UserId).. " on attempt ".. tostring(attempts))
			
			return self.Loaded[player]
		else
			if PrintRetries then
				warn("{EasyStore}: Failed to load data for: ".. tostring(player.UserId).. " on attempt ".. tostring(attempts))
			end
			attempts += 1
			task.wait(Retry_Delay)
		end
	end

	warn("[EasyStore]: Failed to load data for user: " .. tostring(player.UserId))
	
	if KickifLocked then
		player:Kick("Failed to load data. Please rejoin.")
	end
	return false
end

function EasyStore:SaveProfile(player:Player, nolock: boolean?)
	local profile = self.Loaded[player]
	if not profile then
		if CreateOnSave then
			EasyStore:LoadProfile(player)
		end
	end
	if not profile.Dirty then return true end
	
	local attempts = 0
	local success, result
	
	while attempts < Retry_Attempts do
		waitForRequestBudget(Enum.DataStoreRequestType.UpdateAsync)
		success, result = pcall(function()
			return Store:UpdateAsync(Key..player.UserId, function(oldData)
				
				if LockProfiles then
					if oldData and oldData.SessionLock and oldData.SessionLock.Locked then
					local lockTime = oldData.SessionLock.Timestamp
							if os.time() - lockTime < LockTimeout then
								return nil
							end
					end
				end

			if LockProfiles then
				if not nolock then
					profile.SessionLock = {
						Locked = true,
						Timestamp = os.time(),
						Server = game.JobId,
					}
				else
					profile.SessionLock = {
						Locked = false,
						Timestamp = os.time(),
						Server = game.JobId,
					}
				end
			else
					profile.SessionLock = {
						Locked = false,
						Timestamp = os.time(),
						Server = game.JobId,
					}
			end
				
				return profile
			end)
		end)
		
		if success then
			print("{EasyStore} Saved profile for: " ..tostring(player.UserId).. " on attempt ".. tostring(attempts))
			profile.Dirty = false
			return true
		else
			if PrintRetries then
				warn("{EasyStore}: Failed to save data for: ".. tostring(player.UserId).. " on attempt ".. tostring(attempts))
			end
			attempts += 1
			task.wait(Retry_Delay)
		end
	end
	warn("{EasyStore}: failed to save data of player: ".. tostring(player.UserId))
	return false
end

function EasyStore:Release(player: Player)
	self.Releasing[player] = true

	local profile = self.Loaded[player]
	if not profile then return false end

	local success = EasyStore:UnlockProfile(player)

	
	
	self.Loaded[player] = nil
	self.Releasing[player] = nil
	return success
end

function EasyStore:ReleaseAll()
	for _, player in pairs(Players:GetPlayers()) do
		EasyStore:Release(player)
	end
	return true
end

function EasyStore:UnlockProfile(player: Player)
	if not LockProfiles then return true end
	local profile = self.Loaded[player]
	if not profile then return end

	self.Loaded[player].SessionLock = {
		Locked = false,
		Timestamp = os.time(),
		Server = game.JobId
	}
	
	self:SaveProfile(player, true)
	return true
end

function EasyStore:SetDirty(player:Player)
	local profile = EasyStore:GetProfileofPlayer(player)
	
	self.Loaded[player].Dirty = true
end

function EasyStore:GetProfileofPlayer(player:Player)
	if HandleRemovingProfiles then
		if self.Releasing[player] then return nil end
	end
	local profile = self.Loaded[player]
	if not profile then
		profile = EasyStore:LoadProfile(player)
	end
	return profile
end

function EasyStore:HasProfile(player: Player)
	return self.Loaded[player] ~= nil and not self.Releasing[player]
end

function EasyStore:IsLocked(player: Player)
	if not LockProfiles then return false end
	local profile = self.Loaded[player]
	if not profile then return false end
	return profile.SessionLock and profile.SessionLock.Locked
end

function EasyStore:WipeProfile(player: Player)
	waitForRequestBudget(Enum.DataStoreRequestType.SetAsync)
	local success, result = pcall(function()
		return Store:RemoveAsync(Key .. player.UserId)
	end)

	if success then
		warn("{EasyStore}: Wiped profile for", player)
	else
		warn("{EasyStore}: Failed to wipe profile for", player, result)
	end

	return success
end


function EasyStore:Get(player:Player, path)
	local profile = EasyStore:GetProfileofPlayer(player)
	local val
	
	if not DeeperPathing then
		if profile.Data[path] then
			val = profile.Data[path]
		end
	elseif profile[path] then
		val = profile[path]
	end
	
	return val
end


return EasyStore
