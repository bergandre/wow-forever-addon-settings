-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local Rectangle = LibTSMUI:DefineClassType("Rectangle")
local Widgets = LibTSMUI:Include("Util.Widgets")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {
	textureInfo = nil,
}
local CORNER_TEXTURE_KEYS = {
	"topLeft",
	"topRight",
	"bottomLeft",
	"bottomRight",
}
local EDGE_TEXTURE_KEYS = {
	"left",
	"right",
}
local CENTER_TEXTURE_KEYS = {
	"vertical",
}
local ROUNDED_CORNER_SETS = {
	ALL = { topLeft = true, topRight = true, bottomLeft = true, bottomRight = true },
	TOP = { topLeft = true, topRight = true },
	BOTTOM = { bottomLeft = true, bottomRight = true },
	LEFT = { topLeft = true, bottomLeft = true },
	RIGHT = { topRight = true, bottomRight = true },
}

---@alias RectangleCornerSet
---|'"ALL"'
---|'"TOP"'
---|'"BOTTOM"'
---|'"LEFT"'
---|'"RIGHT"'



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers the rectangle corner textures.
---@param info table The corner texture info
function Rectangle.__static.RegisterTextures(info)
	private.textureInfo = info
	for _, key in ipairs(CORNER_TEXTURE_KEYS) do
		assert(info[key])
		assert(type(info[key].texture) == "string")
		assert(#info[key].coord == 4)
	end
end

---Create a rectangle object.
---@param frame Frame The parent frame
---@param subLayer? number The texture subLayer
---@return Rectangle
function Rectangle.__static.New(frame, subLayer)
	assert(frame)
	return Rectangle(frame, subLayer)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function Rectangle.__private:__init(frame, subLayer)
	self._frame = frame
	self._textures = {} ---@type table<string,TextureExtended>
	self._inset = 0
	self._cornerRadius = 0
	self._roundedCorners = ROUNDED_CORNER_SETS.ALL
	self._shown = true

	-- Create the textures
	for _, key in ipairs(CENTER_TEXTURE_KEYS) do
		self._textures[key] = self:_CreateTexture(subLayer)
	end
	for _, key in ipairs(EDGE_TEXTURE_KEYS) do
		self._textures[key] = self:_CreateTexture(subLayer)
	end
	for _, key in ipairs(CORNER_TEXTURE_KEYS) do
		self._textures[key] = self:_CreateTexture(subLayer, private.textureInfo[key])
	end

	self:_LayoutTextures()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Shows the rectangle.
function Rectangle:Show()
	if self._shown then
		return
	end
	self._shown = true
	self:_LayoutTextures()
end

---Hides the rectangle.
function Rectangle:Hide()
	if not self._shown then
		return
	end
	self._shown = false
	self:_LayoutTextures()
end

---Sets whether or not the rectangle is shown.
---@param value boolean|ReactivePublisherSchemaBase Whether or not the rectangle should be shown or a publisher
function Rectangle:SetShown(value)
	if type(value) == "boolean" then
		if value then
			self:Show()
		else
			self:Hide()
		end
	else
		value:CallMethod(self, "SetShown")
	end
end

---Sets the color of the rectangle.
---@param color ThemeColorKey|Color
function Rectangle:SetColor(color)
	for _, key in ipairs(CENTER_TEXTURE_KEYS) do
		self._textures[key]:TSMSetColorTexture(color)
	end
	for _, key in ipairs(EDGE_TEXTURE_KEYS) do
		self._textures[key]:TSMSetColorTexture(color)
	end
	for _, key in ipairs(CORNER_TEXTURE_KEYS) do
		self._textures[key]:TSMSetVertexColor(color)
	end
end

---Subscribes the color of the rectangle to a theme color.
---@param publisher ReactivePublisherSchemaBase A publisher for the color
function Rectangle:SubscribeColor(publisher)
	publisher:FlatMapCallMethod(Theme.GetPublisher, self, "SetColor")
end

---Sets the inset of the rectangle.
---@param value number|ReactivePublisherSchemaBase The inset amount or a publisher
function Rectangle:SetInset(value)
	if type(value) == "number" then
		assert(value >= 0)
		self._inset = value
		self:_LayoutTextures()
	else
		value:CallMethod(self, "SetInset")
	end
end

---Sets the corner radius of the rectangle before any inset is applied (the inset reduces the radius to keep it concentric).
---@param value number|ReactivePublisherSchemaBase The corner radius or a publisher
function Rectangle:SetCornerRadius(value)
	if type(value) == "number" then
		assert(value >= 0)
		self._cornerRadius = value
		self:_LayoutTextures()
	else
		value:CallMethod(self, "SetCornerRadius")
	end
end

---Sets which corners of the rectangle are rounded.
---@param value RectangleCornerSet|ReactivePublisherSchemaBase The corners to round or a publisher
function Rectangle:SetRoundedCorners(value)
	if type(value) == "string" then
		self._roundedCorners = ROUNDED_CORNER_SETS[value]
		assert(self._roundedCorners)
		self:_LayoutTextures()
	else
		value:CallMethod(self, "SetRoundedCorners")
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Rectangle.__private:_LayoutTextures()
	local inset = self._inset
	local radius = max(self._cornerRadius - inset, 0)
	local isRounded = radius > 0
	local roundedCorners = self._roundedCorners
	-- Setting sizes of 0 causes issues, so make it at least 0.1
	local cornerSize = max(radius, 0.1)

	for _, key in ipairs(CORNER_TEXTURE_KEYS) do
		self._textures[key]:SetShown(self._shown and isRounded and roundedCorners[key] or false)
		self._textures[key]:SetSize(cornerSize, cornerSize)
	end
	self._textures.topLeft:SetPoint("TOPLEFT", inset, -inset)
	self._textures.topRight:SetPoint("TOPRIGHT", -inset, -inset)
	self._textures.bottomLeft:SetPoint("BOTTOMLEFT", inset, inset)
	self._textures.bottomRight:SetPoint("BOTTOMRIGHT", -inset, inset)

	for _, key in ipairs(EDGE_TEXTURE_KEYS) do
		self._textures[key]:SetShown(self._shown and isRounded)
		self._textures[key]:SetWidth(cornerSize)
	end
	self._textures.left:SetPoint("TOPLEFT", inset, -inset - (roundedCorners.topLeft and radius or 0))
	self._textures.left:SetPoint("BOTTOMLEFT", inset, inset + (roundedCorners.bottomLeft and radius or 0))
	self._textures.right:SetPoint("TOPRIGHT", -inset, -inset - (roundedCorners.topRight and radius or 0))
	self._textures.right:SetPoint("BOTTOMRIGHT", -inset, inset + (roundedCorners.bottomRight and radius or 0))
	self._textures.vertical:SetShown(self._shown)
	self._textures.vertical:SetPoint("TOPLEFT", inset + radius, -inset)
	self._textures.vertical:SetPoint("BOTTOMRIGHT", -inset - radius, inset)
end

function Rectangle.__private:_CreateTexture(subLayer, info)
	local texture = Widgets.CreateTexture(self, self._frame, "BACKGROUND", subLayer or 0)
	texture:SetSnapToPixelGrid(false)
	texture:SetTexelSnappingBias(0)
	texture:SetBlendMode("BLEND")
	if info then
		texture:SetTexture(info.texture)
		texture:SetTexCoord(unpack(info.coord))
	end
	return texture
end
