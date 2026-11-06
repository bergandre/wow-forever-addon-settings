-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local Auctioning = LibTSMApp:Init("Auctioning")
local CancelScan = LibTSMApp:Include("Auctioning.CancelScan")
local Log = LibTSMApp:Include("Auctioning.Log")
local PostScan = LibTSMApp:Include("Auctioning.PostScan")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local EnumTypes = LibTSMApp:From("LibTSMTypes"):Include("EnumTypes")
local Group = LibTSMApp:From("LibTSMTypes"):Include("Group")
local AuctioningSavedSearches = LibTSMApp:From("LibTSMTypes"):Include("SavedSearches.AuctioningSavedSearches")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local Theme = LibTSMApp:From("LibTSMService"):Include("UI.Theme")
local UIUtils = LibTSMApp:From("LibTSMUI"):Include("Util.UIUtils")
local private = {
	filtersTemp = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AddonSettings.RegisterOnLoad(Auctioning, function(db)
	local settings = db:NewView("AuctioningSettings")
		:AddKey("global", "userData", "savedAuctioningSearches")
		:Commit()
	AuctioningSavedSearches.Configure(settings.savedAuctioningSearches, private.GetSavedSearchName)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Resets all scan and log state.
function Auctioning.Reset()
	Log.Truncate()
	PostScan.Reset()
	CancelScan.Reset()
end

---Create a log query.
---@return DatabaseQuery
function Auctioning.CreateLogQuery()
	return Log.CreateQuery()
end

---Creates a query for posting from the bags.
---@return DatabaseQuery
function Auctioning.CreatePostBagsQuery()
	return PostScan.CreateBagsQuery()
end

---Changes a post detail.
---@param field string The field to change
---@param value number The new value
function Auctioning.ChangePostDetail(field, value)
	return PostScan.ChangePostDetail(field, value)
end

---Gets the existing auctions for the item currently being posted, including the pending post.
---@param auctionScan AuctionScanManager The auction scan manager
---@param result ExistingAuctionsList.Entry[] The table to store the result in (sorted by unit price)
---@return number? minPrice
---@return number? normalPrice
---@return number? maxPrice
function Auctioning.GetCurrentPostAuctions(auctionScan, result)
	return PostScan.GetCurrentRowAuctions(auctionScan, result)
end

---Gets the item buyout the current post would have if it undercut an existing auction.
---@param unitPrice number The unit price of the auction to undercut
---@return number
function Auctioning.GetUndercutPostPrice(unitPrice)
	return PostScan.GetUndercutPrice(unitPrice)
end

---Prepares a scan and returns the thread ID and publishers.
---@param scanType EnumValue The scan type
---@return string threadId
---@return ReactivePublisherSchema currentRowPublisher
---@return ReactivePublisherSchema statusPublisher
---@return ReactivePublisherSchema? postSkipPublisher
function Auctioning.PrepareScan(scanType)
	if scanType == EnumTypes.AUCTIONING_SCAN_TYPE.POST then
		local threadId = PostScan.GetThreadId()
		local currentRowPublisher = PostScan.CurrentRowPublisher()
		local statusPublisher = PostScan.StatusQueryPublisher()
		local postSkipPublisher = PostScan.NumPostSkipPublisher()
		return threadId, currentRowPublisher, statusPublisher, postSkipPublisher
	elseif scanType == EnumTypes.AUCTIONING_SCAN_TYPE.CANCEL then
		local threadId = CancelScan.GetThreadId()
		local currentRowPublisher = CancelScan.CurrentRowPublisher()
		local statusPublisher = CancelScan.StatusQueryPublisher()
		return threadId, currentRowPublisher, statusPublisher, nil
	else
		error("Invalid scan type: "..tostring(scanType))
	end
end

---Processes the current row of an ongoing scan.
---@param scanType EnumValue The scan type
---@return Future? future
---@return boolean canRetry
function Auctioning.DoProcess(scanType)
	if scanType == EnumTypes.AUCTIONING_SCAN_TYPE.POST then
		return PostScan.DoProcess()
	elseif scanType == EnumTypes.AUCTIONING_SCAN_TYPE.CANCEL then
		return CancelScan.DoProcess()
	else
		error("Invalid scan type: "..tostring(scanType))
	end
end

---Skips the current row of an ongoing scan.
---@param scanType EnumValue The scan type
function Auctioning.DoSkip(scanType)
	if scanType == EnumTypes.AUCTIONING_SCAN_TYPE.POST then
		PostScan.DoSkip()
	elseif scanType == EnumTypes.AUCTIONING_SCAN_TYPE.CANCEL then
		CancelScan.DoSkip()
	else
		error("Invalid scan type: "..tostring(scanType))
	end
end

---Handles confirmation of the previous process and returns if the scan is done or not.
---@param scanType EnumValue The scan type
---@param success boolean Whether the previous process was successful
---@param canRetry boolean Whether or not the process can be retried if it failed
---@return boolean
function Auctioning.HandleConfirm(scanType, success, canRetry)
	local isDone, numFailed = nil, nil
	if scanType == EnumTypes.AUCTIONING_SCAN_TYPE.POST then
		PostScan.HandleConfirm(success, canRetry)
		isDone, numFailed = PostScan.GetQueueStatus()
	elseif scanType == EnumTypes.AUCTIONING_SCAN_TYPE.CANCEL then
		CancelScan.HandleConfirm(success, canRetry)
		isDone, numFailed = CancelScan.GetQueueStatus()
	else
		error("Invalid scan type: "..tostring(scanType))
	end

	if not isDone then
		-- Still have more to process
		return false
	elseif numFailed == 0 then
		-- Done with no failures
		return true
	end

	-- Retry the failures
	ChatMessage.PrintfUser(L["Retrying %d auction(s) which failed."], numFailed)
	if scanType == EnumTypes.AUCTIONING_SCAN_TYPE.POST then
		PostScan.PrepareFailedPosts()
	elseif scanType == EnumTypes.AUCTIONING_SCAN_TYPE.CANCEL then
		CancelScan.PrepareFailedCancels()
	else
		error("Invalid scan type: "..tostring(scanType))
	end
	return false
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetSavedSearchName(filter, searchType)
	local filterSep = AuctioningSavedSearches.GetFilterSeparator()
	assert(not next(private.filtersTemp))
	local searchTypeStr, numFiltersStr = nil, nil
	if filter == "" or strsub(filter, 1, 1) == filterSep then
		tinsert(private.filtersTemp, L["Base Group"])
	end
	if searchType == AuctioningSavedSearches.SEARCH_TYPE.POST_GROUPS or searchType == AuctioningSavedSearches.SEARCH_TYPE.CANCEL_GROUPS then
		for groupPath in gmatch(filter, "[^"..filterSep.."]+") do
			local groupName = Group.GetName(groupPath)
			tinsert(private.filtersTemp, Theme.GetGroupColor(Group.GetLevel(groupPath)):ColorText(groupName))
		end
		searchTypeStr = searchType == AuctioningSavedSearches.SEARCH_TYPE.POST_GROUPS and L["Post Scan"] or L["Cancel Scan"]
		numFiltersStr = #private.filtersTemp == 1 and L["1 Group"] or format(L["%d Groups"], #private.filtersTemp)
	elseif searchType == AuctioningSavedSearches.SEARCH_TYPE.POST_ITEMS then
		local numItems = 0
		for itemString in gmatch(filter, "[^"..filterSep.."]+") do
			numItems = numItems + 1
			local coloredName = UIUtils.GetDisplayItemName(itemString)
			if coloredName then
				tinsert(private.filtersTemp, coloredName)
			end
		end
		searchTypeStr = L["Post Scan"]
		numFiltersStr = numItems == 1 and L["1 Item"] or format(L["%d Items"], numItems)
	else
		error("Unknown searchType: "..tostring(searchType))
	end
	local groupList = nil
	if #private.filtersTemp > 10 then
		groupList = table.concat(private.filtersTemp, ", ", 1, 10)..",..."
	else
		groupList = table.concat(private.filtersTemp, ", ")
	end
	wipe(private.filtersTemp)
	return format("%s (%s): %s", searchTypeStr, numFiltersStr, groupList)
end
