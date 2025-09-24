---@enum down.task.Status
local Status = {
  "done",
  "in_progress",
  "cancelled",
  "postponed",
  "todo",
}

local Task = {
  ---@type down.Task.Status
  status = "todo",
  due = nil,
}

function Task:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Task:toggle()
  local cur = vim.api.nvim_win_get_cursor(0)
  local ln = vim.fn.getline(cur[1])
  vim.api.nvim_win_set_cursor(0, cur)
end

return Task
