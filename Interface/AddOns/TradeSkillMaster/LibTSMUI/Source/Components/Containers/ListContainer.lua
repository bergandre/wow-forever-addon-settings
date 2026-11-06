-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ComponentRegistry = LibTSMUI:Include("ComponentRegistry")
local UIElements = LibTSMUI:Include("UIElements")
local INNER_CORNER_RADIUS = 3



-- ============================================================================
-- Element Definition
-- ============================================================================

local ListContainer = ComponentRegistry.Define("ListContainer", "BaseFrame")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ListContainer:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetPadding(1, 1, 1, 4)
	self:SetBorderColor("outline/variant")
	self:SetRoundedBackgroundColor("container/lowest")
end

---Adds a list, rounding its header to match the container's corners.
---@param child List The list
---@return self
function ListContainer:AddChild(child)
	child:SetHeaderCornerRadius(INNER_CORNER_RADIUS)
	self.__super:AddChild(child)
	return self
end

---Adds a header above the list with its top corners rounded to match the container.
---@param header BaseFrame The header frame
---@return self
function ListContainer:AddHeader(header)
	self.__super:AddChild(header
		:SetRoundedBackgroundColor("container/low")
		:SetRoundedCorners("TOP", INNER_CORNER_RADIUS)
	)
	self.__super:AddChild(UIElements.New("HorizontalLine", "headerLine"))
	return self
end

---Adds a footer below the list with its bottom corners rounded to match the container.
---@param footer BaseFrame The footer frame
---@return self
function ListContainer:AddFooter(footer)
	self:SetPadding(1)
	self.__super:AddChild(UIElements.New("HorizontalLine", "footerLine"))
	self.__super:AddChild(footer
		:SetRoundedBackgroundColor("container/low")
		:SetRoundedCorners("BOTTOM", INNER_CORNER_RADIUS)
	)
	return self
end
