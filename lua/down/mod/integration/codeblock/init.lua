--- integration.codeblock - Zero-dependency code block language detection.
---
--- On cursor-move in markdown files: detects code block language via
--- treesitter, applies indent settings, and conditionally attaches LSP.
--- Uses cached region queries for O(log n) lookup — no tree walk per move.

local log = require ("down.log")
local mod = require ("down.mod")

local api = vim.api
local uv = vim.uv or vim.loop

local CodeBlock = mod.new ("integration.codeblock")

CodeBlock.config = {
  lsp = true,
  indent = true,
  format_on_save = false,
  debounce_ms = 150,
  lsp_detach_delay = 5000,
  virtual_text = true,
  indent_defaults = {
    lua = { ts = 2, sw = 2, et = true },
    python = { ts = 4, sw = 4, et = true },
    py = { ts = 4, sw = 4, et = true },
    go = { ts = 4, sw = 4, et = false },
    rust = { ts = 4, sw = 4, et = true },
    rs = { ts = 4, sw = 4, et = true },
    javascript = { ts = 2, sw = 2, et = true },
    js = { ts = 2, sw = 2, et = true },
    typescript = { ts = 2, sw = 2, et = true },
    ts = { ts = 2, sw = 2, et = true },
    jsx = { ts = 2, sw = 2, et = true },
    tsx = { ts = 2, sw = 2, et = true },
    c = { ts = 4, sw = 4, et = true },
    cpp = { ts = 4, sw = 4, et = true },
    cxx = { ts = 4, sw = 4, et = true },
    ruby = { ts = 2, sw = 2, et = true },
    rb = { ts = 2, sw = 2, et = true },
    bash = { ts = 2, sw = 2, et = true },
    sh = { ts = 2, sw = 2, et = true },
    zsh = { ts = 2, sw = 2, et = true },
    fish = { ts = 2, sw = 2, et = true },
    yaml = { ts = 2, sw = 2, et = true },
    yml = { ts = 2, sw = 2, et = true },
    json = { ts = 2, sw = 2, et = true },
    toml = { ts = 2, sw = 2, et = true },
    html = { ts = 2, sw = 2, et = true },
    css = { ts = 2, sw = 2, et = true },
    scss = { ts = 2, sw = 2, et = true },
    sql = { ts = 2, sw = 2, et = true },
    make = { ts = 8, sw = 8, et = false },
    cmake = { ts = 2, sw = 2, et = true },
    java = { ts = 4, sw = 4, et = true },
    kotlin = { ts = 4, sw = 4, et = true },
    scala = { ts = 2, sw = 2, et = true },
    dart = { ts = 2, sw = 2, et = true },
    swift = { ts = 4, sw = 4, et = true },
    elixir = { ts = 2, sw = 2, et = true },
    erlang = { ts = 4, sw = 4, et = true },
    haskell = { ts = 2, sw = 2, et = true },
    ocaml = { ts = 2, sw = 2, et = true },
    fsharp = { ts = 4, sw = 4, et = true },
    nim = { ts = 2, sw = 2, et = true },
    zig = { ts = 4, sw = 4, et = true },
    php = { ts = 4, sw = 4, et = true },
    r = { ts = 2, sw = 2, et = true },
    vim = { ts = 2, sw = 2, et = true },
    vimscript = { ts = 2, sw = 2, et = true },
    dockerfile = { ts = 2, sw = 2, et = true },
    docker = { ts = 2, sw = 2, et = true },
    nix = { ts = 2, sw = 2, et = true },
    tf = { ts = 2, sw = 2, et = true },
    terraform = { ts = 2, sw = 2, et = true },
    powershell = { ts = 4, sw = 4, et = true },
    pwsh = { ts = 4, sw = 4, et = true },
    perl = { ts = 4, sw = 4, et = true },
    groovy = { ts = 4, sw = 4, et = true },
    graphql = { ts = 2, sw = 2, et = true },
  },
  lsp_configs = {},
  lsp_deny = {
    text = true,
    txt = true,
    plain = true,
    markdown = true,
    md = true,
    json = true,
    yaml = true,
    yml = true,
    toml = true,
    html = true,
    css = true,
    scss = true,
    graphql = true,
    make = true,
    cmake = true,
    dockerfile = true,
    docker = true,
    help = true,
    conf = true,
    ini = true,
    cfg = true,
    diff = true,
    patch = true,
    log = true,
  },
}

