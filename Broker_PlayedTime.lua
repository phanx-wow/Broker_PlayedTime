--[[--------------------------------------------------------------------
	Broker_PlayedTime
	Tracks played time for all your characters.
	Written by Phanx <addons@phanx.net>
	Copyright © 2010–2011 Phanx. Some rights reserved. See LICENSE.txt for details.
	http://www.wowinterface.com/downloads/info16711-BrokerPlayedTime.html
	http://www.curse.com/addons/wow/broker-playedtime
----------------------------------------------------------------------]]

local L = setmetatable( {}, { __index = function( t, k )
	if k == nil then return "" end
	local v = tostring( k )
	t[ k ] = v
	return v
end})

L["Time Played"] = TIME_PLAYED_MSG

local LOCALE = GetLocale()
if LOCALE == "deDE" then
	L["Total"] = "Gesamt"
	L["Character levels"] = "Charakterstufen"
	L["Class icons"] = "Klassensymbolen"
	L["Faction icons"] = "Fraktionsymbolen"
	L["Remove character"] = "Charakter entfernen"
elseif LOCALE == "esES" or LOCALE == "esMX" then
	L["Total"] = "Total"
	L["Character levels"] = "Niveles de personajes"
	L["Class icons"] = "Iconos de clase"
	L["Faction icons"] = "Iconos de facción"
	L["Remove character"] = "Eliminar personaje"
elseif LOCALE == "frFR" then
	L["Total"] = "Total"
	L["Character levels"] = "Niveaux de personnages"
	L["Class icons"] = "Icônes de classe"
	L["Faction icons"] = "Icônes de faction"
	L["Remove character"] = "Supprimer personnage"
elseif LOCALE == "ptBR" then
	L["Total"] = "Total"
	L["Character levels"] = "Níveis de personagem"
	L["Class icons"] = "Ícones da classe"
	L["Faction icons"] = "Ícones da facção"
	L["Remove character"] = "Remover o personagem"
elseif LOCALE == "ruRU" then -- Last updated 2011-03-01 by YOti @ CurseForge
	L["Total"] = "Общее"
	L["Character levels"] = "Уровни персонажей"
	L["Class icons"] = "Значки классов"
	L["Faction icons"] = "Значки фракций"
	L["Remove character"] = "Удалить персонаж"
elseif LOCALE == "koKR" then
	L["Total"] = "전체"
	L["Character levels"] = "캐릭터 레벨"
	L["Class icons"] = "직업 아이콘"
	L["Faction icons"] = "진영 아이콘"
	L["Remove character"] = "캐릭터 삭제"
elseif LOCALE == "zhCN" then
	L["Total"] = "总游戏时间"
	L["Character levels"] = "角色等级"
	L["Class icons"] = "职业图标"
	L["Faction icons"] = "阵营图标"
	L["Remove character"] = "移除角色"
elseif LOCALE == "zhTW" then
	L["Total"] = "總遊戲時間"
	L["Character levels"] = "角色等級"
	L["Class icons"] = "職業圖示"
	L["Faction icons"] = "陣營圖示"
	L["Remove character"] = "移除角色"
end

------------------------------------------------------------------------

local format = string.format

local db, myDB
local timePlayed, timeUpdated = 0, 0
local sortedFactions, sortedPlayers, sortedRealms = { "Horde", "Alliance" }, {}, {}

local currentFaction = UnitFactionGroup( "player" )
local currentPlayer = UnitName( "player" )
local currentRealm = GetRealmName()

local MAX_LEVEL = MAX_PLAYER_LEVEL_TABLE[ GetAccountExpansionLevel() ]

local factionIcons = {
	Horde = [[|TInterface\AddOns\Broker_PlayedTime\Faction-Horde:0|t ]],
	Alliance = [[|TInterface\AddOns\Broker_PlayedTime\Faction-Alliance:0|t ]],
}

local classIcons = {}
for class, t in pairs( CLASS_BUTTONS ) do
	local offset, left, right, bottom, top = 0.025, unpack( t )
	classIcons[class] = format( [[|TInterface\Glues\CharacterCreate\UI-CharacterCreate-Classes:16:16:0:0:256:256:%s:%s:%s:%s|t ]], ( left + offset ) * 256, ( right - offset ) * 256, ( bottom + offset ) * 256, ( top - offset ) * 256 )
