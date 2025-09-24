local log = require("down.log")
local mod = require("down.mod")
local ins = table.insert
local nui = require("nui.popup")

---@class down.mod.mod.Mod: down.Mod
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
  --- Print a table of contents
  --- @param tb string[]
  toc = function(tb)
    table.insert(tb, "## Table of Contents")
    for name, _ in pairs(mod.mods) do
      table.insert(tb, "- [" .. name .. "](#" .. name .. ")")
    end
  end,
  --- Print a mod's children
  --- @param m down.Mod.Mod|string
  children = function(m) end,
  --- Print a mod's dependants
  --- @param m down.Mod.Mod|string
  dependants = function(m) end,
  --- Print a mod's dependencies
  --- @param m down.Mod|string
  --- @param tb string[]
  --- @param pre string
  deps = function(m, tb, pre)
    pre = pre or ""
    if m.dependencies and not vim.tbl_isempty(m.dependencies) then
      table.insert(tb, "")
      table.insert(tb, "#### **Dependencies**")
      for i, d in ipairs(m.dependencies) do
        local ix = Mod.print.index(i, pre)
        table.insert(tb, ix .. "" .. "[" .. d .. "](#" .. d .. ")")
      end
    end
  end,
  --- Print a mod's setup
  --- @param m down.Mod.Mod|string
  --- @param tb string[]
  --- @param pre string
  setup = function(m, tb, pre)
    pre = pre or ""
    local s = m.setup()
    if s.loaded then
      table.insert(tb, Mod.print.index(nil, pre, "Loaded", tostring(s.loaded)))
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
  --- Print a mod's methods
  --- @param tb string[]
  --- @param m down.Mod
  --- @param name string
  methods = function(tb, m, name)
    table.insert(tb, "")
    table.insert(tb, "#### **Mod methods**")
    table.insert(tb, "~~~lua")
    local i = 0
    for k, v in pairs(m) do
      i = i + 1
      if type(v) == "function" then
        local ix = Mod.print.index(nil, "\t")
        table.insert(tb, "function " .. name .. "." .. k .. "()")
      end
    end
    table.insert(tb, "~~~")
  end,
  --- Print a mod's command
  --- @param tb string[]
  --- @param pre string
  --- @param cmd string
  --- @param v down.Command
  --- @param i number
  command = function(tb, pre, cmd, v, i)
    local index = Mod.print.index(i, pre)
    local enabled = ""
    if v.enabled ~= nil then
      enabled = "**enabled**: " .. "`" .. tostring(v.enabled) .. "`"
    end
    table.insert(
      tb,
      index .. " __" .. cmd .. "__ `" .. (v.name or "") .. "`" .. " " .. enabled
    )
    Mod.print.commands(v, tb, cmd, pre .. "\t", i)
  end,
  --- Print a mod's commands
  --- @param m down.Mod.Mod|down.Command
  --- @param tb string[]
  --- @param name string
  --- @param pre string
  --- @param i number
  commands = function(m, tb, name, pre, i)
    vim.print(m, tb, name, pre)
    pre = pre or ""
    local ix = Mod.print.index(nil, pre)
    if m.commands then
      if vim.tbl_isempty(m.commands) then
        return
      end
      if pre == "" then
        table.insert(tb, "")
        table.insert(tb, "#### **Commands**")
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
  --- Print a mod
  --- @param m down.Mod.Mod
  --- @param tb string[]
  --- @param i number
  --- @param name string
  mod = function(m, tb, i, name)
    i = i or 1
    name = name or m.id
    Mod.print.index(i)
    tb = tb or {}
    ins(tb, "### " .. "" .. " **" .. name .. "**")
    ins(tb, "")
    -- ins(tb, .. '`' .. (name or m.name or '') .. '`')
    -- Mod.print.commands(m, tb, m.name, '', i)
    Mod.print.setup(m, tb, m.id)
    Mod.print.commands(m, tb, m.id, "", i + 1)
    Mod.print.methods(tb, m, m.id)
    return tb
  end,
  --- Print title
  --- @param lines string[]
  title = function(lines)
    table.insert(lines, "# down.nvim")
    table.insert(lines, "")
  end,
  --- Print mods
  --- @param tb? string[]
  mods = function(tb)
    local lines = tb or {}
    Mod.print.title(lines)
    table.insert(lines, "## Mods")
    table.insert(lines, "")
    Mod.print.toc(lines)
    local i = 0
    for n, m in pairs(mod.mods) do
      local s = string.split(n, ".")
      -- if type(s[1]) == 'string' and type(s[2]) == 'string' then
      --   i = 0
      --   local sub = lines[s[1]] or {}
      --   sub[s[2]] = m
      --   Mod.print.mod(m, sub, i, name)
      --   name = s2
      -- else
      i = i + 1
      Mod.print.mod(m, lines, i, n)
      table.insert(lines, "- - -")
      -- end
    end
    return lines
  end,
}

