local log = require("down.log")
local mod = require("down.mod")

--- Compatibility helper for vim.lsp.get_clients (added in 0.10)
local get_lsp_clients = vim.lsp.get_clients or vim.lsp.get_active_clients or function() return {} end

---@class down.mod.lsp.Lsp: down.Mod
local Lsp = mod.new("lsp")

---@class down.mod.lsp.Config
Lsp.config = {
  --- Enable auto-download of down.lsp binary
  auto_download = true,
  --- Auto-update check on startup
  auto_update = true,
  --- GitHub repo for down.lsp releases
  repo = "clpi/down.lsp",
  --- Binary name
  bin = "down-lsp",
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
  return {
    loaded = true,
    dependencies = { "workspace", "cmd" },
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
  local uv = vim.uv or vim.loop
  local os_name = uv.os_uname().sysname
  local arch = uv.os_uname().machine
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

--- Download and install the LSP binary
---@param cb? fun(success: boolean)
---@param version? string specific version tag to install
Lsp.download = function(cb, version)
  local platform = Lsp.platform()
  if not platform then
    log.warn("down.lsp: unsupported platform for auto-download")
    if cb then
      cb(false)
    end
    return
  end

  local bin_name = Lsp.config.bin
  if vim.fn.has("win32") == 1 then
    bin_name = bin_name .. ".exe"
  end

  vim.notify("[down.nvim] Downloading down.lsp...", vim.log.levels.INFO)

  local install_dir = Lsp.install_dir()
  local tag = version or "latest"
  local url
  if tag == "latest" then
    url = string.format(
      "https://github.com/%s/releases/latest/download/%s-%s",
      Lsp.config.repo,
      Lsp.config.bin,
      platform
    )
  else
    url = string.format(
      "https://github.com/%s/releases/download/%s/%s-%s",
      Lsp.config.repo,
      tag,
      Lsp.config.bin,
      platform
    )
  end
  local dest = vim.fs.joinpath(install_dir, bin_name)

  vim.fn.jobstart({ "curl", "-sL", "-o", dest, url }, {
    on_exit = function(_, code)
      if code == 0 then
        vim.fn.setfperm(dest, "rwxr-xr-x")
        vim.schedule(function()
          -- Save the version we just installed
          if version then
            Lsp.save_version(version)
          else
            -- Query the latest tag and save it
            Lsp.check_update(function(_, ver)
              if ver then
                Lsp.save_version(ver)
              end
            end)
          end
          vim.notify(
            "[down.nvim] down.lsp installed successfully",
            vim.log.levels.INFO
          )
          if cb then
            cb(true)
          end
        end)
      else
        vim.schedule(function()
          vim.notify(
            "[down.nvim] Failed to download down.lsp",
            vim.log.levels.WARN
          )
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
          "[down.nvim] Updating down.lsp to " .. latest .. "...",
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
          "[down.nvim] down.lsp is up to date" .. (latest and (" (" .. latest .. ")") or ""),
          vim.log.levels.INFO
        )
      end)
    end
  end)
end

--- Get workspace folders from workspace module
---@return lsp.WorkspaceFolder[]
Lsp.workspace_folders = function()
  local ws = mod.get_mod("workspace")
  if ws and ws.as_lsp_workspaces then
    return ws.as_lsp_workspaces()
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
Lsp.start = function()
  if not Lsp.is_installed() then
    if Lsp.config.auto_download then
      Lsp.download(function(success)
        if success then
          vim.schedule(function()
            Lsp.attach()
          end)
        end
      end)
    else
      log.info(
        "down.lsp not installed. Set config.lsp.auto_download = true or provide config.lsp.cmd"
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
            "[down.nvim] down.lsp update available: " .. latest .. ". Run :Down lsp update",
            vim.log.levels.INFO
          )
        end)
      end
    end)
  end

  Lsp.attach()
end

--- Get active LSP client for down-lsp
---@return vim.lsp.Client|nil
Lsp.get_client = function()
  local clients = get_lsp_clients({ name = "down-lsp" })
  return clients and clients[1] or nil
end

--- Attach LSP to current buffer
Lsp.attach = function()
  local cmd_path = Lsp.bin_path()
  if vim.fn.executable(cmd_path) ~= 1 then
    return
  end

  local client_id = vim.lsp.start({
    name = "down-lsp",
    cmd = { cmd_path, "serve" },
    filetypes = Lsp.config.filetypes,
    root_dir = vim.fs.root(0, Lsp.config.root_markers) or vim.fn.getcwd(),
    workspace_folders = Lsp.workspace_folders(),
    settings = Lsp.config.settings,
    capabilities = Lsp.capabilities(),
    on_attach = function(client, bufnr)
      Lsp.on_attach(client, bufnr)
    end,
    handlers = Lsp.handlers(),
  })

  if client_id then
    vim.lsp.buf_attach_client(0, client_id)
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
          vim.notify("[down.lsp] " .. (result.value.title or "Working..."), vim.log.levels.INFO)
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
  log.trace("down.lsp attached to buffer " .. bufnr)
end

--- Restart all down-lsp clients
Lsp.restart = function()
  local clients = get_lsp_clients({ name = "down-lsp" })
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
            Lsp.attach()
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
          local clients = get_lsp_clients({ name = "down-lsp" })
          for _, client in ipairs(clients) do
            client.stop()
          end
          vim.notify("[down.nvim] down.lsp stopped", vim.log.levels.INFO)
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
              string.format("[down.nvim] down.lsp v%s (%s) at: %s", ver, status, Lsp.bin_path())
            )
          else
            vim.notify("[down.nvim] down.lsp is not installed")
          end
        end,
      },
    },
  },
}

Lsp.load = function()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = Lsp.config.filetypes,
    callback = function()
      Lsp.start()
    end,
    desc = "Start down.lsp for markdown files",
  })

  -- Re-notify LSP when workspace changes
  mod.await("workspace", function(ws)
    -- If workspace module has events, listen for workspace changes
    if ws.events and ws.events.wschanged then
      -- Will re-attach with new workspace folders on change
    end
  end)
end

Lsp.maps = {
  { "n", ",dl", "<cmd>Down lsp status<CR>", { desc = "LSP status", silent = true } },
  { "n", ",dL", "<cmd>Down lsp restart<CR>", { desc = "LSP restart", silent = true } },
}

return Lsp