end

local CLASS_COLORS = { UNKNOWN = "|cffcccccc" }
for k, v in pairs( RAID_CLASS_COLORS ) do
	CLASS_COLORS[ k ] = format( "|cff%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255 )
end

------------------------------------------------------------------------

local FormatTime
do
	local DAY, MIN, HOUR
	function FormatTime( t )
		if not t then return end

		if not DAY then
			local DAY_ABBR, HOUR_ABBR, MIN_ABBR = DAY_ONELETTER_ABBR:gsub( "%%d", "" ), HOUR_ONELETTER_ABBR:gsub( "%%d", "" ), MINUTE_ONELETTER_ABBR:gsub( "%%d", "" )
			DAY = format( "|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR, "%02d", MIN_ABBR )
			HOUR = format( "|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR )
			MIN = format( "|cffffffff%s|r|cffffcc00%s|r", "%d", MIN_ABBR )
		end

		local d, h, m = floor( t / 86400 ), floor( ( t % 86400 ) / 3600 ), floor( ( t % 3600 ) / 60 )

		if d > 0 then
			return format( DAY, d, h, m )
		elseif h > 0 then
			return format( HOUR, h, m )
		else
			return format( MIN, m )
		end
	end
end

------------------------------------------------------------------------

local BuildSortedLists
do
	local function SortPlayers( a, b )
		if a == currentPlayer then
			return true
		elseif b == currentPlayer then
			return false
		end
		return a < b
	end

	local function SortRealms( a, b )
		if a == currentRealm then
			return true
		elseif b == currentRealm then
			return false
		end
		return a < b
	end

	function BuildSortedLists()
		wipe( sortedRealms )
		for realm in pairs( db ) do
			if type( db[ realm ] ) == "table" then
				table.insert( sortedRealms, realm )
				sortedPlayers[ realm ] = wipe( sortedPlayers[ realm ] or {} )
				for faction in pairs( db[ realm ] ) do
					sortedPlayers[ realm ][ faction ] = wipe( sortedPlayers[ realm ][ faction ] or {} )
					for name in pairs( db[ realm ][ faction ] ) do
						table.insert( sortedPlayers[ realm ][ faction ], name )
					end
					if realm == currentRealm and faction == currentFaction then
						table.sort( sortedPlayers[ realm ][ faction ], SortPlayers )
					else
						table.sort( sortedPlayers[ realm ][ faction ] )
					end
				end
			end
		end
		table.sort( sortedRealms, SortRealms )
	end
end

------------------------------------------------------------------------

local BrokerPlayedTime = CreateFrame( "Frame" )
BrokerPlayedTime:SetScript( "OnEvent", function( self, event, ... ) return self[ event ] and self[ event ] (self, ... ) end )
BrokerPlayedTime:RegisterEvent( "PLAYER_LOGIN" )

function BrokerPlayedTime:PLAYER_LOGIN()
	local function copyTable( src, dst )
		if type( src ) ~= "table" then return {} end
		if type( dst ) ~= "table" then dst = {} end
		for k, v in pairs( src ) do
			if type( v ) == "table" then
				dst[ k ] = copyTable( v, dst[ k ] )
			elseif type( v ) ~= type( dst[ k ] ) then
				dst[ k ] = v
			end
		end
		return dst
	end

	local defaults = {
		classIcons = false,
		factionIcons = false,
		levels = false,
		[ currentRealm ] = {
			[ currentFaction ] = {
				[ currentPlayer ] = {
					class = ( select( 2, UnitClass("player") ) ),
					level = UnitLevel( "player" ),
					timePlayed = 0,
					timeUpdated = 0,
				},
			}
		}
	}

	BrokerPlayedTimeDB = BrokerPlayedTimeDB or {}
	db = copyTable( defaults, BrokerPlayedTimeDB )

	myDB = db[ currentRealm ][ currentFaction ][ currentPlayer ]

	BuildSortedLists()

	if CUSTOM_CLASS_COLORS then
		local function UpdateClassColors()
			for k, v in pairs( CUSTOM_CLASS_COLORS ) do
				CLASS_COLORS[ k ] = format( "|cff%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255 )
			end
		end
		UpdateClassColors()
		CUSTOM_CLASS_COLORS:RegisterCallback( UpdateClassColors )
	end

	self:UnregisterEvent( "PLAYER_LOGIN" )

	self:RegisterEvent( "PLAYER_LEVEL_UP" )
	self:RegisterEvent( "PLAYER_REGEN_ENABLED" )
	self:RegisterEvent( "PLAYER_UPDATE_RESTING" )
	self:RegisterEvent( "TIME_PLAYED_MSG" )

	self:UpdateTimePlayed()
end

local requesting

local o = ChatFrame_DisplayTimePlayed
ChatFrame_DisplayTimePlayed = function( ... )
	if requesting then
		requesting = false
		return
	end
	return o( ... )
end

function BrokerPlayedTime:UpdateTimePlayed()
	requesting = true
	RequestTimePlayed()
end

function BrokerPlayedTime:SaveTimePlayed()
	local now = time()
	myDB.timePlayed = timePlayed + now - timeUpdated
	myDB.timeUpdated = now
end

function BrokerPlayedTime:PLAYER_LEVEL_UP(level)
	myDB.level = level or UnitLevel( "player" )
	self:SaveTimePlayed()
end

BrokerPlayedTime.PLAYER_REGEN_ENABLED  = BrokerPlayedTime.SaveTimePlayed
BrokerPlayedTime.PLAYER_UPDATE_RESTING = BrokerPlayedTime.SaveTimePlayed

function BrokerPlayedTime:TIME_PLAYED_MSG( t )
	timePlayed = t
	timeUpdated = time()
	self:SaveTimePlayed()
end

------------------------------------------------------------------------

local BrokerPlayedTimeMenu = CreateFrame( "Frame", "BrokerPlayedTimeMenu", nil, "UIDropDownMenuTemplate" )
BrokerPlayedTimeMenu.displayMode = "MENU"
BrokerPlayedTimeMenu.info = {}

BrokerPlayedTimeMenu.GetClassIcons = function() return db.classIcons end
BrokerPlayedTimeMenu.SetClassIcons = function() db.classIcons = not db.classIcons end

BrokerPlayedTimeMenu.GetFactionIcons = function() return db.factionIcons end
BrokerPlayedTimeMenu.SetFactionIcons = function() db.factionIcons = not db.factionIcons end

BrokerPlayedTimeMenu.GetLevels = function() return db.levels end
BrokerPlayedTimeMenu.SetLevels = function() db.levels = not db.levels end

BrokerPlayedTimeMenu.CloseDropDownMenus = function() CloseDropDownMenus() end

BrokerPlayedTimeMenu.RemoveCharacter = function( button )
	local value = button and button.value or UIDROPDOWNMENU_MENU_VALUE
	local realm, faction, name = string.split( "#", value )
	if realm and faction and name and db[ realm ] and db[ realm ][ faction ] and db[ realm ][ faction ][ name ] then
		db[ realm ][ faction ][ name ] = nil

		local nf = 0
		for k in pairs( db[ realm ][ faction ] ) do
			nf = nf + 1
		end
		if nf == 0 then
			db[ realm ][ faction ] = nil
		end

		local nr = 0
		for k in pairs( db[ realm ] ) do
			nr = nr + 1
		end
		if nr == 0 then
			db[ realm ] = nil
			sortedRealms[ realm ] = nil
		end

		BuildSortedLists()
	end
end

BrokerPlayedTimeMenu.initialize = function( self, level )
	if not level then return end
	local info = wipe( self.info )
	if level == 1 then
		info.text = L["Played Time"]
		info.isTitle = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton( info, level )

		info.isTitle = nil

		info.text = " "
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton( info, level )

		info.disabled = nil
		info.notCheckable = nil

		info.keepShownOnClick = 1

		info.text = L["Character levels"]
		info.checked = self.GetLevels
		info.func = self.SetLevels
		UIDropDownMenu_AddButton( info, level )

		info.text = L["Class icons"]
		info.checked = self.GetClassIcons
		info.func = self.SetClassIcons
		UIDropDownMenu_AddButton( info, level )

		info.text = L["Faction icons"]
		info.checked = self.GetFactionIcons
		info.func = self.SetFactionIcons
		UIDropDownMenu_AddButton( info, level )

		info.checked = nil
		info.func = nil

		info.text = " "
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton( info, level )

		info.disabled = nil
		info.notCheckable = 1

		info.text = L["Remove character"]
		info.hasArrow = 1
		UIDropDownMenu_AddButton( info, level )

		info.checked = nil
		info.func = nil
		info.hasArrow = nil

		info.text = " "
		info.disabled = 1
		UIDropDownMenu_AddButton( info, level )

		info.disabled = nil
		info.keepShownOnClick = nil

		info.text = CLOSE
		info.func = self.CloseDropDownMenus
		info.notCheckable = 1
		UIDropDownMenu_AddButton( info, level )
	elseif level == 2 then
		for _, realm in ipairs( sortedRealms ) do
			info.text = realm
			info.value = realm
			info.hasArrow = 1
			info.keepShownOnClick = 1
			info.notCheckable = 1
			UIDropDownMenu_AddButton( info, level )
		end
	elseif level == 3 then
		local factions = 0
		for i, faction in ipairs( sortedFactions ) do
			info.value = nil
			info.colorCode = nil
			info.func = nil

			local realm = UIDROPDOWNMENU_MENU_VALUE
			local rfp = sortedPlayers[ realm ][ faction ]

			if rfp then
				factions = factions + 1

				if factions > 1 then
					info.text = " "
					info.disabled = 1
					info.notCheckable = 1
					UIDropDownMenu_AddButton( info, level )
				end

				info.disabled = nil

				info.text = faction
				info.isTitle = 1
				info.notCheckable = 1
				UIDropDownMenu_AddButton( info, level )

				info.disabled = nil
				info.isTitle = nil
				info.notCheckable = nil

				for j, name in ipairs( rfp ) do
					local cdata = db[ realm ][ faction ][ name ]

					info.text = name
					info.value = format( "%s#%s#%s", realm, faction, name )
					info.colorCode = CLASS_COLORS[ cdata and cdata.class or "UNKNOWN" ]
					info.disabled = ( name == currentPlayer and realm == currentRealm )
					info.func = self.RemoveCharacter
					UIDropDownMenu_AddButton( info, level )
				end
			end
		end
	end
end

------------------------------------------------------------------------

local function OnTooltipShow( tooltip )
	local total = 0
	tooltip:AddLine( L["Time Played"] )
	for _, realm in ipairs( sortedRealms ) do
		tooltip:AddLine(" ")
		if #sortedRealms > 1 then
			tooltip:AddLine( realm )
		end
		for _, faction in ipairs( sortedFactions ) do
			local nfr = sortedPlayers[ realm ][ faction ]
			if nfr and #nfr > 0 then
				for _, name in ipairs( nfr ) do
					local data = db[ realm ][ faction ][ name ]
					if data then
						local t
						if realm == currentRealm and name == currentPlayer then
							t = data.timePlayed + time() - data.timeUpdated
						else
							t = data.timePlayed
						end
						if t > 0 then
							if db.levels then
								tooltip:AddDoubleLine( format("%s%s%s%s (%s)|r", db.factionIcons and factionIcons[ faction ] or "", db.classIcons and classIcons[ data.class ] or "", CLASS_COLORS[ data.class ] or GRAY, name, data.level ), FormatTime( t ) )
							else
								tooltip:AddDoubleLine( format("%s%s%s%s|r", db.factionIcons and factionIcons[ faction ] or "", db.classIcons and classIcons[ data.class ] or "", CLASS_COLORS[ data.class ] or GRAY, name ), FormatTime( t ) )
							end
							total = total + t
						end
					end
				end
			end
		end
	end
	tooltip:AddLine( " " )
	tooltip:AddDoubleLine( L["Total"], FormatTime( total ) )
end

------------------------------------------------------------------------

BrokerPlayedTime.dataObject = LibStub( "LibDataBroker-1.1" ):NewDataObject( "PlayedTime", {
	type = "data source",
	icon = [[Interface\Icons\Spell_Nature_TimeStop]],
	text = L["Time Played"],
	OnTooltipShow = OnTooltipShow,
	OnClick = function( self, button )
		if button == "RightButton" then
			ToggleDropDownMenu( 1, nil, BrokerPlayedTimeMenu, self, 0, 0 )
		end
	end,
} )

------------------------------------------------------------------------