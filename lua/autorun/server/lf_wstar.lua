if !file.Exists( "wstar", "DATA" ) then file.CreateDir( "wstar" ) end

local convars = { }
convars["wstar_sv_auto"]				= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_stripdefault"]		= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_blockloadout"]		= { 0, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_multi"]				= { 0, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_transfer_enabled"]	= { 0, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_transfer_spauto"]		= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["wstar_sv_transfer_mpauto"]		= { 0, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }
convars["wstar_sv_loadouts"]			= { 1, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY ) }
convars["wstar_sv_admins_allowall"]		= { 0, bit.bor( FCVAR_ARCHIVE, FCVAR_REPLICATED ) }

for cvar, v in pairs( convars ) do
	CreateConVar( cvar,	v[1], v[2] )
end

AddCSLuaFile("../client/lf_wstar_client.lua")


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

local WSTAR_LO = { }
local WSTAR_Used = { }


local function WSTAR_GetWeapons( ply )

	local id = ply:SteamID()
	
	if !istable( WSTAR_WR[id] ) then WSTAR_WR[id] = { } end
	WSTAR_WR[id].weapon = { }
	WSTAR_WR[id].ammo = { }
	if !ply:Alive() then WSTAR_Used[id] = nil end
	
	for k,v in pairs(ply:GetWeapons()) do
		
		local weapon_class = v:GetClass()
		local weapon_clip1 = v:Clip1()
		local weapon_clip2 = v:Clip2()
		WSTAR_WR[id].weapon[weapon_class] = { weapon_clip1, weapon_clip2 }
		
		local ammo1_type = v:GetPrimaryAmmoType()
		local ammo1_amount = ply:GetAmmoCount( ammo1_type )
		WSTAR_WR[id].ammo[ammo1_type] = ammo1_amount

		local ammo2_type = v:GetSecondaryAmmoType()
		local ammo2_amount = ply:GetAmmoCount( ammo2_type )
		WSTAR_WR[id].ammo[ammo2_type] = ammo2_amount
		
	end

end

hook.Add("PostPlayerDeath","WSTAR_PlayerDeath", WSTAR_GetWeapons)


local function WSTAR_RestoreWeapons( ply )

	timer.Simple( 0.5, function()
	
		local id = ply:SteamID()
		local tbl
		
		if istable( WSTAR_LO[id] ) then
			tbl = WSTAR_LO[id]
		else
			tbl = WSTAR_WR[id]
		end
		
		if tbl and tbl.weapon and tbl.ammo then
		
			if GetConVar("wstar_sv_stripdefault"):GetBool() then
				ply:StripWeapons()
				ply:StripAmmo()
			end
			
			for k,v in pairs( tbl.weapon ) do
				ply:Give( k )
				local w = ply:GetWeapon( k )
				if w and IsValid(w) and w:IsWeapon() then
					if v[1] and v[1] >= 0 then w:SetClip1( v[1] ) end
					if v[2] and v[2] >= 0 then w:SetClip2( v[2] ) end
				end
			end
			
			for k,v in pairs( tbl.ammo ) do
				if v then ply:SetAmmo( v, k ) end
			end
			
			WSTAR_Used[id] = true
			
			if !tobool( ply:GetInfoNum( "wstar_cl_keeploadout", 0 ) ) then
				WSTAR_LO[id] = nil
			end

		end
		
	end )

end

hook.Add( "PlayerSpawn", "WSTAR_PlayerSpawn", function(ply)
	if GetConVar("wstar_sv_auto"):GetBool() then WSTAR_RestoreWeapons(ply) end
end )
hook.Add( "PlayerLoadout", "WSTAR_PlayerSpawn", function(ply)
	if GetConVar("wstar_sv_blockloadout"):GetBool() then return true end
end )


local function WSTAR_SaveToFile( )
	if GetConVar("wstar_sv_transfer_enabled"):GetBool() then
		for k,ply in pairs( player.GetHumans() ) do
			if ply:Alive() then
				WSTAR_GetWeapons( ply )
			end
		end
	end
end

