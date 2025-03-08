#!/usr/bin/env luajit

local hasminidoc, minidoc = pcall(require, "mini.doc")
local hasvim, vim = pcall(require, "vim")

local mods = {
  "cmd",
  "export",
  "mod",
  "data",
  "ui",
  -- "ui.calendar",
  -- "ui.win",
  -- "ui.popup",
  "workspace",
  "note",
  "log",
  "link",
  -- "edit.indent",
  -- "edit.cursor",
  "code",
  "template",
  "time",
  "tag",
  -- "find.telescope",
  -- "find.builtin",
  -- "find.snacks",
  -- "find.fzf",
  -- "edit.parse",
  -- "data.history",
  -- "data.bookmark",
  "edit",
  "find",
  "lsp",
}

--- Remove the first 2 lines from the generated documentation
---@param l tablelib<integer, string>
local function write_pre(l)
  l:remove(1)
  l:remove(1)
  return l
end

--- Split a string at `sep` and return the fields
---@param str string
---@param sep? string
---@return tablelib<integer, string>
local function split(str, sep)
  local f = {}
  local p = ("([^%s]+)"):format(sep or ".")
  str:gsub(p, function(c)
    f[#f + 1] = c
  end)
  return f
end

local function main()
  vim.notify("Generating documentation", "info", { title = "Down.nvim" })
  vim.notify(vim.fn.getcwd(), "info", { title = "Down.nvim" })
  if not hasminidoc or not hasvim then
    return
  end
  local hooks = vim.deepcopy(minidoc.hooks)
  hooks.write_pre = write_pre
  local doc = minidoc.generate({
    "lua/down.lua",
    "lua/down/config.lua",
    "lua/down/util.lua",
    "lua/down/util/log.lua",
    "lua/down/mod.lua",
    "lua/down/event/init.lua",
    "lua/down/mod/ui/init.lua",
    "lua/down/mod/mod/init.lua",
    "lua/down/mod/cmd/init.lua",
    "lua/down/mod/workspace/init.lua",
    "lua/down/mod/note/init.lua",
    "lua/down/mod/find/init.lua",
    "lua/down/mod/link/init.lua",
    "lua/down/mod/ui/icon/init.lua",
  }, "doc/down.nvim.txt", { hooks = hooks, title = "down.nvim" })
  -- for _, m in ipairs(mods) do
  --   local h = {}
  --   for _, ms in split(m) do
  --     table.insert(h, #h + 1, ms)
  --   end
  --   --   table.concat(h, )
  --   --
  --
  --   -- end
  --   minidoc.generate(
  --     { "lua/down/mod/" .. m .. "/init.lua" },
  --     "dow/down." .. m .. ".txt",
  --     { hooks = hooks }
  --   )
  -- end
end

main()
