----------------------------------------------------
--- Weapon S.T.A.R.: Setup, Transfer And Restore ---
--- Created by LibertyForce                      ---
--- http://steamcommunity.com/id/libertyforce    ---
----------------------------------------------------


local version = "1.3"
local Frame -- This will be our main menu.
local WSTAR_LO -- Main table for saved loadouts

-- If this is the first start, create a directory client-side
if !file.Exists( "wstar", "DATA" ) then file.CreateDir( "wstar" ) end

-- Creates the client-side cvars. 
CreateClientConVar( "wstar_cl_keeploadout", "0", true, true )

-- If the player has already saved loadouts, we'll load them.
if file.Exists( "wstar/loadouts.txt", "DATA" ) then
	WSTAR_LO = util.JSONToTable( file.Read( "wstar/loadouts.txt", "DATA" ) )
	if !istable( WSTAR_LO ) then WSTAR_LO = { } end
else
	WSTAR_LO = { }
end


-- The server sends the server-side cvars for sync. Note, that we create them here without FCVAR_ARCHIVE,
-- because we don't want to fill the client.vdf file with stuff he doesn't need.
net.Receive("wstar_convar_sync", function()
	local tbl = net.ReadTable()
	for k,v in pairs( tbl ) do
		CreateConVar( k, v, { FCVAR_REPLICATED } )
	end
end)

-- After the client requested to save a new Loadout, the server sends the weapons.
-- We'll save them to a file on the CLIENTS computer.
net.Receive("wstar_lo_save", function()
	local name = net.ReadString()
	WSTAR_LO[name] = net.ReadTable()
	file.Write( "wstar/loadouts.txt", util.TableToJSON( WSTAR_LO, true ) )
end)

-- The server tells the player, whether he was allowed to restore his weapons or not.
net.Receive("wstar", function()
	local success = net.ReadBool()
	if success then
		notification.AddLegacy( "Weapons restored.", NOTIFY_GENERIC, 5 )
	else
		notification.AddLegacy( "Weapon Restore already used up in this spawn.", NOTIFY_ERROR, 5 )
	end
end)

-- This function checks, if the player wants to enter something in a text field. In that case, the menu
-- grabs the keyboard and blocks the player's movement. After he's finished, the keyboard is set free again.
local function KeyboardOn( pnl )
	if ( IsValid( Frame ) and IsValid( pnl ) and pnl:HasParent( Frame ) ) then
		Frame:SetKeyboardInputEnabled( true )
	end
end
hook.Add( "OnTextEntryGetFocus", "wstar_keyboard_on", KeyboardOn )
local function KeyboardOff( pnl )
	if ( IsValid( Frame ) and IsValid( pnl ) and pnl:HasParent( Frame ) ) then
		Frame:SetKeyboardInputEnabled( false )
	end
end
hook.Add( "OnTextEntryLoseFocus", "wstar_keyboard_off", KeyboardOff )

-- Sends cvar changes to the server.
local function ChangeConVar( p, v )
	net.Start("wstar_convar_change")
	net.WriteString( p.cvar )
	net.WriteBool( v )
	net.SendToServer()
end


