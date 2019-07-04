----------------------------------------------------
--- Weapon S.T.A.R.: Setup, Transfer And Restore ---
--- Created by LibertyForce                      ---
--- http://steamcommunity.com/id/libertyforce    ---
----------------------------------------------------


-- Pooling net messages
util.AddNetworkString("wstar")
util.AddNetworkString("wstar_clearweapons")
util.AddNetworkString("wstar_save")
util.AddNetworkString("wstar_convar_change")
util.AddNetworkString("wstar_lo_save")
util.AddNetworkString("wstar_lo_load")
util.AddNetworkString("wstar_lo_undo")
util.AddNetworkString("wstar_attach_tfa")


-- Setting up the main table for Weapon Restore. If Weapon Transfer is enabled and we have a file saved, then fill up the table.
local WSTAR_WR = { }
local von, dir, convars, pat_fn_mid, pat_fn, version = WSTAR.von, WSTAR.dir, WSTAR.convars, WSTAR.pat_fn_mid, WSTAR.pat_fn, WSTAR.version
local IsValidFilename, DataToTbl, TblToData = WSTAR.IsValidFilename, WSTAR.DataToTbl, WSTAR.TblToData
local file_trans
if game.SinglePlayer() then
	file_trans = dir .. "transfer_sp.dat"
else
	file_trans = dir .. "transfer_mp.dat"
end


local WSTAR_LO = { } -- Table for requested Loadouts.


local function GetPlayerID( ply )
	local id
	if game.SinglePlayer() then
		id = "STEAM_0:0:0"
	else
		id = ply:SteamID()
	end
	return id
end

-- Main function for saving a players weapons.
local function WSTAR_GetWeapons( ply, IsDead )

	local id = GetPlayerID( ply ) -- We'll use the SteamID to save player's table.
	
	--if !istable( WSTAR_WR[id] ) then WSTAR_WR[id] = { } end
	WSTAR_WR[id] = { }
	WSTAR_WR[id].weapon = { }
	WSTAR_WR[id].ammo = { }
	if IsDead then ply.WSTAR_used = nil end -- If the player is dead, we'll reset the Used state.
	
	local active_weapon = ply:GetActiveWeapon()
	if IsValid( active_weapon ) then
		WSTAR_WR[id].active = active_weapon:GetClass()
	end
	
	for order, w in pairs( ply:GetWeapons() ) do -- Get all weapons
		if IsValid( w ) then
		
			-- Changed to sequential table, so weapon order would be the same after restore.
			local insert = { }
			local weapon_class = w:GetClass()
			insert.class = weapon_class
			insert.clip1 = w:Clip1()
			insert.clip2 = w:Clip2()
			
			if istable( CustomizableWeaponry ) and w.CW20Weapon and istable( w.Attachments ) then
				insert.cw2attachments = {}
				for cat, att in pairs( w.Attachments ) do
					if att.last then
						insert.cw2attachments[cat] = att.last
					end
				end
			end
			
			if istable( TFA ) and w.SetTFAAttachment and istable( w.Attachments ) then
				insert.tfaattachments = {}
				for cat, att in pairs( w.Attachments ) do
					if att.sel then
						insert.tfaattachments[cat] = att.sel
					end
				end
			end
			
			table.insert( WSTAR_WR[id].weapon, insert )
			
		end
	end
	
	if ply.GetAmmo then  -- Get ammo (requires gmod version 2019.07)
		for ammoid, amount in pairs( ply:GetAmmo() ) do
			
			local name = game.GetAmmoName( ammoid )
			WSTAR_WR[id].ammo[name] = amount
			
		end
	end
	
	return true

end

hook.Add("DoPlayerDeath","WSTAR_PlayerDeath", function( ply ) WSTAR_GetWeapons( ply, true ) end ) -- The GetWeapons function will always run, when a player dies.


