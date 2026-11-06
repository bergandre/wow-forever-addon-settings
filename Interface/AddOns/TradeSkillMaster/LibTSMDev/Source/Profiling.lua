-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

if not TSMDEV then ---@diagnostic disable-line: redundant-condition
	return
end
local ADDON_NAME = ...
local Profiling = {}
TSMDEV.Profiling = Profiling
local private = {
	mode = nil, ---@type ProfilingMode?
	startValue = nil,
	nodes = {},
	nodeRuns = {},
	nodeStart = {},
	nodeTotal = {},
	nodeMaxContext = {},
	nodeMaxValue = {},
	nodeParent = {},
	nodeStack = {},
}
local NODE_PATH_SEP = "`"

---@alias ProfilingMode "TIME"|"MEM"



-- ============================================================================
-- Module Functions
-- ============================================================================

---Starts profiling.
---@param mode ProfilingMode The mode of the profiling
function Profiling.Start(mode)
	assert(mode == "TIME" or mode == "MEM")
	assert(not private.mode, "Profiling already started")
	private.mode = mode
	private.startValue = private.GetCurrentValue()
end

---Starts profiling of a node.
---
---Profiling must have been started for this to have any effect.
---@param node string The name of the profiling node
function Profiling.StartNode(node)
	if not private.mode then
		-- Profiling is not running
		return
	end
	local nodeStackLen = #private.nodeStack
	local parentNode = nodeStackLen > 0 and table.concat(private.nodeStack, NODE_PATH_SEP) or nil
	private.nodeStack[nodeStackLen + 1] = node
	node = table.concat(private.nodeStack, NODE_PATH_SEP)
	if private.nodeStart[node] then
		error("Node already started", 2)
	end
	if not private.nodeTotal[node] then
		tinsert(private.nodes, node)
		private.nodeTotal[node] = 0
		private.nodeRuns[node] = 0
		private.nodeMaxContext[node] = nil
		private.nodeMaxValue[node] = 0
		private.nodeParent[node] = parentNode
	elseif private.nodeParent[node] ~= parentNode then
		error("Node changed parents", 2)
	end
	private.nodeStart[node] = private.GetCurrentValue()
end

---Ends profiling of a node.
---
---Profiling of this node must have been started for this to have any effect.
---@param node string The name of the profiling node
---@param arg? any Any extra argument which is printed if this invocation represents the max duration for the node
function Profiling.EndNode(node, arg)
	if not private.mode then
		-- Profiling is not running
		return
	end
	local endValue = private.GetCurrentValue()
	local nodeStackLen = #private.nodeStack
	if node ~= private.nodeStack[nodeStackLen] then
		error("Node isn't at the top of the stack", 2)
	end
	node = table.concat(private.nodeStack, NODE_PATH_SEP)
	if not private.nodeStart[node] then
		error("Node hasn't been started", 2)
	end
	private.nodeStack[nodeStackLen] = nil
	local nodeValue = endValue - private.nodeStart[node]
	private.nodeRuns[node] = private.nodeRuns[node] + 1
	private.nodeTotal[node] = private.nodeTotal[node] + nodeValue
	private.nodeStart[node] = nil
	if nodeValue > private.nodeMaxValue[node] then
		private.nodeMaxContext[node] = arg
		private.nodeMaxValue[node] = nodeValue
	end
end

---Ends profiling and prints the results to chat.
---@param minTotalValue? number The minimum total value in order to print the profiling info
function Profiling.End(minTotalValue)
	if not private.mode then
		-- Profiling is not running
		return
	end
	assert(#private.nodeStack == 0)
	local totalValue = private.GetCurrentValue() - private.startValue
	if totalValue > (minTotalValue or 0) then
		print(format("Total: %s", private.FormatValue(totalValue)))
		for _, node in ipairs(private.nodes) do
			local parentNode = private.nodeParent[node]
			local parentTotalValue = nil
			if parentNode then
				parentTotalValue = private.nodeTotal[parentNode]
			else
				parentTotalValue = totalValue
			end
			local nodeTotalValue = private.nodeTotal[node]
			local pctValue = nodeTotalValue * 100 / parentTotalValue
			local nodeRuns = private.nodeRuns[node]
			local nodeMaxContext = private.nodeMaxContext[node]
			local level = private.GetLevel(node)
			local name = strmatch(node, NODE_PATH_SEP.."?([^"..NODE_PATH_SEP.."]+)$")
			if nodeMaxContext ~= nil then
				local nodeMaxValue = private.nodeMaxValue[node]
				print(format("%s%s | %d%% | %s | %d | %s | %s", strrep("  ", level), name, pctValue, private.FormatValue(nodeTotalValue), nodeRuns, private.FormatValue(nodeMaxValue), tostring(nodeMaxContext)))
			else
				print(format("%s%s | %d%% | %s | %d", strrep("  ", level), name, pctValue, private.FormatValue(nodeTotalValue), nodeRuns))
			end
		end
	end
	private.Reset()
end

---Ends profiling without printing any results to chat and cleaning up any in-progress nodes.
function Profiling.Abort()
	wipe(private.nodeStack)
	private.Reset()
end

---Checks whether or not we're currently profiling.
---@return boolean
function Profiling.IsActive()
	return private.mode and true or false
end

---Gets the total memory used by TSM in bytes.
---@return number
function Profiling.GetMemoryUsage()
	collectgarbage("collect")
	collectgarbage("collect")
	UpdateAddOnMemoryUsage()
	return GetAddOnMemoryUsage(ADDON_NAME) * 1024
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetCurrentValue()
	if private.mode == "TIME" then
		return GetTimePreciseSec()
	elseif private.mode == "MEM" then
		return Profiling.GetMemoryUsage()
	else
		error("Profiling is not running")
	end
end

function private.GetLevel(node)
	local level = 0
	while node do
		level = level + 1
		node = private.nodeParent[node]
	end
	return level
end

function private.Reset()
	private.mode = nil
	private.startValue = nil
	wipe(private.nodes)
	wipe(private.nodeRuns)
	wipe(private.nodeStart)
	wipe(private.nodeTotal)
	wipe(private.nodeMaxContext)
	wipe(private.nodeMaxValue)
	wipe(private.nodeParent)
end

function private.FormatValue(value)
	if private.mode == "TIME" then
		return format("%.06f", value)
	elseif private.mode == "MEM" then
		return format("%.1fKB", value / 1024)
	else
		error("Profiling is not running")
	end
end
