--- automate - File watchers with trigger/action rules
--- Watch workspace files and execute actions on changes.

local log = require ("down.log")
local mod = require ("down.mod")

local Automate = mod.new ("automate")
Automate.dep = { "cmd", "workspace" }

Automate.config = {
  --- Whether to auto-start watching
  auto_start = true,
  --- Polling interval in ms (fallback if fs_event unavailable)
  interval = 5000,
  --- Use native filesystem watchers (vim.uv.fs_event) when available
  use_fs_events = true,
}

---@class down.mod.automate.Rule
---@field name string
---@field trigger string Event trigger: "create", "modify", "delete", "rename"
---@field pattern string File path glob pattern
---@field action string Action: "index", "compact", "tag", "notify", "run", "sync", "vector"
---@field command string Shell command to run (for "run" action)
---@field enabled boolean

Automate.rules = {}
Automate.timer = nil
Automate.watchers = {}

--- Add a rule
---@param rule down.mod.automate.Rule
function Automate.add (rule)
  rule.enabled = true
  Automate.rules[#Automate.rules + 1] = rule
end

--- Remove a rule by name
---@param name string
function Automate.remove (name)
  for i, r in ipairs (Automate.rules) do
    if r.name == name then
      table.remove (Automate.rules, i)
      return true
    end
  end
  return false
end

--- Execute an action
---@param rule down.mod.automate.Rule
---@param file string
local function execute (rule, file)
  if rule.action == "index" then
    local ok, knowledge = pcall (require, "down.mod.data.knowledge")
    if ok then
      knowledge.index_file (file)
      log.info ("Automate: indexed " .. file)
    end
  elseif rule.action == "tag" then
    local ok, tag_mod = pcall (require, "down.mod.tag")
    if ok and tag_mod.scan_file then
      tag_mod.scan_file (file)
    end
  elseif rule.action == "notify" then
    vim.notify (
      "Automate: " .. rule.name .. " triggered for " .. file,
      vim.log.levels.INFO
    )
  elseif rule.action == "run" and rule.command then
    vim.fn.system (rule.command:gsub ("{file}", file))
  elseif rule.action == "compact" then
    local cwd = vim.fn.getcwd ()
    local compact = require ("down.compact")
    local out = compact.pack (cwd)
    local f = io.open (cwd .. "/.down/auto-compact.xml", "w")
    if f then
      f:write (out)
      f:close ()
    end
  elseif rule.action == "sync" then
    local cwd = vim.fn.getcwd ()
    vim.fn.system (
      "cd " .. vim.fn.shellescape (cwd) .. " && down sync 2>/dev/null &"
    )
  elseif rule.action == "vector" then
    local cwd = vim.fn.getcwd ()
    vim.fn.system (
      "cd " .. vim.fn.shellescape (cwd) .. " && down sync vector 2>/dev/null &"
    )
  end
end

--- Match a file against a glob pattern
---@param file string
---@param pattern string
---@return boolean
local function match (file, pattern)
  local p = "^"
    .. pattern:gsub ("%.", "%%."):gsub ("%*", ".*"):gsub ("%?", ".")
    .. "$"
  return file:match (p) ~= nil
end

--- Scan for changes and fire rules
function Automate.scan ()
  local ws = Automate.dep["workspace"]
  if not ws then
    return
  end

  for name, path in pairs (ws.data.workspaces or {}) do
    if vim.fn.isdirectory (path) == 1 then
      -- Use vim.fn.glob to check for changed files
      local files = vim.fn.glob (path .. "/**/*.md", true, true)
      for _, file in ipairs (files) do
        local mtime = vim.fn.getftime (file)
        local key = "automate:" .. file
        local prev = Automate.dep["data"] and Automate.dep["data"].get (key)
          or 0

        if mtime > prev then
          -- Fire matching rules
          for _, rule in ipairs (Automate.rules) do
            if rule.enabled and match (file, rule.pattern) then
              if rule.trigger == "modify" or rule.trigger == "create" then
                execute (rule, file)
              end
            end
          end
          if Automate.dep["data"] then
            Automate.dep["data"].set (key, mtime)
          end
        end
      end
    end
  end
end

--- Start watching
function Automate.start ()
  if Automate.watchers and #Automate.watchers > 0 then
    return
  end

  local uv = vim.uv or vim.loop

  if Automate.config.use_fs_events and uv and uv.fs_event then
    Automate.watchers = {}

    local ws = Automate.dep["workspace"]
    if not ws or not ws.data or not ws.data.workspaces then
      Automate._start_polling ()
      return
    end

    for _, path in pairs (ws.data.workspaces) do
      if vim.fn.isdirectory (path) == 1 then
        local w = uv.new_fs_event ()
        if w then
          local ok, err = pcall (
            w.start,
            w,
            path,
            {},
            function (err, filename, events)
              if err then
                return
              end
              if not filename then
                return
              end
              local full = path .. "/" .. filename
              if not filename:match ("%.md$") then
                return
              end
              local evtype = "modify"
              if events and events.rename then
                evtype = "rename"
              elseif events and events.change then
                evtype = "modify"
              end
              vim.schedule (function ()
                for _, rule in ipairs (Automate.rules) do
                  if
                    rule.enabled
                    and match (filename, rule.pattern)
                    and (rule.trigger == evtype or rule.trigger == "modify")
                  then
                    execute (rule, full)
                  end
                end
              end)
            end
          )
          if ok then
            Automate.watchers[#Automate.watchers + 1] = w
            log.info ("Automate: watching " .. path .. " (fs_event)")
          end
        end
      end
    end

    if #Automate.watchers == 0 then
      Automate._start_polling ()
    else
      log.info ("Automate: started " .. #Automate.watchers .. " fs watchers")
    end
  else
    Automate._start_polling ()
  end
end

function Automate._start_polling ()
  if Automate.timer then
    return
  end
  Automate.timer = vim.fn.timer_start (Automate.config.interval, function ()
    pcall (Automate.scan)
  end, { ["repeat"] = -1 })
  log.info ("Automate: polling (interval: " .. Automate.config.interval .. "ms)")
end

--- Stop watching
function Automate.stop ()
  for _, w in ipairs (Automate.watchers) do
    pcall (w.stop, w)
  end
  Automate.watchers = {}
  if Automate.timer then
    vim.fn.timer_stop (Automate.timer)
    Automate.timer = nil
  end
  log.info ("Automate: stopped")
end

Automate.setup = function ()
  -- Default rules
  Automate.add ({
    name = "auto-index",
    trigger = "modify",
    pattern = "*.md",
    action = "index",
  })
  Automate.add ({
    name = "auto-compact",
    trigger = "modify",
    pattern = "*.md",
    action = "compact",
  })
  Automate.add ({
    name = "auto-vector",
    trigger = "modify",
    pattern = "*.md",
    action = "vector",
  })

  if Automate.config.auto_start then
    vim.schedule (Automate.start)
  end
  return { loaded = true }
end

Automate.commands = {
  automate = {
    enabled = true,
    args = 0,
    name = "automate",
    callback = function (_)
      vim.notify (
        "Automate: " .. #Automate.rules .. " rules active",
        vim.log.levels.INFO
      )
    end,
    commands = {
      start = {
        enabled = true,
        args = 0,
        name = "automate.start",
        callback = function ()
          Automate.start ()
        end,
      },
      stop = {
        enabled = true,
        args = 0,
        name = "automate.stop",
        callback = function ()
          Automate.stop ()
        end,
      },
      add = {
        enabled = true,
        args = 0,
        name = "automate.add",
        callback = function ()
          vim.ui.input ({ prompt = "Rule name: " }, function (name)
            if name then
              vim.ui.input ({ prompt = "Pattern (glob): " }, function (pat)
                if pat then
                  vim.ui.select (
                    { "modify", "create", "delete" },
                    { prompt = "Trigger:" },
                    function (trig)
                      if trig then
                        vim.ui.select ({
                          "index",
                          "tag",
                          "notify",
                          "compact",
                          "sync",
                          "vector",
                        }, { prompt = "Action:" }, function (
                          act
                        )
                          if act then
                            Automate.add ({
                              name = name,
                              trigger = trig,
                              pattern = pat,
                              action = act,
                            })
                            vim.notify (
                              "Rule added: " .. name,
                              vim.log.levels.INFO
                            )
                          end
                        end)
                      end
                    end
                  )
                end
              end)
            end
          end)
        end,
      },
      list = {
        enabled = true,
        args = 0,
        name = "automate.list",
        callback = function ()
          local lines = { "# Automation Rules", "" }
          for _, r in ipairs (Automate.rules) do
            local status = r.enabled and "[x]" or "[ ]"
            lines[#lines + 1] = "- "
              .. status
              .. " "
              .. r.name
              .. " | "
              .. r.trigger
              .. " | "
              .. r.pattern
              .. " -> "
              .. r.action
          end
          local buf = vim.api.nvim_create_buf (false, true)
          vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
          vim.cmd ("vsplit")
          vim.api.nvim_win_set_buf (0, buf)
        end,
      },
    },
  },
}

return Automate