-- Main function for restoring a players weapons.
local function WSTAR_RestoreWeapons( ply )
	
	local id = GetPlayerID( ply )
	local tbl
	
	-- If the WSTAR_LO table exsists for the player, it means he requested a Loadout. Else we'll use the Restore table.
	if istable( WSTAR_LO[id] ) then
		tbl = WSTAR_LO[id]
	else
		tbl = WSTAR_WR[id]
	end
	
	if tbl and tbl.weapon and tbl.ammo and ply:Alive() then
	
		local t_at = ply:GetInfoNum( "wstar_cl_delay", 0 )
		if t_at and isnumber( t_at ) then
			t_at = math.Round( t_at, 1 )
			t_at = math.Clamp( t_at, 1, 5 )
		else
			t_at = 1
		end
		
		local t_cl = t_at + 0.2
		local t_am = t_cl + 0.0
	
		 -- We'll strip all existing weapons, if that's enabled.
		if GetConVar("wstar_sv_stripdefault"):GetBool() then
			ply:StripWeapons()
			ply:StripAmmo()
		end
		
		-- First, we'll handle the Weapons table.
		for _, v in pairs( tbl.weapon ) do -- Go through all saved weapons.
		
			ply:Give( v.class ) -- Give the player the weapon.
			local w = ply:GetWeapon( v.class ) -- Get the ID of the new weapon.
			if w and IsValid( w ) and w:IsWeapon() then
			
				-- Fill the primary and secondary ammo. We need a timer because of CW2.
				timer.Simple( t_cl, function()
					if not ply:Alive() or not IsValid( w ) then return end
					if v.clip1 and v.clip1 >= 0 then w:SetClip1( v.clip1 ) end
					if v.clip2 and v.clip2 >= 0 then w:SetClip2( v.clip2 ) end
				end )
				
				-- Support for Customizable Weaponry 2.0. Code by Spy.
				if GetConVar("wstar_sv_support_cw2"):GetBool() and istable( CustomizableWeaponry ) and w.CW20Weapon and istable( v.cw2attachments ) then
					local loadOrder = {}
					for k, v in pairs( v.cw2attachments ) do
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
					timer.Simple( t_at, function()
						if not ply:Alive() or not IsValid( w ) then return end
						for k, v in pairs(loadOrder) do
							w:attach( v.category, v.position - 1 )
						end
						--CustomizableWeaponry.grenadeTypes.setTo(w, (v["cw2attachments"].grenadeType or 0), true)
					end )

				end
				
				if GetConVar("wstar_sv_support_tfa"):GetBool() and istable( TFA ) and w.SetTFAAttachment and istable( v.tfaattachments ) then
					timer.Simple( t_at, function()
						if not ply:Alive() or not IsValid( w ) then return end
						w:InitAttachments()
						local tbl = { }
						tbl.class = v.class
						tbl.content = v.tfaattachments
						local data = TblToData( tbl )
						if data then
							local size = string.len( data )
							net.Start( "wstar_attach_tfa" )
							net.WriteUInt( size, 16 )
							net.WriteData( data, size )
							net.Send( ply )
						end
						timer.Simple( 0.1, function()
							if not ply:Alive() or not IsValid( w ) then return end
							for cat, att in pairs( v.tfaattachments ) do
								w:SetTFAAttachment(cat, att, true)
							end
						end )
					end )
				end
				
			end
			
		end
		
		-- Next, we'll handle the Ammo table.
		timer.Simple( t_am, function()
		
			if not ply:Alive() then return end
			for k, v in pairs( tbl.ammo ) do
				if v then ply:SetAmmo( v, k ) end
			end
			
			if tbl.active then
				ply:SelectWeapon( tbl.active )
			end
			
		end )
		
		ply.WSTAR_used = true -- Mark that the player used up his weapon restore.
		
		if !tobool( ply:GetInfoNum( "wstar_cl_keeploadout", 0 ) ) then -- If the player doesn't want to keep Loadouts, get rid of the WSTAR_LO table.
			WSTAR_LO[id] = nil
		end

	end

end

-- If Auto restore is enabled, we'll run the RestoreWeapons function upon spawn.
hook.Add( "PlayerSpawn", "WSTAR_PlayerSpawn", function(ply)
	if GetConVar("wstar_sv_auto"):GetBool() then
		WSTAR_RestoreWeapons(ply)
	end
end )
-- Blocks the default loadout, if that's enabled.
hook.Add( "PlayerLoadout", "WSTAR_PlayerSpawn", function(ply)
	if GetConVar("wstar_sv_blockloadout"):GetBool() then return true end
end )


-- This function fills the WSTAR_WR table with the weapons of all players. Called in MP, manually by the Admin or via timer,
-- in order to prepare Weapon Transfer. This is to heavy to be called in the Shutdown hook.
local function WSTAR_SaveToFile( )
	if GetConVar("wstar_sv_transfer_enabled"):GetBool() then
		for _, ply in pairs( player.GetHumans() ) do
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
		if ( game.SinglePlayer() and WSTAR_GetWeapons( player.GetByID(1) ) ) or ( not game.SinglePlayer() ) then
			local data = TblToData( WSTAR_WR )
			if data then
				file.Write( file_trans, data )
			end
		end
	end
end )

hook.Add( "InitPostEntity", "WSTAR_Transfer_Hook", function()
	if file.Exists( file_trans, "DATA" ) then
		if GetConVar("wstar_sv_transfer_enabled"):GetBool() then
			WSTAR_WR = DataToTbl( file.Read( file_trans, "DATA" ) )
		end
		if !istable( WSTAR_WR ) then WSTAR_WR = { } end
		file.Delete( file_trans )
	end
end )


