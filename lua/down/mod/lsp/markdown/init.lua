local log = require("down.log")
local mod = require("down.mod")

---@class down.mod.lsp.markdown.Markdown: down.Mod
local Markdown = mod.new("lsp.markdown")

---@class down.mod.lsp.markdown.Config
Markdown.config = {
  --- Enable the LSP module (set to false to disable)
  enabled = true,
  --- Enable completion
  completion = true,
  --- Enable semantic tokens
  semantic_tokens = true,
  --- Enable inlay hints
  inlay_hints = true,
  --- Enable hover
  hover = true,
  --- Enable diagnostics
  diagnostics = false,
  --- Enable workspace symbols
  workspace_symbols = true,
  --- Enable frontmatter completion
  frontmatter = true,
}

---@return down.mod.Setup
Markdown.setup = function()
  return {
    loaded = true,
    dependencies = {
      "workspace",
      "tag",
      "link",
      "time",
      "integration.treesitter",
    },
  }
end

---@class down.mod.lsp.markdown.Client
Markdown.client = nil

---@class down.mod.lsp.markdown.Data
Markdown.data = {
  --- Cached workspace files
  files = {},
  --- Cached tags
  tags = {},
  --- Cached backlinks
  backlinks = {},
}

--- Check if buffer is in a workspace
---@param bufnr number
---@return boolean
Markdown.is_workspace_file = function(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == "" then
    return false
  end

  local workspace = Markdown.dep.workspace
  if not workspace then
    log.warn("Workspace dependency not loaded for lsp.markdown")
    return false
  end

  local workspaces = workspace.workspaces()
  if not workspaces or vim.tbl_isempty(workspaces) then
    log.trace("No workspaces configured")
    return false
  end

  for _, ws_path in pairs(workspaces) do
    if vim.startswith(filepath, vim.fs.normalize(vim.fn.expand(ws_path))) then
      return true
    end
  end
  return false
end

--- Get all markdown files in current workspace
---@return string[]
Markdown.get_workspace_files = function()
  local workspace = Markdown.dep.workspace
  local current = workspace.current()
  return workspace.markdown(current) or {}
end

--- Update cached data
Markdown.update_cache = function()
  Markdown.data.files = Markdown.get_workspace_files()
  Markdown.data.tags = Markdown.get_all_tags()
  Markdown.data.backlinks = Markdown.get_backlinks()
end

--- Get all tags from workspace
---@return table<string, down.Tag.Instance[]>
Markdown.get_all_tags = function()
  local tags = {}
  local tag_mod = Markdown.dep.tag

  for _, file in ipairs(Markdown.data.files) do
    local ok, lines = pcall(vim.fn.readfile, file)
    if ok then
      for i, line in ipairs(lines) do
        for tag in line:gmatch("#%S+") do
          if not tags[tag] then
            tags[tag] = {}
          end
          table.insert(tags[tag], {
            tag = tag,
            path = file,
            line = line,
            position = { line = i, char = 0 },
          })
        end
      end
    end
  end

  return tags
end

--- Get backlinks for current file
---@return table<string, string[]>
Markdown.get_backlinks = function()
  local backlinks = {}
  local current_file = vim.fn.expand("%:p")
  local current_name = vim.fn.expand("%:t:r")

  for _, file in ipairs(Markdown.data.files) do
    if file ~= current_file then
      local ok, lines = pcall(vim.fn.readfile, file)
      if ok then
        for _, line in ipairs(lines) do
          if line:match("%[.-%]%(.*" .. vim.pesc(current_name) .. ".*%)")
            or line:match("%[%[" .. vim.pesc(current_name) .. "%]%]") then
            if not backlinks[file] then
              backlinks[file] = {}
            end
            table.insert(backlinks[file], line)
          end
        end
      end
    end
  end

  return backlinks
end

--- Load the module
Markdown.load = function()
  log.info("[lsp.markdown] load() called")

  if not Markdown.config.enabled then
    log.info("[lsp.markdown] Module disabled by config")
    return
  end

  log.info("[lsp.markdown] Starting module load")

  -- Set up autocmd to start LSP client on markdown files in workspaces
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    pattern = "*.md",
    callback = function(ev)
      log.trace("[lsp.markdown] BufEnter triggered for buffer " .. ev.buf)

      if not Markdown.is_workspace_file(ev.buf) then
        log.trace("[lsp.markdown] Buffer is not in workspace, skipping")
        return
      end

      log.info("[lsp.markdown] Starting LSP client for workspace buffer " .. ev.buf)
      Markdown.start_client(ev.buf)
    end,
  })

  log.info("[lsp.markdown] Module loaded and autocmds registered")
end

