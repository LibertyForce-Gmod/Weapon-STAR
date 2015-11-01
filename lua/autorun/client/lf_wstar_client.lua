if !file.Exists( "wstar", "DATA" ) then file.CreateDir( "wstar" ) end

CreateClientConVar( "wstar_cl_keeploadout", "0", true, true )

if file.Exists( "wstar/loadouts.txt", "DATA" ) then
	WSTAR_LO = util.JSONToTable( file.Read( "wstar/loadouts.txt", "DATA" ) )
	if !istable( WSTAR_LO ) then WSTAR_LO = { } end
else
	WSTAR_LO = { }
end


net.Receive("wstar_convar_sync", function()
	local tbl = net.ReadTable()
	for k,v in pairs( tbl ) do
		CreateConVar( k, v, { FCVAR_REPLICATED } )
	end
end)

net.Receive("wstar_lo_save_send", function()
	local name = net.ReadString()
	WSTAR_LO[name] = net.ReadTable()
	file.Write( "wstar/loadouts.txt", util.TableToJSON( WSTAR_LO ) )
end)

net.Receive("wstar_notify_restore", function()
	local success = net.ReadBool()
	if success then
		notification.AddLegacy( "Weapons restored.", NOTIFY_GENERIC, 5 )
	else
		notification.AddLegacy( "Weapon Restore already used up in this spawn.", NOTIFY_ERROR, 5 )
	end
end)


local function PopulateList( LoadoutList )
	LoadoutList:Clear()
	for k in pairs( WSTAR_LO ) do
		LoadoutList:AddLine( k )
	end
	LoadoutList:SortByColumn( 1 )
end


