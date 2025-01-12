local mod = require('down.mod')

---@type down.Mod
local M = mod.new('tool.blink')

local has_blink, blink = pcall(require, 'blink.cmp')

---@class down.tool.blink.Config
M.config = {}
---@class down.tool.blink.Data
M.source = require('down.mod.tool.blink.source')
M.format = require('down.mod.tool.blink.format')

return M