--- Start LSP client for buffer
---@param bufnr number
Markdown.start_client = function(bufnr)
  -- Check if client already attached to this buffer
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "down-lsp" })
  if #clients > 0 then
    log.trace("[lsp.markdown] LSP client already attached to buffer " .. bufnr)
    return clients[1]
  end

  -- Get workspace root
  local workspace = Markdown.dep.workspace
  local root_dir = workspace.current_path() or vim.fn.getcwd()

  log.info("[lsp.markdown] Starting LSP client with root_dir: " .. root_dir)

  -- Start in-process LSP client
  local client_id = vim.lsp.start({
    name = "down-lsp",
    cmd = function(dispatchers)
      -- Create in-process server using RPC
      return Markdown.create_rpc_server(dispatchers)
    end,
    root_dir = root_dir,
    on_attach = function(client, buf)
      log.info("[lsp.markdown] LSP client attached to buffer " .. buf)
      Markdown.on_attach(client, buf)
    end,
    capabilities = vim.lsp.protocol.make_client_capabilities(),
  }, {
    bufnr = bufnr,
    reuse_client = function(client, conf)
      return client.config.root_dir == conf.root_dir
    end,
  })

  if client_id then
    log.info("[lsp.markdown] LSP client started with id: " .. client_id)
  else
    log.error("[lsp.markdown] Failed to start LSP client")
  end

  return client_id
end

--- Create in-process RPC server
---@param dispatchers table
---@return table
Markdown.create_rpc_server = function(dispatchers)
  log.info("[lsp.markdown] Creating in-process RPC server")

  local server = {}
  local request_id = 0

  -- Handle requests from the LSP client
  server.request = function(method, params, callback)
    request_id = request_id + 1
    local id = request_id

    log.trace("[lsp.markdown] Request: " .. method)

    vim.schedule(function()
      local handler = Markdown.handlers[method]
      if handler then
        local success, result = pcall(handler, params)
        if success then
          callback(nil, result)
        else
          callback({ code = -32603, message = tostring(result) }, nil)
        end
      else
        callback({ code = -32601, message = "Method not found: " .. method }, nil)
      end
    end)

    return true, id
  end

  -- Handle notifications from the LSP client
  server.notify = function(method, params)
    log.trace("[lsp.markdown] Notify: " .. method)

    vim.schedule(function()
      local handler = Markdown.handlers[method]
      if handler then
        pcall(handler, params)
      end
    end)

    return true
  end

  -- Server is ready
  server.is_closing = function()
    return false
  end

  server.terminate = function()
    log.info("[lsp.markdown] Server terminated")
  end

  -- Initialize the server
  vim.schedule(function()
    dispatchers.notification("initialized", {})
  end)

  return server
end

--- LSP method handlers
Markdown.handlers = {}

--- Handle initialize request
Markdown.handlers["initialize"] = function(params)
  log.info("[lsp.markdown] Initialize request")

  return {
    capabilities = {
      completionProvider = {
        triggerCharacters = { "#", "[", "@", ":", "." },
        resolveProvider = false,
      },
      textDocumentSync = {
        openClose = true,
        change = 1, -- Full sync
      },
      hoverProvider = true,
      semanticTokensProvider = {
        legend = {
          tokenTypes = { "keyword", "variable", "string" },
          tokenModifiers = {},
        },
        full = true,
      },
      inlayHintProvider = true,
    },
    serverInfo = {
      name = "down-lsp",
      version = "0.1.0",
    },
  }
end

--- Handle initialized notification
Markdown.handlers["initialized"] = function(params)
  log.info("[lsp.markdown] Initialized")
  Markdown.update_cache()
end

--- Handle textDocument/completion
Markdown.handlers["textDocument/completion"] = function(params)
  local completion = require("down.mod.lsp.markdown.completion")
  return completion.get_items(params)
end

--- Handle textDocument/semanticTokens/full
Markdown.handlers["textDocument/semanticTokens/full"] = function(params)
  local semantic = require("down.mod.lsp.markdown.semantic")
  return semantic.get_tokens(params)
end

--- Handle textDocument/inlayHint
Markdown.handlers["textDocument/inlayHint"] = function(params)
  local hints = require("down.mod.lsp.markdown.hints")
  return hints.get_hints(params.textDocument.uri)
end

--- Handle textDocument/didOpen
Markdown.handlers["textDocument/didOpen"] = function(params)
  log.trace("[lsp.markdown] Document opened: " .. params.textDocument.uri)
  Markdown.update_cache()
end

--- Handle textDocument/didChange
Markdown.handlers["textDocument/didChange"] = function(params)
  log.trace("[lsp.markdown] Document changed")
  Markdown.update_cache()
end

--- Handle textDocument/didSave
Markdown.handlers["textDocument/didSave"] = function(params)
  log.trace("[lsp.markdown] Document saved")
  Markdown.update_cache()
end

--- On attach callback
---@param client vim.lsp.Client
---@param bufnr number
Markdown.on_attach = function(client, bufnr)
  log.info("[lsp.markdown] Attaching to buffer " .. bufnr)

  -- Update cache when buffer changes
  vim.api.nvim_create_autocmd({ "BufWritePost", "TextChanged", "TextChangedI" }, {
    buffer = bufnr,
    callback = function()
      vim.schedule(function()
        Markdown.update_cache()
      end)
    end,
  })

  log.info("[lsp.markdown] Successfully attached to buffer " .. bufnr)
end

return Markdown
