local log = require("down.util.log")
local mod = require("down.mod")
local ins = table.insert

---@class down.mod.Modod: down.Modod
local Mod = mod.new("mod")

Mod.style = {
  table = function(s)
    return "|" .. s .. "|"
  end,
  i = function(s)
    return "__" .. s .. "__"
  end,
  b = function(s)
    return "**" .. s .. "**"
  end,
  code = function(s)
    return "`" .. s .. "`"
  end,
}

Mod.print = {
  toc = function(tb)
    ins(tb, "## Table of Contents")
    for name, _ in pairs(mod.mods) do
      ins(tb, "- [" .. name .. "](#" .. name .. ")")
    end
  end,
  children = function(m) end,
  dependants = function() end,
  deps = function(m, tb, pre)
    pre = pre or ""
    if m.dependencies and not vim.tbl_isempty(m.dependencies) then
      ins(tb, "")
      ins(tb, "#### **Dependencies**")
      for i, d in ipairs(m.dependencies) do
        local ix = Mod.print.index(i, pre)
        ins(tb, ix .. "" .. "[" .. d .. "](#" .. d .. ")")
      end
    end
  end,
  setup = function(m, tb, pre)
    pre = pre or ""
    local s = m.setup()
    if s.loaded then
      ins(tb, Mod.print.index(nil, pre, "Loaded", tostring(s.loaded)))
    end
    if s.dependencies then
      Mod.print.deps(m.setup(), tb, pre)
    end
  end,
  index = function(i, pre, title, value)
    pre = pre or ""
    title = tostring(title or "")
    value = tostring(value or "")
    if title ~= "" then
      title = "**" .. title .. "**: "
    end
    if value ~= "" then
      value = "`" .. value .. "`"
    end
    local ix
    if i then
      ix = i .. ". "
    else
      ix = "- "
    end
    return pre .. ix .. title .. value
  end,
  methods = function(tb, m, name)
    ins(tb, "")
    ins(tb, "#### **Modethods**")
    ins(tb, "~~~lua")
    local i = 0
    for k, v in pairs(m) do
      i = i + 1
      if type(v) == "function" then
        local ix = Mod.print.index(nil, "\t")
        ins(tb, "function " .. name .. "." .. k .. "()")
      end
    end
    ins(tb, "~~~")
  end,
  command = function(tb, pre, cmd, v, i)
    local index = Mod.print.index(i, pre)
    local enabled = ""
    if v.enabled ~= nil then
      enabled = "**enabled**: " .. "`" .. tostring(v.enabled) .. "`"
    end
    ins(
      tb,
      index .. " __" .. cmd .. "__ `" .. (v.name or "") .. "`" .. " " .. enabled
    )
    Mod.print.commands(v, tb, cmd, pre .. "\t", i)
  end,
  commands = function(m, tb, name, pre, i)
    pre = pre or ""
    ix = Mod.print.index(nil, pre)
    if m.commands then
      if vim.tbl_isempty(m.commands) then
        return
      end
      if pre == "" then
        ins(tb, "")
        ins(tb, "#### **Commands**")
      end
      local i = 0
      for k, v in pairs(m.commands) do
        i = i + 1
        if pre == "" then
        else
        end
        local ix = Mod.print.index(i, pre)
        Mod.print.command(tb, pre, k, v, i)
      end
    end
  end,
  mod = function(m, tb, i, name)
    Mod.print.index(i)
    ins(tb, "### " .. "" .. " **" .. name .. "**")
    ins(tb, "")
    -- ins(tb, .. '`' .. (name or m.name or '') .. '`')
    -- Mod.print.commands(m, tb, m.name, '', i)
    Mod.print.toc(tb)
    Mod.print.setup(m, tb, m.name)
    Mod.print.commands(m, tb, m.name, "")
    Mod.print.methods(tb, m, name)
  end,
  title = function(lines)
    ins(lines, "# down.nvim")
    ins(lines, "")
  end,
  mods = function(tb)
    local lines = tb or {}
    Mod.print.title(lines)
    ins(lines, "## Modods")
    ins(lines, "")
    local i = 0
    for name, m in pairs(mod.mods) do
      local s = string.split(name, ".")
      -- if type(s[1]) == 'string' and type(s[2]) == 'string' then
      --   i = 0
      --   local sub = lines[s[1]] or {}
      --   sub[s[2]] = m
      --   Mod.print.mod(m, sub, i, name)
      --   name = s2
      -- else
      i = i + 1
      Mod.print.mod(m, lines, i, name)
      table.insert(lines, "---")
      -- end
    end
    return lines
  end,
}

Mod.commands = {
  mod = {
    enabled = true,
    name = "mod",
    args = 1,
    callback = function(e)
      log.trace("Modod.commands.mod: Callback")
    end,
    commands = {
      new = {
        args = 1,
        name = "mod.new",
        enabled = false,
        callback = function()
          log.trace("Modod.commands.new: Callback")
        end,
      },
      load = {
        name = "mod.load",
        args = 1,
        enabled = false,
        callback = function(e)
          local ok = pcall(mod.load_mod, e.body[1])
          if not ok then
            vim.notify(
              ("mod `%s` does not exist!"):format(e.body[1]),
              vim.log.levels.ERROR,
              {}
            )
          end
        end,
      },
      unload = {
        name = "mod.unload",
        args = 1,
        callback = function(e)
          log.trace("Modod.commands.unload: Callback")
        end,
      },
      list = {
        args = 0,
        name = "mod.list",
        callback = function(e)
          local mods_popup = require("nui.popup")({
            position = "50%",
            size = { width = "50%", height = "80%" },
            enter = true,
            buf_options = {
              filetype = "markdown",
              modifiable = true,
              readonly = false,
            },
            win_options = {
              conceallevel = 3,
              concealcursor = "nvic",
            },
          })
          mods_popup:on("VimResized", function()
            mods_popup:update_layout()
          end)

          local function close()
            mods_popup:unmount()
          end

          mods_popup:map("n", "<Esc>", close, {})
          mods_popup:map("n", "q", close, {})
          local lines = Mod.print.mods()
          vim.api.nvim_buf_set_lines(mods_popup.bufnr, 0, -1, true, lines)
          vim.bo[mods_popup.bufnr].modifiable = false
          mods_popup:mount()
        end,
      },
    },
  },
}
Mod.maps = {
  { "n", ",dml", "<CModD>Down mod list<CR>",   "List mods" },
  { "n", ",dmL", "<CModD>Down mod load<CR>",   "Load mod" },
  { "n", ",dmu", "<CModD>Down mod unload<CR>", "Unload mod" },
}
Mod.setup = function()
  return { loaded = true, dependencies = { "cmd" } }
end

return Mod
