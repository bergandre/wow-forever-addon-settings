-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local View = LibTSMTypes:InitInternal("Settings.View")
local Types = LibTSMTypes:Include("Settings.Types")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local CallbackRegistry = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("CallbackRegistry")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local Vararg = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Vararg")
local Reactive = LibTSMTypes:From("LibTSMReactive"):Include("Reactive")
local private = {
	context = {}, ---@type table<SettingsView,ViewContext>
}
-- Make the keys weak so we clean up our context if the view is GC'd
setmetatable(private.context, { __mode = "k" })

---@class ViewContext
---@field name string
---@field committed boolean
---@field settingsDB SettingsDB
---@field scopeLookup table<string,ScopeName>
---@field namespaceLookup table<string,string>
---@field callbacks CallbackRegistry
---@field accessibleFactions string[]
---@field stream ReactiveStream?



-- ============================================================================
-- Metatable
-- ============================================================================

---@class SettingsView
local VIEW_METHODS = {}
local VIEW_MT = nil
VIEW_MT = {
	__index = function(self, key)
		if VIEW_METHODS[key] then
			return VIEW_METHODS[key]
		elseif key == "ToDebugString" then
			-- Wow calls this - defer to __tostring
			return VIEW_MT.__tostring
		end
		local context = private.context[self]
		assert(context.committed)
		return context.settingsDB:Get(context.scopeLookup[key], nil, context.namespaceLookup[key], key)
	end,
	__newindex = function(self, key, value)
		local context = private.context[self]
		assert(context.committed)
		context.settingsDB:Set(context.scopeLookup[key], nil, context.namespaceLookup[key], key, value)
	end,
	__tostring = function(self)
		local context = private.context[self]
		return "SettingsView:"..context.name
	end,
	__metatable = false,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new view.
---@param db SettingsDB
---@param accessibleFactions string[]
---@param name string
---@return SettingsView
function View.New(db, accessibleFactions, name)
	local view = setmetatable({}, VIEW_MT)
	private.context[view] = {
		name = name,
		settingsDB = db,
		scopeLookup = {},
		namespaceLookup = {},
		callbacks = CallbackRegistry.NewWithKeys(),
		accessibleFactions = accessibleFactions,
	}
	return view
end



-- ============================================================================
-- Setting View Class
-- ============================================================================

---Adds a key to the view.
---@param scopeName ScopeName The scope name
---@param namespace string The namespace
---@param key string The setting key
---@builds-field 3 any
---@return self
function VIEW_METHODS:AddKey(scopeName, namespace, key)
	local context = private.context[self]
	assert(context and not context.committed)
	assert(not context.scopeLookup[key] and context.settingsDB:HasKey(scopeName, namespace, key))
	context.scopeLookup[key] = scopeName
	context.namespaceLookup[key] = namespace
	return self
end

---@return built: SettingsView
function VIEW_METHODS:Commit()
	local context = private.context[self]
	assert(not context.committed)
	context.committed = true
	return self
end

---Registers a callback for when a key changes.
---@param key string The setting key
---@param callback fun() The callback function
---@return self
function VIEW_METHODS:RegisterCallback(key, callback)
	self:AssertHasKeys(key)
	local context = private.context[self]
	context.callbacks:Add(callback, key)
	return self
end

---Gets a publisher for when a key changes.
---@param key string The setting key
---@return ReactivePublisherSchema
function VIEW_METHODS:PublisherForKey(key)
	self:AssertHasKeys(key)
	local context = private.context[self]
	if not context.stream then
		context.stream = Reactive.GetStream(function() return self end)
	end
	return context.stream:Publisher()
		:IgnoreDuplicatesWithKeys(key)
		:Map(key)
		:IgnoreDuplicates()
end

---Gets a publisher for when any of a list of keys changes.
---@param ... string The setting keys
---@return ReactivePublisherSchema
function VIEW_METHODS:PublisherForKeys(...)
	local context = private.context[self]
	self:AssertHasKeys(...)
	if not context.stream then
		context.stream = Reactive.GetStream(function() return self end)
	end
	return context.stream:Publisher()
		:IgnoreDuplicatesWithKeys(...)
end

---Gets the read-only default for a key.
---@param key string The setting key
---@return any
function VIEW_METHODS:GetDefaultReadOnly(key)
	local context = private.context[self]
	return context.settingsDB:_GetDefaultReadOnly(context.scopeLookup[key], context.namespaceLookup[key], key)
end

---Resets the key to its default value.
---@param key string The setting key
function VIEW_METHODS:ResetToDefault(key)
	local context = private.context[self]
	local value = self:GetDefaultReadOnly(key)
	if type(value) == "table" then
		value = CopyTable(value)
	end
	context.settingsDB:Set(context.scopeLookup[key], nil, context.namespaceLookup[key], key, value)
end

---Returns an iterator over all accessible values for a key (must have a `regionWide` key).
---@param key string The setting key
---@return fun(): number, ...any
---@return table
---@return number
function VIEW_METHODS:AccessibleValueIterator(key)
	local context = private.context[self]
	local connectedOnly = not self.regionWide ---@diagnostic disable-line: undefined-field
	local scopeType = context.scopeLookup[key]
	local namespace = context.namespaceLookup[key]
	local result = TempTable.Acquire()
	for _, realm in context.settingsDB:AccessibleRealmIterator("realm", connectedOnly) do
		if scopeType == "realm" then
			local value = context.settingsDB:Get(scopeType, realm, namespace, key)
			if value ~= nil then
				Table.InsertMultiple(result, value, realm)
			end
		else
			for _, faction in ipairs(context.accessibleFactions) do
				local factionrealm = strjoin(Types.SCOPE_KEY_SEP, faction, realm)
				if scopeType == "sync" then
					for scopeKey in pairs(context.settingsDB._tbl._syncOwner) do ---@diagnostic disable-line: invisible
						local character = strmatch(scopeKey, "^(.+)"..String.Escape(Types.SCOPE_KEY_SEP..factionrealm))
						if character then
							local value = context.settingsDB:Get(scopeType, scopeKey, namespace, key)
							if value ~= nil then
								Table.InsertMultiple(result, value, character, factionrealm)
							end
						end
					end
				elseif scopeType == "factionrealm" then
					local value = context.settingsDB:Get(scopeType, factionrealm, namespace, key)
					if value ~= nil then
						Table.InsertMultiple(result, value, factionrealm)
					end
				else
					error("Invalid scopeType: "..tostring(scopeType))
				end
			end
		end
	end
	if scopeType == "sync" then
		return TempTable.Iterator(result, 3)
	elseif scopeType == "factionrealm" then
		return TempTable.Iterator(result, 2)
	elseif scopeType == "realm" then
		return TempTable.Iterator(result, 2)
	else
		error("Invalid scopeType: "..tostring(scopeType))
	end
end

---Iterates over all the local values (current account and factionrealm)
---@param key string The setting key
---@return fun(): number, any, string @Iterator with fields: `index`, `value`, `character`
---@return table
---@return number
function VIEW_METHODS:LocalValueIterator(key)
	local context = private.context[self]
	assert(context.scopeLookup[key] == "sync")
	local namespace = context.namespaceLookup[key]
	local result = TempTable.Acquire()
	for _, character in context.settingsDB:AccessibleCharacterIterator() do
		local scopeKey = context.settingsDB:GetSyncScopeKeyByCharacter(character)
		local value = context.settingsDB:Get("sync", scopeKey, namespace, key)
		if value ~= nil then
			Table.InsertMultiple(result, value, character)
		end
	end
	return TempTable.Iterator(result, 2)
end

---Get the setting value for a given scope key.
---@param key string The setting key
---@param ... string|nil The character followed by the factionrealm for sync scope keys or just the single scope key otherwise
---@return any
function VIEW_METHODS:GetForScopeKey(key, ...)
	local context = private.context[self]
	local scopeType = context.scopeLookup[key]
	local scopeKey = nil
	if scopeType == "sync" then
		assert(select("#", ...) == 2)
		scopeKey = context.settingsDB:GetSyncScopeKeyByCharacter(...)
	elseif scopeType == "factionrealm" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	elseif scopeType == "realm" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	elseif scopeType == "profile" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	else
		error("Invalid scopeType: "..tostring(scopeType))
	end
	return context.settingsDB:Get(context.scopeLookup[key], scopeKey, context.namespaceLookup[key], key)
end

---Set the setting value for a given scope key.
---@param key string The setting key
---@param value any The value to set
---@param ... string The character followed by the factionrealm for sync scope keys or just the single scope key otherwise
---@return any
function VIEW_METHODS:SetForScopeKey(key, value, ...)
	local context = private.context[self]
	local scopeType = context.scopeLookup[key]
	local scopeKey = nil
	if scopeType == "sync" then
		assert(select("#", ...) == 2)
		scopeKey = context.settingsDB:GetSyncScopeKeyByCharacter(...)
	elseif scopeType == "factionrealm" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	elseif scopeType == "realm" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	elseif scopeType == "profile" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	else
		error("Invalid scopeType: "..tostring(scopeType))
	end
	return context.settingsDB:Set(context.scopeLookup[key], scopeKey, context.namespaceLookup[key], key, value)
end

---Asserts that the view has the specified keys.
---@param ... string The setting keys
function VIEW_METHODS:AssertHasKeys(...)
	for _, key in Vararg.Iterator(...) do
		assert(private.context[self].scopeLookup[key])
	end
end

function VIEW_METHODS:_HandleSettingChanged(scopeName, namespace, key)
	local context = private.context[self]
	if context.scopeLookup[key] == scopeName and context.namespaceLookup[key] == namespace then
		if context.callbacks:HasCallback(key) then
			context.callbacks:Call(key)
		end
		if context.stream then
			context.stream:Send(self)
		end
	end
end
