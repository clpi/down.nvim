local log = require ("down.log")
local mod = require ("down.mod")
local util = require ("down.util")
local api, bo, fn = vim.api, vim.bo, vim.fn

---@class down.mod.cmd.Cmd: down.Mod
local Cmd = mod.new ("cmd")

Cmd.setup = function ()
  vim.api.nvim_create_user_command ("Down", Cmd.cb, {
    desc = "The down command",
    range = 2,
    force = true,
    nargs = "*",
    complete = Cmd.generate_completions,
  })

  -- Helper: resolve the down CLI binary path
  local function down_bin ()
    local paths = {
      vim.fn.stdpath ("data") .. "/down/bin/down",
      "down", -- system PATH
    }
    for _, p in ipairs (paths) do
      if vim.fn.executable (p) == 1 then return p end
    end
    return nil
  end

  -- Helper: run down CLI and return stdout
  local function down_run (args)
    local bin = down_bin ()
    if not bin then return nil, "no cli binary" end
    local cmd = { bin, table.unpack (args) }
    local result = vim.fn.system (cmd)
    if vim.v.shell_error ~= 0 then return nil, result end
    return result:gsub ("%s+$", ""), nil
  end

  -- Register compact and skills commands
  Cmd.commands.compact = {
    enabled = true,
    args = 0,
    min_args = 0,
    max_args = 1,
    name = "compact",
    complete = function () return {} end,
    callback = function (e)
      local root = e.body and e.body[1] or vim.fn.getcwd ()
      local compact = require ("down.compact")
      local result = compact.pack (root)
      vim.cmd ("new")
      vim.api.nvim_buf_set_lines (0, 0, -1, false, vim.split (result, "\n"))
      vim.bo.filetype = "xml"
      vim.bo.buflisted = false
      vim.bo.bufhidden = "wipe"
    end,
  }
  Cmd.commands.skills = {
    enabled = true,
    args = 0,
    min_args = 0,
    max_args = 1,
    name = "skills",
    complete = function () return {} end,
    callback = function (e)
      local root = e.body and e.body[1] or vim.fn.getcwd ()
      local skills = require ("down.skills")
      skills.config.output = nil
      local result = skills.generate (root)
      vim.cmd ("new")
      vim.api.nvim_buf_set_lines (0, 0, -1, false, vim.split (result, "\n"))
      vim.bo.filetype = "markdown"
      vim.bo.buflisted = false
      vim.bo.bufhidden = "wipe"
    end,
  }

  -- Register init command
  Cmd.commands.init = {
    enabled = true,
    args = 0,
    min_args = 0,
    max_args = 1,
    name = "init",
    complete = function () return {} end,
    callback = function (e)
      local root = e.body and e.body[1] or vim.fn.getcwd ()
      local init = require ("down.init")
      local ok, name = init.setup (root)
      if ok then
        vim.notify ("Initialized workspace '" .. name .. "' at " .. root, vim.log.levels.INFO)
      else
        vim.notify ("Init failed: " .. (name or "unknown"), vim.log.levels.ERROR)
      end
    end,
  }

  -- Register add command
  Cmd.commands.add = {
    enabled = true,
    args = 1,
    min_args = 1,
    max_args = 1,
    name = "add",
    complete = function ()
      local buf = vim.api.nvim_get_current_buf ()
      local file = vim.api.nvim_buf_get_name (buf)
      if file ~= "" then return { file } end
      return {}
    end,
    callback = function (e)
      local source = e.body and e.body[1]
      do_add = function (src)
        local out, err = down_run ({ "add", src })
        if out then
          vim.notify (out, vim.log.levels.INFO)
        else
          -- Fall back to Lua implementation
          local add = require ("down.add")
          local path, lua_err = add.ingest (src)
          if path then
            vim.notify ("Added: " .. path, vim.log.levels.INFO)
          else
            vim.notify ("Error: " .. (lua_err or err or "unknown"), vim.log.levels.ERROR)
          end
        end
      end
      if not source then
        vim.ui.input ({ prompt = "Add source (file/dir/URL/name): " }, function (input)
          if input and input ~= "" then do_add (input) end
        end)
        return
      end
      do_add (source)
    end,
  }

  -- Register ignore command (append to .downignore)
  Cmd.commands.ignore = {
    enabled = true,
    args = 1,
    min_args = 1,
    max_args = 1,
    name = "ignore",
    complete = function () return {} end,
    callback = function (e)
      local pattern = e.body and e.body[1]
      if not pattern then
        vim.ui.input ({ prompt = "Pattern to ignore: " }, function (input)
          if input and input ~= "" then
            local cwd = vim.fn.getcwd ()
            local ignore_path = cwd .. "/.down/.downignore"
            local f = io.open (ignore_path, "a")
            if f then
              f:write (input .. "\n")
              f:close ()
              vim.notify ("Added to .downignore: " .. input, vim.log.levels.INFO)
            else
              vim.notify ("No .down/ directory found. Run :Down init first.", vim.log.levels.WARN)
            end
          end
        end)
        return
      end
      local cwd = vim.fn.getcwd ()
      local ignore_path = cwd .. "/.down/.downignore"
      local f = io.open (ignore_path, "a")
      if f then
        f:write (pattern .. "\n")
        f:close ()
        vim.notify ("Added to .downignore: " .. pattern, vim.log.levels.INFO)
      else
        vim.notify ("No .down/ directory found. Run :Down init first.", vim.log.levels.WARN)
      end
    end,
  }

  -- Register profile command
  Cmd.commands.profile = {
    enabled = true,
    args = 0,
    name = "profile",
    callback = function (e)
      local body = e.body or {}
      local sub = body[1]
      local mod = require ("down.mod")

      -- Load profile data from global config
      local config_home = os.getenv ("XDG_CONFIG_HOME") or (os.getenv ("HOME") or "~") .. "/.config"
      local profile_path = config_home .. "/down/down.json"
      local function load_profiles ()
        local f = io.open (profile_path, "r")
        if not f then return { profiles = { default = { workspaces = {} } }, active_profile = "default" } end
        local raw = f:read ("*a")
        f:close ()
        if not raw or raw == "" then return { profiles = { default = { workspaces = {} } }, active_profile = "default" } end
        local ok, data = pcall (vim.json.decode, raw)
        if ok and type (data) == "table" then
          if not data.profiles then data.profiles = { default = { workspaces = data.workspaces or {} } } end
          if not data.active_profile then data.active_profile = "default" end
          return data
        end
        return { profiles = { default = { workspaces = {} } }, active_profile = "default" }
      end
      local function save_profiles (data)
        vim.fn.mkdir (config_home .. "/down", "p")
        local f = io.open (profile_path, "w")
        if f then f:write (vim.json.encode (data)) f:close () end
      end

      if sub == "list" or sub == "ls" or not sub then
        local data = load_profiles ()
        local items = {}
        for n, p in pairs (data.profiles or {}) do
          local marker = (data.active_profile == n) and " *" or "  "
          local count = 0
          for _ in pairs (p.workspaces or {}) do count = count + 1 end
          items[#items + 1] = marker .. n .. " (" .. count .. " workspaces)"
        end
        if #items == 0 then
          vim.notify ("No profiles configured", vim.log.levels.INFO)
        else
          vim.ui.select (items, { prompt = "Profiles:" }, function (choice)
            if choice then
              local name = choice:match ("%s+(%S+)%s") or choice:match ("(%S+)")
              local data = load_profiles ()
              data.active_profile = name
              save_profiles (data)
              -- Update workspace data
              local ws = mod.get_mod ("workspace")
              if ws and data.profiles[name] then
                for wname, wpath in pairs (data.profiles[name].workspaces or {}) do
                  ws.data.workspaces[wname] = wpath
                end
                if data.profiles[name].default then
                  ws.data.default = data.profiles[name].default
                  ws.data.active = data.profiles[name].default
                end
                ws.sync ()
              end
              vim.notify ("Switched to profile: " .. name, vim.log.levels.INFO)
            end
          end)
        end
      elseif sub == "switch" or sub == "use" then
        local name = body[2]
        local data = load_profiles ()
        local function do_switch (profile_name)
          if not data.profiles[profile_name] then
            vim.notify ("Profile not found: " .. profile_name, vim.log.levels.ERROR)
            return
          end
          data.active_profile = profile_name
          save_profiles (data)
          -- Update workspace data from profile
          local ws = mod.get_mod ("workspace")
          if ws and data.profiles[profile_name] then
            local pw = data.profiles[profile_name]
            for wname, wpath in pairs (pw.workspaces or {}) do
              ws.data.workspaces[wname] = wpath
            end
            if pw.default then
              ws.data.default = pw.default
              ws.data.active = pw.default
            end
            ws.sync ()
          end
          vim.notify ("Switched to profile: " .. profile_name, vim.log.levels.INFO)
        end
        if not name then
          local items = {}
          for n in pairs (data.profiles or {}) do
            items[#items + 1] = n
          end
          vim.ui.select (items, { prompt = "Switch to profile:" }, function (choice)
            if choice then do_switch (choice) end
          end)
        else
          do_switch (name)
        end
      end
    end,
    commands = {
      add = {
        enabled = true, args = 0, name = "profile.add",
        callback = function ()
          vim.ui.input ({ prompt = "New profile name: " }, function (name)
            if name and name ~= "" then
              local config_home = os.getenv ("XDG_CONFIG_HOME") or (os.getenv ("HOME") or "~") .. "/.config"
              local profile_path = config_home .. "/down/down.json"
              local f = io.open (profile_path, "r")
              local data = { profiles = { default = { workspaces = {} } }, active_profile = "default" }
              if f then
                local raw = f:read ("*a")
                f:close ()
                if raw and raw ~= "" then
                  local ok, parsed = pcall (vim.json.decode, raw)
                  if ok and type (parsed) == "table" then data = parsed end
                end
              end
              if not data.profiles then data.profiles = { default = { workspaces = {} } } end
              data.profiles[name] = { workspaces = {} }
              vim.fn.mkdir (config_home .. "/down", "p")
              local wf = io.open (profile_path, "w")
              if wf then wf:write (vim.json.encode (data)) wf:close () end
              vim.notify ("Added profile: " .. name, vim.log.levels.INFO)
            end
          end)
        end,
      },
      remove = {
        enabled = true, args = 0, name = "profile.remove",
        callback = function ()
          local config_home = os.getenv ("XDG_CONFIG_HOME") or (os.getenv ("HOME") or "~") .. "/.config"
          local profile_path = config_home .. "/down/down.json"
          local f = io.open (profile_path, "r")
          if not f then vim.notify ("No profiles found", vim.log.levels.WARN) return end
          local raw = f:read ("*a")
          f:close ()
          local ok, data = pcall (vim.json.decode, raw)
          if not ok then return end
          if not data.profiles then data.profiles = { default = { workspaces = {} } } end
          local items = {}
          for n in pairs (data.profiles) do
            if n ~= "default" then items[#items + 1] = n end
          end
          if #items == 0 then
            vim.notify ("No removable profiles", vim.log.levels.INFO)
            return
          end
          vim.ui.select (items, { prompt = "Remove profile:" }, function (choice)
            if choice then
              data.profiles[choice] = nil
              if data.active_profile == choice then data.active_profile = "default" end
              vim.fn.mkdir (config_home .. "/down", "p")
              local wf = io.open (profile_path, "w")
              if wf then wf:write (vim.json.encode (data)) wf:close () end
              vim.notify ("Removed profile: " .. choice, vim.log.levels.INFO)
            end
          end)
        end,
      },
      list = {
        enabled = true, args = 0, name = "profile.list",
        callback = function ()
          local config_home = os.getenv ("XDG_CONFIG_HOME") or (os.getenv ("HOME") or "~") .. "/.config"
          local profile_path = config_home .. "/down/down.json"
          local f = io.open (profile_path, "r")
          local data = { profiles = { default = { workspaces = {} } }, active_profile = "default" }
          if f then
            local raw = f:read ("*a")
            f:close ()
            if raw and raw ~= "" then
              local ok, parsed = pcall (vim.json.decode, raw)
              if ok and type (parsed) == "table" then data = parsed end
            end
          end
          local items = {}
          for n, p in pairs (data.profiles or {}) do
            local marker = (data.active_profile == n) and " *" or "  "
            local count = 0
            for _ in pairs (p.workspaces or {}) do count = count + 1 end
            items[#items + 1] = marker .. n .. " (" .. count .. " workspaces)"
          end
          vim.ui.select (items, { prompt = "Profiles:" }, function (_) end)
        end,
      },
      switch = {
        enabled = true, args = 0, name = "profile.switch",
        callback = function ()
          local config_home = os.getenv ("XDG_CONFIG_HOME") or (os.getenv ("HOME") or "~") .. "/.config"
          local profile_path = config_home .. "/down/down.json"
          local f = io.open (profile_path, "r")
          local data = { profiles = { default = { workspaces = {} } }, active_profile = "default" }
          if f then
            local raw = f:read ("*a")
            f:close ()
            if raw and raw ~= "" then
              local ok, parsed = pcall (vim.json.decode, raw)
              if ok and type (parsed) == "table" then data = parsed end
            end
          end
          local items = {}
          for n in pairs (data.profiles or {}) do
            items[#items + 1] = n
          end
          vim.ui.select (items, { prompt = "Switch to profile:" }, function (choice)
            if choice then
              data.active_profile = choice
              vim.fn.mkdir (config_home .. "/down", "p")
              local wf = io.open (profile_path, "w")
              if wf then wf:write (vim.json.encode (data)) wf:close () end
              -- Update workspace data
              local ws = require ("down.mod").get_mod ("workspace")
              if ws and data.profiles[choice] then
                for wname, wpath in pairs (data.profiles[choice].workspaces or {}) do
                  ws.data.workspaces[wname] = wpath
                end
                if data.profiles[choice].default then
                  ws.data.default = data.profiles[choice].default
                  ws.data.active = data.profiles[choice].default
                end
                ws.sync ()
              end
              vim.notify ("Switched to profile: " .. choice, vim.log.levels.INFO)
            end
          end)
        end,
      },
    },
  }

  -- Register memory command
  Cmd.commands.memory = {
    enabled = true,
    args = 0,
    name = "memory",
    callback = function (e)
      local body = e.body or {}
      local sub = body[1]
      local data_home = os.getenv ("XDG_DATA_HOME") or (os.getenv ("HOME") .. "/.local/share")
      local mem_dir = data_home .. "/down/memory"

      if sub == "add" or sub == "set" then
        local key = body[2]
        local value = body[3]
        if not key then
          vim.ui.input ({ prompt = "Memory key: " }, function (k)
            if k and k ~= "" then
              vim.ui.input ({ prompt = "Value: " }, function (v)
                if v then
                  os.execute ('mkdir -p "' .. mem_dir .. '"')
                  local f = io.open (mem_dir .. "/" .. k .. ".json", "w")
                  if f then
                    f:write (vim.json.encode ({ key = k, value = v, created = os.date ("%Y-%m-%d %H:%M") }))
                    f:close ()
                    vim.notify ("Memory saved: " .. k, vim.log.levels.INFO)
                  end
                end
              end)
            end
          end)
          return
        end
        os.execute ('mkdir -p "' .. mem_dir .. '"')
        local f = io.open (mem_dir .. "/" .. key .. ".json", "w")
        if f then
          f:write (vim.json.encode ({ key = key, value = value, created = os.date ("%Y-%m-%d %H:%M") }))
          f:close ()
          vim.notify ("Memory saved: " .. key, vim.log.levels.INFO)
        end
      elseif sub == "list" or sub == "ls" or not sub then
        local entries = vim.fn.glob (mem_dir .. "/*.json", true, true)
        if #entries == 0 then
          vim.notify ("No memory entries", vim.log.levels.INFO)
        else
          local buf = vim.api.nvim_create_buf (false, true)
          vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
          vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
          local lines = { "# Memory", "" }
          for _, path in ipairs (entries) do
            local f = io.open (path, "r")
            if f then
              local raw = f:read ("*a")
              f:close ()
              local ok, data = pcall (vim.json.decode, raw)
              if ok and data then
                lines[#lines + 1] = "## " .. (data.key or "?")
                lines[#lines + 1] = ""
                for _, l in ipairs (vim.split (data.value or "", "\n")) do
                  lines[#lines + 1] = l
                end
                lines[#lines + 1] = "---"
                lines[#lines + 1] = ""
              end
            end
          end
          vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
          vim.cmd ("vsplit")
          vim.api.nvim_win_set_buf (0, buf)
        end
      elseif sub == "show" then
        local key = body[2]
        if not key then
          vim.ui.input ({ prompt = "Show memory key: " }, function (k)
            if k then _show_memory_entry (mem_dir, k) end
          end)
        else
          _show_memory_entry (mem_dir, key)
        end
      elseif sub == "search" then
        local query = body[2]
        if not query then
          vim.ui.input ({ prompt = "Search memory: " }, function (q)
            if q then _search_memory (mem_dir, q) end
          end)
        else
          _search_memory (mem_dir, query)
        end
      elseif sub == "delete" or sub == "rm" then
        local key = body[2]
        if not key then
          vim.ui.input ({ prompt = "Delete memory key: " }, function (k)
            if k then os.remove (mem_dir .. "/" .. k .. ".json") vim.notify ("Deleted: " .. k, vim.log.levels.INFO) end
          end)
        else
          os.remove (mem_dir .. "/" .. key .. ".json")
          vim.notify ("Deleted: " .. key, vim.log.levels.INFO)
        end
      end
    end,
  }

  -- Register context command
  Cmd.commands.context = {
    enabled = true,
    args = 0,
    min_args = 0,
    max_args = 1,
    name = "context",
    callback = function (e)
      local root = e.body and e.body[1] or vim.fn.getcwd ()
      local name = vim.fn.fnamemodify (root, ":t")
      local out = { "# " .. name .. " — AI Context", "", "> Generated: " .. os.date "%Y-%m-%d %H:%M:%S", "" }

      -- Try Go CLI context first
      local ctx_out, _ = down_run ({ "context", root, "-o", root .. "/.down/context.md" })

      -- Embed compact output if Go binary available
      local compact_str = nil
      down_run ({ "compact", root, "-o", root .. "/.down/compact.xml" })

      -- Detect languages
      local langs = {}
      pcall (function ()
        for ext, lang in pairs ({ lua = "Lua", go = "Go", js = "JavaScript", py = "Python", rs = "Rust", md = "Markdown", json = "JSON", toml = "TOML", yml = "YAML" }) do
          local count = tonumber (vim.fn.system ("find " .. root .. " -name '*." .. ext .. "' -not -path '*/.git/*' 2>/dev/null | wc -l")) or 0
          if count > 0 then langs[lang] = true end
        end
      end)
      local lang_list = {}
      for l in pairs (langs) do lang_list[#lang_list + 1] = l end
      table.sort (lang_list)
      if #lang_list > 0 then
        out[#out + 1] = "**Languages:** " .. table.concat (lang_list, ", ")
        out[#out + 1] = ""
      end
      out[#out + 1] = "## Structure"
      out[#out + 1] = "```"
      pcall (function ()
        for _, l in ipairs (vim.split (vim.fn.system ("ls -R " .. root .. " 2>/dev/null | head -80"), "\n")) do
          out[#out + 1] = l
        end
      end)
      out[#out + 1] = "```"
      out[#out + 1] = ""
      out[#out + 1] = "## Task"
      out[#out + 1] = ""
      out[#out + 1] = "<!-- Describe what you want the AI to do -->"

      -- Write context
      os.execute ('mkdir -p "' .. root .. '/.down"')
      local out_path = root .. "/.down/context.md"
      local f = io.open (out_path, "w")
      if f then f:write (table.concat (out, "\n")) f:close () end

      -- Open in buffer
      vim.cmd (ctx_out and "vsplit " .. out_path or "vsplit")
      if ctx_out then vim.cmd ("edit " .. out_path) end
      vim.notify ("Context written to " .. out_path, vim.log.levels.INFO)
    end,
  }

  return { loaded = true }
end

-- Memory helpers
local function _show_memory_entry (mem_dir, key)
  local f = io.open (mem_dir .. "/" .. key .. ".json", "r")
  if not f then vim.notify ("Not found: " .. key, vim.log.levels.ERROR) return end
  local raw = f:read ("*a")
  f:close ()
  local ok, data = pcall (vim.json.decode, raw)
  if ok then
    local buf = vim.api.nvim_create_buf (false, true)
    vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
    local lines = { "# " .. (data.key or key), "", data.value or "", "" }
    vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
    vim.cmd ("vsplit")
    vim.api.nvim_win_set_buf (0, buf)
  end
end

local function _search_memory (mem_dir, query)
  local entries = vim.fn.glob (mem_dir .. "/*.json", true, true)
  local results = {}
  for _, path in ipairs (entries) do
    local f = io.open (path, "r")
    if f then
      local raw = f:read ("*a")
      f:close ()
      if raw:lower ():find (query:lower (), 1, true) then
        local ok, data = pcall (vim.json.decode, raw)
        if ok then results[#results + 1] = data end
      end
    end
  end
  if #results == 0 then
    vim.notify ("No memory matches for: " .. query, vim.log.levels.WARN)
    return
  end
  local buf = vim.api.nvim_create_buf (false, true)
  vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
  local lines = { "# Memory search: " .. query, "" }
  for _, r in ipairs (results) do
    lines[#lines + 1] = "## " .. (r.key or "?")
    lines[#lines + 1] = ""
    for _, l in ipairs (vim.split (r.value or "", "\n")) do
      lines[#lines + 1] = l
    end
    lines[#lines + 1] = "---"
    lines[#lines + 1] = ""
  end
  vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
  vim.cmd ("vsplit")
  vim.api.nvim_win_set_buf (0, buf)
end

Cmd.get_commands = function (m)
  local c = {}
  if m.commands then
    if type (c) == "table" then
      for cmd, cc in pairs (m.commands) do
        if type (cc) == "table" then
          if c.enabled ~= false then
            c[cmd] = cc
          end
        end
      end
    end
  end
  return c
end

Cmd.commands = {
  cmd = {
    enabled = false,
    name = "cmd",
    args = 0,
    max_args = 1,
    callback = function (e)
      log.trace ("Cmd callback")
    end,
    commands = {
      add = {
        enabled = true,
        name = "cmd.add",
        args = 0,
        max_args = 1,
        callback = function (e)
          log.trace ("Cmd add callback")
        end,
      },
      edit = {
        name = "cmd.edit",
        args = 0,
        max_args = 1,
        callback = function (e)
          log.trace ("Cmd edit callback")
        end,
      },
      remove = {
        name = "cmd.remove",
        args = 0,
        max_args = 1,
        callback = function (e)
          log.trace ("Cmd remove callback")
        end,
      },
      update = {
        name = "cmd.update",
        args = 0,
        max_args = 1,
        callback = function (e)
          log.trace ("Cmd update callback")
        end,
      },
    },
  },
}
Cmd.cb = function (data)
  local args = data.fargs
  local buf = api.nvim_get_current_buf ()
  local is_down = bo[buf].filetype == "markdown"

  local ref = { commands = Cmd.commands }
  local argument_index = 0

  for i, cmd in ipairs (args) do
    if not ref.commands or vim.tbl_isempty (ref.commands) then
      break
    end
    ref = ref.commands[cmd]
    if not ref then
      log.error (
        ("Error when executing `:Down %s` - such a command does not exist!"):format (
          table.concat (vim.list_slice (args, 1, i), " ")
        )
      )
      return
    elseif not Cmd.cond (ref.condition) then
      log.error (
        ("Error when executing `:Down %s` - the command is currently disabled. Some commands will only become available under certain conditions, e.g. being within a `.down` file!"):format (
          table.concat (vim.list_slice (args, 1, i), " ")
        )
      )
      return
    end

    argument_index = i
  end

  local argument_count = (#args - argument_index)

  if ref.args then
    ref.min_args = ref.args
    ref.max_args = ref.args
  elseif ref.min_args and not ref.max_args then
    ref.max_args = math.huge
  else
    ref.min_args = ref.min_args or 0
    ref.max_args = ref.max_args or 0
  end

  if #args == 0 or argument_count < ref.min_args then
    local completions = Cmd.generate_completions (
      _,
      table.concat ({ "Down ", data.args, " " })
    ) or {}
    Cmd.select_next_cmd_arg (data.args, completions)
    return
  elseif argument_count > ref.max_args then
    log.error (
      ("Error when executing `:down %s` - too many arguments supplied! The command expects %s argument%s."):format (
        data.args,
        ref.max_args == 0 and "no" or ref.max_args,
        ref.max_args == 1 and "" or "s"
      )
    )
    return
  end

  if not ref.name then
    log.error (
      ("Error when executing `:down %s` - the ending command didn't have a `name` variable associated with it! This is an implementation error on the developer's side, so file a report to the author of the mod."):format (
        data.args
      )
    )
    return
  end
  if not Cmd.events[ref.name] then
    Cmd.events[ref.name] = mod.define_event (Cmd, ref.name)
    if ref.callback then
      if not Cmd.handle then
        Cmd.handle = {}
      end
      if not Cmd.handle["cmd"] then
        Cmd.handle["cmd"] = {}
      end
      Cmd.handle["cmd"][ref.name] = ref.callback
    end
  end

  local e = mod.new_event (
    Cmd,
    table.concat ({ "cmd.events.", ref.name }),
    vim.list_slice (args, argument_index + 1)
  )
  if ref.callback then
    log.trace ("Cmd.cb: Running ", ref.name, " callback")
    ref.callback (e)
  else
    log.trace ("Cmd.cb: Running ", ref.name, " broadcast")
    -- Cmd.handle['cmd'][ref.name]
    mod.broadcast (e)
  end
end
--
-- --- Handles the calling of the appropriate function based on the command the user entered
-- Cmd.cb = function(data)
--   local args = data.fargs
--   local buf = vim.api.nvim_get_current_buf()
--   local is_down = vim.bo[buf].filetype == "markdown"
--
--   local ref = { commands = Cmd.commands }
--   local argument_index = 0
--
--   for i, cmd in ipairs(args) do
--     if not ref.commands or vim.tbl_isempty(ref.commands) then
--       break
--     end
--     if
--       ref.commands[cmd]
--       and ref.commands[cmd].enabled ~= nil
--       and ref.commands[cmd].enabled == false
--     then
--       break
--     end
--     ref = ref.commands[cmd]
--     if not ref then
--       log.error(
--         ("Error when executing `:Down %s` - such a command does not exist!"):format(
--           table.concat(vim.list_slice(args, 1, i), " ")
--         )
--       )
--       return
--     elseif not Cmd.cond(ref.condition, buf, is_down) then
--       log.error(
--         ("Error when executing `:Down %s` - the command is currently disabled. Some commands will only become available under certain conditions, e.g. being within a `.down` file!"):format(
--           table.concat(vim.list_slice(args, 1, i), " ")
--         )
--       )
--       return
--     end
--
--     argument_index = i
--   end
--
--   local argument_count = (#args - argument_index)
--
--   if ref.args then
--     ref.min_args = ref.args
--     ref.max_args = ref.args
--   elseif ref.min_args and not ref.max_args then
--     ref.max_args = math.huge
--   else
--     ref.min_args = ref.min_args or 0
--     ref.max_args = ref.max_args or 0
--   end
--
--   if #args == 0 or argument_count < ref.min_args then
--     local completions =
--       Cmd.generate_completions(_, table.concat({ "Down ", data.args, " " }))
--     Cmd.select_next_cmd_arg(data.args, completions)
--     return
--   elseif argument_count > ref.max_args then
--     log.error(
--       ("Error when executing `:down %s` - too many arguments supplied! The command expects %s argument%s."):format(
--         data.args,
--         ref.max_args == 0 and "no" or ref.max_args,
--         ref.max_args == 1 and "" or "s"
--       )
--     )
--     return
--   end
--
--   if not ref.name then
--     log.error(
--       ("Error when executing `:down %s` - the ending command didn't have a `name` variable associated with it! This is an implementation error on the developer's side, so file a report to the author of the mod."):format(
--         data.args
--       )
--     )
--     return
--   end
--   if not Cmd.events[ref.name] then
--     Cmd.events[ref.name] = mod.define_event(Cmd, ref.name)
--     if ref.callback then
--       if not Cmd.handle then
--         Cmd.handle = {}
--       end
--       if not Cmd.handle["cmd"] then
--         Cmd.handle["cmd"] = {}
--       end
--       Cmd.handle["cmd"][ref.name] = ref.callback
--     end
--   end
--
--   local e = mod.new_event(
--     Cmd,
--     table.concat({ "cmd.events.", ref.name }),
--     vim.list_slice(args, argument_index + 1)
--   )
--   if ref.callback then
--     log.trace("Cmd.cb: Running ", ref.name, " callback")
--     ref.callback(e)
--   else
--     log.trace("Cmd.cb: Running ", ref.name, " broadcast")
--     mod.broadcast(e)
--   end
-- end
--
Cmd.cond = function (condition, buf, is_down)
  buf = buf or vim.api.nvim_get_current_buf ()
  is_down = is_down or vim.bo[buf].filetype == "markdown"
  if condition == nil then
    return true
  end
  if condition == "markdown" and not is_down then
    return false
  end
  if type (condition) == "function" then
    return condition (buf, is_down)
  end
  return condition
end

--- This function returns all available commands to be used for the :down command
---@param _ nil #Placeholder variable
---@param command string #Supplied by nvim itself; the full typed out command
Cmd.generate_completions = function (_, command)
  local current_buf = vim.api.nvim_get_current_buf ()
  local is_down = vim.bo[current_buf].filetype == "markdown"

  command = command:gsub ("^%s*", "")

  local splitcmd = vim.list_slice (
    vim.split (command, " ", {
      plain = true,
      trimempty = true,
    }),
    2
  )

  local ref = {
    commands = Cmd.commands,
  }
  local last_valid_ref = ref
  local last_completion_level = 0

  for _, cmd in ipairs (splitcmd) do
    -- if ref.enabled ~= nil and ref.enabled == false then return end
    if not ref or not Cmd.cond (ref.condition, current_buf, is_down) then
      break
    end

    ref = ref.commands or {}
    ref = ref[cmd]

    if ref then
      if ref.enabled ~= nil and ref.enabled == false then
        break
      end
      last_valid_ref = ref
      last_completion_level = last_completion_level + 1
    end
  end

  if last_valid_ref.enabled ~= nil and last_valid_ref.enabled == false then
    return
  end
  if not last_valid_ref.commands and last_valid_ref.complete then
    if type (last_valid_ref.complete) == "function" then
      last_valid_ref.complete = last_valid_ref.complete (current_buf, is_down)
    end

    if vim.endswith (command, " ") then
      local completions = last_valid_ref.complete[#splitcmd - last_completion_level + 1]
        or {}

      if type (completions) == "function" then
        completions = completions (current_buf, is_down) or {}
      end

      return completions
    else
      local completions = last_valid_ref.complete[#splitcmd - last_completion_level]
        or {}

      if type (completions) == "function" then
        completions = completions (current_buf, is_down) or {}
      end

      return vim.tbl_filter (function (key)
        return key:find (splitcmd[#splitcmd])
      end, completions)
    end
  end

  -- TODO: Fix `:down m <tab>` giving invalid completions
  local keys = ref and vim.tbl_keys (ref.commands or {})
    or (
      vim.tbl_filter (function (key)
        return key:find (splitcmd[#splitcmd])
      end, vim.tbl_keys (last_valid_ref.commands or {}))
    )
  table.sort (keys)
  do
    local commands = (ref and ref.commands or last_valid_ref.commands) or {}

    return vim.tbl_filter (function (key)
      if type (commands[key]) == "table" then
        return Cmd.cond (commands[key].condition, current_buf, is_down)
      end
    end, keys)
  end
end

--- Queries the user to select next argument
---@param qargs table #A string of arguments previously supplied to the down command
---@param choices table #all possible choices for the next argument
Cmd.select_next_cmd_arg = function (qargs, choices)
  local current = table.concat ({ "Down ", qargs })

  local query

  if vim.tbl_isempty (choices) then
    query = function (...)
      vim.ui.input (...)
    end
  else
    query = function (...)
      vim.ui.select (choices, ...)
    end
  end

  query ({
    prompt = current,
  }, function (choice)
    if choice ~= nil then
      vim.cmd (("%s %s"):format (current, choice))
    end
  end)
end

-- The table containing all the functions. This can get a tad complex so I recommend you read the wiki entry

---@param mod_name string #An absolute path to a loaded init with a mod.config.commands table following a valid structure
Cmd.add_commands = function (mod_name)
  local mod_config = mod.get_mod (mod_name)

  if
    not mod_config
    or not mod_config.commands
    or (
      mod_config.commands.enabled ~= nil
      and mod_config.commands.enabled == false
    )
  then
    return
  end

  Cmd.commands = vim.tbl_extend ("force", Cmd.commands, mod_config.commands)
end

Cmd.enabled = function (c)
  return vim.iter (c):filter (function (v)
    return v.enabled == nil or (v.enabled ~= nil and v.enabled == true)
  end)
end

--- Recursively merges the provided table with the mod.config.commands table.
---@param f down.Command[] #A table that follows the mod.config.commands structure
Cmd.add_commands_from_table = function (f)
  vim.tbl_extend ("force", Cmd.commands, f)
end

--- Rereads data from all mod and rebuild the list of available autocompletiinitinitons and commands
Cmd.sync = function ()
  for mn, lm in pairs (mod.mods) do
    for cn, c in pairs (lm.commands or {}) do
      if type (c) == "table" then
        Cmd.commands[cn] = vim.tbl_extend ("force", Cmd.commands[cn] or {}, c)
      end
    end
  end
end

--- Defines a custom completion function to use for `base.cmd`.
---@param callback function
Cmd.set_completion = function (callback)
  Cmd.generate_completions = callback
end

---@class down.mod.cmd.Config
Cmd.config = {}
---@class cmd

Cmd.after = function ()
  Cmd.sync ()
end

return Cmd
