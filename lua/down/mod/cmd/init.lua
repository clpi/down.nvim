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

  -- LuaJIT has `unpack` (global); Lua 5.2+ has `table.unpack`.
  local unpack = table.unpack or unpack
  -- Helper: resolve the down CLI binary path
  local function down_bin ()
    local paths = {}
    for _, p in
      ipairs (vim.api.nvim_get_runtime_file ("scripts/bin/down", true))
    do
      paths[#paths + 1] = p
    end
    for _, p in
      ipairs (vim.api.nvim_get_runtime_file ("ext/down/bin/down", true))
    do
      paths[#paths + 1] = p
    end
    for _, p in ipairs (vim.api.nvim_get_runtime_file ("ext/down/down", true)) do
      paths[#paths + 1] = p
    end
    paths[#paths + 1] = vim.fn.stdpath ("data") .. "/down/bin/down"
    paths[#paths + 1] = "down" -- system PATH
    for _, p in ipairs (paths) do
      if vim.fn.executable (p) == 1 then
        return p
      end
    end
    return nil
  end

  -- Helper: run down CLI and return stdout
  local function down_run (args)
    local bin = down_bin ()
    if not bin then
      return nil, "no cli binary"
    end
    local cmd = { bin, unpack (args) }
    local result = vim.fn.system (cmd)
    if vim.v.shell_error ~= 0 then
      return nil, result
    end
    return result:gsub ("%s+$", ""), nil
  end

  -- Helper: run down CLI, show stdout in a scratch buffer (ft optional)
  local function down_show (args, ft)
    local out, err = down_run (args)
    if err then
      vim.notify (
        "[down] " .. args[1] .. " failed: " .. tostring (err),
        vim.log.levels.ERROR
      )
      return nil
    end
    if not out or out == "" then
      vim.notify (
        "[down] " .. args[1] .. " produced no output",
        vim.log.levels.INFO
      )
      return ""
    end
    local buf = vim.api.nvim_create_buf (false, true)
    vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_lines (buf, 0, -1, false, vim.split (out, "\n"))
    vim.cmd ("vsplit")
    vim.api.nvim_win_set_buf (0, buf)
    if ft then
      vim.bo[buf].filetype = ft
    end
    return out
  end

  -- Register compact and skills commands
  Cmd.commands.compact = {
    enabled = true,
    args = 0,
    min_args = 0,
    max_args = math.huge,
    name = "compact",
    complete = function ()
      return {
        "xml",
        "markdown",
        "json",
        "plain",
        "tree",
        "-f",
        "-o",
        "--no-tree",
        "--no-stats",
        "--no-tokens",
        "-i",
        "-x",
        "-s",
        "--max-size",
        "--ignore-file",
      }
    end,
    callback = function (e)
      local args = e.body or {}
      local root = "."
      local fmt = "xml"
      local extra = {}
      local i = 1
      -- First non-flag positional may be a directory or a format name
      while i <= #args do
        local a = args[i]
        if a:match ("^-%") or a:match ("^--") then
          table.insert (extra, a)
        elseif
          vim.tbl_contains (
            { "xml", "markdown", "md", "json", "plain", "text", "tree" },
            a
          )
        then
          fmt = a
        elseif vim.fn.isdirectory (a) == 1 or vim.fn.filereadable (a) == 1 then
          root = a
        else
          table.insert (extra, a)
        end
        i = i + 1
      end
      -- Prefer the Go CLI for full repomix parity (all formats + flags);
      -- fall back to the Lua down.compact module when the binary is absent.
      if down_bin () then
        local argv = { "compact", root, "-f", fmt }
        for _, a in ipairs (extra) do
          table.insert (argv, a)
        end
        local ft = (fmt == "json") and "json"
          or (fmt == "markdown" or fmt == "md") and "markdown"
          or (fmt == "xml") and "xml"
          or nil
        down_show (argv, ft)
        return
      end
      local compact = require ("down.compact")
      local result = compact.pack (root, { format = fmt })
      vim.cmd ("new")
      vim.api.nvim_buf_set_lines (0, 0, -1, false, vim.split (result, "\n"))
      vim.bo.filetype = (fmt == "json") and "json"
        or (fmt == "markdown" or fmt == "md") and "markdown"
        or "xml"
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
    complete = function ()
      return {}
    end,
    callback = function (e)
      local root = e.body and e.body[1] or vim.fn.getcwd ()

      -- Try Go CLI sync skills first (rich data: knowledge + vector + memory + data)
      local bin = down_bin ()
      if bin then
        local result = vim.fn.system ({ bin, "sync", "skills" })
        if vim.v.shell_error == 0 and result ~= "" then
          vim.cmd ("new")
          vim.api.nvim_buf_set_lines (0, 0, -1, false, vim.split (result, "\n"))
          vim.bo.filetype = "markdown"
          vim.bo.buflisted = false
          vim.bo.bufhidden = "wipe"
          return
        end
      end

      -- Fallback to Lua skills (filesystem only)
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
    complete = function ()
      return {}
    end,
    callback = function (e)
      local root = e.body and e.body[1] or vim.fn.getcwd ()
      local init = require ("down.init")
      local ok, name = init.setup (root)
      if ok then
        vim.notify (
          "Initialized workspace '" .. name .. "' at " .. root,
          vim.log.levels.INFO
        )
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
      if file ~= "" then
        return { file }
      end
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
            vim.notify (
              "Error: " .. (lua_err or err or "unknown"),
              vim.log.levels.ERROR
            )
          end
        end
      end
      if not source then
        vim.ui.input (
          { prompt = "Add source (file/dir/URL/name): " },
          function (input)
            if input and input ~= "" then
              do_add (input)
            end
          end
        )
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
    complete = function ()
      return {}
    end,
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
              vim.notify (
                "No .down/ directory found. Run :Down init first.",
                vim.log.levels.WARN
              )
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
        vim.notify (
          "No .down/ directory found. Run :Down init first.",
          vim.log.levels.WARN
        )
      end
    end,
  }

  -- Register profile command (workspaces + profiles tracked in
  -- ~/.config/down/down.json via down.global)
  local Global = require ("down.global")
  local function apply_profile (profile_name)
    local ws = mod.get_mod ("workspace")
    if not ws then
      return
    end
    local pw = Global.profile_workspaces (profile_name)
    for wname, wpath in pairs (pw) do
      ws.data.workspaces[wname] = wpath
    end
    local data = Global.load ()
    local p = data.profiles[profile_name]
    if p and p.default then
      ws.data.default = p.default
      ws.data.active = p.default
    end
    ws.sync ()
  end
  local function switch_profile (profile_name)
    local data = Global.load ()
    if not data.profiles[profile_name] then
      vim.notify ("Profile not found: " .. profile_name, vim.log.levels.ERROR)
      return
    end
    Global.set_active_profile (profile_name)
    apply_profile (profile_name)
    vim.notify ("Switched to profile: " .. profile_name, vim.log.levels.INFO)
  end
  local function profile_items ()
    local data = Global.load ()
    local items = {}
    for _, n in ipairs (Global.profile_names ()) do
      local p = data.profiles[n]
      local marker = (data.active_profile == n) and " *" or "  "
      local count = 0
      for _ in pairs (p.workspaces or {}) do
        count = count + 1
      end
      items[#items + 1] = marker .. n .. " (" .. count .. " workspaces)"
    end
    return items
  end
  Cmd.commands.profile = {
    enabled = true,
    args = 0,
    name = "profile",
    callback = function (e)
      local body = e.body or {}
      local sub = body[1]
      if sub == "switch" or sub == "use" then
        local name = body[2]
        if not name then
          vim.ui.select (
            Global.profile_names (),
            { prompt = "Switch to profile:" },
            function (choice)
              if choice then
                switch_profile (choice)
              end
            end
          )
        else
          switch_profile (name)
        end
      else
        -- list / ls / no sub: pick to switch
        local items = profile_items ()
        if #items == 0 then
          vim.notify ("No profiles configured", vim.log.levels.INFO)
        else
          vim.ui.select (items, { prompt = "Profiles:" }, function (choice)
            if choice then
              local name = choice:match ("%s+(%S+)%s") or choice:match ("(%S+)")
              if name then
                switch_profile (name)
              end
            end
          end)
        end
      end
    end,
    commands = {
      add = {
        enabled = true,
        args = 0,
        name = "profile.add",
        callback = function (e)
          local body = e.body or {}
          local name = body[1]
          local function do_add (n)
            if not n or n == "" then
              return
            end
            Global.add_profile (n)
            vim.notify ("Added profile: " .. n, vim.log.levels.INFO)
          end
          if not name then
            vim.ui.input ({ prompt = "New profile name: " }, do_add)
          else
            do_add (name)
          end
        end,
      },
      remove = {
        enabled = true,
        args = 0,
        name = "profile.remove",
        callback = function (e)
          local body = e.body or {}
          local name = body[1]
          local function do_remove (n)
            if not n or n == "default" then
              vim.notify ("Cannot remove default profile", vim.log.levels.WARN)
              return
            end
            if Global.remove_profile (n) then
              vim.notify ("Removed profile: " .. n, vim.log.levels.INFO)
            else
              vim.notify ("Profile not found: " .. n, vim.log.levels.WARN)
            end
          end
          if not name then
            local names = {}
            for _, n in ipairs (Global.profile_names ()) do
              if n ~= "default" then
                names[#names + 1] = n
              end
            end
            if #names == 0 then
              vim.notify ("No removable profiles", vim.log.levels.INFO)
              return
            end
            vim.ui.select (names, { prompt = "Remove profile:" }, do_remove)
          else
            do_remove (name)
          end
        end,
      },
      list = {
        enabled = true,
        args = 0,
        name = "profile.list",
        callback = function ()
          local items = profile_items ()
          if #items == 0 then
            vim.notify ("No profiles configured", vim.log.levels.INFO)
          else
            vim.ui.select (items, { prompt = "Profiles:" }, function (_) end)
          end
        end,
      },
      switch = {
        enabled = true,
        args = 0,
        name = "profile.switch",
        callback = function (e)
          local body = e.body or {}
          local name = body[1]
          if not name then
            vim.ui.select (
              Global.profile_names (),
              { prompt = "Switch to profile:" },
              function (choice)
                if choice then
                  switch_profile (choice)
                end
              end
            )
          else
            switch_profile (name)
          end
        end,
      },
    },
  }

  -- Register memory command
  Cmd.commands.memory = {
    enabled = true,
    args = 0,
    name = "memory",
    complete = function ()
      return { "add", "list", "show", "search", "delete", "export", "import" }
    end,
    callback = function (e)
      local body = e.body or {}
      local sub = body[1]
      local data_home = os.getenv ("XDG_DATA_HOME")
        or (os.getenv ("HOME") .. "/.local/share")
      local mem_dir = data_home .. "/down/memory"

      local function memory_cli (argv, show)
        if down_bin () then
          if show then
            down_show (argv, "markdown")
          else
            local out, err = down_run (argv)
            if err then
              vim.notify ("Memory command failed: " .. err, vim.log.levels.ERROR)
            elseif out and out ~= "" then
              vim.notify (out, vim.log.levels.INFO)
            end
          end
          return true
        end
        return false
      end

      if sub == "add" or sub == "set" then
        local key = body[2]
        local value = body[3]
        if not key then
          vim.ui.input ({ prompt = "Memory key: " }, function (k)
            if k and k ~= "" then
              vim.ui.input ({ prompt = "Value: " }, function (v)
                if v then
                  if not memory_cli ({ "memory", "add", k, v }) then
                    os.execute ('mkdir -p "' .. mem_dir .. '"')
                    local f = io.open (mem_dir .. "/" .. k .. ".json", "w")
                    if f then
                      f:write (vim.json.encode ({
                        key = k,
                        value = v,
                        tags = {},
                        meta = {},
                        created_at = os.date ("%Y-%m-%dT%H:%M:%SZ"),
                        updated_at = os.date ("%Y-%m-%dT%H:%M:%SZ"),
                      }))
                      f:close ()
                      vim.notify ("Memory saved: " .. k, vim.log.levels.INFO)
                    end
                  end
                end
              end)
            end
          end)
          return
        end
        if memory_cli ({ "memory", "add", key, value or "" }) then
          return
        end
        os.execute ('mkdir -p "' .. mem_dir .. '"')
        local f = io.open (mem_dir .. "/" .. key .. ".json", "w")
        if f then
          f:write (vim.json.encode ({
            key = key,
            value = value,
            tags = {},
            meta = {},
            created_at = os.date ("%Y-%m-%dT%H:%M:%SZ"),
            updated_at = os.date ("%Y-%m-%dT%H:%M:%SZ"),
          }))
          f:close ()
          vim.notify ("Memory saved: " .. key, vim.log.levels.INFO)
        end
      elseif sub == "list" or sub == "ls" or not sub then
        if memory_cli ({ "memory", "list" }, true) then
          return
        end
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
            if k then
              if not memory_cli ({ "memory", "show", k }, true) then
                _show_memory_entry (mem_dir, k)
              end
            end
          end)
        elseif not memory_cli ({ "memory", "show", key }, true) then
          _show_memory_entry (mem_dir, key)
        end
      elseif sub == "search" then
        local query = body[2]
        if not query then
          vim.ui.input ({ prompt = "Search memory: " }, function (q)
            if q then
              if not memory_cli ({ "memory", "search", q }, true) then
                _search_memory (mem_dir, q)
              end
            end
          end)
        elseif not memory_cli ({ "memory", "search", query }, true) then
          _search_memory (mem_dir, query)
        end
      elseif sub == "delete" or sub == "rm" then
        local key = body[2]
        if not key then
          vim.ui.input ({ prompt = "Delete memory key: " }, function (k)
            if k then
              if not memory_cli ({ "memory", "delete", k }) then
                os.remove (mem_dir .. "/" .. k .. ".json")
                vim.notify ("Deleted: " .. k, vim.log.levels.INFO)
              end
            end
          end)
        elseif not memory_cli ({ "memory", "delete", key }) then
          os.remove (mem_dir .. "/" .. key .. ".json")
          vim.notify ("Deleted: " .. key, vim.log.levels.INFO)
        end
      elseif sub == "export" then
        local file = body[2]
        local argv = { "memory", "export" }
        if file then
          table.insert (argv, file)
        end
        memory_cli (argv, not file)
      elseif sub == "import" then
        local file = body[2]
        if file then
          memory_cli ({ "memory", "import", file })
        else
          vim.notify ("Usage: :Down memory import <file>", vim.log.levels.ERROR)
        end
      end
    end,
  }

  -- Register context command
  Cmd.commands.context = {
    enabled = true,
    args = 0,
    min_args = 0,
    max_args = math.huge,
    name = "context",
    complete = function ()
      return {
        "-o",
        "--output",
        "--no-compact",
        "--no-memory",
        "--no-vectors",
        "-q",
        "--vector-query",
        "-l",
        "--vector-limit",
        "-p",
        "--prompt",
      }
    end,
    callback = function (e)
      local args = e.body or {}
      local root = vim.fn.getcwd ()
      local cli = { "context" }
      local i = 1
      while i <= #args do
        local a = args[i]
        if a:match ("^%-") then
          table.insert (cli, a)
          if
            a:match ("^%-%-")
            and not vim.tbl_contains ({
              "--no-compact",
              "--no-memory",
              "--no-vectors",
            }, a)
          then
            if args[i + 1] and not args[i + 1]:match ("^%-") then
              table.insert (cli, args[i + 1])
              i = i + 1
            end
          end
        elseif
          not root:match ("^%.$")
          and i == 1
          and vim.fn.isdirectory (a) == 1
        then
          root = a
        else
          table.insert (cli, a)
        end
        i = i + 1
      end
      table.insert (cli, 2, root)
      local out_path = root .. "/.down/context.md"
      local _, err = down_run (cli)
      if err then
        vim.notify ("Context command failed: " .. err, vim.log.levels.ERROR)
        return
      end
      if vim.fn.filereadable (out_path) == 1 then
        vim.cmd ("vsplit " .. vim.fn.fnameescape (out_path))
      end
      vim.notify ("Context written to " .. out_path, vim.log.levels.INFO)
    end,
  }

  -- Register repomix command
  Cmd.commands.repomix = {
    enabled = true,
    args = 0,
    min_args = 0,
    max_args = math.huge,
    name = "repomix",
    complete = function ()
      return { "json", "markdown", "xml", "plain", "tree" }
    end,
    callback = function (e)
      local args = e.body or {}
      local root = "."
      local fmt = "xml"
      local extra = {}
      for _, a in ipairs (args) do
        if a:match ("^-%") or a:match ("^--") then
          table.insert (extra, a)
        elseif vim.fn.isdirectory (a) == 1 or vim.fn.filereadable (a) == 1 then
          root = a
        elseif
          a == "json"
          or a == "markdown"
          or a == "xml"
          or a == "plain"
          or a == "tree"
        then
          fmt = a
        else
          table.insert (extra, a)
        end
      end
      local argv = { "repomix", root, "-f", fmt }
      for _, a in ipairs (extra) do
        table.insert (argv, a)
      end
      local out, err = down_run (argv)
      if err then
        vim.notify ("repomix failed: " .. err, vim.log.levels.ERROR)
        return
      end
      if out and out ~= "" then
        local ft = fmt == "json" and "json"
          or fmt == "markdown" and "markdown"
          or "xml"
        local buf = vim.api.nvim_create_buf (false, true)
        vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
        vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
        vim.api.nvim_buf_set_lines (buf, 0, -1, false, vim.split (out, "\n"))
        vim.cmd ("vsplit")
        vim.api.nvim_win_set_buf (0, buf)
        vim.bo[buf].filetype = ft
      end
    end,
  }

  -- Register sync command (delegates to Go CLI `down sync` which detects
  -- added/modified/deleted files via SHA-256 index and re-indexes data,
  -- knowledge, memory, context, vector, web sources)
  Cmd.commands.sync = {
    enabled = true,
    args = 0,
    min_args = 0,
    max_args = math.huge,
    name = "sync",
    complete = function ()
      return {
        "add",
        "data",
        "knowledge",
        "memory",
        "context",
        "vector",
        "web",
        "git",
        "--force",
        "-f",
        "--verbose",
        "-v",
        "--dry-run",
      }
    end,
    callback = function (e)
      local args = e.body or {}
      local sub = args[1]
      if sub and not sub:match ("^%-") then
        -- sub-sync: down sync <sub>
        down_show ({ "sync", sub, unpack (args, 2) }, nil)
        return
      end
      down_show ({ "sync", unpack (args) }, nil)
    end,
    commands = {
      add = {
        enabled = true,
        args = 1,
        name = "sync.add",
        complete = function ()
          return {}
        end,
        callback = function (e)
          local url = e.body and e.body[1]
          if not url then
            vim.ui.input ({ prompt = "URL to fetch and add: " }, function (input)
              if input and input ~= "" then
                down_show ({ "sync", "add", input })
              end
            end)
            return
          end
          down_show ({ "sync", "add", url })
        end,
      },
      data = {
        enabled = true,
        args = 0,
        name = "sync.data",
        callback = function ()
          down_show ({ "sync", "data" })
        end,
      },
      knowledge = {
        enabled = true,
        args = 0,
        name = "sync.knowledge",
        callback = function ()
          down_show ({ "sync", "knowledge" })
        end,
      },
      memory = {
        enabled = true,
        args = 0,
        name = "sync.memory",
        callback = function ()
          down_show ({ "sync", "memory" })
        end,
      },
      context = {
        enabled = true,
        args = 0,
        name = "sync.context",
        callback = function ()
          down_show ({ "sync", "context" })
        end,
      },
      vector = {
        enabled = true,
        args = 0,
        name = "sync.vector",
        callback = function ()
          down_show ({ "sync", "vector" })
        end,
      },
      web = {
        enabled = true,
        args = 0,
        name = "sync.web",
        callback = function ()
          down_show ({ "sync", "web" })
        end,
      },
      skills = {
        enabled = true,
        args = 0,
        min_args = 0,
        max_args = math.huge,
        name = "sync.skills",
        complete = function ()
          return {
            "--output",
            "-o",
            "--profile",
            "-p",
            "--no-fs",
            "--no-kb",
            "--no-memory",
            "--no-vector",
            "--no-data",
          }
        end,
        callback = function (e)
          down_show ({ "sync", "skills", unpack (e.body or {}) }, "markdown")
        end,
      },
      git = {
        enabled = true,
        args = 0,
        min_args = 0,
        max_args = math.huge,
        name = "sync.git",
        complete = function ()
          return {
            "status",
            "log",
            "diff",
            "--force",
            "-f",
            "--verbose",
            "-v",
            "--root",
          }
        end,
        callback = function (e)
          local args = e.body or {}
          local sub = args[1]
          if sub and not sub:match ("^%-") then
            down_show ({ "sync", "git", sub, unpack (args, 2) }, "markdown")
          else
            down_show ({ "sync", "git", unpack (args) }, "markdown")
          end
        end,
        commands = {
          status = {
            enabled = true,
            args = 0,
            name = "sync.git.status",
            callback = function (e)
              down_show (
                { "sync", "git", "status", unpack (e.body or {}, 2) },
                "markdown"
              )
            end,
          },
          log = {
            enabled = true,
            args = 0,
            name = "sync.git.log",
            callback = function (e)
              down_show (
                { "sync", "git", "log", unpack (e.body or {}, 2) },
                "markdown"
              )
            end,
          },
          diff = {
            enabled = true,
            args = 0,
            name = "sync.git.diff",
            callback = function (e)
              down_show (
                { "sync", "git", "diff", unpack (e.body or {}, 2) },
                "markdown"
              )
            end,
          },
        },
      },
    },
  }

  -- Pass-through commands: each delegates to the Go CLI `down <cmd> <args>`
  -- and shows stdout in a scratch buffer. These replicate all CLI
  -- functionality in the neovim plugin.
  local passthrough = {
    export = { subcmds = { "html", "csv", "pdf", "markdown" }, ft = nil },
    publish = { subcmds = {}, ft = "markdown" },
    vector = {
      subcmds = {
        "index",
        "index-all",
        "index-kb",
        "search",
        "list",
        "delete",
        "cluster",
        "dedup",
        "stats",
        "compare",
      },
      ft = nil,
    },
    todo = { subcmds = { "add", "list", "done", "delete" }, ft = "markdown" },
    mcp = { subcmds = {}, ft = nil },
    remove = { subcmds = {}, ft = nil },
    delete = { subcmds = {}, ft = nil },
    serve = { subcmds = {}, ft = nil },
    shell = { subcmds = {}, ft = nil },
    list = { subcmds = {}, ft = nil },
    find = { subcmds = {}, ft = nil },
    config = { subcmds = { "get", "set" }, ft = nil },
    log = { subcmds = {}, ft = nil },
    tag = { subcmds = { "list" }, ft = nil },
    new = { subcmds = {}, ft = nil },
    link = { subcmds = { "backlinks" }, ft = nil },
    snippet = { subcmds = { "list", "show" }, ft = nil },
    template = {
      subcmds = {
        "list",
        "show",
        "apply",
        "create",
        "delete",
        "init",
        "types",
        "validate",
      },
      ft = nil,
    },
    workspace = {
      subcmds = { "add", "list", "switch", "remove", "init", "clear" },
      ft = nil,
    },
    upgrade = { subcmds = {}, ft = nil },
    database = {
      subcmds = {
        "list",
        "show",
        "query",
        "view",
        "create",
        "add-row",
        "add",
        "update-row",
        "update",
        "set",
        "export",
      },
      ft = "markdown",
    },
    generate = {
      subcmds = {
        "all",
        "daily",
        "notes",
        "journal",
        "calendar",
        "cal",
        "toc",
        "table-of-contents",
        "tasks",
        "task",
        "todos",
        "links",
        "tags",
        "mentions",
        "mention",
        "@",
        "backlinks",
        "bl",
        "orphans",
        "orphan",
        "stats",
        "dashboard",
        "summary",
        "entities",
        "entity",
        "knowledge",
        "graph",
        "diagram",
        "mermaid",
        "databases",
        "database",
        "db",
        "dbs",
      },
      ft = "markdown",
    },
    run = { subcmds = {}, ft = nil },
    lsp = {
      subcmds = {
        "slash",
        "tags",
        "mentions",
        "tasks",
        "outline",
        "backlinks",
        "databases",
        "database",
        "knowledge",
      },
      ft = nil,
    },
  }
  local lsp_knowledge_subcmds = {
    "summary",
    "search",
    "entities",
    "relations",
    "related",
    "reindex",
  }

  -- Note command: open daily notes in editor (Notion-style journal)
  Cmd.commands.note = {
    enabled = true,
    args = 0,
    min_args = 0,
    max_args = math.huge,
    name = "note",
    complete = function ()
      return {
        "today",
        "yesterday",
        "tomorrow",
        "week",
        "month",
        "year",
        "path",
      }
    end,
    callback = function (e)
      local body = e.body or {}
      local sub = body[1] or "today"
      local note_mod = mod.get_mod ("note")
      local journal_cmds = {
        today = "note_today",
        yesterday = "note_yesterday",
        tomorrow = "note_tomorrow",
        week = "week_index",
        month = "month_index",
        year = "year_index",
      }
      if note_mod and journal_cmds[sub] and note_mod[journal_cmds[sub]] then
        note_mod[journal_cmds[sub]] ()
        return
      end
      local argv = { "note", sub }
      for i = 2, #body do
        argv[#argv + 1] = body[i]
      end
      local out, err = down_run (argv)
      if err then
        vim.notify ("Note command failed: " .. err, vim.log.levels.ERROR)
        return
      end
      if out and out ~= "" then
        local path = out:match ("open%s+(.+)") or out:match ("^%s*(%S+)%s*$")
        if path and vim.fn.filereadable (path) == 1 then
          vim.cmd ("edit " .. vim.fn.fnameescape (path))
        end
      end
    end,
  }

  local function current_buf_file ()
    local f = vim.api.nvim_buf_get_name (0)
    if f ~= "" then
      return f
    end
    return nil
  end

  for cmd_name, spec in pairs (passthrough) do
    Cmd.commands[cmd_name] = {
      enabled = true,
      args = 0,
      min_args = 0,
      max_args = math.huge,
      name = cmd_name,
      complete = function ()
        return spec.subcmds
      end,
      callback = function (e)
        local args = e.body or {}
        if cmd_name == "run" or cmd_name == "serve" then
          down_show ({ "lsp", unpack (args) }, spec.ft)
          return
        end
        if cmd_name == "upgrade" then
          local out, err = down_run ({ "upgrade", unpack (args) })
          if err then
            vim.notify ("[down] upgrade failed: " .. err, vim.log.levels.ERROR)
          elseif out and out ~= "" then
            vim.notify (out, vim.log.levels.INFO)
          else
            vim.notify ("[down] upgrade complete", vim.log.levels.INFO)
          end
          return
        end
        if cmd_name == "database" then
          local sub = args[1] or "list"
          if sub == "view" or sub == "open" then
            local db_mod = mod.get_mod ("data.database")
            if db_mod then
              if sub == "open" then
                db_mod.open_database (args[2])
                return
              end
              local view_type = args[2] or "table"
              local group_by = args[3]
              db_mod.show_view (view_type, group_by)
              return
            end
          end
          if sub == "create" then
            local out, err =
              down_run ({ "database", "create", unpack (args, 2) })
            if err then
              vim.notify (
                "[down] database create failed: " .. err,
                vim.log.levels.ERROR
              )
              return
            end
            local path = out
              and (out:match ("open%s+(%S+)") or out:match ("Created:%s+(%S+)"))
            if path and vim.fn.filereadable (path) == 1 then
              vim.cmd ("edit " .. vim.fn.fnameescape (path))
            elseif out and out ~= "" then
              down_show ({ "database", unpack (args) }, spec.ft)
            end
            return
          end
          down_show ({ "database", unpack (args) }, spec.ft)
          return
        end
        if cmd_name == "generate" then
          local out, err = down_run ({ "generate", unpack (args) })
          if err then
            vim.notify ("[down] generate failed: " .. err, vim.log.levels.ERROR)
            return
          end
          local sub = args[1] or "all"
          local expected = ({
            all = "index.md",
            daily = "daily-notes.md",
            notes = "daily-notes.md",
            journal = "daily-notes.md",
            calendar = "calendar.md",
            cal = "calendar.md",
            toc = "toc.md",
            ["table-of-contents"] = "toc.md",
            tasks = "tasks.md",
            task = "tasks.md",
            todos = "tasks.md",
            links = "links.md",
            tags = "tags.md",
            mentions = "mentions.md",
            mention = "mentions.md",
            ["@"] = "mentions.md",
            backlinks = "backlinks.md",
            bl = "backlinks.md",
            orphans = "orphans.md",
            orphan = "orphans.md",
            stats = "stats.md",
            dashboard = "stats.md",
            summary = "stats.md",
            entities = "entities.md",
            entity = "entities.md",
            knowledge = "entities.md",
            graph = "graph.md",
            diagram = "graph.md",
            mermaid = "graph.md",
            databases = "databases.md",
            database = "databases.md",
            db = "databases.md",
            dbs = "databases.md",
          })[sub]
          local path = out
            and (
              out:match ("open%s+(%S+)")
              or out:match ("Generated:%s+(%S+)")
              or (expected and out:match (
                "(%S+" .. expected:gsub ("%.", "%%.") .. ")"
              ))
              or out:match ("(%S+index%.md)")
            )
          if path and vim.fn.filereadable (path) == 1 then
            vim.cmd ("vsplit " .. vim.fn.fnameescape (path))
            vim.bo.filetype = "markdown"
          elseif out and out ~= "" then
            local buf = vim.api.nvim_create_buf (false, true)
            vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
            vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
            vim.api.nvim_buf_set_lines (buf, 0, -1, false, vim.split (out, "\n"))
            vim.cmd ("vsplit")
            vim.api.nvim_win_set_buf (0, buf)
            vim.bo[buf].filetype = "markdown"
          end
          return
        end
        if cmd_name == "workspace" then
          down_show ({ "workspace", unpack (args) }, spec.ft)
          return
        end
        if cmd_name == "lsp" then
          local sub = args[1]
          local lsp_mod = mod.get_mod ("lsp")
          if lsp_mod and lsp_mod.get_client and lsp_mod.get_client () then
            if sub == "tags" then
              lsp_mod.workspace_symbol_picker ({
                kind = "tag",
                query = args[2] or "",
              })
              return
            end
            if sub == "mentions" or sub == "@" then
              lsp_mod.workspace_symbol_picker ({
                kind = "mention",
                query = args[2] or "",
              })
              return
            end
            if sub == "tasks" or sub == "task" or sub == "todos" then
              lsp_mod.list_tasks ()
              return
            end
            if sub == "outline" then
              vim.lsp.buf.document_symbol ()
              return
            end
            if sub == "backlinks" then
              local file = args[2] or current_buf_file ()
              local client = lsp_mod.get_client ()
              if client then
                client.request ("workspace/executeCommand", {
                  command = "down.backlinks",
                  arguments = file and { file } or {},
                }, function (err, result)
                  if err then
                    vim.notify (
                      "[down] backlinks failed: " .. vim.inspect (err),
                      vim.log.levels.ERROR
                    )
                    return
                  end
                  local text = type (result) == "string" and result
                    or vim.inspect (result or {})
                  local buf = vim.api.nvim_create_buf (false, true)
                  vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
                  vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
                  vim.api.nvim_buf_set_lines (
                    buf,
                    0,
                    -1,
                    false,
                    vim.split (text, "\n")
                  )
                  vim.cmd ("vsplit")
                  vim.api.nvim_win_set_buf (0, buf)
                  vim.bo[buf].filetype = "markdown"
                end, 0)
                return
              end
            end
            if sub == "knowledge" and args[2] and lsp_mod.knowledge_show then
              if lsp_mod.knowledge_show (args[2], { unpack (args, 3) }) then
                return
              end
            end
          end
          if sub == "outline" or sub == "backlinks" then
            if not args[2] then
              local file = current_buf_file ()
              if file then
                args[2] = file
              end
            end
          end
          down_show ({ "lsp", unpack (args) }, spec.ft)
          return
        end
        if
          cmd_name == "link" and (args[1] == nil or args[1] == "backlinks")
        then
          local file = args[2] or current_buf_file ()
          if file then
            down_show ({ "link", "backlinks", file }, spec.ft)
            return
          end
        end
        down_show ({ cmd_name, unpack (args) }, spec.ft)
      end,
    }
  end

  Cmd.commands.lsp.commands = {
    knowledge = {
      enabled = true,
      args = 0,
      name = "lsp.knowledge",
      complete = function ()
        return lsp_knowledge_subcmds
      end,
      callback = function (e)
        local args = e.body or {}
        down_show ({ "lsp", "knowledge", unpack (args) })
      end,
      commands = {
        summary = {
          enabled = true,
          args = 0,
          name = "lsp.knowledge.summary",
          callback = function ()
            down_show ({ "lsp", "knowledge", "summary" })
          end,
        },
        search = {
          enabled = true,
          args = 0,
          name = "lsp.knowledge.search",
          callback = function (e)
            down_show ({ "lsp", "knowledge", "search", unpack (e.body or {}, 2) })
          end,
        },
        entities = {
          enabled = true,
          args = 0,
          name = "lsp.knowledge.entities",
          callback = function (e)
            down_show ({
              "lsp",
              "knowledge",
              "entities",
              unpack (e.body or {}, 2),
            })
          end,
        },
        relations = {
          enabled = true,
          args = 0,
          name = "lsp.knowledge.relations",
          callback = function (e)
            down_show ({
              "lsp",
              "knowledge",
              "relations",
              unpack (e.body or {}, 2),
            })
          end,
        },
        related = {
          enabled = true,
          args = 0,
          name = "lsp.knowledge.related",
          callback = function (e)
            down_show ({
              "lsp",
              "knowledge",
              "related",
              unpack (e.body or {}, 2),
            })
          end,
        },
        reindex = {
          enabled = true,
          args = 0,
          name = "lsp.knowledge.reindex",
          callback = function ()
            down_show ({ "lsp", "knowledge", "reindex" })
          end,
        },
      },
    },
  }

  return { loaded = true }
end

-- Memory helpers
local function _show_memory_entry (mem_dir, key)
  local f = io.open (mem_dir .. "/" .. key .. ".json", "r")
  if not f then
    vim.notify ("Not found: " .. key, vim.log.levels.ERROR)
    return
  end
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
  -- First try substring search
  local entries = vim.fn.glob (mem_dir .. "/*.json", true, true)
  local results = {}
  for _, path in ipairs (entries) do
    local f = io.open (path, "r")
    if f then
      local raw = f:read ("*a")
      f:close ()
      if raw:lower ():find (query:lower (), 1, true) then
        local ok, data = pcall (vim.json.decode, raw)
        if ok then
          results[#results + 1] = data
        end
      end
    end
  end

  -- Fallback: try semantic search via embedding module
  if #results == 0 then
    local ok, sem = pcall (require, "down.mod.data.semantic")
    if ok and next (sem.embeddings or {}) then
      local scored = {}
      for _, path in ipairs (entries) do
        local f = io.open (path, "r")
        if f then
          local raw = f:read ("*a")
          f:close ()
          local ok2, data = pcall (vim.json.decode, raw)
          if ok2 and data.value then
            local score =
              sem.cosine (sem.embed (query) or {}, sem.embed (data.value) or {})
            if score > 0.2 then
              data._score = score
              scored[#scored + 1] = data
            end
          end
        end
      end
      table.sort (scored, function (a, b)
        return a._score > b._score
      end)
      results = scored
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