---@param e down.Event
Mod.list = function(e)
  ---@type down.Mod.Mod
  local spec = nil
  if
    e.body ~= nil
    and e.body[1] ~= nil
    and mod.mods[e.body[1]] ~= nil
  then
    spec = mod.mods[e.body[1]]
    Mod.popup.init(Mod.popup.create(), Mod.print.mod(spec, {}, 1, e.body[1]))
  else
  end
  if spec == nil then
    Mod.popup.init(Mod.popup.create(), Mod.print.mods())
  else
  end
end

--- Load a mod
--- @param e down.Event
Mod.load_mod = function(e)
  if e.body and e.body[1] and mod.util.check_id(e.body[1]) then
    local ok, loadedmod = pcall(mod.load_mod, e.body[1])
    if not ok then
      return vim.notify(
        ("mod `%s` does not exist!"):format(e.body[1]),
        vim.log.levels.ERROR,
        {}
      )
    end
    vim.notify("Loaded mod " .. e.body[1] .. vim.inspect(loadedmod))
  end
end

Mod.popup = {
  ---@paam  mp NuiPopup
  maps = function(mp)
    return {
      ["<esc>"] = function()
        mp:unmount()
      end,
      ["<cr>"] = function()
        require("down.mod.link").follow.link()
      end,
      ["<tab>"] = function()
        require("down.mod.link").goto.next()
      end,
      ["<s-tab>"] = function()
        require("down.mod.link").goto.prev()
      end,
      ["H"] = function()
        mp:hide()
      end,
      ["S"] = function()
        mp:show()
      end,
      ["<bs>"] = function()
        mp:hide()
      end,
      ["q"] = function()
        mp:unmount()
      end,
    }
  end,
  autocmds = function(mp)
    return {
      ["VimResized"] = function()
        mp:update_layout()
      end,
      ["BufEnter"] = function()
        mp:update_layout()
      end,
    }
  end,
  ---@param mp NuiPopup
  bo = function(mp)
    vim.bo[mp.bufnr].modifiable = false
    vim.bo[mp.bufnr].readonly = true
    vim.bo[mp.bufnr].filetype = "markdown"
    -- vim.wo.concealcursor = ""
    -- vim.wo.conceallevel = 3
  end,
  ---@param mp? NuiPopup
  ---@param ln? string[]
  init = function(mp, ln)
    mp = mp or Mod.popup.create()
    vim.iter(Mod.popup.autocmds(mp)):each(function(ev, ac)
      mp:on(ev, ac)
    end)
    vim.iter(Mod.popup.maps(mp)):each(function(km, mf)
      mp:map("n", km, mf)
    end)
    vim.api.nvim_buf_set_lines(mp.bufnr, 0, -1, true, ln or Mod.print.mods())
    Mod.popup.bo(mp)
    mp:mount()
  end,
  create = function(o)
    return nui(o or Mod.popup.opts)
  end,
  ---@param ln? string[]
  new = function(ln)
    Mod.popup.init(Mod.popup.create(), ln)
  end,
  ---@type nui_popup_options
  opts = {
    position = "50%",
    size = { width = "70%", height = "80%" },
    enter = true,
    border = "rounded",
    relative = "editor",
    focusable = true,
    zindex = 100,
    ns_id = "down.mod.mod",
    buf_options = {
      filetype = "markdown",
      modifiable = true,
      readonly = false,
    },
    win_options = {
      conceallevel = 3,
      concealcursor = "nvic",
    },
  },
}

