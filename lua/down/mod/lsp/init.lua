local log = require("down.log")
local mod = require("down.mod")

---@class down.mod.lsp.Lsp: down.Mod
local Lsp = mod.new("lsp")
Lsp.dep = { "workspace", "cmd" }

---@class down.mod.lsp.Config
Lsp.config = {
  --- Enable auto-download of down binary
  auto_download = true,
  --- Auto-update check on startup
  auto_update = true,
  --- GitHub repo for down releases
  repo = "clpi/down",
  --- Binary name
  bin = "down",
  --- Custom binary path (overrides auto-download)
  cmd = nil,
  --- Additional LSP settings to pass
  settings = {
    --- Enable completion provider in LSP
    completion = {
      enable = true,
      --- Trigger characters for completion
      triggerCharacters = { "/", "@", "#", "[", "(", ":" },
    },
    --- Enable tag indexing
    tags = {
      enable = true,
      --- Pattern for tags
      pattern = "#%S+",
    },
    --- Enable workspace symbol support
    workspace = {
      enable = true,
    },
    --- Enable diagnostics
    diagnostics = {
      enable = true,
      --- Check for broken links
      brokenLinks = true,
      --- Check for duplicate headings
      duplicateHeadings = false,
    },
  },
  --- Filetypes to attach LSP
  filetypes = { "markdown", "md", "down" },
  --- Root directory markers
  root_markers = { ".down", ".git", "index.md", ".obsidian", ".vault" },
  --- Version file to track installed version
  version_file = "version.txt",
}

---@return down.mod.Setup
Lsp.setup = function()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = Lsp.config.filetypes,
    callback = function(ev)
      if mod.get_mod("workspace").is_wiki_path(ev.file) then
        Lsp.start(ev.buf)
      end
    end,
    desc = "Start down LSP for markdown files in wiki workspaces",
  })

  mod.await("workspace", function(ws)
    if ws.events and ws.events.wschanged then
    end
  end)
  return {
    loaded = true,
  }
end

--- Get the install directory for the LSP binary
---@return string
Lsp.install_dir = function()
  local dir = vim.fs.joinpath(vim.fn.stdpath("data"), "down", "lsp")
  vim.fn.mkdir(dir, "p")
  return dir
end

--- Get the binary path
---@return string
Lsp.bin_path = function()
  if Lsp.config.cmd then
    return Lsp.config.cmd
  end
  local bin = Lsp.config.bin
  if vim.fn.has("win32") == 1 then
    bin = bin .. ".exe"
  end
  return vim.fs.joinpath(Lsp.install_dir(), bin)
end

--- Check if the binary is installed
---@return boolean
Lsp.is_installed = function()
  return vim.fn.executable(Lsp.bin_path()) == 1
end

--- Get installed version
---@return string|nil
Lsp.installed_version = function()
  local vfile = vim.fs.joinpath(Lsp.install_dir(), Lsp.config.version_file)
  local f = io.open(vfile, "r")
  if f then
    local ver = f:read("*l")
    f:close()
    return ver
  end
  return nil
end

--- Save installed version
---@param version string
Lsp.save_version = function(version)
  local vfile = vim.fs.joinpath(Lsp.install_dir(), Lsp.config.version_file)
  local f = io.open(vfile, "w")
  if f then
    f:write(version)
    f:close()
  end
end

--- Detect the platform for download
---@return string?
Lsp.platform = function()
  local os_name = vim.loop.os_uname().sysname
  local arch = vim.loop.os_uname().machine
  if os_name == "Linux" then
    if arch == "x86_64" then
      return "linux-amd64"
    elseif arch == "aarch64" then
      return "linux-arm64"
    end
  elseif os_name == "Darwin" then
    if arch == "arm64" then
      return "darwin-arm64"
    else
      return "darwin-amd64"
    end
  elseif os_name == "Windows_NT" then
    return "windows-amd64"
  end
  return nil
end

