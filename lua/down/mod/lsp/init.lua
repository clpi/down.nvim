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

--- Set up semantic token highlight links for down LSP
Lsp.setup_semantic_highlights = function()
  local links = {
    ["@lsp.type.namespace.down"] = "@markup.heading",
    ["@lsp.type.macro.down"] = "@tag",
    ["@lsp.type.variable.down"] = "@variable",
    ["@lsp.type.class.down"] = "@markup.link.label",
    ["@lsp.type.function.down"] = "@markup.link.url",
    ["@lsp.type.event.down"] = "@tag",
    ["@lsp.type.string.down"] = "@markup.raw",
    ["@lsp.type.number.down"] = "@number",
    ["@lsp.type.property.down"] = "@property",
    ["@lsp.type.comment.down"] = "@comment",
    ["@lsp.type.keyword.down"] = "@markup.strong",
    ["@lsp.type.modifier.down"] = "@markup.italic",
    ["@lsp.type.type.down"] = "@type",
    ["@lsp.type.regexp.down"] = "@markup.strikethrough",
    ["@lsp.type.decorator.down"] = "@markup.underline",
    ["@lsp.type.label.down"] = "@label",
    ["@lsp.type.operator.down"] = "@markup.math",
    ["@lsp.type.struct.down"] = "@punctuation.delimiter",
    ["@lsp.type.typeParameter.down"] = "@markup.quote",
    ["@lsp.type.interface.down"] = "@markup.link",
    ["@lsp.type.enumMember.down"] = "@constant",
    ["@lsp.type.enum.down"] = "@punctuation",
    ["@lsp.type.mod.deprecated.down"] = "@comment",
    ["@lsp.type.mod.abstract.down"] = "@markup.link",
    ["@lsp.type.mod.link.down"] = "@markup.link",
    ["@lsp.type.mod.declaration.down"] = "@markup.heading",
  }
  for group, link in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end
end

Lsp.setup = function()
  Lsp.setup_semantic_highlights()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = Lsp.config.filetypes,
    callback = function(ev)
      if mod.get_mod("workspace").is_wiki_path(ev.file) then
        Lsp.start(ev.buf)
      end
    end,
    desc = "Start down LSP for markdown files in wiki workspaces",
  })

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

  -- Get plugin root directory from runtime path (lua/down.lua → repo root)
  local runtime = vim.api.nvim_get_runtime_file("lua/down.lua", false)
  local plugin_root = runtime[1] and vim.fn.fnamemodify(runtime[1], ":p:h:h") or nil
  if not plugin_root then
    local script_path = debug.getinfo(1, "S").source:sub(2)
    plugin_root = vim.fn.fnamemodify(script_path, ":p:h:h:h:h")
  end
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

  -- Semantic token support (knowledge-aware highlighting)
  caps.textDocument.semanticTokens = {
    dynamicRegistration = true,
    formats = { "relative" },
    requests = {
      range = true,
      full = { delta = true },
    },
    tokenTypes = {
      "namespace", "macro", "variable", "class", "function", "event",
      "string", "number", "property", "comment", "keyword", "modifier",
      "type", "regexp", "decorator", "label", "operator", "struct",
      "typeParameter", "interface", "enumMember", "enum",
    },
    tokenModifiers = {
      "declaration", "definition", "readonly", "deprecated", "documentation",
      "abstract", "static", "async", "modification", "defaultLibrary",
    },
  }

  -- Inlay hints for knowledge graph annotations
  caps.textDocument.inlayHint = {
    dynamicRegistration = true,
  }

  -- Document link support (wiki links, tags, mentions, embeds)
  caps.textDocument.documentLink = {
    dynamicRegistration = true,
    tooltipSupport = true,
    resolveSupport = { properties = { "tooltip", "target", "range" } },
  }

  -- Linked editing for wiki links, tags, mentions
  caps.textDocument.linkedEditingRange = {
    dynamicRegistration = true,
  }

  -- Code lenses for tasks, workspaces, knowledge graph
  caps.textDocument.codeLens = {
    dynamicRegistration = true,
  }

  -- Hierarchical document symbols (headings, tasks)
  caps.textDocument.documentSymbol = {
    dynamicRegistration = true,
    hierarchicalDocumentSymbolSupport = true,
    symbolKind = {
      valueSet = vim.tbl_values(vim.lsp.protocol.SymbolKind),
    },
  }

  -- Workspace folders and file operations
  caps.workspace = caps.workspace or {}
  caps.workspace.workspaceFolders = true
  caps.workspace.fileOperations = {
    dynamicRegistration = true,
    didCreate = true,
    didRename = true,
    didDelete = true,
    willCreate = true,
    willRename = true,
    willDelete = true,
  }
  caps.workspace.semanticTokens = { refreshSupport = true }

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


--- Check if down LSP is attached to a buffer
---@param bufnr? integer
---@return boolean
Lsp.attached = function(bufnr)
  bufnr = bufnr or 0
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "down" })
  return clients ~= nil and #clients > 0
end

