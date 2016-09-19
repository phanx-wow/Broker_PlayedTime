--[[--------------------------------------------------------------------
	Broker_PlayedTime
	DataBroker plugin to track played time across all your characters.
	Copyright (c) 2010-2016 Phanx <addons@phanx.net>. All rights reserved.
	http://www.wowinterface.com/downloads/info16711-BrokerPlayedTime.html
	https://mods.curse.com/addons/wow/broker-playedtime
	https://github.com/Phanx/Broker_PlayedTime
----------------------------------------------------------------------]]

local ADDON, L = ...

local floor, format, gsub, ipairs, pairs, sort, tinsert, type, wipe = floor, format, gsub, ipairs, pairs, sort, tinsert, type, wipe

local db, myDB
local timePlayed, timeUpdated = 0, 0
local sortedFactions, sortedPlayers, sortedRealms = { "Horde", "Alliance" }, {}, {}

local currentFaction = UnitFactionGroup("player")
local currentPlayer = UnitName("player")
local currentRealm = GetRealmName()

local MAX_LEVEL = MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()]

local factionIcons = {
	Alliance = [[|TInterface\BattlefieldFrame\Battleground-Alliance:16:16:0:0:32:32:4:26:4:27|t ]],
	Horde = [[|TInterface\BattlefieldFrame\Battleground-Horde:16:16:0:0:32:32:5:25:5:26|t ]],
}

local classIcons = {}
for class, t in pairs(CLASS_ICON_TCOORDS) do
	local offset, left, right, bottom, top = 0.025, unpack(t)
	classIcons[class] = format([[|TInterface\Glues\CharacterCreate\UI-CharacterCreate-Classes:14:14:0:0:256:256:%s:%s:%s:%s|t ]], (left + offset) * 256, (right - offset) * 256, (bottom + offset) * 256, (top - offset) * 256)
end