--- Check for updates from GitHub releases
---@param cb fun(has_update: boolean, latest_version: string|nil)
Lsp.check_update = function(cb)
  local url = string.format(
    "https://api.github.com/repos/%s/releases/latest",
    Lsp.config.repo
  )
  vim.fn.jobstart({ "curl", "-sL", url }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local json_str = table.concat(data, "")
      local ok, release = pcall(vim.json.decode, json_str)
      if ok and release and release.tag_name then
        local latest = release.tag_name
        local current = Lsp.installed_version()
        if current ~= latest then
          cb(true, latest)
        else
          cb(false, current)
        end
      else
        cb(false, nil)
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        cb(false, nil)
      end
    end,
  })
end

--- Compile and install the LSP binary
---@param cb? fun(success: boolean)
Lsp.download = function(cb, version)
  local bin_name = Lsp.config.bin
  if vim.fn.has("win32") == 1 then
    bin_name = bin_name .. ".exe"
  end

  vim.notify("[down.nvim] Compiling down binary...", vim.log.levels.INFO)

  local install_dir = Lsp.install_dir()
  local dest = vim.fs.joinpath(install_dir, bin_name)

  -- Get plugin root directory
  local script_path = debug.getinfo(1).source:sub(2)
  local plugin_root = vim.fn.fnamemodify(script_path, ":p:h:h:h:h:h")
  local ext_down_path = vim.fs.joinpath(plugin_root, "ext", "down")

  if vim.fn.executable("go") ~= 1 then
    vim.notify("[down.nvim] Error: 'go' is not installed. Cannot compile down binary.", vim.log.levels.ERROR)
    if cb then cb(false) end
    return
  end

  if vim.fn.isdirectory(ext_down_path) == 0 then
    vim.notify("[down.nvim] Error: ext/down directory not found at " .. ext_down_path, vim.log.levels.ERROR)
    if cb then cb(false) end
    return
  end

  vim.fn.jobstart({ "go", "build", "-o", dest, "main.go" }, {
    cwd = ext_down_path,
    on_exit = function(_, code)
      if code == 0 then
        vim.fn.setfperm(dest, "rwxr-xr-x")
        vim.schedule(function()
          -- Save a fake version to prevent re-downloads immediately
          Lsp.save_version("local-build")
          vim.notify("[down.nvim] down binary compiled successfully", vim.log.levels.INFO)
          if cb then
            cb(true)
          end
        end)
      else
        vim.schedule(function()
          vim.notify("[down.nvim] Failed to compile down binary. Check your go installation.", vim.log.levels.WARN)
          if cb then
            cb(false)
          end
        end)
      end
    end,
  })
end

--- Update the LSP binary if a newer version is available
---@param force? boolean Force re-download even if up to date
Lsp.update = function(force)
  Lsp.check_update(function(has_update, latest)
    if has_update and latest then
      vim.schedule(function()
        vim.notify(
          "[down.nvim] Updating down to " .. latest .. "...",
          vim.log.levels.INFO
        )
        Lsp.download(function(success)
          if success then
            -- Restart LSP clients
            vim.schedule(function()
              Lsp.restart()
            end)
          end
        end, latest)
      end)
    elseif force then
      vim.schedule(function()
        Lsp.download(nil, latest)
      end)
    else
      vim.schedule(function()
        vim.notify(
          "[down.nvim] down is up to date" .. (latest and (" (" .. latest .. ")") or ""),
          vim.log.levels.INFO
        )
      end)
    end
  end)
end

--- Get workspace folders from workspace module
---@param name? string
---@return lsp.WorkspaceFolder[]
Lsp.workspace_folders = function(name)
  local ws = mod.get_mod("workspace")
  if ws and ws.as_lsp_workspaces then
    return ws.as_lsp_workspaces(name, true)
  end
  return {
    {
      name = "default",
      uri = vim.uri_from_fname(vim.fn.getcwd()),
    },
  }
end

