----------------------------------------------------
--- Weapon S.T.A.R.: Setup, Transfer And Restore ---
--- Created by LibertyForce                      ---
--- http://steamcommunity.com/id/libertyforce    ---
----------------------------------------------------


WSTAR = { }


local version = "2.0"

local von = include( "lf_shared/von_1_3_4.lua" )
local dir = "wstar/"
local pat_fn_mid = "%. "
local pat_fn = "[^%w%-%+%$%%%(%)%[%]!#&',;=@_{}" .. pat_fn_mid .. "]"
local convars = { }


-- CVARS

local flag = FCVAR_REPLICATED
if SERVER then flag = FCVAR_ARCHIVE + FCVAR_REPLICATED end
convars["wstar_sv_auto"]				= { 1, flag + FCVAR_NOTIFY }
convars["wstar_sv_stripdefault"]		= { 1, flag + FCVAR_NOTIFY }
convars["wstar_sv_blockloadout"]		= { 0, flag + FCVAR_NOTIFY }
convars["wstar_sv_multi"]				= { 1, flag + FCVAR_NOTIFY }
convars["wstar_sv_transfer_enabled"]	= { 0, flag + FCVAR_NOTIFY }
convars["wstar_sv_transfer_spauto"]		= { 1, flag }
convars["wstar_sv_transfer_mpauto"]		= { 0, flag }
convars["wstar_sv_loadouts"]			= { 1, flag + FCVAR_NOTIFY }
convars["wstar_sv_wait_com"]			= { 5, flag + FCVAR_NOTIFY }
convars["wstar_sv_wait_restore"]		= { 5, flag + FCVAR_NOTIFY }
--convars["wstar_sv_delay"]				= { 1, flag + FCVAR_NOTIFY }
convars["wstar_sv_support_cw2"]			= { 1, flag + FCVAR_NOTIFY }
convars["wstar_sv_support_tfa"]			= { 1, flag + FCVAR_NOTIFY }
convars["wstar_sv_admins_allowall"]		= { 0, flag }
flag = nil

for cvar, v in pairs( convars ) do
	CreateConVar( cvar,	v[1], v[2] )
end


-- SHARED FUNCTIONS

-- If this is the first start, create a directory
if !file.Exists( dir, "DATA" ) then file.CreateDir( dir ) end


local function IsValidFilename( str )
	if str == "" or string.len( str ) > 100 or string.find( str, pat_fn ) or string.find( str, "^[" .. pat_fn_mid .. "]" ) or string.find( str, "[" .. pat_fn_mid .. "]$" ) then
		return false
	else
		return true
	end
end

local function DataToTbl( datastring )
	
	if not datastring then return end
	local checksum = string.Left( datastring, 8 )
	datastring = string.Right( datastring, string.len( datastring ) - 8 )
	if ( not checksum ) or ( not datastring ) then return end
	if checksum ~= bit.tohex( util.CRC( datastring ), 8 ) then return end
	datastring = util.Decompress( datastring )
	if not datastring then return end
	local tbl = von.deserialize( datastring )
	if not tbl then return end
	return tbl
	
end

local function TblToData( tbl )
	
	if not istable( tbl ) then return end
	local datastring = von.serialize( tbl )
	if not datastring then return end
	datastring = util.Compress( datastring )
	if not datastring then return end
	local checksum = bit.tohex( util.CRC( datastring ), 8 )
	if not checksum then return end
	datastring = checksum .. datastring
	return datastring
	
end


-- END OF SHARED

WSTAR.von, WSTAR.dir, WSTAR.convars, WSTAR.pat_fn_mid, WSTAR.pat_fn, WSTAR.version = von, dir, convars, pat_fn_mid, pat_fn, version
WSTAR.IsValidFilename, WSTAR.DataToTbl, WSTAR.TblToData = IsValidFilename, DataToTbl, TblToData

if SERVER then
	AddCSLuaFile( "lf_shared/von_1_3_4.lua" )
	AddCSLuaFile( "lf_wstar/cl_wstar_client.lua" )
	include( "lf_wstar/sv_wstar.lua" )
else
	include( "lf_wstar/cl_wstar_client.lua" )
end
