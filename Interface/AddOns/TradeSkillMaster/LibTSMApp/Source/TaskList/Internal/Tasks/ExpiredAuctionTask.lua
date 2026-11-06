-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Task = LibTSMApp:From("LibTSMTypes"):IncludeClassType("Task")
local ExpiredAuctionTask = LibTSMApp:DefineInternalClassType("ExpiredAuctionTask", Task)
local CharacterInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.CharacterInfo")
local GlobalStrings = LibTSMApp:From("LibTSMWoW"):Include("Util.GlobalStrings")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	settings = nil,
	updateFunc = nil,
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Configures the expired auction task code.
---@param db SettingsDB The settings DB
---@param updateFunc fun() The update function
function ExpiredAuctionTask.__static.Configure(db, updateFunc)
	assert(not private.updateFunc)
	private.updateFunc = updateFunc
	private.settings = db:NewView("ExpiredAuctionTaskSettings")
		:AddKey("factionrealm", "internalData", "expiringAuction")
		:AddKey("sync", "internalData", "classKey")
		:Commit()
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ExpiredAuctionTask:__init()
	self.__super:__init()
	self._characters = {}
	self._daysLeft = {}
end

function ExpiredAuctionTask:Acquire(doneHandler, category)
	self.__super:Acquire(doneHandler, category, L["Expired Auctions"])
end

function ExpiredAuctionTask:Release()
	self.__super:Release()
	wipe(self._characters)
	wipe(self._daysLeft)
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ExpiredAuctionTask:IsSecureMacro()
	return true
end

function ExpiredAuctionTask:GetSecureMacroText()
	return "/logout"
end

function ExpiredAuctionTask:GetDaysLeft(character)
	return self._daysLeft[character] or false
end

function ExpiredAuctionTask:WipeCharacters()
	wipe(self._characters)
	wipe(self._daysLeft)
end

function ExpiredAuctionTask:HasCharacters()
	return #self._characters > 0
end

function ExpiredAuctionTask:HasCharacter(character)
	return self._daysLeft[character] and true or false
end

function ExpiredAuctionTask:AddCharacter(character, days)
	tinsert(self._characters, character)
	self._daysLeft[character] = days
end

function ExpiredAuctionTask:CanHideSubTasks()
	return true
end

function ExpiredAuctionTask:HideSubTask(index)
	local character = self._characters[index]
	if not character then
		return
	end
	private.settings.expiringAuction[character] = nil
	private.updateFunc()
end

function ExpiredAuctionTask:HasSubTasks()
	assert(self:HasCharacters())
	return true
end

function ExpiredAuctionTask:SubTaskIterator()
	assert(self:HasCharacters())
	sort(self._characters)
	return private.SubTaskIterator, self, 0
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ExpiredAuctionTask:_UpdateState()
	return self:_SetButtonState(true, strupper(GlobalStrings.Get("LOGOUT")))
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SubTaskIterator(self, index)
	index = index + 1
	local character = self._characters[index]
	if not character then
		return
	end
	local classColor = CharacterInfo.GetClassRaidColorString(private.settings:GetForScopeKey("classKey", character, SessionInfo.GetFactionrealmName()))
	if classColor then
		character = "|c"..classColor..character.."|r"
	end
	return index, character
end