--- Build full client capabilities including completion
---@return table
Lsp.capabilities = function()
  local caps = vim.lsp.protocol.make_client_capabilities()

  -- Enhance completion capabilities
  caps.textDocument.completion = {
    dynamicRegistration = true,
    completionItem = {
      snippetSupport = true,
      commitCharactersSupport = true,
      deprecatedSupport = true,
      preselectSupport = true,
      labelDetailsSupport = true,
      documentationFormat = { "markdown", "plaintext" },
      resolveSupport = {
        properties = { "documentation", "detail", "additionalTextEdits" },
      },
      insertReplaceSupport = true,
    },
    completionList = {
      itemDefaults = { "commitCharacters", "editRange", "insertTextFormat", "insertTextMode", "data" },
    },
    contextSupport = true,
  }

  -- Workspace symbol support
  caps.workspace.symbol = {
    dynamicRegistration = true,
    symbolKind = {
      valueSet = vim.tbl_values(vim.lsp.protocol.SymbolKind),
    },
  }

  -- Document link support (for wiki links, file links)
  caps.textDocument.documentLink = {
    dynamicRegistration = true,
    tooltipSupport = true,
  }

  return caps
end

--- Start the LSP client
---@param bufnr? integer
Lsp.start = function(bufnr)
  bufnr = bufnr or 0
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local ws = mod.get_mod("workspace")
  if ws and ws.is_wiki_path and not ws.is_wiki_path(bufname) then
    return
  end

  if not Lsp.is_installed() then
    if Lsp.config.auto_download then
      Lsp.download(function(success)
        if success then
          vim.schedule(function()
            Lsp.attach(bufnr)
          end)
        end
      end)
    else
      log.info(
        "down not installed. Set config.lsp.auto_download = true or provide config.lsp.cmd"
      )
    end
    return
  end

  -- Check for updates in background if enabled
  if Lsp.config.auto_update then
    Lsp.check_update(function(has_update, latest)
      if has_update and latest then
        vim.schedule(function()
          vim.notify(
            "[down.nvim] down update available: " .. latest .. ". Run :Down lsp update",
            vim.log.levels.INFO
          )
        end)
      end
    end)
  end

  Lsp.attach(bufnr)
end

--- Get active LSP client for down
---@return vim.lsp.Client|nil
Lsp.get_client = function()
  local clients = vim.lsp.get_clients({ name = "down" })
  return clients and clients[1] or nil
end

--- Attach LSP to current buffer
---@param bufnr? integer
Lsp.attach = function(bufnr)
  bufnr = bufnr or 0
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local ws = mod.get_mod("workspace")
  if ws and ws.is_wiki_path and not ws.is_wiki_path(bufname) then
    return
  end

  local cmd_path = Lsp.bin_path()
  if vim.fn.executable(cmd_path) ~= 1 then
    return
  end

  local root_dir = vim.fs.root(bufnr, Lsp.config.root_markers) or vim.fn.getcwd()
  local workspace_name = ws and ws.name_for_path and ws.name_for_path(root_dir)
  local client_id = vim.lsp.start({
    name = "down",
    cmd = { cmd_path, "lsp" },
    filetypes = Lsp.config.filetypes,
    root_dir = root_dir,
    workspace_folders = Lsp.workspace_folders(workspace_name),
    settings = Lsp.config.settings,
    capabilities = Lsp.capabilities(),
    on_attach = function(client, attached_bufnr)
      Lsp.on_attach(client, attached_bufnr)
    end,
    handlers = Lsp.handlers(),
  })

  if client_id then
    vim.lsp.buf_attach_client(bufnr, client_id)
  end
end

--- Handlers for LSP notifications/requests
---@return table
Lsp.handlers = function()
  return {
    -- Handle workspace/configuration requests
    ["workspace/configuration"] = function(_, result, ctx)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if not client then
        return {}
      end
      local response = {}
      for _, item in ipairs(result.items) do
        table.insert(response, Lsp.config.settings)
      end
      return response
    end,
    -- Custom handler for tag indexing progress
    ["$/progress"] = function(_, result, ctx)
      if result.value and result.value.kind then
        if result.value.kind == "begin" then
          vim.notify("[down] " .. (result.value.title or "Working..."), vim.log.levels.INFO)
        end
      end
    end,
  }
