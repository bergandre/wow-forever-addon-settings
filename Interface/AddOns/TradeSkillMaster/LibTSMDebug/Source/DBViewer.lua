-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMDebug = select(2, ...).LibTSMDebug
local DBViewer = LibTSMDebug:InitInternal("DBViewer")
local Reactive = LibTSMDebug:From("LibTSMReactive"):Include("Reactive")
local UIManager = LibTSMDebug:From("LibTSMReactive"):IncludeClassType("UIManager")
local Database = LibTSMDebug:From("LibTSMDatabase"):Include("Database")
local UIElements = LibTSMDebug:From("LibTSMUI"):Include("UIElements")
local SlashCommands = LibTSMDebug:From("LibTSMApp"):Include("Service.SlashCommands")
local private = {
	manager = nil,
	frameContext = {},
	dividedContainerContext = {},
}
local DEFAULT_FRAME_CONTEXT = {
	width = 900,
	height = 600,
	centerX = 100,
	centerY = 0,
	scale = 1,
}
local MIN_FRAME_SIZE = {
	width = 900,
	height = 600
}
local DEFAULT_DIVIDED_CONTAINER_CONTEXT = {
	leftWidth = 200,
}
local STATE_SCHEMA = Reactive.CreateStateSchema("DBViewerUIState")
	:AddDeferredUIElementField("frame", "ApplicationFrame")
	:AddDeferredUIElementField("browseScrollTable", "DatabaseBrowseScrollTable")
	:AddDeferredUIElementField("contentFrame", "BaseFrame")
	:AddOptionalStringField("selectedDBName")
	:AddStringField("queryCode", "query")
	:Commit()



-- ============================================================================
-- Module Loading
-- ============================================================================

DBViewer:OnModuleLoad(function()
	SlashCommands.RegisterDebug("db", DBViewer.Toggle)

	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("DB_VIEWER", state, private.ActionHandler)
		:SuppressActionLog("ACTION_HIDE_FRAME")
		:SuppressActionLog("ACTION_HANDLE_FRAME_HIDE")
		:AddFrameBuilder(private.CreateMainFrame)
end)

DBViewer:OnModuleUnload(function()
	private.manager:ProcessAction("ACTION_HIDE_FRAME")
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function DBViewer.Toggle()
	private.manager:ProcessAction("ACTION_TOGGLE")
end



-- ============================================================================
-- UI Functions
-- ============================================================================

---@param state DBViewerUIState
function private.CreateMainFrame(state)
	state.selectedDBName = nil
	return UIElements.New("ApplicationFrame", "base")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:SetContextTable(private.frameContext, DEFAULT_FRAME_CONTEXT)
		:SetTitle("TSM DB Viewer")
		:BindElement(state, "frame")
		:SetManager(private.manager)
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_HANDLE_FRAME_HIDE"))
		:SetContentFrame(UIElements.New("DividedContainer", "container")
			:SetContextTable(private.dividedContainerContext, DEFAULT_DIVIDED_CONTAINER_CONTEXT)
			:SetBackgroundColor("container/lowest")
			:SetMinWidth(100, 100)
			:SetLeftChild(UIElements.New("BaseScrollFrame", "left")
				:AddChildrenWithFunction(private.AddTableRows, state)
			)
			:SetRightChild(UIElements.New("BaseFrame", "right")
				:SetLayout("VERTICAL")
				:BindElement(state, "contentFrame")
			)
		)
end

---@param state DBViewerUIState
function private.AddTableRows(frame, state)
	for _, name in Database.InfoNameIterator() do
		frame:AddChild(UIElements.New("DatabaseNavButton", "nav_"..name)
			:SetHeight(20)
			:SetPadding(8, 0, 0, 0)
			:SetTableName(name)
			:SetTextColor(state:Publisher("selectedDBName"):ToBooleanEquals(name):ReplaceBooleanWith("accent/main", "on/surface"))
			:SetAction("OnClick", "ACTION_SHOW_TABLE")
		)
	end
end

function private.ContentNavCallback(tabGroup, path)
	local state = tabGroup:GetContext() ---@type DBViewerUIState
	if path == "Structure" then
		return private.CreateStructureFrame(state)
	elseif path == "Browse" then
		return private.CreateBrowseFrame(state)
	else
		error("Invalid path: "..tostring(path))
	end
end

---@param state DBViewerUIState
function private.CreateStructureFrame(state)
	assert(state.selectedDBName)
	return UIElements.New("BaseFrame", "structure")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("BaseFrame", "info")
			:SetLayout("HORIZONTAL")
			:SetHeight(20)
			:SetMargin(4)
			:AddChild(UIElements.New("Text", "numRows")
				:SetFont("BODY_SMALL")
				:SetText("Total Rows: "..Database.GetNumRows(state.selectedDBName))
			)
			:AddChild(UIElements.New("Text", "numQueries")
				:SetFont("BODY_SMALL")
				:SetText("Active Queries: "..Database.GetNumActiveQueries(state.selectedDBName))
			)
		)
		:AddChild(UIElements.New("DatabaseStructureScrollTable", "table")
			:SetQuery(Database.CreateInfoFieldQuery(state.selectedDBName))
		)
end

---@param state DBViewerUIState
function private.CreateBrowseFrame(state)
	assert(state.selectedDBName)
	state.queryCode = "query"
	return UIElements.New("BaseFrame", "browse")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Input", "queryInput")
			:SetHeight(26)
			:SetMargin(8)
			:SetValue("query")
			:BindValue(state, "queryCode")
			:SetAction("OnEnterPressed", "ACTION_UPDATE_QUERY")
		)
		:AddChild(UIElements.New("DatabaseBrowseScrollTable", "table")
			:SetTable(state.selectedDBName)
			:BindElement(state, "browseScrollTable")
		)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager<DBViewerUIState>
---@param state DBViewerUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_TOGGLE" then
		if state.frame then
			return manager:ProcessAction("ACTION_HIDE_FRAME")
		else
			private.manager:BuildFrame()
				:Show()
				:Draw()
		end
	elseif action == "ACTION_HIDE_FRAME" then
		if not state.frame then
			return
		end
		state.frame:Hide()
	elseif action == "ACTION_HANDLE_FRAME_HIDE" then
		state.frame:Release()
	elseif action == "ACTION_UPDATE_QUERY" then
		state.browseScrollTable:UpdateQueryWithLoadedFunction(state.queryCode)
	elseif action == "ACTION_SHOW_TABLE" then
		local selectedDBName = ...
		state.selectedDBName = selectedDBName
		state.contentFrame
			:ReleaseAllChildren()
			:AddChild(UIElements.New("SegmentedTabGroup", "tabs")
				:SetMargin(0, 0, 4, 0)
				:SetContext(state)
				:SetNavCallback(private.ContentNavCallback)
				:AddPath("Structure", true)
				:AddPath("Browse")
			)
			:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end
