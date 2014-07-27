-----------------------------------------------------------------------------------------------
-- Client Lua Script for DPSStats
-- Copyright (c) Foxykeep. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"


-----------------------------------------------------------------------------------------------
-- DPSStats Module Definition
-----------------------------------------------------------------------------------------------
local DPSStats = {}

local foxyLib = nil

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
DPSStats.PrimaryStatsLabel = {
	[GameLib.CodeEnumClass.Engineer] = Apollo.GetString("CRB_Finesse"),
	[GameLib.CodeEnumClass.Warrior] = Apollo.GetString("CRB_Brutality"),
	[GameLib.CodeEnumClass.Stalker] = Apollo.GetString("CRB_Brutality"),
	[GameLib.CodeEnumClass.Esper] = Apollo.GetString("CRB_Moxie"),
	[GameLib.CodeEnumClass.Spellslinger] = Apollo.GetString("CRB_Finesse"),
	[GameLib.CodeEnumClass.Medic] = Apollo.GetString("CRB_Tech_Attribute")
}

DPSStats.PrimaryStats = {
	[GameLib.CodeEnumClass.Engineer] = Unit.CodeEnumProperties.Dexterity,
	[GameLib.CodeEnumClass.Warrior] = Unit.CodeEnumProperties.Strength,
	[GameLib.CodeEnumClass.Stalker] = Unit.CodeEnumProperties.Strength,
	[GameLib.CodeEnumClass.Esper] = Unit.CodeEnumProperties.Magic,
	[GameLib.CodeEnumClass.Spellslinger] = Unit.CodeEnumProperties.Dexterity,
	[GameLib.CodeEnumClass.Medic] = Unit.CodeEnumProperties.Technology
}

local defaultSettings = {
	isVisible = false,
	wndPosition = {50, 30, 210, 155}
}

-----------------------------------------------------------------------------------------------
-- DPSStats Initialization
-----------------------------------------------------------------------------------------------

function DPSStats:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    return o
end

function DPSStats:InitUserSettings()

end

function DPSStats:Init()
	local bHasConfigurateFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"FoxyLib-1.0"
	}
    Apollo.RegisterAddon(self, bHasConfigurateFunction, strConfigureButtonText, tDependencies)
end


-----------------------------------------------------------------------------------------------
-- DPSStats Save & Restore settings
-----------------------------------------------------------------------------------------------

function DPSStats:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return nil
	end

    local tSave = {}
    tSave.isVisible = self.userSettings.isVisible
    tSave.wndPosition = foxyLib.DeepCopy(self.userSettings.wndPosition)

	return tSave
end

function DPSStats:OnRestore(eType, tSave)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	self.userSettings.isVisible = tSave.isVisible
	self.userSettings.wndPosition = foxyLib.DeepCopy(tSave.wndPosition)

	-- Data saved in future versions must be lazy restored (if present (~= nil), grab from tSave else
	-- grab from defaultSettings).

	self.onRestoreCalled = true
	self:SetupWndMain()
end


-----------------------------------------------------------------------------------------------
-- DPSStats OnLoad
-----------------------------------------------------------------------------------------------

function DPSStats:OnLoad()
	foxyLib = Apollo.GetPackage("FoxyLib-1.0").tPackage

	self.userSettings = foxyLib.DeepCopy(defaultSettings)

	self.onRestoreCalled = false
	self.onXmlDocLoadedCalled = false

	self.onPrimaryLabelSet = false

	-- Create the form
	self.xmlDoc = XmlDoc.CreateFromFile("DPSStats.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)

	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnFrame", self)
end

-----------------------------------------------------------------------------------------------
-- GotHUD OnDocLoaded
-----------------------------------------------------------------------------------------------
function DPSStats:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
		-- Load the settings window
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "DPSStatsWindow", nil, self)
		if not self.wndMain then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		self.wndMain:Show(false)

		-- Register handlers for events, slash commands and timer, etc.
		Apollo.RegisterSlashCommand("DPSStats", "ToggleMainUI", self)
		Apollo.RegisterSlashCommand("dpsstats", "ToggleMainUI", self)

		self.onXmlDocLoadedCalled = true
		self:SetupWndMain()
	end
end


-----------------------------------------------------------------------------------------------
-- Wnd position
-----------------------------------------------------------------------------------------------

function DPSStats:SetupWndMain()
	if not self.onRestoreCalled or not self.onXmlDocLoadedCalled then
		return
	end

	local anchors = self.userSettings.wndPosition
	self.wndMain:SetAnchorOffsets(anchors[1], anchors[2], anchors[3], anchors[4])
end


-----------------------------------------------------------------------------------------------
-- Main loop (on every 4 frames)
-----------------------------------------------------------------------------------------------

function DPSStats:OnFrame()
	if self.userSettings.isVisible then
		-- We are in not visible. Nothing to do here. Let's just hide if we are currently visible
		if self.wndMain:IsVisible() then
			self.wndMain:Show(false)
		end
		return
	end

	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		-- We don't have the player object yet.
		return
	end

	-- Show the window if not currently visible
	if not self.wndMain:IsVisible() then
		self.wndMain:Show(true)
	end

	-- Set the primary stats label if not done yet
	if not self.onPrimaryLabelSet then
		local primaryLabel = DPSStats.PrimaryStatsLabel[unitPlayer:GetClassId()]
		self.wndMain:FindChild("LabelPrimary"):SetText(primaryLabel)
	end

	-- Save the position
	local left, top, right, bottom = self.wndMain:GetAnchorOffsets()
	self.userSettings.wndPosition  = { left, top, right, bottom }

	self.wndMain:FindChild("ValueAP"):SetText(math.floor(unitPlayer:GetAssaultPower()))
	local primaryValue = math.floor(unitPlayer:GetUnitProperty(DPSStats.PrimaryStats[unitPlayer:GetClassId()]).fValue)
	self.wndMain:FindChild("ValuePrimary"):SetText(primaryValue)
	local stValue = math.floor((unitPlayer:GetStrikethroughChance() + 0.000005) * 10000) / 100
	self.wndMain:FindChild("ValueST"):SetText(stValue .. "%")
	local critHitValue = math.floor((unitPlayer:GetCritChance() + 0.000005) * 10000) / 100
	self.wndMain:FindChild("ValueCritHit"):SetText(critHitValue .. "%")
	local critSevValue = math.floor((unitPlayer:GetCritSeverity() + 0.000005) * 10000) / 100
	self.wndMain:FindChild("ValueCritSev"):SetText(critSevValue .. "%")
end


-----------------------------------------------------------------------------------------------
-- Toggle visibility
-----------------------------------------------------------------------------------------------

function DPSStats:ToggleMainUI()
	self.userSettings.isVisible = not self.userSettings.isVisible
end

-----------------------------------------------------------------------------------------------
-- DPSStats Instance
-----------------------------------------------------------------------------------------------
local DPSStatsInst = DPSStats:new()
DPSStatsInst:Init()