local CLASS_COLORS = { UNKNOWN = "|cffcccccc" }
for k, v in pairs(RAID_CLASS_COLORS) do
	CLASS_COLORS[k] = format("|cff%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255)
end

------------------------------------------------------------------------

local FormatTime
do
	local DAY_ABBR, HOUR_ABBR, MIN_ABBR = gsub(DAY_ONELETTER_ABBR, "%%d%s*", ""), gsub(HOUR_ONELETTER_ABBR, "%%d%s*", ""), gsub(MINUTE_ONELETTER_ABBR, "%%d%s*", "")
	local DHM = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR, "%02d", MIN_ABBR)
	local  DH = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR)
	local  HM = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR)
	local   H = format("|cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR)
	local   M = format("|cffffffff%s|r|cffffcc00%s|r", "%d", MIN_ABBR)

	function FormatTime(t, noMinutes)
		if not t then return end

		local d, h, m = floor(t / 86400), floor((t % 86400) / 3600), floor((t % 3600) / 60)
		if d > 0 then
			return noMinutes and format(DH, d, h) or format(DHM, d, h, m)
		elseif h > 0 then
			return noMinutes and format(H, h) or format(HM, h, m)
		else
			return format(M, m)
		end
	end
end

------------------------------------------------------------------------

local BuildSortedLists
do
	local function SortPlayers(a, b)
		if a == currentPlayer then
			return true
		elseif b == currentPlayer then
			return false
		end
		return a < b
	end

	local function SortRealms(a, b)
		if a == currentRealm then
			return true
		elseif b == currentRealm then
			return false
		end
		return a < b
	end

	function BuildSortedLists()
		wipe(sortedRealms)
		for realm in pairs(db) do
			if type(db[realm]) == "table" then
				tinsert(sortedRealms, realm)
				sortedPlayers[realm] = wipe(sortedPlayers[realm] or {})
				for faction in pairs(db[realm]) do
					sortedPlayers[realm][faction] = wipe(sortedPlayers[realm][faction] or {})
					for name in pairs(db[realm][faction]) do
						tinsert(sortedPlayers[realm][faction], name)
					end
					if realm == currentRealm and faction == currentFaction then
						sort(sortedPlayers[realm][faction], SortPlayers)
					else
						sort(sortedPlayers[realm][faction])
					end
				end
			end
		end
		sort(sortedRealms, SortRealms)
	end
end

------------------------------------------------------------------------

local BrokerPlayedTime = CreateFrame("Frame")
BrokerPlayedTime:SetScript("OnEvent", function(self, event, ...) return self[event] and self[event](self, ...) or self:SaveTimePlayed() end)
BrokerPlayedTime:RegisterEvent("PLAYER_LOGIN")

function BrokerPlayedTime:PLAYER_LOGIN()
	local function copyTable(src, dst)
		if type(src) ~= "table" then return {} end
		if type(dst) ~= "table" then dst = {} end
		for k, v in pairs(src) do
			if type(v) == "table" then
				dst[k] = copyTable(v, dst[k])
			elseif type(v) ~= type(dst[k]) then
				dst[k] = v
			end
		end
		return dst
	end

	local defaults = {
		classIcons = false,
		factionIcons = false,
		levels = false,
		[currentRealm] = {
			[currentFaction] = {
				[currentPlayer] = {
					class = (select(2, UnitClass("player"))),
					level = UnitLevel("player"),
					timePlayed = 0,
					timeUpdated = 0,
				},
			}
		}
	}

	BrokerPlayedTimeDB = BrokerPlayedTimeDB or {}
	db = copyTable(defaults, BrokerPlayedTimeDB)

	myDB = db[currentRealm][currentFaction][currentPlayer]

	BuildSortedLists()

	if CUSTOM_CLASS_COLORS then
		local function UpdateClassColors()
			for k, v in pairs(CUSTOM_CLASS_COLORS) do
				CLASS_COLORS[k] = format("|cff%02x%02x%02x", v.r * 255, v.g * 255, v.b * 255)
			end
		end
		UpdateClassColors()
		CUSTOM_CLASS_COLORS:RegisterCallback(UpdateClassColors)
	end

	self:UnregisterEvent("PLAYER_LOGIN")

	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("PLAYER_LOGOUT")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_UPDATE_RESTING")
	self:RegisterEvent("TIME_PLAYED_MSG")

	self:UpdateTimePlayed()
end

local requesting

local o = ChatFrame_DisplayTimePlayed
ChatFrame_DisplayTimePlayed = function(...)
	if requesting then
		requesting = false
		return
	end
	return o(...)
end

function BrokerPlayedTime:UpdateTimePlayed()
	requesting = true
	RequestTimePlayed()
end

function BrokerPlayedTime:SaveTimePlayed()
	local now = time()
	myDB.timePlayed = timePlayed + now - timeUpdated
	myDB.timeUpdated = now

	self:UpdateText()
	self:SetUpdateInterval(timePlayed < 3600)
end

function BrokerPlayedTime:PLAYER_LEVEL_UP(level)
	myDB.level = level or UnitLevel("player")
	self:SaveTimePlayed()
end

function BrokerPlayedTime:TIME_PLAYED_MSG(t)
	timePlayed = t
	timeUpdated = time()
	self:SaveTimePlayed()
end

------------------------------------------------------------------------

local BrokerPlayedTimeMenu = CreateFrame("Frame", "BrokerPlayedTimeMenu", nil, "UIDropDownMenuTemplate")
BrokerPlayedTimeMenu.displayMode = "MENU"
BrokerPlayedTimeMenu.info = {}

BrokerPlayedTimeMenu.GetClassIcons = function() return db.classIcons end
BrokerPlayedTimeMenu.SetClassIcons = function() db.classIcons = not db.classIcons end

BrokerPlayedTimeMenu.GetFactionIcons = function() return db.factionIcons end
BrokerPlayedTimeMenu.SetFactionIcons = function() db.factionIcons = not db.factionIcons end

BrokerPlayedTimeMenu.GetLevels = function() return db.levels end
BrokerPlayedTimeMenu.SetLevels = function() db.levels = not db.levels end

BrokerPlayedTimeMenu.CloseDropDownMenus = function() CloseDropDownMenus() end

BrokerPlayedTimeMenu.RemoveCharacter = function(button)
	local value = button and button.value or UIDROPDOWNMENU_MENU_VALUE
	local realm, faction, name = string.split("#", value)
	if realm and faction and name and db[realm] and db[realm][faction] and db[realm][faction][name] then
		db[realm][faction][name] = nil

		local nf = 0
		for k in pairs(db[realm][faction]) do
			nf = nf + 1
		end
		if nf == 0 then
			db[realm][faction] = nil
		end

		local nr = 0
		for k in pairs(db[realm]) do
			nr = nr + 1
		end
		if nr == 0 then
			db[realm] = nil
			sortedRealms[realm] = nil
		end

		BuildSortedLists()
		CloseDropDownMenus()
	end
end

BrokerPlayedTimeMenu.initialize = function(self, level)
	if not level then return end
	local info = wipe(self.info)
	if level == 1 then
		info.text = L["Played Time"]
		info.isTitle = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)

		info.isTitle = nil

		info.text = " "
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)

		info.disabled = nil
		info.notCheckable = nil

		info.keepShownOnClick = 1
		info.isNotRadio = true

		info.text = L["Character levels"]
		info.checked = self.GetLevels
		info.func = self.SetLevels
		UIDropDownMenu_AddButton(info, level)

		info.text = L["Class icons"]
		info.checked = self.GetClassIcons
		info.func = self.SetClassIcons
		UIDropDownMenu_AddButton(info, level)

		info.text = L["Faction icons"]
		info.checked = self.GetFactionIcons
		info.func = self.SetFactionIcons
		UIDropDownMenu_AddButton(info, level)

		info.checked = nil
		info.func = nil
		info.isNotRadio = nil

		info.text = " "
		info.disabled = 1
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)

		info.disabled = nil
		info.notCheckable = 1

		info.text = L["Remove character"]
		info.hasArrow = 1
		UIDropDownMenu_AddButton(info, level)

		info.checked = nil
		info.func = nil
		info.hasArrow = nil

		info.text = " "
		info.disabled = 1
		UIDropDownMenu_AddButton(info, level)

		info.disabled = nil
		info.keepShownOnClick = nil

		info.text = CLOSE
		info.func = self.CloseDropDownMenus
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info, level)
	elseif level == 2 then
		for _, realm in ipairs(sortedRealms) do
			info.text = realm
			info.value = realm
			info.hasArrow = 1
			info.keepShownOnClick = 1
			info.notCheckable = 1
			UIDropDownMenu_AddButton(info, level)
		end
	elseif level == 3 then
		local factions = 0
		for i, faction in ipairs(sortedFactions) do
			info.value = nil
			info.colorCode = nil
			info.func = nil
			info.keepShownOnClick = nil

			local realm = UIDROPDOWNMENU_MENU_VALUE
			local rfp = sortedPlayers[realm][faction]

			if rfp then
				factions = factions + 1

				if factions > 1 then
					info.text = " "
					info.disabled = 1
					info.notCheckable = 1
					UIDropDownMenu_AddButton(info, level)
				end

				info.disabled = nil

				info.text = faction
				info.isTitle = 1
				UIDropDownMenu_AddButton(info, level)

				info.isTitle = nil

				for j, name in ipairs(rfp) do
					local cdata = db[realm][faction][name]

					info.text = name
					info.value = format("%s#%s#%s", realm, faction, name)
					info.colorCode = CLASS_COLORS[cdata and cdata.class or "UNKNOWN"]
					info.disabled = (name == currentPlayer and realm == currentRealm)
					info.func = self.RemoveCharacter
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end
	end