local function WSTAR_Menu( )

	local Frame = vgui.Create( "DFrame" )
	local fw, fh = 600, 700
	local pw, ph = fw - 10, fh - 62
	Frame:SetSize( fw, fh )
	Frame:SetTitle( "Weapon S.T.A.R.: Setup, Transfer And Restore" )
	Frame:SetVisible( true )
	Frame:SetDraggable( false )
	Frame:ShowCloseButton( true )
	Frame:Center()
	Frame:MakePopup()
	
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

		PopulateList( LoadoutList )
		
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
			net.Start("wstar_lo_save_request")
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
			net.Start("wstar_lo_save_request")
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
			file.Write( "wstar/loadouts.txt", util.TableToJSON( WSTAR_LO ) )
			PopulateList( LoadoutList )
		end
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c:SetPos( 320, 370 )
		c:SetValue( GetConVar("wstar_cl_keeploadout"):GetBool() )
		c:SetText( "Persistent Loadout" )
		c:SetDark( true )
		c:SizeToContents()
		function c:OnChange( v )
			if v then v = "1" else v = "0" end
			RunConsoleCommand( "wstar_cl_keeploadout", v )
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
				net.Start("wstar_lo_load_request")
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
			net.Start("wstar_lo_undo_request")
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
		c:SetPos( 20, 70 )
		c:SetValue( GetConVar("wstar_sv_auto"):GetBool() )
		c:SetText( "Auto Restore" )
		c:SetDark( true )
		c:SizeToContents()
		function c:OnChange( v )
			net.Start("wstar_convar_change")
			net.WriteString( "wstar_sv_auto" )
			net.WriteBit( v )
			net.SendToServer()
		end
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 90 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "If enabled, your weapons will be restored immediately after respawning.\nIf disabled, you will have to use the manual button on the first tab." )
		t:SetWrap( true )
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c:SetPos( 20, 140 )
		c:SetValue( GetConVar("wstar_sv_stripdefault"):GetBool() )
		c:SetText( "Strip default weapons" )
		c:SetDark( true )
		c:SizeToContents()
		function c:OnChange( v )
			net.Start("wstar_convar_change")
			net.WriteString( "wstar_sv_stripdefault" )
			net.WriteBit( v )
			net.SendToServer()
		end
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 160 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "If enabled, the default loadout will be removed upon restore. Please note, that your ammo will be overwritten regardless. Recommended to keep on." )
		t:SetWrap( true )
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c:SetPos( 20, 210 )
		c:SetValue( GetConVar("wstar_sv_blockloadout"):GetBool() )
		c:SetText( "Block default weapon loadout" )
		c:SetDark( true )
		c:SizeToContents()
		function c:OnChange( v )
			net.Start("wstar_convar_change")
			net.WriteString( "wstar_sv_blockloadout" )
			net.WriteBit( v )
			net.SendToServer()
		end
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 230 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "If enabled, the default weapon loadout will be blocked. This is useful for transition between maps (like the HL2 campain). By default the Sandbox gamemode deletes all your weapons upon spawn and replaces them with the default loadout. Enabling this setting prevents this.\n\nShould be enabled on maps that give weapons automatically but should be disabled otherwise. Disabled by default. For manual map changes, you might want to consider: Weapon Transfer (see 2nd tab above)." )
		t:SetWrap( true )
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c:SetPos( 20, 330 )
		c:SetValue( GetConVar("wstar_sv_multi"):GetBool() )
		c:SetText( "Allow multiple restores" )
		c:SetDark( true )
		c:SizeToContents()
		function c:PerformLayout()
			self:SetFontInternal( "ChatFont" )
			self:SetFGColor( Color( 255, 255, 255 ) )
		end
		function c:OnChange( v )
			net.Start("wstar_convar_change")
			net.WriteString( "wstar_sv_multi" )
			net.WriteBit( v )
			net.SendToServer()
		end
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 350 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "If enabled, you will be able to restore your weapons and ammo manually anytime. Normally, you can only restore your weapons once per spawn. This allows cheating for more ammo.\n\nThis also effects Loadouts! If disabled, Loadouts can only be applied on next respawn. Disabled by default." )
		t:SetWrap( true )
		
		local c = vgui.Create( "DCheckBoxLabel", panel )
		c:SetPos( 20, 420 )
		c:SetValue( GetConVar("wstar_sv_loadouts"):GetBool() )
		c:SetText( "Enable Loadouts" )
		c:SetDark( true )
		c:SizeToContents()
		function c:OnChange( v )
			net.Start("wstar_convar_change")
			net.WriteString( "wstar_sv_loadouts" )
			net.WriteBit( v )
			net.SendToServer()
		end
		
		local t = vgui.Create( "DLabel", panel )
		t:SetPos( 20, 440 )
		t:SetAutoStretchVertical( true )
		t:SetSize( pw - 40, 0 )
		t:SetDark( true )
		t:SetText( "If enabled, all players can use the Loadout function.\nIf disabled, they can still save and edit Loadouts but not apply them." )
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
			c:SetPos( 20, 600 )
			c:SetValue( GetConVar("wstar_sv_admins_allowall"):GetBool() )
			c:SetText( "Allow all admins to access Settings and Weapon Transfer." )
			c:SetDark( true )
			c:SizeToContents()
			c:SetEnabled( false )
			function c:OnChange( v )
				net.Start("wstar_convar_change")
				net.WriteString( "wstar_sv_admins_allowall" )
				net.WriteBit( v )
				net.SendToServer()
			end
		
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
		c:SetPos( 20, 70 )
		c:SetValue( GetConVar("wstar_sv_transfer_enabled"):GetBool() )
		c:SetText( "Enable Weapon Transfer" )
		c:SetDark( true )
		c:SizeToContents()
		function c:OnChange( v )
			net.Start("wstar_convar_change")
			net.WriteString( "wstar_sv_transfer_enabled" )
			net.WriteBit( v )
			net.SendToServer()
		end
		
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
		c:SetPos( 20, 290 )
		c:SetValue( GetConVar("wstar_sv_transfer_spauto"):GetBool() )
		c:SetText( "Enable autosave on shutdown" )
		c:SetDark( true )
		c:SizeToContents()
		function c:OnChange( v )
			net.Start("wstar_convar_change")
			net.WriteString( "wstar_sv_transfer_spauto" )
			net.WriteBit( v )
			net.SendToServer()
		end
		
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
		c:SetPos( 20, 430 )
		c:SetValue( GetConVar("wstar_sv_transfer_mpauto"):GetBool() )
		c:SetText( "Enable 10 sec. autosave timer" )
		c:SetDark( true )
		c:SizeToContents()
		function c:OnChange( v )
			net.Start("wstar_convar_change")
			net.WriteString( "wstar_sv_transfer_mpauto" )
			net.WriteBit( v )
			net.SendToServer()
		end
		
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
			net.Start("wstar_changelevel")
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
		t:SetText( "Created by LibertyForce." )
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
		b:SetSize( 120, 25 )
		b:SetText( "Visit addon page" )
		b.DoClick = function()
			gui.OpenURL( "http://steamcommunity.com/sharedfiles/filedetails/?id=492765756" )
		end
	
		
end


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


concommand.Add( "wstar_menu", WSTAR_Menu )

concommand.Add( "wstar", function()
	net.Start("wstar")
	net.SendToServer()
end )

concommand.Add( "wstar_save", function()
	net.Start("wstar_save")
	net.SendToServer()
end )