-- The main menu.
local function WSTAR_Menu( )

	Frame = vgui.Create( "DFrame" )
	local fw, fh = 600, 700
	local pw, ph = fw - 10, fh - 62
	Frame:SetSize( fw, fh )
	Frame:SetTitle( "Weapon S.T.A.R.: Setup, Transfer And Restore" )
	Frame:SetVisible( true )
	Frame:SetDraggable( true )
	Frame:ShowCloseButton( true )
	Frame:Center()
	Frame:MakePopup()
	Frame:SetKeyboardInputEnabled( false )
	
	local Sheet = vgui.Create( "DPropertySheet", Frame )
	Sheet:Dock( FILL )
	
	
	local panel = vgui.Create( "DPanel", Sheet )
	Sheet:AddSheet( "Weapon Loadouts", panel, "icon16/arrow_refresh.png" )
	
		local b = vgui.Create( "DButton", panel )
		local w, h = 300, 50
		b:SetPos( pw / 2 - w / 2, 20 )
		b:SetSize( w, h )
		b:SetText( "Restore Weapons" )
		b.DoClick = function()
			LocalPlayer():ConCommand("wstar")
		end
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 145, 80 )
		b:SetSize( 145, 20 )
		b:SetText( "Clear all weapons" )
		b.DoClick = function()
			net.Start("wstar_clearweapons")
			net.SendToServer()
			notification.AddLegacy( "All weapons removed.", NOTIFY_CLEANUP, 5 )
		end
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 300, 80 )
		b:SetSize( 145, 20 )
		b:SetText( "Suicide" )
		b.DoClick = function()
			LocalPlayer():ConCommand("kill")
		end
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 130 )
		t:SetText( "Weapon Loadouts" )
		t:SetDark( true )
		t:SetFont( "DermaLarge" )
		t:SizeToContents()
		
		local LoadoutList = vgui.Create( "DListView", panel )
		LoadoutList:SetPos( 10, 180 )
		LoadoutList:SetSize( 280, 430 )
		LoadoutList:SetMultiSelect( true )
		LoadoutList:AddColumn( "Weapon Loadouts" )

		local function PopulateList()
			LoadoutList:Clear()
			for k in pairs( WSTAR_LO ) do
				LoadoutList:AddLine( k )
			end
			LoadoutList:SortByColumn( 1 )
		end
		
		PopulateList()
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 320, 180 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "Save current weapons as a Loadout:" )
		t:SetWrap( true )
		
		local LoadoutEntry = vgui.Create( "DTextEntry", panel )
		LoadoutEntry:SetPos( 320, 200 )
		LoadoutEntry:SetSize( 180, 20 )
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 510, 200 )
		b:SetSize( 50, 20 )
		b:SetText( "Add new" )
		b.DoClick = function()
			local name = LoadoutEntry:GetValue()
			if name == "" then return end
			WSTAR_LO[name] = { }
			net.Start("wstar_lo_save")
			net.WriteString( name )
			net.SendToServer()
			PopulateList( LoadoutList )
		end
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 320, 240 )
		t:SetText( "Selected\nentry:" )
		t:SetDark( true )
		t:SizeToContents()
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 380, 240 )
		b:SetSize( 85, 25 )
		b:SetText( "Overwrite" )
		b.DoClick = function()
			local sel = LoadoutList:GetSelected()
			if !sel[1] then return end
			local name = tostring( sel[1]:GetValue(1) )
			net.Start("wstar_lo_save")
			net.WriteString( name )
			net.SendToServer()
			PopulateList( LoadoutList )
		end
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 475, 240 )
		b:SetSize( 85, 25 )
		b:SetText( "Delete" )
		b.DoClick = function()
			local sel = LoadoutList:GetSelected()
			for k,v in pairs( sel ) do
				local name = tostring( v:GetValue(1) )
				WSTAR_LO[name] = nil
			end
			file.Write( "wstar/loadouts.txt", util.TableToJSON( WSTAR_LO, true ) )
			PopulateList( LoadoutList )
		end
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c.cvar = "wstar_cl_keeploadout"
		c:SetPos( 320, 370 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Persistent Loadout" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = function( p, v )
			RunConsoleCommand( c.cvar, v == true and "1" or "0" )
		end
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 320, 390 )
		t:SetDark( true )
		t:SetText( "If enabled, you will always spawn with this loadout.\nDisabling this, will take one respawn to apply." )
		t:SizeToContents()
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 320, 440 )
		b:SetSize( 240, 50 )
		b:SetText( "Request\nLoadout" )
		b:SetEnabled( GetConVar("wstar_sv_loadouts"):GetBool() )
		b.DoClick = function()
			local sel = LoadoutList:GetSelected()
			if !sel[1] then return end
			local name = tostring( sel[1]:GetValue(1) )
			if istable( WSTAR_LO[name] ) then
				net.Start("wstar_lo_load")
				net.WriteTable( WSTAR_LO[name] )
				net.SendToServer()
				notification.AddLegacy( "Loadout will be applied upon respawn.", NOTIFY_GENERIC, 5 )
			end
		end
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 320, 500 )
		b:SetSize( 240, 20 )
		b:SetText( "Undo request" )
		b.DoClick = function()
			net.Start("wstar_lo_undo")
			net.SendToServer()
			notification.AddLegacy( "Loadout request undone.", NOTIFY_CLEANUP, 5 )
		end
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 320, 540 )
		if GetConVar("wstar_sv_loadouts"):GetBool() then
			t:SetText( "Loadout will be applied on next respawn." )
		else
			t:SetText( "Loadouts are currently disabled by Admin." )
			t:SetTextColor( Color( 255, 0, 0, 255 ) )
		end
		t:SetDark( true )
		t:SizeToContents()
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 320, 570 )
		t:SetText( "Or click the Restore Button above. Remember,\nthis will only work if either Auto Restore is disabled\nor Multiple Restores is enabled." )
		t:SetDark( true )
		t:SizeToContents()
		
		
	if ( LocalPlayer():IsSuperAdmin() or ( GetConVar("wstar_sv_admins_allowall"):GetBool() and LocalPlayer():IsAdmin() ) ) then
	
	local panel = vgui.Create( "DPanel", Sheet )
	Sheet:AddSheet( "Main Settings", panel, "icon16/table_gear.png" )	
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 20 )
		t:SetText( "Main Settings" )
		t:SetDark( true )
		t:SetFont( "DermaLarge" )
		t:SizeToContents()
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c.cvar = "wstar_sv_auto"
		c:SetPos( 20, 70 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Auto Restore" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = ChangeConVar
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 90 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "If enabled, your weapons will be restored immediately after respawning.\nIf disabled, you will have to use the manual button on the first tab." )
		t:SetWrap( true )
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c.cvar = "wstar_sv_stripdefault"
		c:SetPos( 20, 140 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Strip default weapons" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = ChangeConVar
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 160 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "If enabled, the default loadout will be removed upon restore. Please note, that your ammo will be overwritten regardless. Recommended to keep on." )
		t:SetWrap( true )
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c.cvar = "wstar_sv_blockloadout"
		c:SetPos( 20, 210 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Block default weapon loadout" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = ChangeConVar
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 230 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "If enabled, the default weapon loadout will be blocked. This is useful for transition between maps (like the HL2 campain). By default the Sandbox gamemode deletes all your weapons upon spawn and replaces them with the default loadout. Enabling this setting prevents this.\n\nShould be enabled on maps that give weapons automatically but should be disabled otherwise. Disabled by default. For manual map changes, you might want to consider: Weapon Transfer (see 2nd tab above)." )
		t:SetWrap( true )
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c.cvar = "wstar_sv_multi"
		c:SetPos( 20, 330 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Allow multiple restores" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = ChangeConVar
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 350 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "If enabled, you will be able to restore your weapons and ammo manually anytime. Normally, you can only restore your weapons once per spawn. This allows cheating for more ammo.\n\nThis also effects Loadouts! If disabled, Loadouts can only be applied on next respawn. Disabled by default." )
		t:SetWrap( true )
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c.cvar = "wstar_sv_loadouts"
		c:SetPos( 20, 420 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Enable Loadouts" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = ChangeConVar
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 440 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "If enabled, all players can use the Loadout function.\nIf disabled, they can still save and edit Loadouts but not apply them." )
		t:SetWrap( true )
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c.cvar = "wstar_sv_support_cw2"
		c:SetPos( 20, 490 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Enable Customizable Weaponry 2.0 support" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = ChangeConVar
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 510 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "Enables support for Customizable Weaponry 2.0 attachments. If enabled, all attachments on CW2 weapons can be restored. This setting has no effect if CW2 isn't installed." )
		t:SetWrap( true )
		
		if LocalPlayer():IsSuperAdmin() then
		
			local t = vgui.Create( "DLabel", panel )
			t:SetPos( 20, 580 )
			t:SetAutoStretchVertical( true )
			t:SetSize( pw - 40, 0 )
			t:SetDark( true )
			t:SetFont( "DermaDefaultBold" )
			t:SetText( "SUPER-ADMINS ONLY:" )
			t:SetWrap( true )
			
			local c = vgui.Create( "DCheckBoxLabel", panel )
			c.cvar = "wstar_sv_admins_allowall"
			c:SetPos( 20, 600 )
			c:SetValue( GetConVar(c.cvar):GetBool() )
			c:SetText( "Allow all admins to access Settings and Weapon Transfer." )
			c:SetDark( true )
			c:SizeToContents()
			c:SetEnabled( false )
			c.OnChange = ChangeConVar
		
		end
	
	
	local panel = vgui.Create( "DPanel", Sheet )
	Sheet:AddSheet( "Weapon Transfer", panel, "icon16/package_go.png" )
	
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 20 )
		t:SetText( "Weapon Transfer" )
		t:SetDark( true )
		t:SetFont( "DermaLarge" )
		t:SizeToContents()
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c.cvar = "wstar_sv_transfer_enabled"
		c:SetPos( 20, 70 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Enable Weapon Transfer" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = ChangeConVar
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 100 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "Weapon Transfer allows you to transfer all your current weapons and ammo to another map. This is useful for adventure / horror maps made of multiple parts.\n\nThis function is different in Single- and MultiPlayer. Please read below carefully." )
		t:SetWrap( true )
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 200 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetFont( "DermaDefaultBold" )
		t:SetText( "SINGLEPLAYER:" )
		t:SetWrap( true )
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 230 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "In SinglePlayer, your weapons will save to a file on your disk, when the game ends (eg. map change, disconnect). When you load a new game, all your weapons will be restored.\nRecommended to keep on by default. Disable Weapon Transfer completely (checkbox on top), if you don't want to use it." )
		t:SetWrap( true )
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c.cvar = "wstar_sv_transfer_spauto"
		c:SetPos( 20, 290 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Enable autosave on shutdown" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = ChangeConVar
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 350 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetFont( "DermaDefaultBold" )
		t:SetText( "MULTIPLAYER:" )
		t:SetWrap( true )
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 380 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "In Multiplayer, it is NOT possible to automatically save the weapons of all players on map change. You can either do it manually with the functions below, BEFORE the map changes. Or you can tick the checkbox below, to enable a timer, that will save the data every 10 seconds." )
		t:SetWrap( true )
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c.cvar = "wstar_sv_transfer_mpauto"
		c:SetPos( 20, 430 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Enable 10 sec. autosave timer" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = ChangeConVar
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 20, 500 )
		b:SetSize( 150, 50 )
		b:SetText( "Save weapons\nfor all players" )
		b.DoClick = function()
			net.Start("wstar_save")
			net.SendToServer()
			if GetConVar("wstar_sv_transfer_enabled"):GetBool() then
				notification.AddLegacy( "Weapons for all players saved.", NOTIFY_GENERIC, 5 )
			end
		end
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 560 )
		t:SetAutoStretchVertical( true )
		t:SetSize( 150, 0 )
		t:SetDark( true )
		t:SetText( "and disconnect / change map manually" )
		t:SetWrap( true )
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 200, 520 )
		t:SetText( "OR" )
		t:SetDark( true )
		t:SetFont( "DermaLarge" )
		t:SizeToContents()
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 260, 500 )
		t:SetAutoStretchVertical( true )
		t:SetSize( 100, 0 )
		t:SetDark( true )
		t:SetText( "Enter Map name:" )
		t:SetWrap( true )
		
		local MapEntry = vgui.Create( "DTextEntry", panel )
		MapEntry:SetPos( 260, 520 )
		MapEntry:SetSize( 300, 20 )
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 260, 560 )
		b:SetSize( 300, 20 )
		b:SetText( "Save weapons and change map" )
		b.DoClick = function()
			net.Start("wstar_save")
			net.WriteString( MapEntry:GetValue() )
			net.SendToServer()
		end	
	
	end
	
	
	local panel = vgui.Create( "DPanel", Sheet )
	Sheet:AddSheet( "About", panel, "icon16/help.png" )
	
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 20 )
		t:SetText( "Weapon S.T.A.R.:\nSetup, Transfer and Restore" )
		t:SetDark( true )
		t:SetFont( "DermaLarge" )
		t:SizeToContents()
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 100 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetFont( "DermaDefaultBold" )
		t:SetText( "Version "..version.." - Created by LibertyForce." )
		t:SetWrap( true )
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 140 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "If you encounter any problems (especially LUA errors!), please report them on the addon page. Got any suggestions? Feel free to write them down. And if you like this mod, please leave a thumbs up!" )
		t:SetWrap( true )
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 20, 190 )
		b:SetSize( 150, 25 )
		b:SetText( "Visit addon page" )
		b.DoClick = function()
			gui.OpenURL( "http://steamcommunity.com/sharedfiles/filedetails/?id=492765756" )
		end
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 190, 190 )
		b:SetSize( 150, 25 )
		b:SetText( "More addons" )
		b.DoClick = function()
			gui.OpenURL( "http://steamcommunity.com/workshop/filedetails/?id=500953460" )
		end
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 360, 190 )
		b:SetSize( 150, 25 )
		b:SetText( "My Playermodels (Anime)" )
		b.DoClick = function()
			gui.OpenURL( "http://steamcommunity.com/sharedfiles/filedetails/?id=334922161" )
		end
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 250 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "Console Commands:" )
		t:SetWrap( true )
		
		local t = vgui.Create( "DHTML", panel )
		t:SetSize( pw - 35, 350 )
		t:SetPos( 10, 270 )
		t:SetHTML( [[
			<html><body style="background-color: #FFFFFF; font-family: sans-serif; font-size: 10pt">
			<h3>Client-side commands and convars</h3><br>These can be executed / changed from client console.<br><br><ul class="bb_ul"><li><b>wstar_menu</b><br>Opens the main menu. Recommended to bind this to a key.<br><br></li><li><b>wstar</b><br>Restores your weapons. Same as the big Restore Weapons button.<br><br></li><li><b>wstar_save</b><br>Admins only: Manually save the weapons of all players to a file. Used to prepare Weapon Transfer. Works only if Weapon Transfer is enabled.<br><br><br></li><li><b>wstar_cl_keeploadout</b> 0 / 1 <i>(Default: 0)</i><br>Enable persistent Weapon Loadouts.</li></ul><br><br><h3>Server-side convars</h3><br>These can only be changed from server console / rcon. Or use the menu, which allows admins to easily change all settings.<br><br><ul class="bb_ul"><li><b>wstar_sv_auto</b> 0 / 1 <i>(Default: 1)</i><br>Toggle auto restore of weapons. Can be used to disable the addon, if you don't want to use it.<br><br></li><li><b>wstar_sv_stripdefault</b> 0 / 1 <i>(Default: 1)</i><br>If enabled, the default loadout will be removed upon restore. Please note, that your ammo will be overwritten regardless. Recommended to keep on.<br><br></li><li><b>wstar_sv_blockloadout</b> 0 / 1 <i>(Default: 0)</i><br>If enabled, the default weapon loadout will be blocked. This is useful for transition between maps (like the HL2 campain).<br><br></li><li><b>wstar_sv_multi</b> 0 / 1 <i>(Default: 0)</i><br>If enabled, you will be able to restore your weapons and ammo manually anytime. Normally, you can only restore your weapons once per spawn. This allows cheating for more ammo.<br><br></li><li><b>wstar_sv_loadouts</b> 0 / 1 <i>(Default: 1)</i><br>Toggles the Loadout function. Disable if you don't want to use Loadouts on your server.<br><br></li><li><b>wstar_sv_support_cw2</b> 0 / 1 <i>(Default: 1)</i><br>Enables support for Customizable Weaponry 2.0 attachments.<br><br></li><li><b>wstar_sv_transfer_enabled</b> 0 / 1 <i>(Default: 0)</i><br>Toggles the Weapon Transfer function. You should only enable this, if you want to transfer weapons, otherwise you may startup Gmod and end up with yesterday's weapons.<br><br></li><li><b>wstar_sv_transfer_spauto</b> 0 / 1 <i>(Default: 1)</i><br>Toggles auto save for Weapon Transfer in SinglePlayer. If you disable that, you will have to use the wstar_save command BEFORE changing the map (or use the changelevel function in the menu).<br><br></li><li><b>wstar_sv_transfer_mpauto</b> 0 / 1 <i>(Default: 0)</i><br>Multiplayer only: Creates a timer, which saves the weapons of all players every 10 seconds. Normally you'll need to save manually before Weapon Transfer in multiplayer. Enabling this might cause performance issues. Use on your own risk!<br><br></li><li><b>wstar_sv_admins_allowall</b> 0 / 1 <i>(Default: 0)</i><br>If enabled, all other settings can be changed by normal admins via menu. Otherwise, only Super-Admins can change settings.<br><i>Of course, this setting can only be changed by Super-Admins / rcon / server console.</i></li></ul>
			</body></html>
		]] )
		
