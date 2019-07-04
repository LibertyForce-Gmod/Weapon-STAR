----------------------------------------------------
--- Weapon S.T.A.R.: Setup, Transfer And Restore ---
--- Created by LibertyForce                      ---
--- http://steamcommunity.com/id/libertyforce    ---
----------------------------------------------------


local Menu = { } -- This will be our main menu.
--local WSTAR_LO = { } -- Main table for saved loadouts
local von, dir, convars, pat_fn_mid, pat_fn, version = WSTAR.von, WSTAR.dir, WSTAR.convars, WSTAR.pat_fn_mid, WSTAR.pat_fn, WSTAR.version
local IsValidFilename, DataToTbl, TblToData = WSTAR.IsValidFilename, WSTAR.DataToTbl, WSTAR.TblToData
local dir_loadouts = dir .. "loadouts/"
local last_com, last_restore

-- If this is the first start, create a directory client-side
if !file.Exists( "wstar", "DATA" ) then file.CreateDir( "wstar" ) end
if !file.Exists( dir_loadouts, "DATA" ) then file.CreateDir( dir_loadouts ) end

-- Creates the client-side cvars. 
CreateClientConVar( "wstar_cl_keeploadout", "0", true, true )
CreateClientConVar( "wstar_cl_delay", "1", true, true )


local function LoadoutGetList()
	local list = file.Find( dir_loadouts .."/*.dat", "DATA" )
	if not istable( list ) then 
		list = { }
	end
	return list
end

local function SendLoadout( filename )

	local datastring = file.Read( dir_loadouts .. filename .. ".dat", "DATA" )
	if not datastring then return end
	
	local checksum = string.Left( datastring, 8 )
	local test = string.Right( datastring, string.len( datastring ) - 8 )
	if ( not checksum ) or ( not test ) then return end
	test = util.Decompress( test )
	if not test then return end
	if not istable( von.deserialize( test ) ) then return end
	test, checksum = nil
	
	local size = string.len( datastring )
	if size > 65000 then return end
	
	net.Start( "wstar_lo_load" )
	net.WriteUInt( size, 16 )
	net.WriteData( datastring, size )
	net.SendToServer()
	
	return true
	
end


-- Converting old v1 Loadout format
if ( not file.Exists( "wstar/loadouts_isconvertedv2.txt", "DATA" ) ) and file.Exists( "wstar/loadouts.txt", "DATA" ) then
	file.Write( "wstar/loadouts_isconvertedv2.txt", "" )
	local old = util.JSONToTable( file.Read( "wstar/loadouts.txt", "DATA" ) )
	if istable( old ) then
		local current_run = 0
		local used_filenames = { }
		for k, v in pairs( old ) do
			
			current_run = current_run + 1
			local filename = tostring( k )
			local size = string.len( filename )
			
			filename = string.gsub( filename, pat_fn, "_" )
			
			if string.len( filename ) > 100 then
				filename = string.Left( filename, 100 )
			end
			
			filename = string.gsub( filename, "^[" .. pat_fn_mid .. "]", "_" )
			filename = string.gsub( filename, "[" .. pat_fn_mid .. "]$", "_" )
			
			if used_filenames[ filename ] then
				filename = filename .. "-" .. string.format( "%03u", tostring( current_run ) )
			end
			
			used_filenames[ filename ] = true
			
			local tbl = { }
			
			tbl.weapon = { }
			for k2, v2 in pairs( v.weapon ) do
				local insert = { }
				insert.class = tostring( k2 )
				insert.clip1 = v2[1]
				insert.clip2 = v2[2]
				if v2.cw2attachments then
					insert.cw2attachments = v2.cw2attachments
				end
				table.insert( tbl.weapon, insert )
			end
			
			tbl.ammo = { }
			for k2, v2 in pairs( v.ammo ) do
				tbl.ammo[ tostring( k2 ) ] = v2
			end
			
			local datastring = TblToData( tbl )
			if datastring then
				file.Write( dir_loadouts .. filename .. ".dat", datastring )
			end

		end
	end
end


