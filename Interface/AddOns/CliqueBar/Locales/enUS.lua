local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L
