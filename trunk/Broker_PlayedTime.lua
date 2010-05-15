--[[--------------------------------------------------------------------
	Broker_PlayedTime
	Tracks played time for all your characters.
	by Phanx < addons@phanx.net >
	Copyright © 2010 Alyssa "Phanx" Kinley
	http://www.wowinterface.com/downloads/info-BrokerPlayedTime.html
	http://wow.curse.com/downloads/wow-addons/details/broker-playedtime.aspx
----------------------------------------------------------------------]]
--  TODO:
--  option to show seconds in tooltip ?
--  option to show all realms or just current realm ?

local L = setmetatable({}, {
	__index = function(t, s)
		if s then
			t[s] = tostring(s)
			return t[s]
		end
	end
})

local db
local myDB

local sortedFactions = { "Horde", "Alliance" }
local sortedPlayers = {}
local sortedRealms = {}

local currentFaction = UnitFactionGroup("player")
local currentPlayer = UnitName("player")
local currentRealm = GetRealmName()

local timePlayed = 0
local timeUpdated = 0

local maxLevel = MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()]

local factionIcons = {
	Horde = "|TInterface\\AddOns\\Broker_PlayedTime\\Faction-Horde:0|t ",
	Alliance = "|TInterface\\AddOns\\Broker_PlayedTime\\Faction-Alliance:0|t ",
}

local classIcons = {
	DEATHKNIGHT = "|TInterface\\Icons\\Spell_Deathknight_ClassIcon:0|t ",
	DRUID = "|TInterface\\Icons\\INV_Misc_MonsterClaw_04:0|t ",
	HUNTER = "|TInterface\\Icons\\INV_Weapon_Bow_07:0|t ",
	MAGE = "|TInterface\\Icons\\INV_Staff_13:0|t ",
	PRIEST = "|TInterface\\Icons\\INV_Staff_30:0|t ",
	PALADIN = "|TInterface\\AddOns\\Broker_PlayedTime\\Class-Paladin:0|t ",
	ROGUE = "|TInterface\\AddOns\\Broker_PlayedTime\\Class-Rogue:0|t ",
	SHAMAN = "|TInterface\\Icons\\Spell_Nature_BloodLust:0|t ",
	WARRIOR = "|TInterface\\Icons\\INV_Sword_27:0|t ",
	WARLOCK = "|TInterface\\Icons\\Spell_Nature_FaerieFire:0|t ",
}

local GRAY = "cccccc"
local CLASS_COLORS = {}
for k, v in pairs(RAID_CLASS_COLORS) do
	CLASS_COLORS[k] = ("|cff%02x%02x%02x"):format(v.r * 255, v.g * 255, v.b * 255)
end

local TIME_STRING = "|cffffffff%d|r|cffffcc00d|r |cffffffff%02d|r|cffffcc00h|r |cffffffff%02d|r|cffffcc00m|r" -- |cffffffff%02d|r|cffffcc00s|r"
local function FormatTime(t)
	if not t then return end

	local d = floor(t / 86400)
	local h = floor((t - (d * 86400)) / 3600)
	local m = floor((t - (d * 86400) - (h * 3600)) / 60)
--	local s = mod(t, 60)

	local text = format(TIME_STRING, d, h, m) --, s)
	return(text)
end

local BrokerPlayedTime = CreateFrame("Frame")
BrokerPlayedTime:SetScript("OnEvent", function(self, event, ...) return self[event] and self[event](self, ...) end)
BrokerPlayedTime:RegisterEvent("PLAYER_LOGIN")

function BrokerPlayedTime:PLAYER_LOGIN()
	if not BrokerPlayedTimeDB then
		BrokerPlayedTimeDB = {
			classIcons = false,
			factionIcons = true,
			levels = true,
		}
	end

	db = BrokerPlayedTimeDB

	if not db[currentRealm] then db[currentRealm] = { } end
	if not db[currentRealm][currentFaction] then db[currentRealm][currentFaction] = { } end
	if not db[currentRealm][currentFaction][currentPlayer] then db[currentRealm][currentFaction][currentPlayer] = { } end

	myDB = db[currentRealm][currentFaction][currentPlayer]

	if not myDB.class then myDB.class = select(2, UnitClass("player"))end
	if not myDB.level then myDB.level = UnitLevel("player") end
	if not myDB.timePlayed then myDB.timePlayed = 0 end
	if not myDB.timeUpdated then myDB.timeUpdated = 0 end

	for realm in pairs(db) do
		if type(db[realm]) == "table" then
			table.insert(sortedRealms, realm)
			sortedPlayers[realm] = { }
			for faction in pairs(db[realm]) do
				sortedPlayers[realm][faction] = { }
				for name in pairs(db[realm][faction]) do
					table.insert(sortedPlayers[realm][faction], name)
				end
				if realm == currentRealm and faction == currentFaction then
					table.sort(sortedPlayers[realm][faction], function(a, b)
						if a == currentPlayer then
							return true
						elseif b == currentPlayer then
							return false
						end
						return a < b
					end)
				else
					table.sort(sortedPlayers[realm][faction])
				end
			end
		end
	end
	table.sort(sortedRealms, function(a, b)
		if a == currentRealm then
			return true
		elseif b == currentRealm then
			return false
		end
		return a < b
	end)

	if CUSTOM_CLASS_COLORS then
		local function UpdateClassColors()
			for k, v in pairs(CUSTOM_CLASS_COLORS) do
				CLASS_COLORS[k] = ("|cff%02x%02x%02x"):format(v.r * 255, v.g * 255, v.b * 255)
			end
		end
		UpdateClassColors()
		CUSTOM_CLASS_COLORS:RegisterCallback(UpdateClassColors)
	end

	self:UnregisterEvent("PLAYER_LOGIN")

	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_UPDATE_RESTING")
	self:RegisterEvent("TIME_PLAYED_MSG")

	self:UpdateTimePlayed()