-- After the client requested to save a new Loadout, the server sends the weapons.
-- We'll save them to a file on the CLIENTS computer.
net.Receive( "wstar_lo_save", function()
	local filename = net.ReadString()
	local size = net.ReadUInt( 16 )
	local datastring = net.ReadData( size )
	if datastring then
		file.Write( dir_loadouts .. filename .. ".dat", datastring )
		if IsValid( Menu.Frame ) and IsValid( Menu.LoadoutList ) then
			Menu.LoadoutList.Populate()
		end
		notification.AddLegacy( "Loadout saved.", NOTIFY_GENERIC, 5 )
	else
		notification.AddLegacy( "Saving loadout failed.", NOTIFY_ERROR, 5 )
	end
	filename, size, datastring = nil
end )

-- The server tells the player, whether he was allowed to restore his weapons or not.
net.Receive( "wstar", function()
	local success = net.ReadBool()
	if success then
		notification.AddLegacy( "Weapons restored.", NOTIFY_GENERIC, 5 )
	else
		notification.AddLegacy( "Weapon Restore already used up in this spawn.", NOTIFY_ERROR, 5 )
	end
end )

net.Receive( "wstar_clearweapons", function()
	notification.AddLegacy( "All weapons removed.", NOTIFY_CLEANUP, 5 )
end )

net.Receive( "wstar_lo_undo", function()
	notification.AddLegacy( "Loadout request undone.", NOTIFY_CLEANUP, 5 )
end )

net.Receive( "wstar_lo_load", function()
	notification.AddLegacy( "Loadout will be applied upon respawn.", NOTIFY_GENERIC, 5 )
end )


-- Support for TFA attachments, requires init client-side
net.Receive( "wstar_attach_tfa", function()
	if not LocalPlayer():Alive() then return end
	local size = net.ReadUInt( 16 )
	local datastring = net.ReadData( size )
	local tbl = DataToTbl( datastring )
	if tbl then
		local weapon_class = tbl.class
		local w = LocalPlayer():GetWeapon( weapon_class )
		tbl = tbl.content
		timer.Create( "wstar_timer_attach_" .. weapon_class, 0.1, 100, function()
			if not LocalPlayer():Alive() then return end
			if istable( TFA ) and w.SetTFAAttachment then
				timer.Remove( "wstar_timer_attach_" .. weapon_class )
				w:InitAttachments()
				timer.Simple( 0.1, function()
					if not LocalPlayer():Alive() then return end
					for cat, att in pairs( tbl ) do
						w:SetTFAAttachment(cat, att, true)
					end
				end )
			end
		end )
	end
	size, datastring = nil
end )


-- Sends cvar changes to the server.
local function ChangeConVar( p, v )
	net.Start("wstar_convar_change")
	net.WriteString( p.cvar )
	net.WriteBool( v )
	net.SendToServer()
end


-- This function checks, if the player wants to enter something in a text field. In that case, the menu
-- grabs the keyboard and blocks the player's movement. After he's finished, the keyboard is set free again.
local function KeyboardOn( pnl )
	if ( IsValid( Menu.Frame ) and IsValid( pnl ) and pnl:HasParent( Menu.Frame ) ) then
		Menu.Frame:SetKeyboardInputEnabled( true )
	end
end
hook.Add( "OnTextEntryGetFocus", "wstar_keyboard_on", KeyboardOn )
local function KeyboardOff( pnl )
	if ( IsValid( Menu.Frame ) and IsValid( pnl ) and pnl:HasParent( Menu.Frame ) ) then
		Menu.Frame:SetKeyboardInputEnabled( false )
	end
end
hook.Add( "OnTextEntryLoseFocus", "wstar_keyboard_off", KeyboardOff )


-- Blur Code by: https://facepunch.com/member.php?u=237675
local blur = Material( "pp/blurscreen" )
local function DrawBlur( panel, amount )
	local x, y = panel:LocalToScreen( 0, 0 )
	local scrW, scrH = ScrW(), ScrH()
	surface.SetDrawColor( 255, 255, 255 )
	surface.SetMaterial( blur )
	for i = 1, 3 do
		blur:SetFloat( "$blur", ( i / 3 ) * ( amount or 6 ) )
		blur:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect( x * -1, y * -1, scrW, scrH )
	end
end