end

--- On-attach callback for LSP client
---@param client vim.lsp.Client
---@param bufnr number
Lsp.on_attach = function(client, bufnr)
  -- Set up buffer-local keymaps for LSP features
  local opts = { buffer = bufnr, silent = true }

  -- Go to definition (follow links)
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition/link" }))

  -- Hover for preview
  vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover preview" }))

  -- Workspace symbols (find tags, headings)
  vim.keymap.set("n", "<leader>ds", vim.lsp.buf.workspace_symbol, vim.tbl_extend("force", opts, { desc = "Workspace symbols" }))

  -- Rename (rename tag across workspace)
  vim.keymap.set("n", "<leader>dr", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename symbol/tag" }))

  -- Code actions
  vim.keymap.set("n", "<leader>da", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code actions" }))

  -- References (find all references to tag/link)
  vim.keymap.set("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "Find references" }))

  -- Document symbols (outline)
  vim.keymap.set("n", "<leader>do", vim.lsp.buf.document_symbol, vim.tbl_extend("force", opts, { desc = "Document outline" }))

  -- Notify about LSP connection
  log.trace("down attached to buffer " .. bufnr)
end

--- Restart all down clients
Lsp.restart = function()
  local clients = vim.lsp.get_clients({ name = "down" })
  for _, client in ipairs(clients) do
    client.stop()
  end
  vim.defer_fn(function()
    -- Re-attach to all markdown buffers
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local ft = vim.bo[bufnr].filetype
        if vim.tbl_contains(Lsp.config.filetypes, ft) then
          vim.api.nvim_buf_call(bufnr, function()
            Lsp.attach(bufnr)
          end)
        end
      end
    end
  end, 500)
end

--- Send a custom notification to the LSP server
---@param method string
---@param params table
Lsp.notify_server = function(method, params)
  local client = Lsp.get_client()
  if client then
    client.notify(method, params)
  end
end

--- Request workspace re-index (e.g., after git pull)
Lsp.reindex = function()
  Lsp.notify_server("workspace/didChangeWorkspaceFolders", {
    event = {
      added = Lsp.workspace_folders(),
      removed = {},
    },
  })
end

Lsp.commands = {
  lsp = {
    name = "lsp",
    args = 0,
    max_args = 1,
    callback = function(e)
      Lsp.start()
    end,
    commands = {
      start = {
        name = "lsp.start",
        args = 0,
        callback = function()
          Lsp.start()
        end,
      },
      stop = {
        name = "lsp.stop",
        args = 0,
        callback = function()
          local clients = vim.lsp.get_clients({ name = "down" })
          for _, client in ipairs(clients) do
            client.stop()
          end
          vim.notify("[down.nvim] down stopped", vim.log.levels.INFO)
        end,
      },
      restart = {
        name = "lsp.restart",
        args = 0,
        callback = function()
          Lsp.restart()
        end,
      },
      install = {
        name = "lsp.install",
        args = 0,
        callback = function()
          Lsp.download()
        end,
      },
      update = {
        name = "lsp.update",
        args = 0,
        callback = function()
          Lsp.update()
        end,
      },
      status = {
        name = "lsp.status",
        args = 0,
        callback = function()
          if Lsp.is_installed() then
            local ver = Lsp.installed_version() or "unknown"
            local client = Lsp.get_client()
            local status = client and "running" or "stopped"
            vim.notify(
              string.format("[down.nvim] down v%s (%s) at: %s", ver, status, Lsp.bin_path())
            )
          else
            vim.notify("[down.nvim] down is not installed")
          end
        end,
      },
    },
  },
}

Lsp.maps = {
  { "n", ",dl", "<cmd>Down lsp status<CR>", { desc = "LSP status", silent = true } },
  { "n", ",dL", "<cmd>Down lsp restart<CR>", { desc = "LSP restart", silent = true } },
}

return Lsp