-- Per-buffer state
CodeBlock.state = {}

CodeBlock.ft_map = {
  lua = "lua",
  python = "python",
  py = "python",
  bash = "bash",
  sh = "sh",
  zsh = "zsh",
  fish = "fish",
  ruby = "ruby",
  rb = "ruby",
  javascript = "javascript",
  js = "javascript",
  typescript = "typescript",
  ts = "typescript",
  tsx = "typescriptreact",
  jsx = "javascriptreact",
  go = "go",
  rust = "rust",
  rs = "rust",
  perl = "perl",
  php = "php",
  r = "r",
  haskell = "haskell",
  hs = "haskell",
  elixir = "elixir",
  erlang = "erlang",
  c = "c",
  cpp = "cpp",
  cxx = "cpp",
  csharp = "cs",
  cs = "cs",
  powershell = "powershell",
  pwsh = "powershell",
  html = "html",
  css = "css",
  scss = "scss",
  less = "less",
  json = "json",
  jsonc = "jsonc",
  yaml = "yaml",
  yml = "yaml",
  toml = "toml",
  sql = "sql",
  graphql = "graphql",
  make = "make",
  cmake = "cmake",
  java = "java",
  scala = "scala",
  kotlin = "kotlin",
  dart = "dart",
  swift = "swift",
  vim = "vim",
  vimscript = "vim",
  dockerfile = "dockerfile",
  docker = "dockerfile",
  tf = "terraform",
  terraform = "terraform",
  nix = "nix",
  zig = "zig",
  nim = "nim",
  ocaml = "ocaml",
  fsharp = "fsharp",
  groovy = "groovy",
  gleam = "gleam",
  elm = "elm",
  clojure = "clojure",
  clj = "clojure",
  proto = "proto",
  protobuf = "proto",
  systemd = "systemd",
  desktop = "desktop",
}

function CodeBlock.ft_for (lang)
  return CodeBlock.ft_map[lang] or lang
end

-- ─── region caching ────────────────────────────────────────────