--- Push client settings to the LSP server
Lsp.did_change_configuration = function()
  local client = Lsp.get_client()
  if not client then
    return
  end
  client.notify("workspace/didChangeConfiguration", { settings = Lsp.config.settings })
end

--- Request workspace symbols from the knowledge graph
---@param query string
---@param cb fun(symbols: lsp.SymbolInformation[]|nil, err?: any)
Lsp.workspace_symbols = function(query, cb)
  local client = Lsp.get_client()
  if not client then
    cb(nil, "LSP not running")
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  client.request("workspace/symbol", { query = query or "" }, function(err, result)
    cb(result, err)
  end, bufnr)
end

--- Symbol kinds used by the down LSP server
Lsp.symbol_kinds = {
  tag = vim.lsp.protocol.SymbolKind.Key,
  mention = vim.lsp.protocol.SymbolKind.Variable,
  task = vim.lsp.protocol.SymbolKind.Event,
  document = vim.lsp.protocol.SymbolKind.File,
}

--- Open a picker for workspace symbols (tags, mentions, tasks, or all)
---@param opts? { query?: string, kind?: "tag"|"mention"|"task"|"document", prompt?: string }
Lsp.workspace_symbol_picker = function(opts)
  opts = opts or {}
  local kind_filter = opts.kind and Lsp.symbol_kinds[opts.kind] or nil
  local prompt = opts.prompt
    or ({
      tag = "Tags",
      mention = "Mentions",
      task = "Tasks",
      document = "Documents",
    })[opts.kind]
    or "Workspace symbols"

  Lsp.workspace_symbols(opts.query or "", function(symbols, err)
    if err then
      vim.notify("[down.nvim] workspace/symbol failed: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end
    symbols = symbols or {}
    if kind_filter then
      symbols = vim.tbl_filter(function(sym)
        return sym.kind == kind_filter
      end, symbols)
    end
    if #symbols == 0 then
      vim.notify("[down.nvim] No " .. string.lower(prompt) .. " found", vim.log.levels.INFO)
      return
    end

    vim.ui.select(symbols, {
      prompt = prompt,
      format_item = function(sym)
        local uri = sym.location and sym.location.uri or ""
        local file = uri:gsub("^file://", "")
        local rel = vim.fn.fnamemodify(file, ":t")
        return string.format("%s  %s", sym.name, rel)
      end,
    }, function(choice)
      if not choice or not choice.location then
        return
      end
      local loc = choice.location
      local uri = loc.uri:gsub("^file://", "")
      vim.cmd("edit " .. vim.fn.fnameescape(uri))
      local line = (loc.range.start.line or 0) + 1
      local col = (loc.range.start.character or 0)
      vim.api.nvim_win_set_cursor(0, { line, col })
      vim.cmd("normal! zz")
    end)
  end)
end

--- List workspace tasks via LSP and jump to selection
---@param opts? { filters?: table, prompt?: string }
Lsp.list_tasks = function(opts)
  opts = opts or {}
  local client = Lsp.get_client()
  if not client then
    local task_mod = mod.get_mod("task")
    if task_mod and task_mod.list_tasks then
      task_mod.list_tasks(opts.filters)
    else
      vim.notify("[down.nvim] LSP not running", vim.log.levels.WARN)
    end
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  client.request("workspace/executeCommand", {
    command = "down.task.list",
    arguments = {},
  }, function(err, result)
    if err then
      vim.notify("[down.nvim] task list failed: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end

    local tasks = (result and result.tasks) or {}
    local filters = opts.filters
    if filters then
      if filters.status == "todo" then
        tasks = vim.tbl_filter(function(t)
          return not t.completed
        end, tasks)
      elseif filters.status == "done" then
        tasks = vim.tbl_filter(function(t)
          return t.completed
        end, tasks)
      end
      if filters.overdue then
        local today = os.date("%Y-%m-%d")
        tasks = vim.tbl_filter(function(t)
          local due = (t.text or ""):match("<([%d%-]+)>")
          return due and due < today and not t.completed
        end, tasks)
      end
    end

    if #tasks == 0 then
      vim.notify("[down.nvim] No tasks found in workspace", vim.log.levels.INFO)
      return
    end

    table.sort(tasks, function(a, b)
      if a.completed ~= b.completed then
        return not a.completed
      end
      return (a.line or 0) < (b.line or 0)
    end)

    vim.ui.select(tasks, {
      prompt = opts.prompt or "Workspace tasks",
      format_item = function(task)
        local mark = task.completed and "✓" or "○"
        local uri = (task.uri or ""):gsub("^file://", "")
        local file = vim.fn.fnamemodify(uri, ":t")
        return string.format("%s %s:%d %s  (%s)", mark, file, (task.line or 0) + 1, task.title or task.text or "", file)
      end,
    }, function(choice)
      if not choice or not choice.uri then
        return
      end
      local uri = choice.uri:gsub("^file://", "")
      vim.cmd("edit " .. vim.fn.fnameescape(uri))
      vim.api.nvim_win_set_cursor(0, { (choice.line or 0) + 1, 0 })
      vim.cmd("normal! zz")
    end)
  end, bufnr)
end

--- Follow document link under cursor via LSP
Lsp.open_document_link = function()
  if vim.lsp.buf.document_link then
    vim.lsp.buf.document_link()
    return
  end
  vim.notify("[down.nvim] Document links not available", vim.log.levels.WARN)
end

--- Run a knowledge-graph LSP command and show results in a scratch buffer
---@param sub string
---@param args? string[]
---@return boolean handled
Lsp.knowledge_show = function(sub, args)
  local client = Lsp.get_client()
  if not client then
    return false
  end
  local command = "down.knowledge." .. sub
  local bufnr = vim.api.nvim_get_current_buf()
  client.request("workspace/executeCommand", {
    command = command,
    arguments = args or {},
  }, function(err, result)
    if err then
      vim.notify("[down.nvim] " .. command .. " failed: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end
    local text
    if type(result) == "string" then
      text = result
    elseif type(result) == "table" then
      text = vim.inspect(result)
    else
      text = tostring(result or "")
    end
    if text == "" then
      vim.notify("[down.nvim] " .. command .. " returned no data", vim.log.levels.INFO)
      return
    end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "
"))
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, buf)
    vim.bo[buf].filetype = "markdown"
  end, bufnr)
  return true
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

  for _, client in ipairs(vim.lsp.get_clients({ name = "down", bufnr = bufnr })) do
    return
  end

  local root_dir = vim.fs.root(bufnr, Lsp.config.root_markers) or vim.fn.getcwd()
  local workspace_name = ws and ws.name_for_path and ws.name_for_path(root_dir)

  local client_id
  local existing = vim.lsp.get_clients({ name = "down" })
  if #existing > 0 then
    client_id = existing[1].id
  else
    client_id = vim.lsp.start({
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
  end

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
    ["workspace/semanticTokens/refresh"] = function(_, _, ctx)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if not client or not vim.lsp.semantic_tokens then
        return
      end
      for bufnr, _ in pairs(client.attached_buffers or {}) do
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.lsp.semantic_tokens.enable(true, bufnr)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
              vim.lsp.buf.semantic_tokens_full({ bufnr = bufnr })
            end
          end)
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

  -- Inline suggestion keymaps (ghost text)
  vim.keymap.set("i", "<C-]>", function()
    local ok, inline = pcall(require, "down.mod.edit.inline")
    if ok and inline.accept then inline.accept() end
  end, vim.tbl_extend("force", opts, { desc = "Accept inline suggestion" }))

  vim.keymap.set("i", "<C-g>", function()
    local ok, inline = pcall(require, "down.mod.edit.inline")
    if ok and inline.clear then inline.clear(bufnr) end
  end, vim.tbl_extend("force", opts, { desc = "Dismiss inline suggestion" }))

  -- Enable semantic highlighting
  if client.server_capabilities.semanticTokensProvider and vim.lsp.semantic_tokens then
    vim.lsp.semantic_tokens.enable(true, bufnr)
    vim.lsp.buf.semantic_tokens_full()
  end

  -- Code lenses (tasks, workspaces, tags)
  if client.server_capabilities.codeLensProvider then
    if vim.lsp.codelens and vim.lsp.codelens.on_attach then
      vim.lsp.codelens.on_attach(client, bufnr)
    end
    vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave", "TextChanged" }, {
      buffer = bufnr,
      callback = function()
        if vim.lsp.codelens then
          vim.lsp.codelens.refresh()
        end
      end,
      desc = "Refresh down code lenses",
    })
  end

  -- Sync configuration with server
  Lsp.did_change_configuration()

  -- Follow document links (gx)
  vim.keymap.set("n", "gx", Lsp.open_document_link, vim.tbl_extend("force", opts, { desc = "Follow document link" }))

  -- Task list via LSP
  vim.keymap.set("n", "<leader>dt", function()
    Lsp.list_tasks()
  end, vim.tbl_extend("force", opts, { desc = "List workspace tasks" }))

  -- Refresh semantic tokens on buffer changes
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = bufnr,
    callback = function()
      if client.server_capabilities.semanticTokensProvider then
        vim.defer_fn(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.lsp.buf.semantic_tokens_full()
          end
        end, 300)
      end
    end,
    desc = "Refresh down semantic tokens",
  })

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
    local ws = mod.get_mod("workspace")
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local ft = vim.bo[bufnr].filetype
        if vim.tbl_contains(Lsp.config.filetypes, ft) then
          local bufname = vim.api.nvim_buf_get_name(bufnr)
          if not ws or not ws.is_wiki_path or ws.is_wiki_path(bufname) then
            vim.api.nvim_buf_call(bufnr, function()
              Lsp.attach(bufnr)
            end)
          end
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
      tasks = {
        name = "lsp.tasks",
        args = 0,
        callback = function()
          Lsp.list_tasks()
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

Lsp.handle = {
  workspace = {
    wschanged = function()
      Lsp.reindex()
    end,
  },
}

return Lsp