end

------------------------------------------------------------------------

local function OnTooltipShow(tooltip)
	local total = 0
	tooltip:AddLine(L["Time Played"])
	for _, realm in ipairs(sortedRealms) do
		tooltip:AddLine(" ")
		if #sortedRealms > 1 then
			tooltip:AddLine(realm)
		end
		for _, faction in ipairs(sortedFactions) do
			local nfr = sortedPlayers[realm][faction]
			if nfr and #nfr > 0 then
				for _, name in ipairs(nfr) do
					local data = db[realm][faction][name]
					if data then
						local t
						if realm == currentRealm and name == currentPlayer then
							t = data.timePlayed + time() - data.timeUpdated
						else
							t = data.timePlayed
						end
						if t > 0 then
							if db.levels then
								tooltip:AddDoubleLine(format("%s%s%s%s (%s)|r", db.factionIcons and factionIcons[faction] or "", db.classIcons and classIcons[data.class] or "", CLASS_COLORS[data.class] or GRAY, name, data.level), FormatTime(t))
							else
								tooltip:AddDoubleLine(format("%s%s%s%s|r", db.factionIcons and factionIcons[faction] or "", db.classIcons and classIcons[data.class] or "", CLASS_COLORS[data.class] or GRAY, name), FormatTime(t))
							end
							total = total + t
						end
					end
				end
			end
		end
	end
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(L["Total"], FormatTime(total))
end

------------------------------------------------------------------------

BrokerPlayedTime.dataObject = LibStub("LibDataBroker-1.1"):NewDataObject(L["Time Played"], {
	type  = "data source",
	icon  = [[Interface\Icons\Spell_Nature_TimeStop]],
	text  = UNKNOWN,
	OnTooltipShow = OnTooltipShow,
	OnClick = function(self, button)
		if button == "RightButton" then
			ToggleDropDownMenu(1, nil, BrokerPlayedTimeMenu, self, 0, 0)
		end
	end,
})

function BrokerPlayedTime:UpdateText()
	local t = myDB.timePlayed + time() - myDB.timeUpdated
	self.dataObject.text = FormatTime(floor(t / 3600) * 3600, true)
end

do
	local t
	local function UpdateText()
		BrokerPlayedTime:UpdateText()
		C_Timer.After(t, UpdateText)
	end
	function BrokerPlayedTime:SetUpdateInterval(fast)
		local o = t
		t = fast and 30 or 300
		if not o then
			C_Timer.After(t, UpdateText)
		end
	end
end

------------------------------------------------------------------------
