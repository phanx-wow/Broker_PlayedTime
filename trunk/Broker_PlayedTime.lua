--[[--------------------------------------------------------------------
	Broker_PlayedTime
	Tracks played time for all your characters.
	Written by Phanx <addons@phanx.net>
	Currently maintained by Akkorian <akkorian@hotmail.com>
	Copyright © 2010–2011 Phanx. Some rights reserved. See LICENSE.txt for details.
	http://www.wowinterface.com/downloads/info16711-BrokerPlayedTime.html
	http://wow.curse.com/downloads/wow-addons/details/broker-playedtime.aspx
----------------------------------------------------------------------]]

local L = setmetatable( { }, { __index = function( t, k )
	if k == nil then return "" end
	local v = tostring( k )
	t[ k ] = v
	return v
end})

L["Time Played"] = TIME_PLAYED_MSG

local LOCALE = GetLocale()
if LOCALE == "deDE" then
	L["Total"] = "Gesamt"
	L["Show character levels"] = "Charakterstufen anzeigen"
	L["Show class icons"] = "Klassensymbolen anzeigen"
	L["Show faction icons"] = "Fraktionsymbolen anzeigen"
	L["Right click to remove a character."] = "Rechtsklicken, um ein Charakter entfernen."
elseif LOCALE == "esES" or LOCALE == "esMX" then
	L["Total"] = "Total"
	L["Show character levels"] = "Mostrar niveles de los personajes"
	L["Show class icons"] = "Mostrar icono de clase"
	L["Show faction icons"] = "Mostrar icono de facción"
	L["Right click to remove a character."] = "Haz clic derecho para eliminar un personaje"
elseif LOCALE == "frFR" then
--	L["Total"] = ""
--	L["Show character levels"] = ""
--	L["Show class icons"] = ""
--	L["Show faction icons"] = ""
--	L["Right click to remove a character."] = ""
elseif LOCALE == "ruRU" then
--	L["Total"] = ""
--	L["Show character levels"] = ""
--	L["Show class icons"] = ""
--	L["Show faction icons"] = ""
--	L["Right click to remove a character."] = ""
elseif LOCALE == "koKR" then
--	L["Total"] = ""
--	L["Show character levels"] = ""
--	L["Show class icons"] = ""
--	L["Show faction icons"] = ""
--	L["Right click to remove a character."] = ""
elseif LOCALE == "zhCN" then
--	L["Total"] = ""
--	L["Show character levels"] = ""
--	L["Show class icons"] = ""
--	L["Show faction icons"] = ""
--	L["Right click to remove a character."] = ""
end

------------------------------------------------------------------------

local db
local myDB

local sortedFactions = { "Horde", "Alliance" }
local sortedPlayers = { }
local sortedRealms = { }

local currentFaction = UnitFactionGroup( "player" )
local currentPlayer = UnitName( "player" )
local currentRealm = GetRealmName( )

local timePlayed = 0
local timeUpdated = 0

local maxLevel = MAX_PLAYER_LEVEL_TABLE[ GetAccountExpansionLevel( ) ]

local factionIcons = {
	Horde = "|TInterface\\AddOns\\Broker_PlayedTime\\Faction-Horde:0|t ",
	Alliance = "|TInterface\\AddOns\\Broker_PlayedTime\\Faction-Alliance:0|t ",
}

local classIcons = { }
for class, t in pairs( CLASS_BUTTONS ) do
	local offset, left, right, bottom, top = 0.025, unpack( t )
	classIcons[class] = string.format( "|TInterface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes:16:16:0:0:256:256:%s:%s:%s:%s|t ", ( left + offset ) * 256, ( right - offset ) * 256, ( bottom + offset ) * 256, ( top - offset ) * 256 )
end