local function WSTAR_SetupTimer()
	if GetConVar("wstar_sv_transfer_enabled"):GetBool() and GetConVar("wstar_sv_transfer_mpauto"):GetBool() then
		timer.Create( "WSTAR_Timer", 10, 0, WSTAR_SaveToFile )
	else
		if timer.Exists( "WSTAR_Timer" ) then timer.Remove( "WSTAR_Timer" ) end
	end
end

cvars.AddChangeCallback( "wstar_sv_transfer_enabled", WSTAR_SetupTimer )
cvars.AddChangeCallback( "wstar_sv_transfer_mpauto", WSTAR_SetupTimer )
WSTAR_SetupTimer()


hook.Add( "ShutDown", "WSTAR_Shutdown_Hook", function()
	if GetConVar("wstar_sv_transfer_enabled"):GetBool() then
		if game.SinglePlayer() then WSTAR_GetWeapons( player.GetByID(1) ) end
		file.Write( "wstar/transfer.txt", util.TableToJSON( WSTAR_WR ) )
	end
end )


util.AddNetworkString("wstar")
util.AddNetworkString("wstar_clearweapons")
util.AddNetworkString("wstar_save")
util.AddNetworkString("wstar_changelevel")

util.AddNetworkString("wstar_convar_sync")
util.AddNetworkString("wstar_convar_change")

util.AddNetworkString("wstar_lo_save_request")
util.AddNetworkString("wstar_lo_save_send")
util.AddNetworkString("wstar_lo_load_request")
util.AddNetworkString("wstar_lo_undo_request")

util.AddNetworkString("wstar_notify_restore")


net.Receive("wstar", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		local id = ply:SteamID()
		local success = false
		if !WSTAR_Used[id] or GetConVar("wstar_sv_multi"):GetBool() then
			WSTAR_RestoreWeapons( ply )
			success = true
		end
		net.Start("wstar_notify_restore")
		net.WriteBool( success )
		net.Send( ply )
	end
end)
net.Receive("wstar_clearweapons", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		local id = ply:SteamID()
		ply:StripWeapons()
		ply:StripAmmo()
		WSTAR_WR[id] = nil
	end
end)
net.Receive("wstar_save", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() and ( ply:IsSuperAdmin() or ( GetConVar("wstar_sv_admins_allowall"):GetBool() and ply:IsAdmin() ) ) then
		WSTAR_SaveToFile()
	end
end)
net.Receive("wstar_changelevel", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() and ( ply:IsSuperAdmin() or ( GetConVar("wstar_sv_admins_allowall"):GetBool() and ply:IsAdmin() ) ) then
		WSTAR_SaveToFile()
		RunConsoleCommand( "changelevel", net.ReadString() )
	end
end)


hook.Add( "PlayerAuthed", "WSTAR_ConVar_Sync", function( ply )
	local tbl = { }
	for cvar in pairs( convars ) do
		tbl[cvar] = GetConVar(cvar):GetInt()
	end
	net.Start("wstar_convar_sync")
	net.WriteTable( tbl )
	net.Send( ply )
end )

net.Receive("wstar_convar_change", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		local cvar = net.ReadString()
		if !convars[cvar] then ply:Kick("Illegal convar change") return end
		if !ply:IsSuperAdmin() and !( GetConVar("wstar_sv_admins_allowall"):GetBool() and ply:IsAdmin() ) then return end
		if !ply:IsSuperAdmin() and cvar == "wstar_sv_admins_allowall" then return end
		RunConsoleCommand( cvar, net.ReadBit() )
	end
end)


net.Receive("wstar_lo_save_request", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		local id = ply:SteamID()
		local name = net.ReadString()
		WSTAR_GetWeapons( ply )
		net.Start( "wstar_lo_save_send" )
		net.WriteString( name )
		net.WriteTable( WSTAR_WR[id] )
		net.Send( ply )
	end
end)

net.Receive("wstar_lo_load_request", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() and GetConVar("wstar_sv_loadouts"):GetBool() then
		local id = ply:SteamID()
		WSTAR_LO[id] = net.ReadTable()
	end
end)

net.Receive("wstar_lo_undo_request", function(len,ply)
	if ply:IsValid() and ply:IsPlayer() then
		local id = ply:SteamID()
		WSTAR_LO[id] = nil
	end
end)