end

function BrokerPlayedTime:UpdateTimePlayed()
	-- TODO:
	-- suppress chat message ?
	RequestTimePlayed()
end

function BrokerPlayedTime:SaveTimePlayed()
	local now = time()
	myDB.timePlayed = timePlayed + now - timeUpdated
	myDB.timeUpdated = now
end

BrokerPlayedTime.PLAYER_LEVEL_UP       = BrokerPlayedTime.SaveTimePlayed
BrokerPlayedTime.PLAYER_REGEN_ENABLED  = BrokerPlayedTime.SaveTimePlayed
BrokerPlayedTime.PLAYER_UPDATE_RESTING = BrokerPlayedTime.SaveTimePlayed

function BrokerPlayedTime:TIME_PLAYED_MSG(t)
	timePlayed = t
	timeUpdated = time()
	self:SaveTimePlayed()
end

BrokerPlayedTime.dataObject = LibStub("LibDataBroker-1.1"):NewDataObject("Played Time", {
	type = "data source",
	icon = "Interface\\Icons\\Spell_Nature_TimeStop", -- factionIcons[currentFaction],
	text = "Played Time",
	OnTooltipShow = function(tt)
		local total = 0
		tt:AddLine("Time Played")
		for _, realm in ipairs(sortedRealms) do
			tt:AddLine(" ")
			tt:AddLine(realm)
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
									tt:AddDoubleLine(("%s%s%s%s (%s)|r"):format(db.factionIcons and factionIcons[faction] or "", db.classIcons and classIcons[data.class] or "", CLASS_COLORS[data.class] or GRAY, name, data.level), FormatTime(t))
								else
									tt:AddDoubleLine(("%s%s%s%s|r"):format(db.factionIcons and factionIcons[faction] or "", db.classIcons and classIcons[data.class] or "", CLASS_COLORS[data.class] or GRAY, name), FormatTime(t))
								end
								total = total + t
							end
						end
					end
				end
			end
		end
		tt:AddLine(" ")
		tt:AddDoubleLine("Total", FormatTime(total))
	end
})

BrokerPlayedTime.optionsPanel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
BrokerPlayedTime.optionsPanel:Hide()

BrokerPlayedTime.optionsPanel.name = GetAddOnInfo("Broker PlayedTime", "Title")
BrokerPlayedTime.optionsPanel:SetScript("OnShow", function(self)
	local name = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	name:SetPoint("TOPLEFT", 16, -16)
	name:SetPoint("TOPRIGHT", -16, -16)
	name:SetJustifyH("LEFT")
	name:SetText(self.name)

	local desc = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -8)
	desc:SetPoint("TOPRIGHT", name, "BOTTOMRIGHT", 0, -8)
	desc:SetHeight(32)
	desc:SetJustifyH("LEFT")
	desc:SetJustifyV("TOP")
	desc:SetNonSpaceWrap(true)
	desc:SetText(GetAddOnMetadata("Broker_PlayedTime", "Notes"))

	local function OnClick(self)
		local checked = self:GetChecked() == 1
		PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
		if self.setValue then
			self.setValue(checked)
		end
	end
	local function CreateCheckbox(parent, label)
		local checkbox = CreateFrame("CheckButton", nil, parent)
		checkbox:SetWidth(26)
		checkbox:SetHeight(26)

		checkbox:SetHitRectInsets(0, -100, 0, 0)

		checkbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
		checkbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
		checkbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
		checkbox:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
		checkbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

		checkbox:SetScript("OnClick", OnClick)

		checkbox.label = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 0, 1)
		checkbox.label:SetText(label)

		return checkbox
	end

	local classIcons = CreateCheckbox(self, L["Show class icons"])
	classIcons:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -8)
	classIcons:SetChecked(db.classIcons)
	classIcons.setValue = function(checked)
		db.classIcons = checked
	end

	local factionIcons = CreateCheckbox(self, L["Show faction icons"])
	factionIcons:SetPoint("TOPLEFT", classIcons, "BOTTOMLEFT", 0, -8)
	factionIcons:SetChecked(db.factionIcons)
	factionIcons.setValue = function(checked)
		db.factionIcons = checked
	end

	local levels = CreateCheckbox(self, L["Show character levels"])
	levels:SetPoint("TOPLEFT", factionIcons, "BOTTOMLEFT", 0, -8)
	levels:SetChecked(db.levels)
	levels.setValue = function(checked)
		db.levels = checked
	end

	self:SetScript("OnShow", nil)
end)
InterfaceOptions_AddCategory(BrokerPlayedTime.optionsPanel)

BrokerPlayedTime.dataObject.OnClick = function(self, button)
	if button == "RightButton" then
		InterfaceOptionsFrame_OpenToCategory(BrokerPlayedTime.optionsPanel)
	end
end