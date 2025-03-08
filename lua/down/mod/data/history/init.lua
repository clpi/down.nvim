local clear = require("table.clear")
local mod = require("down.mod")
local new = require("table.new")
local tbl = require("table")

---@class down.mod.data.history.History: down.Mod
local History = mod.new("data.history")

---@class down.mod.data.history.Config: down.mod.Config
History.config = {
  silent = true,
  store = "data/stores",
  path = "",
}

---@class down.mod.data.history.Commands: { [string]: down.Command }
History.commands = {
  next = {
    args = 0,
    enabled = true,
    condition = "markdown",
    name = "data.history.forward",
    commands = {
      list = {
        enabled = true,
        args = 0,
        condition = "markdown",
        name = "data.history.forward.list",
      },
    },
  },
  back = {
    args = 0,
    condition = "markdown",
    enabled = true,
    name = "data.history.back",
    commands = {
      list = {
        args = 0,
        condition = "markdown",
        enabled = true,
        name = "data.history.back.list",
      },
    },
  },
}

--- @type integer[]
History.history = {
  ---@type integer[]
  hist = {},
  --- @type integer[]
  buf = {},
  ---@type string[]
  file = {},
}

History.history.buf = {}

--- Clear the stacks
History.clear = function()
  clear(History.history.hist)
  clear(History.history.file)
  clear(History.history.buf)
end

History.add = {}

History.add.file = function(buf)
  table.insert(History.history.file, buf or vim.api.nvim_get_current_buf())
end
History.add.current = function(buf)
  table.insert(History.history.buf, buf or vim.api.nvim_get_current_buf())
end

History.push = function(stack, buf)
  table.insert(
    stack or History.history.buf,
    1,
    buf or vim.api.nvim_get_current_buf()
  )
end

History.pop = function(stack, buf)
  table.remove(stack or History.history.buf, 1)
end

History.print = function(self)
  for i, v in ipairs(self) do
    print(i, v.path, v.buf)
  end
end

History.back = function()
  local bn = vim.api.nvim_get_current_buf()
  if bn > 1 and #History.history.buf > 0 then
    History.push(History.history.hist, bn)
    local prev = History.history.buf[1] or 0
    vim.api.nvim_command("buffer " .. prev)
    History.pop(History.history.buf)
    return true
  else
    if History.config.silent then
      vim.api.nvim_echo(
        { { "Can't go back again", "WarningHistorysg" } },
        true,
        {}
      )
    end
    return false
  end
end

History.forward = function()
  local cb = vim.api.nvim_get_current_buf()
  local hb = History.history.hist[1]
  if hb then
    History.push(History.history.buf, cb)
    vim.api.nvim_command("buffer " .. hb)
    History.pop(History.history.hist)
    return true
  else
    if not History.config.silent then
      vim.api.nvim_echo(
        { { "Can't go forward again", "WarningHistorysg" } },
        true,
        {}
      )
    end
    return false
  end
end

---@return down.mod.Setup
History.setup = function()
  ---@type down.mod.Setup
  return {
    dependencies = {
      "cmd",
    },
    loaded = true,
  }
end

History.commands = {
  prev = {
    args = 0,
    condition = "markdown",
    name = "data.history.back",
  },
  next = {
    args = 0,
    condition = "markdown",
    name = "data.history.forward",
  },
}

History.handle = {
  cmd = {
    ["data.history.back"] = function(e)
      local buffers = vim.api.nvim_list_buf()

      local to_delete = {}
      for buffer in vim.iter(buffers):rev() do
        if vim.fn.buflisted(buffer) == 1 then
          if not vim.endswith(vim.api.nvim_buf_get_name(buffer), ".md") then
            vim.api.nvim_win_set_buf(0, buffer)
            break
          else
            table.insert(to_delete, buffer)
          end
        end
      end

      for _, buffer in ipairs(to_delete) do
        vim.api.nvim_buf_delete(buffer, {})
      end
    end,
  },
}

return History