local GRAY = "cccccc"
local CLASS_COLORS = { }
for k, v in pairs( RAID_CLASS_COLORS ) do
	CLASS_COLORS[k] = string.format( "|cff%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255 )
end

local function FormatTime( t )
	if not t then return end

	local d = math.floor( t / 86400 )
	local h = math.floor( ( t - ( d * 86400 ) ) / 3600 )
	local m = math.floor( ( t - ( d * 86400 ) - ( h * 3600 ) ) / 60 )

	return string.format( "|cffffffff%d|r|cffffcc00d|r |cffffffff%02d|r|cffffcc00h|r |cffffffff%02d|r|cffffcc00m|r", d, h, m )
end

local BrokerPlayedTime = CreateFrame( "Frame" )
BrokerPlayedTime:SetScript( "OnEvent", function( self, event, ... ) return self[ event ] and self[ event ] (self, ... ) end )
BrokerPlayedTime:RegisterEvent( "PLAYER_LOGIN" )

function BrokerPlayedTime:PLAYER_LOGIN( )
	local function copyTable( src, dst )
		if type( src ) ~= "table" then return { } end
		if type( dst ) ~= "table" then dst = { } end
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
		factionIcons = true,
		levels = true,
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

	BrokerPlayedTimeDB = BrokerPlayedTimeDB or { }
	db = copyTable( defaults, BrokerPlayedTimeDB )

	myDB = db[ currentRealm ][ currentFaction ][ currentPlayer ]

	for realm in pairs( db ) do
		if type( db[ realm ] ) == "table" then
			table.insert( sortedRealms, realm )
			sortedPlayers[ realm ] = { }
			for faction in pairs( db[ realm ] ) do
				sortedPlayers[ realm ][ faction ] = { }
				for name in pairs( db[ realm ][ faction ] ) do
					table.insert( sortedPlayers[ realm ][ faction ], name )
				end
				if realm == currentRealm and faction == currentFaction then
					table.sort( sortedPlayers[ realm ][ faction ], function( a, b )
						if a == currentPlayer then
							return true
						elseif b == currentPlayer then
							return false
						end
						return a < b
					end )
				else
					table.sort( sortedPlayers[ realm ][ faction ] )
				end
			end
		end
	end

	table.sort( sortedRealms, function( a, b )
		if a == currentRealm then
			return true
		elseif b == currentRealm then
			return false
		end
		return a < b
	end )

	if CUSTOM_CLASS_COLORS then
		local function UpdateClassColors()
			for k, v in pairs( CUSTOM_CLASS_COLORS ) do
				CLASS_COLORS[ k ] = string.format( "|cff%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255 )
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

BrokerPlayedTime.dataObject = LibStub( "LibDataBroker-1.1" ):NewDataObject( "PlayedTime", {
	type = "data source",
	icon = "Interface\\Icons\\Spell_Nature_TimeStop",
	text = L["Time Played"],
	OnClick = function( self, button )
		if button == "RightButton" then
			InterfaceOptionsFrame_OpenToCategory( BrokerPlayedTime.optionsPanel )
		end
	end,
	OnTooltipShow = function( tooltip )
		local total = 0
		tooltip:AddLine( L["Time Played"] )
		for _, realm in ipairs( sortedRealms ) do
			tooltip:AddLine(" ")
			tooltip:AddLine( realm )
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
									tooltip:AddDoubleLine( string.format("%s%s%s%s (%s)|r", db.factionIcons and factionIcons[ faction ] or "", db.classIcons and classIcons[ data.class ] or "", CLASS_COLORS[ data.class ] or GRAY, name, data.level ), FormatTime( t ) )
								else
									tooltip:AddDoubleLine( string.format("%s%s%s%s|r", db.factionIcons and factionIcons[ faction ] or "", db.classIcons and classIcons[ data.class ] or "", CLASS_COLORS[ data.class ] or GRAY, name ), FormatTime( t ) )
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
} )

BrokerPlayedTime.optionsPanel = CreateFrame( "Frame", nil, InterfaceOptionsFramePanelContainer )
BrokerPlayedTime.optionsPanel:Hide()

BrokerPlayedTime.optionsPanel.name = GetAddOnInfo( "Broker PlayedTime", "Title" )
BrokerPlayedTime.optionsPanel:SetScript( "OnShow", function( self )
	local name = self:CreateFontString( nil, "ARTWORK", "GameFontNormalLarge" )
	name:SetPoint( "TOPLEFT", 16, -16 )
	name:SetPoint( "TOPRIGHT", -16, -16 )
	name:SetJustifyH( "LEFT" )
	name:SetText( self.name )

	local desc = self:CreateFontString( nil, "ARTWORK", "GameFontHighlightSmall" )
	desc:SetPoint( "TOPLEFT", name, "BOTTOMLEFT", 0, -8 )
	desc:SetPoint( "TOPRIGHT", name, "BOTTOMRIGHT", 0, -8 )
	desc:SetHeight( 32 )
	desc:SetJustifyH( "LEFT" )
	desc:SetJustifyV( "TOP" )
	desc:SetNonSpaceWrap( true )
	desc:SetText( GetAddOnMetadata( "Broker_PlayedTime", "Notes" ) )

	local CreateCheckbox = LibStub( "PhanxConfig-Checkbox" ).CreateCheckbox

	local classIcons = CreateCheckbox( self, L[ "Show class icons" ] )
	classIcons:SetPoint( "TOPLEFT", desc, "BOTTOMLEFT", 0, -8 )
	classIcons:SetChecked( db.classIcons )
	classIcons.OnClick = function( checked )
		db.classIcons = checked
	end

	local factionIcons = CreateCheckbox( self, L[ "Show faction icons" ] )
	factionIcons:SetPoint( "TOPLEFT", classIcons, "BOTTOMLEFT", 0, -8 )
	factionIcons:SetChecked( db.factionIcons )
	factionIcons.OnClick = function( checked )
		db.factionIcons = checked
	end

	local levels = CreateCheckbox( self, L[ "Show character levels" ] )
	levels:SetPoint( "TOPLEFT", factionIcons, "BOTTOMLEFT", 0, -8 )
	levels:SetChecked( db.levels )
	levels.OnClick = function( checked )
		db.levels = checked
	end

	self:SetScript( "OnShow", nil )
end )

InterfaceOptions_AddCategory( BrokerPlayedTime.optionsPanel )

------------------------------------------------------------------------

SLASH_BROKERPLAYEDTIME1 = "/bpt"

local function Purge( realm, faction, name )
	db[ realm ][ faction ][ name ] = nil
	sortedPlayers[ realm ][ faction ][ name ] = nil

	local n = 0
	for k in pairs( db[ realm ][ faction ] ) do
		n = n + 1
	end
	if n == 0 then
		db[ realm ][ faction ] = nil
		sortedPlayers[ realm ][ faction ] = nil
	end

	n = 0
	for k in pairs( db[ realm ] ) do
		n = n + 1
	end
	if n == 0 then
		db[ realm ] = nil
		sortedPlayers[ realm ] = nil
		for i, v in pairs( sortedRealms ) do
			if v == realm then
				sortedRealms[ i ] = nil
				break
			end
		end
	end
end

SlashCmdList.BROKERPLAYEDTIME = function( input )
	local command, name, realm = string.match( string.trim( input ), "^(%S+) (%S+) ?(.*)$" )

	if not command then
		return InterfaceOptionsFrame_OpenToCategory( BrokerPlayedTime.optionsPanel )
	end

	if command ~= "delete" then
		return print( [[Usage: "/bpt delete Name" or "/bpt delete Name Realm"]] )
	end

	if realm and string.len( realm ) > 0 then
		local realmData = db[ realm ]
		if realmData then
			for faction, factionData in pairs( realmData ) do
				if factionData[ name ] then
					Purge( realm, faction, name )
					return print( "Character", name, "of", realm, "successfully removed." )
				else
					return print( "Character", name, "of", realm, "not found." )
				end
			end
		end
		return print( "Realm", realm, "not found." )
	end

	for realm, realmData in pairs( db ) do
		if type( realmData ) == "table" then
			for faction, factionData in pairs( realmData ) do
				if factionData[ name ] then
					Purge( realm, faction, name )
					return print( "Character", name, "of", realm, "successfully removed." )
				end
			end
		end
	end

	return print( "Character", name, "not found." )
end