-- The player manually requested a Weapon Restore.
net.Receive( "wstar", function( len, ply )
	if ply:IsValid() and ply:IsPlayer() and ( game.SinglePlayer() or not ( ply.WSTAR_last_restore and ply.WSTAR_last_restore > CurTime() ) ) then
		ply.WSTAR_last_restore = CurTime() + GetConVar("wstar_sv_wait_restore"):GetInt()
		local id = GetPlayerID( ply )
		local success = false
		-- Only restore, if the player hasn't used up his restore already, unless Multi Restore is enabled.
		if !ply.WSTAR_used or GetConVar("wstar_sv_multi"):GetBool() then
			WSTAR_RestoreWeapons( ply )
			success = true
		end
		-- Report to the player, if the restore was allowed or not.
		net.Start("wstar")
		net.WriteBool( success )
		net.Send( ply )
	end
end )

-- The player requested to strip all his weapons. We'll do this without asking the admin, because it's his own fault.
net.Receive( "wstar_clearweapons", function( len, ply )
	if ply:IsValid() and ply:IsPlayer() and ( game.SinglePlayer() or not ( ply.WSTAR_last_com and ply.WSTAR_last_com > CurTime() ) ) then
		ply.WSTAR_last_com = CurTime() + GetConVar("wstar_sv_wait_com"):GetInt()
		local id = GetPlayerID( ply )
		ply:StripWeapons()
		ply:StripAmmo()
		WSTAR_WR[id] = nil
		net.Start( "wstar_clearweapons" )
		net.Send( ply )
	end
end )


-- The player requested to save his current weapons as a Loadout.
net.Receive( "wstar_lo_save", function( len, ply )
	if ply:IsValid() and ply:IsPlayer() and ( game.SinglePlayer() or not ( ply.WSTAR_last_com and ply.WSTAR_last_com > CurTime() ) ) then
		ply.WSTAR_last_com = CurTime() + GetConVar("wstar_sv_wait_com"):GetInt()
		local id = GetPlayerID( ply )
		local name = net.ReadString()
		if not IsValidFilename( name ) then return end
		WSTAR_GetWeapons( ply ) -- Get the weapons he's currently holding.
		local data = TblToData( WSTAR_WR[id] )
		if data then
			local size = string.len( data )
			net.Start( "wstar_lo_save" )
			net.WriteString( name )
			net.WriteUInt( size, 16 )
			net.WriteData( data, size ) -- Send it to the player.
			net.Send( ply )
		end
	end
end )

-- The player requested to get a Loadout.
net.Receive( "wstar_lo_load", function( len, ply )
	if ply:IsValid() and ply:IsPlayer() and ( game.SinglePlayer() or not ( ply.WSTAR_last_com and ply.WSTAR_last_com > CurTime() ) ) then
		ply.WSTAR_last_com = CurTime() + GetConVar("wstar_sv_wait_com"):GetInt()
		local id = GetPlayerID( ply )
		local size = net.ReadUInt( 16 )
		local tbl = net.ReadData( size )
		tbl = DataToTbl( tbl )
		if istable( tbl ) then
			WSTAR_LO[id] = tbl -- We'll create the WSTAR_LO table. It get's used on next call of the RestoreWeapons function.
		end
		net.Start( "wstar_lo_load" )
		net.Send( ply )
		id, size, tbl = nil
	end
end )

-- The player changed his mind and doesn't want to use the Loadout.
net.Receive( "wstar_lo_undo", function( len, ply )
	if ply:IsValid() and ply:IsPlayer() and ( game.SinglePlayer() or not ( ply.WSTAR_last_com and ply.WSTAR_last_com > CurTime() ) ) then
		ply.WSTAR_last_com = CurTime() + GetConVar("wstar_sv_wait_com"):GetInt()
		local id = GetPlayerID( ply )
		WSTAR_LO[id] = nil -- Get rid of the WSTAR_LO table.
		net.Start( "wstar_lo_undo" )
		net.Send( ply )
	end
end )


-- The admin requested to save all player's weapons in order to prepare a Weapon Transfer.
net.Receive( "wstar_save", function( len, ply )
	if ply:IsValid() and ply:IsPlayer() and ( ply:IsSuperAdmin() or ( GetConVar("wstar_sv_admins_allowall"):GetBool() and ply:IsAdmin() ) ) then
		WSTAR_SaveToFile()
		local map = net.ReadString()
		if map != "" then RunConsoleCommand( "changelevel", map ) end
	end
end )


-- The admin changed a cvar setting.
net.Receive( "wstar_convar_change", function( len, ply )
	if ply:IsValid() and ply:IsPlayer() then
		local cvar = net.ReadString()
		-- We'll kick everyone trying to change non-WSTAR cvars.
		if !convars[cvar] then ply:Kick("Illegal convar change") return end
		-- Only admins can proceed.
		if !ply:IsSuperAdmin() and !( GetConVar("wstar_sv_admins_allowall"):GetBool() and ply:IsAdmin() ) then return end
		if !ply:IsSuperAdmin() and cvar == "wstar_sv_admins_allowall" then return end -- Of course, non-SuperAdmins can't change this cvar.
		RunConsoleCommand( cvar, net.ReadBool() == true and "1" or "0" )
	end
end )