----------------------------------------------------
--- Weapon S.T.A.R.: Setup, Transfer And Restore ---
--- Created by LibertyForce                      ---
--- http://steamcommunity.com/id/libertyforce    ---
----------------------------------------------------


-- If this is the first start, create a directory server-side
if !file.Exists( "wstar", "DATA" ) then file.CreateDir( "wstar" ) end

-- Setup the server cvars. We're only doing this server-side, because FCVAR_REPLICATED doesn't sync correctly with connecting clients.
-- We'll have to sync the cvars manually later. For now, we need a table that contains all the cvars.
local convars = { }
convars["wstar_sv_auto"]				= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_stripdefault"]		= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_blockloadout"]		= { 0, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_multi"]				= { 0, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_transfer_enabled"]	= { 0, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_transfer_spauto"]		= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["wstar_sv_transfer_mpauto"]		= { 0, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["wstar_sv_loadouts"]			= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_support_cw2"]			= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_admins_allowall"]		= { 0, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }

-- Let's create the cvars server-side.
for cvar, v in pairs( convars ) do
	CreateConVar( cvar,	v[1], v[2] )
end

AddCSLuaFile("../client/lf_wstar_client.lua") -- Send the client file to the players.


-- Setting up the main table for Weapon Restore. If Weapon Transfer is enabled and we have a file saved, then fill up the table.
local WSTAR_WR

if file.Exists( "wstar/transfer.txt", "DATA" ) then
	if GetConVar("wstar_sv_transfer_enabled"):GetBool() then
		WSTAR_WR = util.JSONToTable( file.Read( "wstar/transfer.txt", "DATA" ) )
	end
	if !istable( WSTAR_WR ) then WSTAR_WR = { } end
	file.Delete( "wstar/transfer.txt" )
else
	WSTAR_WR = { }
end

local WSTAR_LO = { } -- Table for requested Loadouts.
local WSTAR_Used = { } -- Table that contains all players, who used up their Weapon Restore.


-- Main function for saving a players weapons.
local function WSTAR_GetWeapons( ply )

	local id = ply:SteamID() -- We'll use the SteamID to save player's table.
	
	if !istable( WSTAR_WR[id] ) then WSTAR_WR[id] = { } end
	WSTAR_WR[id].weapon = { }
	WSTAR_WR[id].ammo = { }
	if !ply:Alive() then WSTAR_Used[id] = nil end -- If the player is dead, we'll reset the Used state.
	
	for k,v in pairs( ply:GetWeapons() ) do -- Get all weapons
		
		-- The first table contains the weapon class as key, and the primary and secondary ammo in clip.
		local weapon_class = v:GetClass()
		local weapon_clip1 = v:Clip1()
		local weapon_clip2 = v:Clip2()
		WSTAR_WR[id].weapon[weapon_class] = { weapon_clip1, weapon_clip2 }
		
		-- The second table contains all ammo types in reserve. Since this is shared among all weapons, we'll need to save it in another table. 
		local ammo1_type = v:GetPrimaryAmmoType()
		if ammo1_type != nil and ammo1_type != -1 then
			local ammo1_name = game.GetAmmoName( ammo1_type )
			local ammo1_amount = ply:GetAmmoCount( ammo1_type )
			WSTAR_WR[id].ammo[ammo1_name] = ammo1_amount
		end

		local ammo2_type = v:GetSecondaryAmmoType()
		if ammo2_type != nil and ammo2_type != -1 then
			local ammo2_name = game.GetAmmoName( ammo2_type )
			local ammo2_amount = ply:GetAmmoCount( ammo2_type )
			WSTAR_WR[id].ammo[ammo2_name] = ammo2_amount
		end
		
		-- Support for Customizable Weaponry 2.0. Code by Spy.
		if istable( CustomizableWeaponry ) and v.CW20Weapon then -- Only run for CW2 weapons.
			WSTAR_WR[id].weapon[weapon_class]["cw2attachments"] = {}
			WSTAR_WR[id].weapon[weapon_class]["cw2attachments"].wepClass = (v.ThisClass or v:GetClass())
			WSTAR_WR[id].weapon[weapon_class]["cw2attachments"].grenadeType = v.Grenade40MM
			for k, v in pairs(v.Attachments) do
				if v.last and v.last > 0 then
					WSTAR_WR[id].weapon[weapon_class]["cw2attachments"][k] = v.last
				end
			end
		end
		
	end

end

hook.Add("PostPlayerDeath","WSTAR_PlayerDeath", WSTAR_GetWeapons) -- The GetWeapons function will always run, when a player dies.