--- Scan buffer with treesitter query to cache all fenced_code_block regions.
--- Returns table of { srow, erow, lang } sorted by srow.
---@param bufnr number
---@return table[]|nil
local function build_regions (bufnr)
  if vim.bo[bufnr].filetype ~= "markdown" then
    return nil
  end
  local ok, parser = pcall (vim.treesitter.get_parser, bufnr, "markdown")
  if not ok or not parser then
    return nil
  end
  local tree = parser:parse ()[1]
  if not tree then
    return nil
  end

  local query = vim.treesitter.query.parse (
    "markdown",
    [[
    (fenced_code_block
      (info_string) @info
      (code_fence_content) @content)
  ]]
  )
  if not query then
    return nil
  end

  local regions = {}
  for _, match, _ in
    query:iter_matches (tree:root (), bufnr, 0, -1, { all = true })
  do
    local info_node = nil
    local content_node = nil
    for id, node in pairs (match) do
      local name = query.captures[id]
      if name == "info" then
        info_node = node
      elseif name == "content" then
        content_node = node
      end
    end
    if info_node and content_node then
      local srow, scol, erow, ecol = info_node:range ()
      local lines = api.nvim_buf_get_lines (bufnr, srow, erow + 1, false)
      local raw = ""
      if srow == erow then
        raw = lines[1]:sub (scol + 1, ecol)
      else
        raw = lines[1]:sub (scol + 1)
        for i = 2, #lines - 1 do
          raw = raw .. "\n" .. lines[i]
        end
        raw = raw .. "\n" .. lines[#lines]:sub (1, ecol)
      end
      local lang = raw:match ("^([%w_%-]+)")
      if lang then
        local csrow, _, cerow = content_node:range ()
        regions[#regions + 1] = {
          srow = csrow,
          erow = cerow,
          lang = lang:lower (),
        }
      end
    end
  end

  table.sort (regions, function (a, b)
    return a.srow < b.srow
  end)
  return regions
end

--- Binary search regions for the block containing `line` (0-indexed).
---@param regions table[]
---@param line number
---@return table|nil
local function find_region (regions, line)
  local lo, hi = 1, #regions
  while lo <= hi do
    local mid = math.floor ((lo + hi) / 2)
    local r = regions[mid]
    if line < r.srow then
      hi = mid - 1
    elseif line > r.erow then
      lo = mid + 1
    else
      return r
    end
  end
  return nil
end

--- Get language at cursor line using cached regions. Returns nil if not in a block.
---@param bufnr? number
---@param line? number
---@return string|nil
function CodeBlock.detect (bufnr, line)
  bufnr = bufnr or api.nvim_get_current_buf ()
  if vim.bo[bufnr].filetype ~= "markdown" then
    return nil
  end

  local state = CodeBlock.state[bufnr]
  if not state then
    state = { regions = nil }
    CodeBlock.state[bufnr] = state
  end

  if not state.regions then
    state.regions = build_regions (bufnr)
  end

  if not state.regions or #state.regions == 0 then
    return nil
  end

  line = line or (vim.fn.line (".") - 1)
  local r = find_region (state.regions, line)
  return r and r.lang
end

function CodeBlock.is_inside (bufnr)
  return CodeBlock.detect (bufnr) ~= nil
end

function CodeBlock.get_range (bufnr, line)
  bufnr = bufnr or api.nvim_get_current_buf ()
  local state = CodeBlock.state[bufnr]
  if not state or not state.regions then
    return nil, nil
  end
  line = line or (vim.fn.line (".") - 1)
  local r = find_region (state.regions, line)
  if r then
    return r.srow, r.erow
  end
  return nil, nil
end

--- Invalidate cached regions for a buffer (call on BufWritePost, TextChanged).
---@param bufnr number
function CodeBlock.invalidate (bufnr)
  local state = CodeBlock.state[bufnr]
  if state then
    state.regions = nil
  end
end

-- ─── enter / leave ──────────────────────────────────────────────

function CodeBlock.enter (bufnr, lang)
  if not lang or not api.nvim_buf_is_valid (bufnr) then
    return
  end

  local state = CodeBlock.state[bufnr]
  if not state then
    state = { lsp_clients = {}, active_lang = nil }
    CodeBlock.state[bufnr] = state
  end

  if state.active_lang == lang then
    -- Cancel pending leave timer
    if state.leave_timer then
      state.leave_timer:stop ()
      state.leave_timer = nil
    end
    return
  end

  -- Save markdown defaults (once)
  if not state.saved then
    state.saved = {
      tabstop = vim.bo[bufnr].tabstop,
      shiftwidth = vim.bo[bufnr].shiftwidth,
      expandtab = vim.bo[bufnr].expandtab,
      softtabstop = vim.bo[bufnr].softtabstop,
    }
  end

  local ft = CodeBlock.ft_for (lang)

  -- Indent
  if CodeBlock.config.indent then
    local d = CodeBlock.config.indent_defaults[lang]
      or CodeBlock.config.indent_defaults[ft]
    if d then
      vim.bo[bufnr].tabstop = d.ts
      vim.bo[bufnr].shiftwidth = d.sw
      vim.bo[bufnr].expandtab = d.et
      vim.bo[bufnr].softtabstop = d.sw
    end
  end

  -- LSP
  if
    CodeBlock.config.lsp
    and not CodeBlock.config.lsp_deny[lang]
    and not CodeBlock.config.lsp_deny[ft]
  then
    CodeBlock.attach_lsp (bufnr, ft, lang)
  end

  -- Virtual text indicator
  if CodeBlock.config.virtual_text then
    CodeBlock.show_indicator (bufnr, lang)
  end

  state.active_lang = lang
end

function CodeBlock.leave (bufnr)
  local state = CodeBlock.state[bufnr]
  if not state or not state.active_lang then
    return
  end

  -- Clear virtual text
  if CodeBlock.config.virtual_text then
    CodeBlock.clear_indicator (bufnr)
  end

  -- Restore settings after delay (so rapid in/out doesn't thrash)
  if state.leave_timer then
    state.leave_timer:stop ()
  end
  state.leave_timer = uv.new_timer ()
  if state.leave_timer then
    state.leave_timer:start (CodeBlock.config.lsp_detach_delay, 0, function ()
      state.leave_timer:close ()
      state.leave_timer = nil
      if not api.nvim_buf_is_valid (bufnr) then
        return
      end
      -- Only restore if still outside a block
      if not state.active_lang then
        if state.saved then
          vim.bo[bufnr].tabstop = state.saved.tabstop
          vim.bo[bufnr].shiftwidth = state.saved.shiftwidth
          vim.bo[bufnr].expandtab = state.saved.expandtab
          vim.bo[bufnr].softtabstop = state.saved.softtabstop
          state.saved = nil
        end
        for client_id in pairs (state.lsp_clients) do
          pcall (vim.lsp.buf_detach_client, bufnr, client_id)
        end
        state.lsp_clients = {}
      end
    end)
  end

  state.active_lang = nil
end

-- ─── virtual text indicator ─────────────────────────────────────

function CodeBlock.show_indicator (bufnr, lang)
  local ns = api.nvim_create_namespace ("down_codeblock_lang")
  local line = vim.fn.line (".") - 1
  api.nvim_buf_clear_namespace (bufnr, ns, 0, -1)
  local srow, _ = CodeBlock.get_range (bufnr, line)
  if srow then
    api.nvim_buf_set_extmark (bufnr, ns, srow, 0, {
      virt_text = { { " [" .. lang .. "]", "Comment" } },
      virt_text_pos = "overlay",
      ephemeral = true,
    })
  end
end

function CodeBlock.clear_indicator (bufnr)
  local ns = api.nvim_create_namespace ("down_codeblock_lang")
  api.nvim_buf_clear_namespace (bufnr, ns, 0, -1)
end

-- ─── LSP ────────────────────────────────────────────────────────

local lsp_binaries = {
  lua = "lua-language-server",
  python = "pyright-langserver",
  py = "pyright-langserver",
  go = "gopls",
  rust = "rust-analyzer",
  rs = "rust-analyzer",
  javascript = "typescript-language-server",
  js = "typescript-language-server",
  typescript = "typescript-language-server",
  ts = "typescript-language-server",
  c = "clangd",
  cpp = "clangd",
  cxx = "clangd",
  csharp = "omnisharp",
  cs = "omnisharp",
  ruby = "ruby-lsp",
  rb = "ruby-lsp",
  bash = "bash-language-server",
  sh = "bash-language-server",
  zsh = "bash-language-server",
  sql = "sql-language-server",
  java = "jdtls",
  terraform = "terraform-ls",
  tf = "terraform-ls",
  yaml = "yaml-language-server",
  yml = "yaml-language-server",
  json = "vscode-json-language-server",
  dockerfile = "docker-langserver",
  docker = "docker-langserver",
  vim = "vim-language-server",
  nix = "nil",
  elixir = "elixir-ls",
  gleam = "gleam",
  elm = "elm-language-server",
  erlang = "erlang_ls",
  haskell = "haskell-language-server",
  hs = "haskell-language-server",
  zig = "zls",
  nim = "nimlsp",
  dart = "dart",
  kotlin = "kotlin-language-server",
  scala = "metals",
  swift = "sourcekit-lsp",
  ocaml = "ocamllsp",
  fsharp = "fsautocomplete",
  groovy = "groovy-language-server",
  clojure = "clojure-lsp",
  clj = "clojure-lsp",
  php = "intelephense",
  r = "R",
  protobuf = "buf",
  proto = "buf",
  perl = "perl-language-server",
}

local lsp_fallbacks = {
  ["typescript-language-server"] = { "typescript-language-server", "vtsls" },
  ["ruby-lsp"] = { "ruby-lsp", "solargraph" },
  ["pyright-langserver"] = {
    "pyright-langserver",
    "pyright",
    "jedi-language-server",
  },
  ["clangd"] = { "clangd", "ccls" },
  ["sql-language-server"] = { "sql-language-server", "sqls" },
  ["rust-analyzer"] = { "rust-analyzer", "rls" },
  ["gopls"] = { "gopls", "golangci-lint-lsp" },
  ["lua-language-server"] = { "lua-language-server", "lua-lsp" },
  ["omnisharp"] = { "omnisharp", "omnisharp-mono" },
  ["haskell-language-server"] = {
    "haskell-language-server",
    "haskell-ide-engine",
  },
  ["gleam"] = { "gleam", "gleam-lsp" },
  ["dart"] = { "dart", "dart_language_server" },
  ["R"] = { "R", "languageserver" },
  ["perl-language-server"] = { "perl-language-server", "pls" },
}

local function find_lsp_cmd (lang)
  local binary = lsp_binaries[lang]
  if not binary then
    return nil
  end
  if vim.fn.executable (binary) == 1 then
    return { binary }
  end
  local alts = lsp_fallbacks[binary]
  if alts then
    for _, alt in ipairs (alts) do
      if alt ~= binary and vim.fn.executable (alt) == 1 then
        return { alt }
      end
    end
  end
  return nil
end

--- Find project root by walking up for common markers.
---@param bufnr number
---@return string
local function find_root (bufnr)
  local path = api.nvim_buf_get_name (bufnr)
  local dir = vim.fn.fnamemodify (path, ":p:h")
  local markers = {
    ".git",
    "go.mod",
    "Cargo.toml",
    "package.json",
    "pyproject.toml",
    "Makefile",
    "mix.exs",
    "build.gradle",
    "pom.xml",
    "composer.json",
    "stack.yaml",
    "cabal.project",
    "flake.nix",
    "default.nix",
  }
  for _, m in ipairs (markers) do
    local found = vim.fn.finddir (m, dir .. ";")
    if found ~= "" then
      return vim.fn
        .fnamemodify (vim.fn.fnamemodify (found, ":h"), ":p")
        :gsub ("/$", "")
    end
  end
  return dir
end

function CodeBlock.attach_lsp (bufnr, ft, lang)
  local state = CodeBlock.state[bufnr]
  if not state then
    return
  end

  for _, cf in pairs (state.lsp_clients) do
    if cf == ft then
      return
    end
  end

  -- Try to re-use an already-running client for this filetype
  local active = vim.lsp.get_clients and vim.lsp.get_clients ()
    or vim.lsp.get_active_clients and vim.lsp.get_active_clients ()
    or {}
  for _, client in ipairs (active) do
    if client.config.filetypes then
      for _, cf in ipairs (client.config.filetypes) do
        if cf == ft then
          pcall (vim.lsp.buf_attach_client, bufnr, client.id)
          state.lsp_clients[client.id] = ft
          return
        end
      end
    end
  end

  -- Start a new server
  local cmd = find_lsp_cmd (lang)
  if not cmd then
    return
  end

  local root = find_root (bufnr)
  local config = {
    name = "down-cb-" .. ft,
    cmd = cmd,
    root_dir = root,
    filetypes = { ft },
    single_file_support = true,
    flags = { debounce_text_changes = 150 },
  }

  local override = CodeBlock.config.lsp_configs[lang]
    or CodeBlock.config.lsp_configs[ft]
  if override then
    config = vim.tbl_deep_extend ("force", config, override)
  end

  local client_id = vim.lsp.start (config, { bufnr = bufnr })
  if client_id then
    state.lsp_clients[client_id] = ft
  end
end

-- Try to format code block content on save
function CodeBlock.on_format (bufnr)
  if not CodeBlock.config.format_on_save then
    return
  end
  local state = CodeBlock.state[bufnr]
  if not state or not state.active_lang then
    return
  end
  local srow, erow = CodeBlock.get_range (bufnr)
  if not srow then
    return
  end
  -- Try formatting via attached LSP
  pcall (function ()
    vim.lsp.buf.format ({
      bufnr = bufnr,
      range = {
        ["start"] = { srow, 0 },
        ["end"] = { erow + 1, 0 },
      },
    })
  end)
end

-- ─── cursor movement handler ────────────────────────────────────

function CodeBlock.on_cursor_moved (bufnr)
  local lang = CodeBlock.detect (bufnr)
  local state = CodeBlock.state[bufnr]
  if not state then
    return
  end

  if lang then
    if state.active_lang ~= lang then
      CodeBlock.enter (bufnr, lang)
    end
  else
    if state.active_lang then
      CodeBlock.leave (bufnr)
    end
  end
end

-- ─── autocmds ───────────────────────────────────────────────────

function CodeBlock.setup_autocmds ()
  local aug = api.nvim_create_augroup ("DownCodeBlock", { clear = true })

  -- CursorMoved with timer debounce
  api.nvim_create_autocmd ("CursorMoved", {
    group = aug,
    pattern = "*.md",
    callback = function (args)
      local state = CodeBlock.state[args.buf]
      if not state then
        CodeBlock.state[args.buf] = {}
        state = CodeBlock.state[args.buf]
      end
      if state.debounce then
        state.debounce:stop ()
      end
      state.debounce = uv.new_timer ()
      if state.debounce then
        state.debounce:start (CodeBlock.config.debounce_ms, 0, function ()
          state.debounce:close ()
          state.debounce = nil
          vim.schedule (function ()
            if api.nvim_buf_is_valid (args.buf) then
              CodeBlock.on_cursor_moved (args.buf)
            end
          end)
        end)
      end
    end,
  })

  -- Invalidate cache on changes
  api.nvim_create_autocmd ({ "TextChanged", "TextChangedI", "BufWritePost" }, {
    group = aug,
    pattern = "*.md",
    callback = function (args)
      CodeBlock.invalidate (args.buf)
      vim.schedule (function ()
        if api.nvim_buf_is_valid (args.buf) then
          CodeBlock.on_cursor_moved (args.buf)
        end
      end)
    end,
  })

  -- Format on save
  api.nvim_create_autocmd ("BufWritePre", {
    group = aug,
    pattern = "*.md",
    callback = function (args)
      CodeBlock.on_format (args.buf)
    end,
  })

  -- Cleanup
  api.nvim_create_autocmd ("BufUnload", {
    group = aug,
    pattern = "*.md",
    callback = function (args)
      if CodeBlock.state[args.buf] then
        if CodeBlock.state[args.buf].leave_timer then
          CodeBlock.state[args.buf].leave_timer:stop ()
          CodeBlock.state[args.buf].leave_timer:close ()
        end
        if CodeBlock.state[args.buf].debounce then
          CodeBlock.state[args.buf].debounce:stop ()
          CodeBlock.state[args.buf].debounce:close ()
        end
        CodeBlock.leave (args.buf)
        CodeBlock.state[args.buf] = nil
      end
    end,
  })

  -- Check on enter
  api.nvim_create_autocmd ("BufEnter", {
    group = aug,
    pattern = "*.md",
    callback = function (args)
      if vim.bo[args.buf].filetype == "markdown" then
        vim.schedule (function ()
          CodeBlock.on_cursor_moved (args.buf)
        end)
      end
    end,
  })

  -- Re-check on WinEnter (for split windows)
  api.nvim_create_autocmd ("WinEnter", {
    group = aug,
    pattern = "*.md",
    callback = function ()
      local bufnr = api.nvim_get_current_buf ()
      if vim.bo[bufnr].filetype == "markdown" then
        vim.schedule (function ()
          CodeBlock.on_cursor_moved (bufnr)
        end)
      end
    end,
  })
end

CodeBlock.setup = function ()
  CodeBlock.setup_autocmds ()
  return { loaded = true }
end

CodeBlock.teardown = function ()
  for bufnr, state in pairs (CodeBlock.state) do
    if state.leave_timer then
      state.leave_timer:stop ()
      state.leave_timer:close ()
    end
    if state.debounce then
      state.debounce:stop ()
      state.debounce:close ()
    end
    if state.active_lang then
      pcall (CodeBlock.leave, bufnr)
    end
  end
  CodeBlock.state = {}
  pcall (api.nvim_del_augroup_by_name, "DownCodeBlock")
end

-- ─── public API ─────────────────────────────────────────────────

function CodeBlock.in_codeblock (bufnr)
  return CodeBlock.is_inside (bufnr)
end

function CodeBlock.current_lang (bufnr)
  return CodeBlock.detect (bufnr)
end

--- Get all code block languages and their ranges in the buffer.
---@param bufnr? number
---@return { srow: number, erow: number, lang: string }[]
function CodeBlock.list_blocks (bufnr)
  bufnr = bufnr or api.nvim_get_current_buf ()
  local state = CodeBlock.state[bufnr]
  if not state or not state.regions then
    state = state or {}
    state.regions = build_regions (bufnr)
    CodeBlock.state[bufnr] = state
  end
  return state.regions or {}
end

--- Get the active language for the buffer (nil if cursor not in block).
--- Use this in statusline components.
---@param bufnr? number
---@return string|nil
function CodeBlock.active_lang (bufnr)
  bufnr = bufnr or api.nvim_get_current_buf ()
  local state = CodeBlock.state[bufnr]
  return state and state.active_lang
end

return CodeBlock