--- Reload a mod
--- @param e down.Event
Mod.reload = function(e)
  if e and e.body and e.body[1] then
    log.trace("Mod.commands.reload: Reloading " .. e.body[1])
    mod.reload(e.body[1])
    vim.notify("Reloaded " .. e.body[1])
  else
    log.trace("Mod.commands.reload: Reloading all")
    for k, _ in pairs(mod.mods) do
      mod.reload(k)
    end
    vim.notify("Reloaded all mods")
  end
end

--- Load a mod
--- @param e down.Event
Mod.load_mod_cb = function(e)
  if e and e.body and e.body[1] then
    log.trace("Mod.commands.load: Loading " .. vim.inspect(e.body[1]))
    local m = Mod.load_mod(e.body[1])
    if m then
      vim.notify("Loaded " .. e.body[1])
    else
      vim.notify("Failed to load " .. e.body[1])
    end
  else
    vim.notify("No mod specified")
    log.trace("Mod.commands.load: No mod specified")
  end
end

--- Unload a mod
--- @param e down.Event
Mod.unload = function(e)
  if e and e.body and e.body[1] then
    mod.unload(e.body[1])
    vim.notify("Unloaded " .. e.body[1])
    -- vim.notify_once(vim.inspect(mod.mods[e.body[1]]))
    mod.sync_unloaded()
    log.trace("Mod.commands.unload: Unloaded " .. e.body[1])
  else
    log.trace("Mod.commands.unload: No mod specified")
  end
end

--- @type table<string, down.Command>
Mod.commands = {
  mod = {
    enabled = true,
    name = "mod",
    args = 1,
    complete = {
      vim.tbl_keys(mod.mods),
    },
    --   mod.sync_unloaded()
    --   return vim.tbl_keys(mod.mods)
    -- end,
    callback = function(e)
      Mod.load_mod(e)
    end,
    commands = {
      new = {
        args = 1,
        name = "mod.new",
        enabled = false,
        complete = {},
        callback = function()
          log.trace("Mod.commands.new: Callback")
        end,
      },
      reload = {
        name = "mod.reload",
        args = 1,
        enabled = true,
        complete = { vim.tbl_keys(mod.mods) },
        callback = function(e)
          Mod.reload(e)
        end,
      },
      load = {
        name = "mod.load",
        args = 1,
        enabled = true,
        complete = { mod.unloaded },
        callback = function(e)
          Mod.load_mod(e)
        end,
        --   mod.sync_unloaded()
        --   return vim.tbl_keys(mod.unloaded)
        -- end,
      },
      unload = {
        name = "mod.unload",
        args = 1,
        min_args = 1,
        max_args = 1,
        enabled = true,
        callback = function(e)
          Mod.unload(e)
        end,
        complete = { vim.tbl_keys(mod.mods) },
      },
      list = {
        args = 0,
        min_args = 0,
        max_args = 1,
        name = "mod.list",
        complete = { vim.tbl_keys(mod.mods) },
        callback = function(e)
          Mod.list(e)
        end,
      },
    },
  },
}
Mod.maps = {
  { "n", ",dml", "<CModD>Down mod list<CR>", "List mods" },
  { "n", ",dmL", "<CModD>Down mod load<CR>", "Load mod" },
  { "n", ",dmu", "<CModD>Down mod unload<CR>", "Unload mod" },
}
Mod.setup = function()
  return {
    loaded = true,
    dependencies = { "cmd", "link" },
  }
end

return Mod