end

local function MenuToggle()
	if IsValid( Frame ) then Frame:Close() else WSTAR_Menu() end
end


-- Spawn Menu entry.
local function WSTAR_SpawnMenu( panel )
	panel:AddControl("Label", {Text = " "})
	local a = panel:AddControl("Button", {Label = "Restore Weapons", Command = "wstar"})
	a:SetSize(0, 50)
	panel:AddControl("Label", {Text = " "})
	local a = panel:AddControl("Button", {Label = "Open Menu", Command = "wstar_menu"})
	a:SetSize(0, 40)
	panel:AddControl("Label", {Text = " "})
	local a = panel:AddControl("Label", {Text = "How to open the Settings Menu on gamemodes without SpawnMenu (such as Horror gamemodes, etc.):"})
	a:SetFont( "DermaDefaultBold" )
	panel:AddControl("Label", {Text = "Open Console and type in:\nwstar_menu"})
	panel:AddControl("Label", {Text = "For easier access to the menu, it is recommended that you bind this command to a key. To do that, open your console and type in:"})
	local a = panel:AddControl("RichText", {Text = ""})
	a:InsertColorChange( 0, 0, 0, 255 )
	a:AppendText( "bind X wstar_menu" )
	a:SetVerticalScrollbarEnabled( false )
	panel:AddControl("Label", {Text = "You can copy and paste above command to your console. Replace X with a valid key on your keyboard."})
end
hook.Add( "PopulateToolMenu", "WSTAR_SpawnMenu_Hook", function() spawnmenu.AddToolMenuOption( "Options", "Player", "WSTAR_SpawnMenuItem", "Weapon S.T.A.R.", "", "", WSTAR_SpawnMenu, {} ) end )

-- Context menu icon.
list.Set( "DesktopWindows", "WSTAR", {
	title		= "Weapon STAR",
	icon		= "icon64/wstar_icon.png",
	init		= function( icon, window )
		window:Remove()
		RunConsoleCommand("wstar_menu")
	end
} )


-- Client-side concommands.

concommand.Add( "wstar_menu", MenuToggle ) -- Opens the menu.

concommand.Add( "wstar", function() -- Manual weapon restore.
	net.Start("wstar")
	net.SendToServer()
end )

concommand.Add( "wstar_save", function() -- Save all players weapons.
	net.Start("wstar_save")
	net.SendToServer()
end )