-- The main menu.
local function WSTAR_Menu( )

	Menu.Frame = vgui.Create( "DFrame" )
	local window_title = "Weapon S.T.A.R.: Setup, Transfer And Restore"
	local fw, fh = 600, 700
	local pw, ph = fw - 10, fh - 62
	Menu.Frame:SetSize( fw, fh )
	Menu.Frame:SetTitle( window_title )
	Menu.Frame:SetVisible( true )
	Menu.Frame:SetDraggable( true )
	Menu.Frame:ShowCloseButton( true )
	Menu.Frame:Center()
	Menu.Frame:MakePopup()
	Menu.Frame:SetKeyboardInputEnabled( false )
	function Menu.Frame:Paint( w, h )
		DrawBlur( self, 2 )
		draw.RoundedBox( 10, 0, 0, w, h, Color( 0, 99, 177, 200 ) )
		return true
	end
	function Menu.Frame.lblTitle:Paint( w, h )
		draw.SimpleTextOutlined( window_title, "DermaDefaultBold", 1, 2, Color( 255, 255, 255, 255 ), 0, 0, 1, Color( 0, 0, 0, 255 ) )
		return true
	end
	
	local Sheet = vgui.Create( "DPropertySheet", Menu.Frame )
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
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 455, 52 )
		t:SetAutoStretchVertical( true )
		t:SetSize( 35, 0 )
		t:SetDark( true )
		t:SetText( "Delay:" )
		t:SetWrap( true )
		
		local s = vgui.Create( "DNumberWang", panel )
		s.cvar = "wstar_cl_delay"
		s:SetWide( 40 )
		s:SetPos( 490, 50 )
		s:SetDecimals( 1 )
		s:SetInterval( 0.5 )
		s:SetMinMax( 1, 5 )
		s:SetValue( GetConVar( "wstar_cl_delay" ):GetFloat() )
		s.OnValueChanged = function( p, v )
			RunConsoleCommand( p.cvar, v )
		end
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 145, 80 )
		b:SetSize( 145, 20 )
		b:SetText( "Clear all weapons" )
		b.DoClick = function()
			if game.SinglePlayer() or not ( last_com and last_com > CurTime() ) then
				last_com = CurTime() + GetConVar("wstar_sv_wait_com"):GetInt()
				net.Start("wstar_clearweapons")
				net.SendToServer()
			else
				notification.AddLegacy( "Please wait longer between requests.", NOTIFY_ERROR, 5 )
			end
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
		
		Menu.LoadoutList = vgui.Create( "DListView", panel )
		Menu.LoadoutList:SetPos( 10, 180 )
		Menu.LoadoutList:SetSize( 280, 430 )
		Menu.LoadoutList:SetMultiSelect( true )
		Menu.LoadoutList:AddColumn( "Weapon Loadouts" )

		function Menu.LoadoutList:Populate()
			Menu.LoadoutList:Clear()
			for _, v in pairs( LoadoutGetList() ) do
				local name = string.TrimRight( v, ".dat" )
				if IsValidFilename( name ) then
					Menu.LoadoutList:AddLine( name )
				end
			end
			Menu.LoadoutList:SortByColumn( 1 )
		end
		
		Menu.LoadoutList:Populate()
		
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
		LoadoutEntry.AllowInput = function( self, str )
			if string.find( str, pat_fn ) then
				return true
			else
				return false
			end
		end
		local function Send()
			if game.SinglePlayer() or not ( last_com and last_com > CurTime() ) then
				last_com = CurTime() + GetConVar("wstar_sv_wait_com"):GetInt()
				local name = LoadoutEntry:GetValue()
				if not IsValidFilename( name ) then
					notification.AddLegacy( "Invalid filename.", NOTIFY_ERROR, 5 )
					return
				end
				net.Start("wstar_lo_save")
				net.WriteString( name )
				net.SendToServer()
			else
				notification.AddLegacy( "Please wait longer between requests.", NOTIFY_ERROR, 5 )
			end
		end
		LoadoutEntry.OnEnter = Send
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 510, 200 )
		b:SetSize( 50, 20 )
		b:SetText( "Add new" )
		b.DoClick = Send
		
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
			if game.SinglePlayer() or not ( last_com and last_com > CurTime() ) then
				last_com = CurTime() + GetConVar("wstar_sv_wait_com"):GetInt()
				local sel = Menu.LoadoutList:GetSelected()
				if #sel < 1 then
					notification.AddLegacy( "Nothing selected.", NOTIFY_ERROR, 5 )
					return
				elseif #sel > 1 then
					notification.AddLegacy( "You can't overwrite more than one entry.", NOTIFY_ERROR, 5 )
					return
				end
				if !sel[1] then return end
				local name = tostring( sel[1]:GetValue(1) )
				net.Start("wstar_lo_save")
				net.WriteString( name )
				net.SendToServer()
			else
				notification.AddLegacy( "Please wait longer between requests.", NOTIFY_ERROR, 5 )
			end
		end
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 475, 240 )
		b:SetSize( 85, 25 )
		b:SetText( "Delete" )
		b.DoClick = function()
			local sel = Menu.LoadoutList:GetSelected()
			if #sel < 1 then
				notification.AddLegacy( "Nothing selected.", NOTIFY_ERROR, 5 )
				return
			end
			for k,v in pairs( sel ) do
				local name = tostring( v:GetValue(1) )
				file.Delete( dir_loadouts .. name .. ".dat" )
			end
			Menu.LoadoutList:Populate()
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
		
		local function RequestLoadout()
			if game.SinglePlayer() or not ( last_com and last_com > CurTime() ) then
				last_com = CurTime() + GetConVar("wstar_sv_wait_com"):GetInt()
				local sel = Menu.LoadoutList:GetSelected()
				if #sel < 1 then
					notification.AddLegacy( "Nothing selected.", NOTIFY_ERROR, 5 )
					return
				end
				local name = tostring( sel[1]:GetValue(1) )
				local success = SendLoadout( name )
				if not success then
					notification.AddLegacy( "File is invalid.", NOTIFY_ERROR, 5 )
				end
			else
				notification.AddLegacy( "Please wait longer between requests.", NOTIFY_ERROR, 5 )
			end
		end
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 320, 440 )
		b:SetSize( 240, 50 )
		b:SetText( "Request\nLoadout" )
		b:SetEnabled( GetConVar("wstar_sv_loadouts"):GetBool() )
		b.DoClick = RequestLoadout
		Menu.LoadoutList.DoDoubleClick = RequestLoadout
		
		local b = vgui.Create( "DButton", panel )
		b:SetPos( 320, 500 )
		b:SetSize( 240, 20 )
		b:SetText( "Undo request" )
		b.DoClick = function()
			if game.SinglePlayer() or not ( last_com and last_com > CurTime() ) then
				last_com = CurTime() + GetConVar("wstar_sv_wait_com"):GetInt()
				net.Start("wstar_lo_undo")
				net.SendToServer()
			else
				notification.AddLegacy( "Please wait longer between requests.", NOTIFY_ERROR, 5 )
			end
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
		c.cvar = "wstar_sv_support_tfa"
		c:SetPos( 20, 490 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Enable TFA INS2 attachment support" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = ChangeConVar
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c.cvar = "wstar_sv_support_cw2"
		c:SetPos( 20, 510 )
		c:SetValue( GetConVar(c.cvar):GetBool() )
		c:SetText( "Enable Customizable Weaponry 2.0 support" )
		c:SetDark( true )
		c:SizeToContents()
		c.OnChange = ChangeConVar
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 530 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "Enables support for weapon attachments. If enabled, all attachments on TFA/CW2 weapons can be restored. Experimental feature that might not work under all conditions." )
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
		
		local ShowHelpButton = vgui.Create( "DButton", panel )
		ShowHelpButton:SetPos( 120, 250 )
		ShowHelpButton:SetSize( 30, 15 )
		ShowHelpButton:SetText( "Show" )
		ShowHelpButton.DoClick = function( self )
			self:Remove()
			local t = vgui.Create( "DHTML", panel )
			t:SetSize( pw - 35, 350 )
			t:SetPos( 10, 270 )
			t:SetHTML( [[
				<html><body style="background-color: #FFFFFF; font-family: sans-serif; font-size: 10pt">
				<h3>Client-side commands and convars</h3><br>These can be executed / changed from client console.<br><br><ul class="bb_ul"><li><b>wstar_menu</b><br>Opens the main menu. Recommended to bind this to a key.<br><br></li><li><b>wstar</b><br>Restores your weapons. Same as the big Restore Weapons button.<br><br></li><li><b>wstar_save</b><br>Admins only: Manually save the weapons of all players to a file. Used to prepare Weapon Transfer. Works only if Weapon Transfer is enabled.<br><br><br></li><li><b>wstar_cl_keeploadout</b> 0 / 1 <i>(Default: 0)</i><br>Enable persistent Weapon Loadouts.</li></ul><br><br><h3>Server-side convars</h3><br>These can only be changed from server console / rcon. Or use the menu, which allows admins to easily change all settings.<br><br><ul class="bb_ul"><li><b>wstar_sv_auto</b> 0 / 1 <i>(Default: 1)</i><br>Toggle auto restore of weapons. Can be used to disable the addon, if you don't want to use it.<br><br></li><li><b>wstar_sv_stripdefault</b> 0 / 1 <i>(Default: 1)</i><br>If enabled, the default loadout will be removed upon restore. Please note, that your ammo will be overwritten regardless. Recommended to keep on.<br><br></li><li><b>wstar_sv_blockloadout</b> 0 / 1 <i>(Default: 0)</i><br>If enabled, the default weapon loadout will be blocked. This is useful for transition between maps (like the HL2 campain).<br><br></li><li><b>wstar_sv_multi</b> 0 / 1 <i>(Default: 1)</i><br>If enabled, you will be able to restore your weapons and ammo manually anytime. Normally, you can only restore your weapons once per spawn. This allows cheating for more ammo.<br><br></li><li><b>wstar_sv_loadouts</b> 0 / 1 <i>(Default: 1)</i><br>Toggles the Loadout function. Disable if you don't want to use Loadouts on your server.<br><br></li><li><b>wstar_sv_support_cw2</b> 0 / 1 <i>(Default: 1)</i><br>Enables support for Customizable Weaponry 2.0 attachments.<br><br></li><li><b>wstar_sv_support_delay</b> 0.5 - 5.0 <i>(Default: 3.0)</i><br>Delay in ms before Auto Restore, in order to increase compatibility with Customizable Weaponry 2.0 attachments. Has not affect without CW 2 installed and support enabled.<br><br></li><li><b>wstar_sv_transfer_enabled</b> 0 / 1 <i>(Default: 0)</i><br>Toggles the Weapon Transfer function. You should only enable this, if you want to transfer weapons, otherwise you may startup Gmod and end up with yesterday's weapons.<br><br></li><li><b>wstar_sv_transfer_spauto</b> 0 / 1 <i>(Default: 1)</i><br>Toggles auto save for Weapon Transfer in SinglePlayer. If you disable that, you will have to use the wstar_save command BEFORE changing the map (or use the changelevel function in the menu).<br><br></li><li><b>wstar_sv_transfer_mpauto</b> 0 / 1 <i>(Default: 0)</i><br>Multiplayer only: Creates a timer, which saves the weapons of all players every 10 seconds. Normally you'll need to save manually before Weapon Transfer in multiplayer. Enabling this might cause performance issues. Use on your own risk!<br><br></li><li><b>wstar_sv_admins_allowall</b> 0 / 1 <i>(Default: 0)</i><br>If enabled, all other settings can be changed by normal admins via menu. Otherwise, only Super-Admins can change settings.<br><i>Of course, this setting can only be changed by Super-Admins / rcon / server console.</i></li></ul>
				</body></html>
			]] )
		end
		
end

local function MenuToggle()
	if IsValid( Menu.Frame ) then Menu.Frame:Close() else WSTAR_Menu() end
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
	if game.SinglePlayer() or not ( last_restore and last_restore > CurTime() ) then
		last_restore = CurTime() + GetConVar("wstar_sv_wait_restore"):GetInt()
		net.Start("wstar")
		net.SendToServer()
	else
		notification.AddLegacy( "Please wait longer between restores.", NOTIFY_ERROR, 5 )
	end
end )

concommand.Add( "wstar_save", function() -- Save all players weapons.
	net.Start("wstar_save")
	net.SendToServer()
end )