-- Main function for restoring a players weapons.
local function WSTAR_RestoreWeapons( ply )

	timer.Simple( 0.5, function() -- Give some time after player spawn.
	
		local id = ply:SteamID()
		local tbl
		
		-- If the WSTAR_LO table exsists for the player, it means he requested a Loadout. Else we'll use the Restore table.
		if istable( WSTAR_LO[id] ) then
			tbl = WSTAR_LO[id]
		else
			tbl = WSTAR_WR[id]
		end
		
		if tbl and tbl.weapon and tbl.ammo then
		
			 -- We'll strip all existing weapons, if that's enabled.
			if GetConVar("wstar_sv_stripdefault"):GetBool() then
				ply:StripWeapons()
				ply:StripAmmo()
			end
			
			-- First, we'll handle the Weapons table.
			for k,v in pairs( tbl.weapon ) do -- Go through all saved weapons.
				ply:Give( k ) -- Give the player the weapon.
				local w = ply:GetWeapon( k ) -- Get the ID of the new weapon.
				if w and IsValid(w) and w:IsWeapon() then
				
					-- Fill the primary and secondary ammo. We need a timer because of CW2.
					timer.Simple( 0.4, function()
						if v[1] and v[1] >= 0 then w:SetClip1( v[1] ) end
						if v[2] and v[2] >= 0 then w:SetClip2( v[2] ) end
					end )
					
					-- Support for Customizable Weaponry 2.0. Code by Spy.
					if GetConVar("wstar_sv_support_cw2"):GetBool() and istable( CustomizableWeaponry ) and w.CW20Weapon and istable( v["cw2attachments"] ) then
						local loadOrder = {}
						for k, v in pairs(v["cw2attachments"]) do
							local attCategory = w.Attachments[k]
							if attCategory then
								local att = CustomizableWeaponry.registeredAttachmentsSKey[attCategory.atts[v]]
								if att then
									local pos = 1
									if att.dependencies or attCategory.dependencies or (w.AttachmentDependencies and w.AttachmentDependencies[att.name]) then
										pos = #loadOrder + 1
									end
									table.insert(loadOrder, pos, {category = k, position = v})
								end
							end
						end

						-- After giving a CW2 weapon to the player, it needs some time to initialize, before we can send the attachments.
						timer.Simple( 0.2, function()
							for k, v in pairs(loadOrder) do
								w:attach(v.category, v.position - 1)
							end
							CustomizableWeaponry.grenadeTypes.setTo(w, (v["cw2attachments"].grenadeType or 0), true)
						end )

					end
					
				end
			end
			
			-- Next, we'll handle the Ammo table.
			timer.Simple( 0.6, function()
				for k,v in pairs( tbl.ammo ) do
					if v then ply:SetAmmo( v, k ) end
				end
			end )
			
			WSTAR_Used[id] = true -- Mark that the player used up his weapon restore.
			
			if !tobool( ply:GetInfoNum( "wstar_cl_keeploadout", 0 ) ) then -- If the player doesn't want to keep Loadouts, get rid of the WSTAR_LO table.
				WSTAR_LO[id] = nil
			end

		end
		
	end )

end

-- If Auto restore is enabled, we'll run the RestoreWeapons function upon spawn.
hook.Add( "PlayerSpawn", "WSTAR_PlayerSpawn", function(ply)
	if GetConVar("wstar_sv_auto"):GetBool() then WSTAR_RestoreWeapons(ply) end
end )
-- Blocks the default loadout, if that's enabled.
hook.Add( "PlayerLoadout", "WSTAR_PlayerSpawn", function(ply)
	if GetConVar("wstar_sv_blockloadout"):GetBool() then return true end
end )


-- This function fills the WSTAR_WR table with the weapons of all players. Called in MP, manually by the Admin or via timer,
-- in order to prepare Weapon Transfer. This is to heavy to be called in the Shutdown hook.
local function WSTAR_SaveToFile( )
	if GetConVar("wstar_sv_transfer_enabled"):GetBool() then
		for k,ply in pairs( player.GetHumans() ) do
			if ply:Alive() then
				WSTAR_GetWeapons( ply )
			end
		end
	end
end

-- The timer for SaveToFile. Only used in multiplayer. This get's called at the beginning and whenever the settings change.
local function WSTAR_SetupTimer()
	if timer.Exists( "WSTAR_Timer" ) then timer.Remove( "WSTAR_Timer" ) end
	if !game.SinglePlayer() and GetConVar("wstar_sv_transfer_enabled"):GetBool() and GetConVar("wstar_sv_transfer_mpauto"):GetBool() then
		timer.Create( "WSTAR_Timer", 10, 0, WSTAR_SaveToFile )
	end
end

cvars.AddChangeCallback( "wstar_sv_transfer_enabled", WSTAR_SetupTimer )
cvars.AddChangeCallback( "wstar_sv_transfer_mpauto", WSTAR_SetupTimer )
WSTAR_SetupTimer()


