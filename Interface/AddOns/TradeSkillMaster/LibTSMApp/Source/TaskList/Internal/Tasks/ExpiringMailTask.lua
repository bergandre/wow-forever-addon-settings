-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Task = LibTSMApp:From("LibTSMTypes"):IncludeClassType("Task")
local ExpiringMailTask = LibTSMApp:DefineInternalClassType("ExpiringMailTask", Task)
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

---Configures the expiring mail task code.
---@param db SettingsDB The settings DB
---@param updateFunc fun() The update function
function ExpiringMailTask.__static.Configure(db, updateFunc)
	assert(not private.updateFunc)
	private.updateFunc = updateFunc
	private.settings = db:NewView("ExpiringMailTaskSettings")
		:AddKey("factionrealm", "internalData", "expiringMail")
		:AddKey("sync", "internalData", "classKey")
		:Commit()
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ExpiringMailTask:__init()
	self.__super:__init()
	self._characters = {}
	self._daysLeft = {}
end

function ExpiringMailTask:Acquire(doneHandler, category)
	self.__super:Acquire(doneHandler, category, L["Expiring Mails"])
end

function ExpiringMailTask:Release()
	self.__super:Release()
	wipe(self._characters)
	wipe(self._daysLeft)
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ExpiringMailTask:IsSecureMacro()
	return true
end

function ExpiringMailTask:GetSecureMacroText()
	return "/logout"
end

function ExpiringMailTask:GetDaysLeft(character)
	return self._daysLeft[character] or false
end

function ExpiringMailTask:WipeCharacters()
	wipe(self._characters)
	wipe(self._daysLeft)
end

function ExpiringMailTask:HasCharacters()
	return #self._characters > 0
end

function ExpiringMailTask:HasCharacter(character)
	return self._daysLeft[character] and true or false
end

function ExpiringMailTask:AddCharacter(character, days)
	tinsert(self._characters, character)
	self._daysLeft[character] = days
end

function ExpiringMailTask:CanHideSubTasks()
	return true
end

function ExpiringMailTask:HideSubTask(index)
	local character = self._characters[index]
	if not character then
		return
	end
	private.settings.expiringMail[character] = nil
	private.updateFunc()
end

function ExpiringMailTask:HasSubTasks()
	assert(self:HasCharacters())
	return true
end

function ExpiringMailTask:SubTaskIterator()
	assert(self:HasCharacters())
	sort(self._characters)
	return private.SubTaskIterator, self, 0
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ExpiringMailTask:_UpdateState()
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
	local timeLeft = self._daysLeft[character]
	if timeLeft < 0 then
		timeLeft = L["Expired"]
	elseif timeLeft >= 1 then
		timeLeft = floor(timeLeft).." "..GlobalStrings.Get("DAYS")
	else
		local hoursLeft = floor(timeLeft * 24)
		if hoursLeft > 1 then
			timeLeft = hoursLeft.." "..L["Hrs"]
		elseif hoursLeft == 1 then
			timeLeft = hoursLeft.." "..L["Hr"]
		else
			timeLeft = floor(hoursLeft / 60).." "..L["Min"]
		end
	end
	local charColored = character
	local classColor = CharacterInfo.GetClassRaidColorString(private.settings:GetForScopeKey("classKey", character, SessionInfo.GetFactionrealmName()))
	if classColor then
		charColored = "|c"..classColor..charColored.."|r"
	end
	return index, charColored.." ("..timeLeft..")"
end
