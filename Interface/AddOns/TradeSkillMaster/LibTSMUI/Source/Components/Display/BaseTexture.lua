-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local BaseTexture = ComponentRegistry.Define("BaseTexture", "Element")
BaseTexture._STATE_SCHEMA = BaseTexture._STATE_SCHEMA:Extend("BaseTextureState")
	:AddOptionalStringField("color", Theme.IsValidColor)
	:AddOptionalStringField("texturePackKey")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function BaseTexture:__init()
	local texture = self:_CreateTexture(UIParent)
	-- Hook SetParent/GetParent since textures can't have a nil parent
	texture._oldSetParent = texture.SetParent ---@diagnostic disable-line: inject-field
	texture.SetParent = private.SetParent
	texture.GetParent = private.GetParent
	texture:SetSnapToPixelGrid(false)
	texture:SetTexelSnappingBias(0)
	self._frame = texture
	self.__super:__init(texture)

	self._frame:TSMSubscribeColorTexture(self._state:Publisher("color"):IgnoreNil())
	self._frame:TSMSetTextureAndCoord(self._state:Publisher("texturePackKey"):IgnoreNil())
end

function BaseTexture:Release()
	self._frame:SetTexture(nil)
	self._frame:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
	self._frame:SetColorTexture(0, 0, 0, 0)
	self.__super:Release()
end

---Sets the texture to a theme color key.
---@param value ThemeColorKey|ReactivePublisherSchemaBase A theme color key or a publisher
---@return self
function BaseTexture:SetColor(value)
	if type(value) == "string" then
		assert(not self._state.texturePackKey)
		self._state.color = value
	else
		self:_MethodPublisher(value, "SetColor")
	end
	return self
end

---Sets the texture and size based on a texture pack string.
---@param value string|ReactivePublisherSchemaBase A texture pack key
---@return self
function BaseTexture:SetTextureAndSize(value)
	if type(value) == "string" then
		assert(not self._state.color)
		self._state.texturePackKey = value
		self:SetSize(TextureAtlas.GetSize(value))
	else
		self:_MethodPublisher(value, "SetTextureAndSize")
	end
	return self
end

---Gets whether the mouse is currently over the frame.
---@param includeMargin? boolean Whether or not to include the margin of the frame
---@return boolean
function BaseTexture:IsMouseOver(includeMargin)
	if includeMargin then
		return self._frame:IsMouseOver(self:_GetMargin("TOP"), -self:_GetMargin("BOTTOM"), -self:_GetMargin("LEFT"), self:_GetMargin("RIGHT"))
	else
		return self._frame:IsMouseOver()
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SetParent(texture, parent)
	texture._parent = parent
	if parent then
		texture:Show()
	else
		texture:Hide()
	end
	texture:_oldSetParent(parent or UIParent)
end

function private.GetParent(texture)
	return texture._parent
end