-- This gets called when the game ends. Saves the main table for Weapon Transfer. In SinglePlayer it
-- automatically gets the players weapons. In Multiplayer, it's not possible to save all the player's weapons,
-- because we can't run loops here.
hook.Add( "ShutDown", "WSTAR_Shutdown_Hook", function()
	if GetConVar("wstar_sv_transfer_enabled"):GetBool() then
		if game.SinglePlayer() then WSTAR_GetWeapons( player.GetByID(1) ) end
		file.Write( "wstar/transfer.txt", util.TableToJSON( WSTAR_WR ) )
	end
end )


-- The player manually requested a Weapon Restore.
util.AddNetworkString("wstar")
net.Receive("wstar", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		local id = ply:SteamID()
		local success = false
		-- Only restore, if the player hasn't used up his restore already, unless Multi Restore is enabled.
		if !WSTAR_Used[id] or GetConVar("wstar_sv_multi"):GetBool() then
			WSTAR_RestoreWeapons( ply )
			success = true
		end
		-- Report to the player, if the restore was allowed or not.
		net.Start("wstar")
		net.WriteBool( success )
		net.Send( ply )
	end
end)

-- The player requested to strip all his weapons. We'll do this without asking the admin, because it's his own fault.
util.AddNetworkString("wstar_clearweapons")
net.Receive("wstar_clearweapons", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		local id = ply:SteamID()
		ply:StripWeapons()
		ply:StripAmmo()
		WSTAR_WR[id] = nil
	end
end)

-- The admin requested to save all player's weapons in order to prepare a Weapon Transfer.
util.AddNetworkString("wstar_save")
net.Receive("wstar_save", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() and ( ply:IsSuperAdmin() or ( GetConVar("wstar_sv_admins_allowall"):GetBool() and ply:IsAdmin() ) ) then
		WSTAR_SaveToFile()
		local map = net.ReadString()
		if map != "" then RunConsoleCommand( "changelevel", map ) end
	end
end)


-- Whenever a player connects, we'll sync the server cvars with him, because FCVAR_REPLICATED doesn't work as intended.
util.AddNetworkString("wstar_convar_sync")
hook.Add( "PlayerAuthed", "WSTAR_ConVar_Sync", function( ply )
	local tbl = { }
	for cvar in pairs( convars ) do
		tbl[cvar] = GetConVar(cvar):GetInt()
	end
	net.Start("wstar_convar_sync")
	net.WriteTable( tbl )
	net.Send( ply )
end )

-- The admin changed a cvar setting.
util.AddNetworkString("wstar_convar_change")
net.Receive("wstar_convar_change", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		local cvar = net.ReadString()
		-- We'll kick everyone, including and especially admins, who try to change non-WSTAR cvars via this function.
		-- Just because the owner allowed you to change WSTAR settings, doesn't mean you can abuse this to change something like sv_cheats.
		-- Yes, this get's run before the admin check, in order to get rid of players trying to hack into this. Only needed for servers with sv_allowcslua.
		if !convars[cvar] then ply:Kick("Illegal convar change") return end
		-- Only admins can proceed.
		if !ply:IsSuperAdmin() and !( GetConVar("wstar_sv_admins_allowall"):GetBool() and ply:IsAdmin() ) then return end
		if !ply:IsSuperAdmin() and cvar == "wstar_sv_admins_allowall" then return end -- Of course, non-SuperAdmins can't change this cvar.
		RunConsoleCommand( cvar, net.ReadBool() == true and "1" or "0" )
	end
end)


-- The player requested to save his current weapons as a Loadout.
util.AddNetworkString("wstar_lo_save")
net.Receive("wstar_lo_save", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		local id = ply:SteamID()
		local name = net.ReadString()
		WSTAR_GetWeapons( ply ) -- Get the weapons he's currently holding.
		net.Start( "wstar_lo_save" )
		net.WriteString( name )
		net.WriteTable( WSTAR_WR[id] ) -- Send it to the player.
		net.Send( ply )
	end
end)


-- The player requested to get a Loadout.
util.AddNetworkString("wstar_lo_load")
net.Receive("wstar_lo_load", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() and GetConVar("wstar_sv_loadouts"):GetBool() then
		local id = ply:SteamID()
		WSTAR_LO[id] = net.ReadTable() -- We'll create the WSTAR_LO table. It get's used on next call of the RestoreWeapons function.
	end
end)

-- The player changed his mind and doesn't want to use the Loadout.
util.AddNetworkString("wstar_lo_undo")
net.Receive("wstar_lo_undo", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		local id = ply:SteamID()
		WSTAR_LO[id] = nil -- Get rid of the WSTAR_LO table.
	end
end)
