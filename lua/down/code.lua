--- down.code - Discover and run runnable fenced code blocks in markdown.
--- Brings org-mode-style "execute code block" parity to down.nvim, both in the
--- Neovim plugin (via the `down.mod.code` mod) and the `down code` CLI.
---
--- This module is intentionally free of hard `vim` dependencies so it works in
--- the plain-Lua CLI (`scripts/bin/down code`) as well as inside Neovim. When
--- `vim` is available it is used only for notification/output display.

local code = {}

---@class down.code.Block
---@field lang string          info-string language (lowercased), "" if none
---@field info string          full info string after the fence (lang + args)
---@field body string          raw block body (without enclosing fences)
---@field start_line number    1-indexed line of the opening fence
---@field end_line number      1-indexed line of the closing fence
---@field fence string         the fence marker (``` or ~~~)
---@field index number         1-indexed ordinal among all blocks
---@field headers table        parsed org-babel header args (see parse_headers)
---@field name string|nil      block name (header `:name` or preceding `#+name:`)

---@class down.code.RunResult
---@field ok boolean           whether the interpreter exited 0
---@field exit_code number     process exit code (0 when ok)
---@field output string        combined stdout+stderr
---@field lang string          language that was run
---@field command string       the command that was executed
---@field skipped boolean      true when no runner/interpreter was available

---@class down.code.Config
code.config = {
  --- Languages that should never be treated as runnable even if an
  --- interpreter happens to exist on PATH (markup/data languages).
  non_runnable = {
    [""] = true,
    json = true,
    yaml = true,
    yml = true,
    toml = true,
    ini = true,
    html = true,
    css = true,
    scss = true,
    less = true,
    xml = true,
    svg = true,
    markdown = true,
    md = true,
    mdx = true,
    rst = true,
    asciidoc = true,
    text = true,
    txt = true,
    plaintext = true,
    log = true,
    diff = true,
    shell = true,
    console = true,
    dockerfile = true,
    makefile = true,
    gitignore = true,
    gitconfig = true,
    properties = true,
    csv = true,
    tsv = true,
    graphql = true,
    proto = true,
    terraform = true,
    hcl = true,
    vim = true,
    vimdoc = true,
  },
  --- When true, lua blocks that look like Neovim API code (reference `vim.`
  --- or `require` a `down` module) are run with `nvim --headless` so they
  --- have access to the editor API. Only honored when `vim` is present.
  prefer_nvim_for_lua = true,
  --- Per-language runner overrides. Each entry is a function
  ---   fun(block: down.code.Block, tmpfile: string): string?
  --- returning the shell command to run, or nil to fall back to the
  --- built-in runner table. Useful for project-local runners.
  runners = {},
  --- Extra environment variables to set when running blocks (map).
  env = nil,
  --- Working directory for block execution. nil = inherit.
  cwd = nil,
  --- Timeout in seconds for each block (enforced via `timeout`/`gtimeout`
  --- when available, otherwise unbounded).
  timeout = nil,
}

--- Built-in interpreter definitions. Each entry has:
---   ext   string          temp-file extension to write the block as
---   check fun():string|nil resolve the interpreter binary (nil = unavailable)
---   build fun(tmp:string):string  produce the shell command for the temp file
code.builtin_runners = {
  lua = {
    ext = "lua",
    check = function ()
      return code.which ("lua")
        or code.which ("lua5.4")
        or code.which ("lua5.3")
    end,
    build = function (tmp)
      -- Prefer nvim for blocks that use the editor API; this is a no-op in
      -- the plain CLI (no vim) and only triggers when prefer_nvim_for_lua is on.
      if code.config.prefer_nvim_for_lua and code._looks_like_nvim_lua then
        if
          code._looks_like_nvim_lua (code._pending_body or "")
          and code.which ("nvim")
        then
          return 'nvim --headless -u NONE -c "luafile ' .. tmp .. '" -c "qa!"'
        end
      end
      local lua = code.builtin_runners.lua.check ()
      return lua .. " " .. tmp
    end,
  },
  python = {
    ext = "py",
    check = function ()
      return code.which ("python3") or code.which ("python")
    end,
    build = function (tmp)
      return (code.builtin_runners.python.check ()) .. " " .. tmp
    end,
  },
  py = {
    ext = "py",
    check = function ()
      return code.which ("python3") or code.which ("python")
    end,
    build = function (tmp)
      return (code.which ("python3") or code.which ("python")) .. " " .. tmp
    end,
  },
  bash = {
    ext = "sh",
    check = function ()
      return code.which ("bash")
    end,
    build = function (tmp)
      return "bash " .. tmp
    end,
  },
  sh = {
    ext = "sh",
    check = function ()
      return code.which ("sh")
    end,
    build = function (tmp)
      return "sh " .. tmp
    end,
  },
  zsh = {
    ext = "zsh",
    check = function ()
      return code.which ("zsh")
    end,
    build = function (tmp)
      return "zsh " .. tmp
    end,
  },
  fish = {
    ext = "fish",
    check = function ()
      return code.which ("fish")
    end,
    build = function (tmp)
      return "fish " .. tmp
    end,
  },
  ruby = {
    ext = "rb",
    check = function ()
      return code.which ("ruby")
    end,
    build = function (tmp)
      return "ruby " .. tmp
    end,
  },
  rb = {
    ext = "rb",
    check = function ()
      return code.which ("ruby")
    end,
    build = function (tmp)
      return "ruby " .. tmp
    end,
  },
  javascript = {
    ext = "js",
    check = function ()
      return code.which ("node")
    end,
    build = function (tmp)
      return "node " .. tmp
    end,
  },
  js = {
    ext = "js",
    check = function ()
      return code.which ("node")
    end,
    build = function (tmp)
      return "node " .. tmp
    end,
  },
  typescript = {
    ext = "ts",
    check = function ()
      return code.which ("ts-node") or code.which ("tsx")
    end,
    build = function (tmp)
      if code.which ("ts-node") then
        return "ts-node " .. tmp
      end
      if code.which ("npx") then
        return "npx -y tsx " .. tmp
      end
      return "tsx " .. tmp
    end,
  },
  ts = {
    ext = "ts",
    check = function ()
      return code.which ("ts-node") or code.which ("tsx") or code.which ("npx")
    end,
    build = function (tmp)
      if code.which ("ts-node") then
        return "ts-node " .. tmp
      end
      if code.which ("npx") then
        return "npx -y tsx " .. tmp
      end
      return "tsx " .. tmp
    end,
  },
  go = {
    ext = "go",
    check = function ()
      return code.which ("go")
    end,
    build = function (tmp)
      return "go run " .. tmp
    end,
  },
  rust = {
    ext = "rs",
    check = function ()
      return code.which ("rustc")
    end,
    build = function (tmp)
      local out = tmp:gsub ("%.rs$", "")
      return "rustc -O -o "
        .. out
        .. " "
        .. tmp
        .. " && "
        .. out
        .. " ; rm -f "
        .. out
    end,
  },
  rs = {
    ext = "rs",
    check = function ()
      return code.which ("rustc")
    end,
    build = function (tmp)
      local out = tmp:gsub ("%.rs$", "")
      return "rustc -O -o "
        .. out
        .. " "
        .. tmp
        .. " && "
        .. out
        .. " ; rm -f "
        .. out
    end,
  },
  perl = {
    ext = "pl",
    check = function ()
      return code.which ("perl")
    end,
    build = function (tmp)
      return "perl " .. tmp
    end,
  },
  php = {
    ext = "php",
    check = function ()
      return code.which ("php")
    end,
    build = function (tmp)
      return "php " .. tmp
    end,
  },
  r = {
    ext = "R",
    check = function ()
      return code.which ("Rscript")
    end,
    build = function (tmp)
      return "Rscript " .. tmp
    end,
  },
  rscript = {
    ext = "R",
    check = function ()
      return code.which ("Rscript")
    end,
    build = function (tmp)
      return "Rscript " .. tmp
    end,
  },
  julia = {
    ext = "jl",
    check = function ()
      return code.which ("julia")
    end,
    build = function (tmp)
      return "julia " .. tmp
    end,
  },
  awk = {
    ext = "awk",
    check = function ()
      return code.which ("awk")
    end,
    build = function (tmp)
      return "awk -f " .. tmp
    end,
  },
  scheme = {
    ext = "scm",
    check = function ()
      return code.which ("guile") or code.which ("gosh")
    end,
    build = function (tmp)
      if code.which ("guile") then
        return "guile -s " .. tmp
      end
      return "gosh " .. tmp
    end,
  },
  clojure = {
    ext = "clj",
    check = function ()
      return code.which ("clojure")
    end,
    build = function (tmp)
      return "clojure " .. tmp
    end,
  },
  haskell = {
    ext = "hs",
    check = function ()
      return code.which ("runghc") or code.which ("runhaskell")
    end,
    build = function (tmp)
      if code.which ("runghc") then
        return "runghc " .. tmp
      end
      return "runhaskell " .. tmp
    end,
  },
  hs = {
    ext = "hs",
    check = function ()
      return code.which ("runghc") or code.which ("runhaskell")
    end,
    build = function (tmp)
      if code.which ("runghc") then
        return "runghc " .. tmp
      end
      return "runhaskell " .. tmp
    end,
  },
  elixir = {
    ext = "exs",
    check = function ()
      return code.which ("elixir")
    end,
    build = function (tmp)
      return "elixir " .. tmp
    end,
  },
  erlang = {
    ext = "erl",
    check = function ()
      return code.which ("escript")
    end,
    build = function (tmp)
      return "escript " .. tmp
    end,
  },
  powershell = {
    ext = "ps1",
    check = function ()
      return code.which ("pwsh") or code.which ("powershell")
    end,
    build = function (tmp)
      return (code.which ("pwsh") or "powershell") .. " -File " .. tmp
    end,
  },
  pwsh = {
    ext = "ps1",
    check = function ()
      return code.which ("pwsh")
    end,
    build = function (tmp)
      return "pwsh -File " .. tmp
    end,
  },
}

--- Heuristic: does a lua block look like Neovim API code?
---@param body string
---@return boolean
function code._looks_like_nvim_lua (body)
  if not body then
    return false
  end
  if body:match ("%Wvim%.") then
    return true
  end
  if body:match ("require%s*%(%s*['\"]down") then
    return true
  end
  if body:match ("require%s*['\"]down") then
    return true
  end
  return false
end

--- `command -v` lookup that works without `vim.fn`.
---@param name string
---@return string|nil
function code.which (name)
  if not name or name == "" then
    return nil
  end
  if vim and vim.fn and vim.fn.executable then
    if vim.fn.executable (name) == 1 then
      return name
    end
    return nil
  end
  local h = io.popen ("command -v " .. name .. " 2>/dev/null")
  if not h then
    return nil
  end
  local r = h:read ("*l")
  h:close ()
  if r and r ~= "" then
    return r
  end
  return nil
end

--- Resolve the runner for a language.
---@param lang string
---@return table|nil
function code.runner_for (lang)
  lang = (lang or ""):lower ()
  if code.config.non_runnable[lang] then
    return nil
  end
  local override = code.config.runners[lang]
  if type (override) == "table" and override.build then
    return override
  end
  return code.builtin_runners[lang]
end

--- Is a language considered runnable (runner exists AND interpreter present)?
---@param lang string
---@return boolean
function code.is_runnable (lang)
  local r = code.runner_for (lang)
  if not r then
    return false
  end
  if r.check then
    return r.check () ~= nil
  end
  return true
end

--- Parse fenced code blocks from markdown text.
--- Handles ``` and ~~~ fences (CommonMark-ish), including indented fences
--- (up to 3 leading spaces) and info strings. Returns blocks in document order.
---@param text string
---@return down.code.Block[]
function code.parse_blocks (text)
  local blocks = {}
  local lines = {}
  for ln in (text or ""):gmatch ("([^\n]*)\n?") do
    lines[#lines + 1] = ln
  end
  -- handle trailing newline-less last line
  if #lines > 0 and lines[#lines] == "" and (text or ""):sub (-1) ~= "\n" then
    lines[#lines] = nil
  end

  local i = 1
  local idx = 0
  while i <= #lines do
    local line = lines[i]
    -- a fence line: up to 3 leading spaces, then 3+ backticks or tildes.
    -- Lua patterns have no alternation/`{n,}`, so detect the fence char run
    -- manually.
    local indent = line:match ("^(%s*)") or ""
    if #indent <= 3 then
      local rest = line:sub (#indent + 1)
      local ch = rest:sub (1, 1)
      if ch == "`" or ch == "~" then
        local run = rest:match ("^(" .. ch .. ch .. ch .. ch .. "+)")
          or rest:match ("(" .. ch .. ch .. ch .. ")")
        -- `run` is the fence marker (3+ of `ch`); capture length >= 3
        if run and #run >= 3 then
          local fence_len = #run
          local info = rest:sub (#run + 1)
          -- strip trailing whitespace/carriage return from info
          info = info:gsub ("%s+$", ""):gsub ("\r$", "")
          local lang = info:match ("^%s*([%w_-]+)") or ""
          lang = lang:lower ()
          local body_lines = {}
          local start_line = i
          local j = i + 1
          local closed = false
          while j <= #lines do
            local bl = lines[j]
            local bi = bl:match ("^(%s*)") or ""
            if #bi <= #indent then
              local brest = bl:sub (#bi + 1)
              local brun = brest:match ("^(" .. ch .. ch .. ch .. ch .. "+)")
                or brest:match ("(" .. ch .. ch .. ch .. ")")
              if
                brun
                and #brun >= fence_len
                and brest:sub (#brun + 1):match ("^%s*$")
              then
                closed = true
                break
              end
            end
            body_lines[#body_lines + 1] = bl
            j = j + 1
          end
          idx = idx + 1
          local headers = code.parse_headers (info)
          local name = headers.name
          if not name and i > 1 then
            local prev = lines[i - 1] or ""
            name = prev:match ("^%s*#%+name:%s*(%S+)")
              or prev:match ("^%s*<!--%s*down:name:%s*(%S+)%s*-->%s*$")
          end
          blocks[#blocks + 1] = {
            lang = lang,
            info = info,
            body = table.concat (body_lines, "\n"),
            start_line = start_line,
            end_line = closed and j or (#lines + 1),
            fence = run,
            index = idx,
            headers = headers,
            name = name,
          }
          i = (closed and j or #lines) + 1
        else
          i = i + 1
        end
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end
  return blocks
end

--- Read a file's contents (io.popen-free path when possible).
---@param path string
---@return string|nil
function code.read_file (path)
  local f = io.open (path, "rb")
  if not f then
    return nil
  end
  local data = f:read ("*a")
  f:close ()
  return data
end

--- Parse blocks from a file on disk.
---@param path string
---@return down.code.Block[]|nil
function code.blocks_in_file (path)
  local data = code.read_file (path)
  if not data then
    return nil
  end
  return code.parse_blocks (data)
end

--- Split text into a 1-indexed array of lines (no trailing empty for a
--- final newline; an empty string yields an empty table).
---@param s string
---@return string[]
function code.split_lines (s)
  s = s or ""
  local t = {}
  local i = 1
  while i <= #s do
    local j = s:find ("\n", i, true) or (#s + 1)
    t[#t + 1] = s:sub (i, j - 1)
    i = j + 1
  end
  return t
end

--- Parse org-babel-style header args from a fence info string.
--- `info` is the full text after the fence marker, e.g.
--- `python :tangle out.py :var x=2 :results output :noweb yes :name foo`.
--- The first token (the language) is skipped. Header keys are lowercased.
---@param info string
---@return table  { vars = {name=value}, tangle, mkdirp, results, session, noweb, name, ... }
function code.parse_headers (info)
  local h = {
    vars = {},
    tangle = nil,
    mkdirp = false,
    results = "default",
    session = nil,
    noweb = false,
    name = nil,
  }
  if not info or info == "" then
    return h
  end
  -- tokenize on whitespace, keeping quoted strings intact
  local tokens = {}
  local i = 1
  local s = info
  while i <= #s do
    while i <= #s and s:sub (i, i):match ("%s") do
      i = i + 1
    end
    if i > #s then
      break
    end
    local tok
    if s:sub (i, i) == '"' or s:sub (i, i) == "'" then
      local q = s:sub (i, i)
      local j = i + 1
      while j <= #s and s:sub (j, j) ~= q do
        j = j + 1
      end
      tok = s:sub (i + 1, j - 1)
      i = j + 1
    else
      local j = i
      while j <= #s and not s:sub (j, j):match ("%s") do
        j = j + 1
      end
      tok = s:sub (i, j - 1)
      i = j
    end
    tokens[#tokens + 1] = tok
  end
  -- first token is the language; parse remaining `:key [value]` pairs
  local k = 2
  while k <= #tokens do
    local t = tokens[k]
    if t:sub (1, 1) == ":" then
      local key = t:sub (2):lower ()
      local nxt = tokens[k + 1]
      if nxt and nxt:sub (1, 1) ~= ":" then
        h[key] = nxt
        k = k + 2
        if key == "var" then
          local nm, v = nxt:match ("^([^=]+)=(.*)$")
          if nm then
            h.vars[nm] = code._coerce_var (v)
          end
        end
      else
        h[key] = "yes"
        k = k + 1
      end
    else
      k = k + 1
    end
  end
  h.mkdirp = h.mkdirp == "yes" or h.mkdirp == "true"
  h.noweb = h.noweb == "yes" or h.noweb == "true" or h.noweb == "tangle"
  if h.name then
    h.name = tostring (h.name)
  end
  return h
end

--- Coerce a `:var` value string into a typed Lua value.
---@param v string
---@return any
function code._coerce_var (v)
  if v == nil then
    return nil
  end
  if v == "true" then
    return true
  end
  if v == "false" then
    return false
  end
  local n = tonumber (v)
  if n then
    return n
  end
  return v
end

--- Resolve a block's name (header `:name` takes precedence over a preceding
--- `#+name:` / `<!-- down:name: -->` line).
---@param block down.code.Block
---@return string|nil
function code.block_name (block)
  if not block then
    return nil
  end
  if block.headers and block.headers.name then
    return block.headers.name
  end
  return block.name
end

--- Build a name -> block index for noweb references.
---@param blocks down.code.Block[]
---@return table<string, down.code.Block>
function code.index_by_name (blocks)
  local m = {}
  for _, b in ipairs (blocks or {}) do
    local n = code.block_name (b)
    if n then
      m[n] = b
    end
  end
  return m
end

--- Expand org-babel noweb references `<<name>>` in a body using a name index.
--- Unresolved references are left untouched.
---@param body string
---@param by_name table<string, down.code.Block>
---@return string
function code.expand_noweb (body, by_name)
  if not body or not by_name then
    return body
  end
  return (
    body:gsub ("<<%s*([%w_-]+)%s*>>", function (n)
      local ref = by_name[n]
      if ref and ref.body then
        return ref.body
      end
      return "<<" .. n .. ">>"
    end)
  )
end

--- Language-specific variable assignment syntax for `:var` injection.
---@param lang string
---@return fun(name: string, value: any):string
function code.var_formatter (lang)
  local function q (s)
    return '"' .. tostring (s):gsub ('"', '\\"') .. '"'
  end
  local function lit (v)
    if type (v) == "string" then
      return q (v)
    end
    return tostring (v)
  end
  local formatters = {
    python = function (name, v)
      if type (v) == "boolean" then
        return name .. " = " .. (v and "True" or "False")
      end
      return name .. " = " .. lit (v)
    end,
    py = function (name, v)
      return code.var_formatter ("python") (name, v)
    end,
    lua = function (name, v)
      if type (v) == "boolean" then
        return name .. " = " .. tostring (v)
      end
      if type (v) == "string" then
        return name .. " = " .. q (v)
      end
      return name .. " = " .. tostring (v)
    end,
    bash = function (name, v)
      if type (v) == "boolean" then
        return name .. "=" .. (v and "true" or "false")
      end
      if type (v) == "number" then
        return name .. "=" .. tostring (v)
      end
      return name .. "='" .. tostring (v):gsub ("'", "'\\''") .. "'"
    end,
    sh = function (name, v)
      return code.var_formatter ("bash") (name, v)
    end,
    zsh = function (name, v)
      return code.var_formatter ("bash") (name, v)
    end,
    fish = function (name, v)
      if type (v) == "string" then
        return "set " .. name .. " " .. q (v)
      end
      return "set " .. name .. " " .. tostring (v)
    end,
    javascript = function (name, v)
      if type (v) == "boolean" then
        return "let " .. name .. " = " .. tostring (v)
      end
      return "let " .. name .. " = " .. lit (v)
    end,
    js = function (name, v)
      return code.var_formatter ("javascript") (name, v)
    end,
    typescript = function (name, v)
      return code.var_formatter ("javascript") (name, v)
    end,
    ts = function (name, v)
      return code.var_formatter ("javascript") (name, v)
    end,
    ruby = function (name, v)
      if type (v) == "boolean" then
        return name .. " = " .. tostring (v)
      end
      return name .. " = " .. lit (v)
    end,
    rb = function (name, v)
      return code.var_formatter ("ruby") (name, v)
    end,
    go = function (name, v)
      if type (v) == "string" then
        return name .. ' := "' .. tostring (v):gsub ('"', '\\"') .. '"'
      end
      return name .. " := " .. tostring (v)
    end,
    perl = function (name, v)
      if type (v) == "string" then
        return "my $" .. name .. " = " .. q (v) .. ";"
      end
      return "my $" .. name .. " = " .. tostring (v) .. ";"
    end,
  }
  return formatters[lang]
    or function (name, v)
      -- unknown language: drop a comment so the block still runs unmodified
      return "# down:var " .. name .. " = " .. tostring (v)
    end
end

--- Prepend `:var` assignments (language-specific) to a body.
---@param body string
---@param lang string
---@param vars table<string, any>
---@return string
function code.inject_vars (body, lang, vars)
  if not vars or not next (vars) then
    return body
  end
  local fmt = code.var_formatter (lang)
  local pre = {}
  for name, v in pairs (vars) do
    pre[#pre + 1] = fmt (name, v)
  end
  if #pre == 0 then
    return body
  end
  return table.concat (pre, "\n") .. "\n" .. (body or "")
end

--- Produce the executable body for a block: noweb expansion + var injection.
---@param block down.code.Block
---@param opts? { blocks?: down.code.Block[] }
---@return string
function code.prepare_block (block, opts)
  opts = opts or {}
  local body = block.body or ""
  local h = block.headers or code.parse_headers (block.info)
  local by_name = opts.blocks and code.index_by_name (opts.blocks) or nil
  if by_name and (h.noweb or body:match ("<<%s*[%w_-]+%s*>>")) then
    body = code.expand_noweb (body, by_name)
  end
  if h.vars and next (h.vars) then
    body = code.inject_vars (body, block.lang, h.vars)
  end
  return body
end

--- Resolve the tangle target path for a block, or nil if it isn't tangled.
--- `:tangle yes` derives a name from `source_path` + the language extension.
---@param block down.code.Block
---@param source_path? string
---@return string|nil
function code.tangle_target (block, source_path)
  local h = block.headers or code.parse_headers (block.info)
  local t = h.tangle
  if not t then
    return nil
  end
  if t == "yes" or t == "true" then
    local base = "tangled"
    if source_path then
      base = source_path:match ("([^/]+)%.[^./]+$")
        or source_path:match ("([^/]+)$")
        or base
    end
    local r = code.runner_for (block.lang)
    local ext = (r and r.ext) or block.lang or "txt"
    return base .. "." .. ext
  end
  return t
end

--- Tangle every block in `text` that carries a `:tangle` header into files.
--- Returns the list of written paths. noweb expansion is applied when
--- `:noweb tangle`/`yes` is set on a block (or when a reference resolves).
---@param text string
---@param source_path? string
---@param opts? { dir?: string }
---@return string[]  written paths
function code.tangle_text (text, source_path, opts)
  opts = opts or {}
  local blocks = code.parse_blocks (text)
  local written = {}
  for _, b in ipairs (blocks) do
    local target = code.tangle_target (b, source_path)
    if target then
      local h = b.headers or code.parse_headers (b.info)
      if opts.dir and not target:match ("^/") then
        target = opts.dir .. "/" .. target
      end
      local body = code.prepare_block (b, { blocks = blocks })
      local dir = target:match ("^(.*)/[^/]+$")
      if dir and (h.mkdirp or opts.dir) then
        os.execute ("mkdir -p '" .. dir .. "' 2>/dev/null")
      end
      local f = io.open (target, "wb")
      if f then
        f:write (body)
        f:close ()
        written[#written + 1] = target
      end
    end
  end
  return written
end

--- Tangle a file's blocks into files. Returns the list of written paths.
---@param path string
---@param opts? { dir?: string }
---@return string[]|nil
function code.tangle_file (path, opts)
  local text = code.read_file (path)
  if not text then
    return nil
  end
  return code.tangle_text (text, path, opts)
end

--- Is `block` a down results block (fenced with a `:down_result` marker)?
---@param block down.code.Block
---@return boolean
function code.is_result_block (block)
  return block ~= nil
    and block.info ~= nil
    and block.info:find (":down_result", 1, true) ~= nil
end
--- Extract the result name from a result block's info string.
---@param block down.code.Block
---@return string|nil
function code.result_name (block)
  if not block or not block.info then
    return nil
  end
  return (block.info:match (":down_result%s+(%S+)"))
end

--- Build the fenced result block lines for a run result.
---@param block down.code.Block  the source block (for naming)
---@param result down.code.RunResult
---@return string[]  lines including opening/closing fences
function code.result_lines (block, result)
  local name = code.block_name (block) or ("#" .. block.index)
  local info = "text :down_result " .. name
  local lines = { "```" .. info }
  local out = (result and result.output) or ""
  if out ~= "" then
    for _, ln in ipairs (code.split_lines (out)) do
      lines[#lines + 1] = ln
    end
  end
  lines[#lines + 1] = "```"
  return lines
end

--- Replace 1-indexed inclusive range [a, b] of `lines` with `new` (an array).
---@param lines string[]
---@param a number
---@param b number
---@param new string[]
local function replace_slice (lines, a, b, new)
  local n = b - a + 1
  for _ = 1, n do
    table.remove (lines, a)
  end
  for i = #new, 1, -1 do
    table.insert (lines, a, new[i])
  end
end

--- Insert `new` before 1-indexed line `pos` of `lines`.
---@param lines string[]
---@param pos number
---@param new string[]
local function insert_before (lines, pos, new)
  for i = #new, 1, -1 do
    table.insert (lines, pos, new[i])
  end
end

--- Apply run results back into markdown text, inserting or replacing
--- `:down_result` blocks beneath each source block. `results_map` is keyed
--- by block index (1-indexed). Pure string transform (no vim needed).
---@param text string
---@param results_map table<number, down.code.RunResult>
---@return string
function code.apply_results (text, results_map)
  local blocks = code.parse_blocks (text)
  local lines = code.split_lines (text)
  for i = #blocks, 1, -1 do
    local b = blocks[i]
    local r = results_map[b.index]
    if r and not r.skipped then
      local ridx = nil
      if blocks[i + 1] and code.is_result_block (blocks[i + 1]) then
        ridx = i + 1
      else
        local name = code.block_name (b)
        for k = i + 1, #blocks do
          if code.is_result_block (blocks[k]) then
            if not name or code.result_name (blocks[k]) == name then
              ridx = k
            end
            break
          end
        end
      end
      local new_lines = code.result_lines (b, r)
      if ridx then
        local rb = blocks[ridx]
        replace_slice (lines, rb.start_line, rb.end_line, new_lines)
      else
        insert_before (lines, b.end_line + 1, { "" })
        insert_before (lines, b.end_line + 2, new_lines)
      end
    end
  end
  return table.concat (lines, "\n")
end

--- Write a temp file for a block body and return its path.
---@param block down.code.Block
---@param body? string  body to write (defaults to block.body)
---@return string|nil
local function write_temp (block, body)
  local r = code.runner_for (block.lang)
  if not r then
    return nil
  end
  local ext = r.ext or block.lang or "txt"
  -- os.tmpname gives a path we control; append ext for interpreter hints.
  local base = os.tmpname ()
  local tmp = base .. "." .. ext
  local f = io.open (tmp, "wb")
  if not f then
    if base then
      os.remove (base)
    end
    return nil
  end
  f:write (body or block.body)
  f:close ()
  return tmp
end

--- Run a single block. Writes the (noweb-expanded, var-injected) body to a
--- temp file, invokes the runner, captures combined output, cleans up.
---@param block down.code.Block
---@param opts? { dry_run?: boolean, cwd?: string, env?: table, blocks?: down.code.Block[] }
---@return down.code.RunResult
function code.run_block (block, opts)
  opts = opts or {}
  local r = code.runner_for (block.lang)
  if not r then
    return {
      ok = false,
      exit_code = -1,
      output = "",
      lang = block.lang,
      command = "",
      skipped = true,
    }
  end
  local interp = r.check and r.check () or nil
  if r.check and not interp then
    return {
      ok = false,
      exit_code = -1,
      output = "",
      lang = block.lang,
      command = "",
      skipped = true,
    }
  end

  local body = code.prepare_block (block, { blocks = opts.blocks })
  local tmp = write_temp (block, body)
  if not tmp then
    return {
      ok = false,
      exit_code = -1,
      output = "",
      lang = block.lang,
      command = "",
      skipped = true,
    }
  end

  -- expose body to the lua runner's nvim heuristic
  code._pending_body = body
  local cmd = r.build (tmp)
  code._pending_body = nil
  if not cmd or cmd == "" then
    os.remove (tmp)
    return {
      ok = false,
      exit_code = -1,
      output = "",
      lang = block.lang,
      command = "",
      skipped = true,
    }
  end

  if opts.cwd then
    cmd = "cd " .. opts.cwd .. " && " .. cmd
  end
  if opts.env then
    local prefix = {}
    for k, v in pairs (opts.env) do
      prefix[#prefix + 1] = k .. "='" .. tostring (v):gsub ("'", "'\\''") .. "'"
    end
    if #prefix > 0 then
      cmd = table.concat (prefix, " ") .. " " .. cmd
    end
  end
  if code.config.timeout and code.which ("timeout") then
    cmd = "timeout " .. tostring (code.config.timeout) .. " " .. cmd
  end

  if opts.dry_run then
    os.remove (tmp)
    return {
      ok = true,
      exit_code = 0,
      output = "",
      lang = block.lang,
      command = cmd,
      skipped = false,
    }
  end

  -- capture stderr too (2>&1) so users see everything in one place
  local h = io.popen (cmd .. ' 2>&1; echo "\\n__DOWN_EXIT:$?"')
  local out = ""
  local exit_code = 0
  if h then
    out = h:read ("*a")
    h:close ()
    local ec = out:match ("__DOWN_EXIT:(%d+)%s*$")
    if ec then
      exit_code = tonumber (ec) or 0
      out = out:gsub ("%s*__DOWN_EXIT:%d+%s*$", "")
    end
  end
  os.remove (tmp)

  return {
    ok = exit_code == 0,
    exit_code = exit_code,
    output = out,
    lang = block.lang,
    command = cmd,
    skipped = false,
  }
end

--- Run all runnable blocks in a markdown file.
---@param path string
---@param opts? {lang?: string, dry_run?: boolean, cwd?: string, env?: table, on_result?: fun(block, result)}
---@return down.code.RunResult[]
function code.run_file (path, opts)
  opts = opts or {}
  local blocks = code.blocks_in_file (path)
  if not blocks then
    return {}
  end
  local run_opts =
    { dry_run = opts.dry_run, cwd = opts.cwd, env = opts.env, blocks = blocks }
  local results = {}
  for _, b in ipairs (blocks) do
    if opts.lang and b.lang ~= opts.lang:lower () then
      -- filter by language when requested
    elseif code.is_runnable (b.lang) then
      local res = code.run_block (b, run_opts)
      results[#results + 1] = res
      if opts.on_result then
        opts.on_result (b, res)
      end
    end
  end
  return results
end

--- Pretty-print a result (CLI friendly). Uses print().
---@param block down.code.Block
---@param result down.code.RunResult
local function print_result (block, result)
  local header = string.format (
    "▶ [%s] block #%d (line %d)",
    block.lang,
    block.index,
    block.start_line
  )
  print (header)
  if result.skipped then
    print ("  skipped (no runner or interpreter unavailable)")
    return
  end
  if result.output and result.output ~= "" then
    -- indent output for readability
    for ln in (result.output):gmatch ("([^\n]*)") do
      print ("  " .. ln)
    end
  end
  if result.ok then
    print ("  ✓ exit 0")
  else
    print (string.format ("  ✗ exit %d", result.exit_code))
  end
end

--- CLI entry point for `down code [options] <file>` and
--- `down code tangle [options] <file>`.
---@param args string[]
function code.cli (args)
  args = args or {}
  local sub = nil
  if args[1] == "tangle" then
    sub = "tangle"
    table.remove (args, 1)
  end
  local file = nil
  local lang_filter = nil
  local dry_run = false
  local list_only = false
  local do_results = false
  local tangle_dir = nil
  local i = 1
  while i <= #args do
    local a = args[i]
    if a == "--lang" or a == "-l" then
      i = i + 1
      lang_filter = args[i]
    elseif a and a:match ("^%-%-lang=") then
      lang_filter = (a:gsub ("^%-%-lang=", ""))
    elseif a == "--dry-run" then
      dry_run = true
    elseif a == "--list" then
      list_only = true
    elseif a == "--results" then
      do_results = true
    elseif a == "--dir" or a == "-d" then
      i = i + 1
      tangle_dir = args[i]
    elseif a == "--timeout" then
      i = i + 1
      code.config.timeout = tonumber (args[i])
    elseif a == "--cwd" then
      i = i + 1
      code.config.cwd = args[i]
    elseif a == "--help" or a == "-h" then
      print ([[down code - org-babel-style code block execution for markdown

Usage:
  down code [options] <file>          Run runnable fenced blocks
  down code tangle [options] <file>   Write `:tangle` blocks to files

Header args (in the fence info string):
  :tangle FILE|yes    Write this block to FILE (`yes` => <source>.<ext>)
  :mkdirp yes          Create parent dirs when tangling
  :var NAME=VALUE      Inject a variable (string/number/bool) before running
  :noweb yes|tangle    Expand `<<name>>` references from named blocks
  :name NAME           Name this block for noweb references

Options:
  -l, --lang LANG      Only run blocks of this language
  --list               List blocks without executing
  --dry-run            Print the command that would run, don't execute
  --results            Write/replace `:down_result` blocks into the file
  -d, --dir DIR        Tangle output directory (relative paths resolve here)
  --timeout SECS       Kill a block after SECS seconds (needs `timeout`)
  --cwd DIR            Run blocks in this directory
  -h, --help           Show this help]])
      return
    elseif a and a:sub (1, 1) ~= "-" then
      file = a
    end
    i = i + 1
  end

  if not file then
    print ("Usage: down code [tangle] [options] <file>")
    print ("Run `down code --help` for details.")
    os.exit (1)
  end

  local blocks = code.blocks_in_file (file)
  if not blocks then
    io.stderr:write ("down code: cannot read " .. file .. "\n")
    os.exit (1)
  end

  if sub == "tangle" then
    local written =
      code.tangle_text (code.read_file (file) or "", file, { dir = tangle_dir })
    if #written == 0 then
      print ("No `:tangle` blocks found in " .. file)
    else
      for _, p in ipairs (written) do
        print ("tangled -> " .. p)
      end
      print (string.format ("\n%d file(s) tangled", #written))
    end
    return
  end

  if list_only then
    print (string.format ("%s: %d fenced block(s)", file, #blocks))
    for _, b in ipairs (blocks) do
      local runnable = code.is_runnable (b.lang)
      local mark = runnable and "▶" or " "
      local nm = code.block_name (b)
      local tail = nm and (" name=" .. nm) or ""
      print (
        string.format (
          "  %s [%s] #%d line %d%s",
          mark,
          b.lang,
          b.index,
          b.start_line,
          tail
        )
      )
    end
    return
  end

  local results_map = {}
  local ran = 0
  local failed = 0
  for _, b in ipairs (blocks) do
    if (not lang_filter) or b.lang == lang_filter:lower () then
      if code.is_runnable (b.lang) then
        local res = code.run_block (b, {
          dry_run = dry_run,
          cwd = code.config.cwd,
          blocks = blocks,
        })
        print_result (b, res)
        ran = ran + 1
        if not res.ok then
          failed = failed + 1
        end
        results_map[b.index] = res
      end
    end
  end

  if do_results and ran > 0 then
    local new_text =
      code.apply_results (code.read_file (file) or "", results_map)
    local f = io.open (file, "wb")
    if f then
      f:write (new_text)
      f:close ()
      print (string.format ("wrote results back to %s", file))
    end
  end

  if ran == 0 then
    print ("No runnable code blocks found in " .. file)
  else
    print (string.format ("\n%d block(s) run, %d failed", ran, failed))
  end
  os.exit (failed == 0 and 0 or 1)
end

return code
