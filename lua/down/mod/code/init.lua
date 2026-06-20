--- down.mod.code - org-mode-style code block execution for markdown.
--- Provides `:Down code` subcommands and inline "codelens" virtual text on
--- runnable fenced blocks so they can be executed with a single key.
---
--- Block discovery and execution live in the `down.code` library; this mod
--- wires it into Neovim (commands, autocmds, extmark-based codelens, output
--- buffer). It is intentionally tolerant: if the treesitter parser is missing
--- it falls back to the text-based parser in `down.code`.

local lib = require ("down.code")
local log = require ("down.log")
local mod = require ("down.mod")

local api = vim.api
local ns = api.nvim_create_namespace ("down.mod.code")

---@class down.mod.code.Code: down.Mod
local Code = mod.new ("code")
Code.dep = { "cmd" }

---@class down.mod.code.Config
Code.config = {
  --- Enable the inline codelens ("▶ Run") virtual text on runnable blocks.
  codelens = true,
  --- Debounce (ms) for codelens refresh on buffer changes.
  debounce = 150,
  --- Where to display block output: "split" | "vsplit" | "tab" | "echo".
  output = "split",
  --- Keymap (buffer-local) to run the block under the cursor.
  run_key = "<CR>",
  --- Modifier prefix for the run key (used with `<C-c>` style leaders).
  run_prefix = "",
  --- When true, running a block inserts/replaces a `:down_result` block in
  --- the buffer (org-babel `#+RESULTS:` parity). Toggle with `:Down code lens`.
  results = false,
  --- Default directory for `:Down code tangle` (nil => buffer's directory).
  tangle_dir = nil,
}

--- Map a fenced block language to a Neovim filetype for src-edit.
Code.ft_map = {
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
  go = "go",
  rust = "rust",
  rs = "rust",
  perl = "perl",
  php = "php",
  r = "r",
  rscript = "r",
  julia = "julia",
  awk = "awk",
  scheme = "scheme",
  scm = "scheme",
  clojure = "clojure",
  clj = "clojure",
  haskell = "haskell",
  hs = "haskell",
  elixir = "elixir",
  erlang = "erlang",
  powershell = "powershell",
  pwsh = "powershell",
  ps1 = "powershell",
  html = "html",
  css = "css",
  json = "json",
  yaml = "yaml",
  yml = "yaml",
  toml = "toml",
  sql = "sql",
  graphql = "graphql",
}

--- Resolve a Neovim filetype for a block language (fallback: the lang itself).
---@param lang string
---@return string
Code.ft_for = function (lang)
  return Code.ft_map[lang] or lang or "text"
end

--- Highlight groups for the codelens virtual text.
Code.setup_highlights = function ()
  api.nvim_set_hl (0, "DownCodeLens", { link = "LspCodeLens", default = true })
  api.nvim_set_hl (0, "DownCodeLensLang", { link = "Type", default = true })
  api.nvim_set_hl (0, "DownCodeLensRun", { link = "Special", default = true })
end

--- Get the buffer text as a string.
---@param bufnr number
---@return string
local function buf_text (bufnr)
  local lines = api.nvim_buf_get_lines (bufnr, 0, -1, false)
  return table.concat (lines, "\n")
end

--- Find the block whose fenced range contains the cursor line.
---@param blocks down.code.Block[]
---@param cursor_line number  1-indexed
---@return down.code.Block|nil
local function block_at (blocks, cursor_line)
  for _, b in ipairs (blocks) do
    if cursor_line >= b.start_line and cursor_line <= b.end_line then
      return b
    end
  end
  return nil
end

--- Map a down.code.Block to buffer line ranges (0-indexed, end-exclusive).
---@param b down.code.Block
---@return number start_row, number end_row
local function block_rows (b)
  return b.start_line - 1, b.end_line - 1
end

--- Refresh codelens extmarks for a buffer (debounced).
---@param bufnr number
Code.refresh = function (bufnr)
  bufnr = bufnr or 0
  if not Code.config.codelens then
    return
  end
  if not vim.bo[bufnr].filetype then
    return
  end
  local ft = vim.bo[bufnr].filetype
  if not vim.tbl_contains ({ "markdown", "md", "down" }, ft) then
    return
  end

  api.nvim_buf_clear_namespace (bufnr, ns, 0, -1)
  local text = buf_text (bufnr)
  local blocks = lib.parse_blocks (text)
  for _, b in ipairs (blocks) do
    if lib.is_runnable (b.lang) then
      local row = block_rows (b)
      api.nvim_buf_set_extmark (bufnr, ns, row, 0, {
        virt_text = {
          { "▶ Run ", "DownCodeLensRun" },
          { "[" .. b.lang .. "]", "DownCodeLensLang" },
        },
        virt_text_pos = "eol",
        hl_mode = "combine",
        priority = 100,
      })
    end
  end
end

--- Debounced refresh helper keyed by buffer.
Code._timers = {}
Code.schedule_refresh = function (bufnr)
  bufnr = bufnr or 0
  if not Code.config.codelens then
    return
  end
  local existing = Code._timers[bufnr]
  if existing then
    existing:stop ()
  end
  local t = vim.uv.new_timer ()
  Code._timers[bufnr] = t
  t:start (
    Code.config.debounce,
    0,
    vim.schedule_wrap (function ()
      if t then
        t:stop ()
      end
      if api.nvim_buf_is_valid (bufnr) then
        Code.refresh (bufnr)
      end
    end)
  )
end

--- Display output text in the configured output target.
---@param content string
---@param title string
Code.show_output = function (content, title)
  local target = Code.config.output
  if target == "echo" then
    print (content)
    return
  end
  -- Reuse an existing down output window when present so repeated runs
  -- don't pile up splits.
  local reuse = nil
  for _, w in ipairs (api.nvim_list_wins ()) do
    local b = api.nvim_win_get_buf (w)
    if vim.bo[b].filetype == "down.output" then
      reuse = w
      break
    end
  end
  local buf
  if reuse then
    api.nvim_set_current_win (reuse)
    buf = api.nvim_get_current_buf ()
  else
    local cmd = target == "vsplit" and "vsplit"
      or target == "tab" and "tabnew"
      or "split"
    vim.cmd (cmd)
    buf = api.nvim_get_current_buf ()
  end
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines (
    buf,
    0,
    -1,
    false,
    vim.split (content, "\n", { plain = true })
  )
  vim.bo[buf].filetype = "down.output"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  api.nvim_buf_set_name (buf, title or "down://code-output")
end

--- Format a single run result as text.
---@param b down.code.Block
---@param r down.code.RunResult
---@return string
local function format_result (b, r)
  local parts = {
    string.format (
      "▶ [%s] block #%d (line %d)",
      b.lang,
      b.index,
      b.start_line
    ),
  }
  if r.skipped then
    parts[#parts + 1] = "  skipped (no runner or interpreter unavailable)"
  else
    if r.output and r.output ~= "" then
      for ln in (r.output):gmatch ("([^\n]*)") do
        parts[#parts + 1] = "  " .. ln
      end
    end
    parts[#parts + 1] = r.ok and "  ✓ exit 0"
      or string.format ("  ✗ exit %d", r.exit_code)
  end
  return table.concat (parts, "\n")
end

--- Run a single block (by reference) and append its result to the output buffer.
---@param bufnr number
---@param b down.code.Block
---@param lang_filter? string
Code.run_block = function (bufnr, b, lang_filter)
  if lang_filter and b.lang ~= lang_filter:lower () then
    return
  end
  if not lib.is_runnable (b.lang) then
    return
  end
  -- run in the buffer's directory by default so relative paths make sense
  local dir = vim.fs.dirname (api.nvim_buf_get_name (bufnr))
  local r = lib.run_block (b, { cwd = dir })
  log.trace ("code.run_block", b.lang, b.start_line, r.ok)
  return format_result (b, r)
end

--- Buffer directory for a buffer (nil for unnamed buffers).
---@param bufnr number
---@return string|nil
local function buf_dir (bufnr)
  local name = api.nvim_buf_get_name (bufnr)
  if name == "" then
    return nil
  end
  return vim.fs.dirname (name)
end

--- Run all runnable blocks in the buffer (optionally filtered by language).
---@param bufnr number
---@param lang_filter? string
Code.run_all = function (bufnr, lang_filter)
  bufnr = bufnr or 0
  local blocks = lib.parse_blocks (buf_text (bufnr))
  local sections = {}
  local ran = 0
  local failed = 0
  local results_map = {}
  local dir = buf_dir (bufnr)
  for _, b in ipairs (blocks) do
    if (not lang_filter) or b.lang == lang_filter:lower () then
      if lib.is_runnable (b.lang) then
        local r = lib.run_block (b, { cwd = dir, blocks = blocks })
        ran = ran + 1
        if not r.ok then
          failed = failed + 1
        end
        results_map[b.index] = r
        sections[#sections + 1] = format_result (b, r)
      end
    end
  end
  if ran == 0 then
    vim.notify ("[down] no runnable code blocks found", vim.log.levels.INFO)
    return
  end
  Code.apply_results_to_buffer (bufnr, results_map)
  sections[#sections + 1] = ""
  sections[#sections + 1] =
    string.format ("%d block(s) run, %d failed", ran, failed)
  Code.show_output (table.concat (sections, "\n\n"), "down://code-output")
end

Code.run_cursor = function (bufnr)
  bufnr = bufnr or 0
  local row = api.nvim_win_get_cursor (0)[1]
  local blocks = lib.parse_blocks (buf_text (bufnr))
  local b = block_at (blocks, row)
  if not b then
    vim.notify ("[down] no code block at cursor", vim.log.levels.WARN)
    return
  end
  if not lib.is_runnable (b.lang) then
    vim.notify (
      "[down] block [" .. b.lang .. "] is not runnable",
      vim.log.levels.WARN
    )
    return
  end
  local dir = buf_dir (bufnr)
  local r = lib.run_block (b, { cwd = dir, blocks = blocks })
  Code.apply_results_to_buffer (bufnr, { [b.index] = r })
  Code.show_output (format_result (b, r), "down://code-output")
end

--- List code blocks in the buffer (runnable + skipped).
---@param bufnr number
Code.list = function (bufnr)
  bufnr = bufnr or 0
  local blocks = lib.parse_blocks (buf_text (bufnr))
  local lines = { string.format ("%d fenced block(s)", #blocks) }
  for _, b in ipairs (blocks) do
    local mark = lib.is_runnable (b.lang) and "▶" or " "
    lines[#lines + 1] = string.format (
      "  %s [%s] #%d line %d",
      mark,
      b.lang,
      b.index,
      b.start_line
    )
  end
  Code.show_output (table.concat (lines, "\n"), "down://code-list")
end

--- Run by block index (1-indexed) — handy for `:Down code run 2`.
---@param bufnr number
---@param index number|string
Code.run_index = function (bufnr, index)
  bufnr = bufnr or 0
  local blocks = lib.parse_blocks (buf_text (bufnr))
  local b = blocks[tonumber (index)]
  if not b then
    vim.notify ("[down] no block #" .. tostring (index), vim.log.levels.WARN)
    return
  end
  if not lib.is_runnable (b.lang) then
    vim.notify (
      "[down] block [" .. b.lang .. "] is not runnable",
      vim.log.levels.WARN
    )
    return
  end
  local dir = buf_dir (bufnr)
  local r = lib.run_block (b, { cwd = dir, blocks = blocks })
  Code.apply_results_to_buffer (bufnr, { [b.index] = r })
  Code.show_output (format_result (b, r), "down://code-output")
end

--- Write a results map back into the buffer (insert/replace `:down_result`
--- blocks). No-op when results are disabled or the map is empty.
---@param bufnr number
---@param results_map table<number, down.code.RunResult>
Code.apply_results_to_buffer = function (bufnr, results_map)
  if not Code.config.results then
    return
  end
  if not results_map or not next (results_map) then
    return
  end
  local text = buf_text (bufnr)
  local new_text = lib.apply_results (text, results_map)
  if new_text == text then
    return
  end
  local lines = vim.split (new_text, "\n", { plain = true })
  api.nvim_buf_set_lines (bufnr, 0, -1, false, lines)
end

--- Tangle `:tangle` blocks from the buffer into files.
---@param bufnr number
---@param dir? string  output directory (defaults to buffer dir / tangle_dir)
Code.tangle = function (bufnr, dir)
  bufnr = bufnr or 0
  local name = api.nvim_buf_get_name (bufnr)
  local out_dir = dir or Code.config.tangle_dir or buf_dir (bufnr)
  local written = lib.tangle_text (buf_text (bufnr), name, { dir = out_dir })
  if #written == 0 then
    vim.notify ("[down] no `:tangle` blocks in buffer", vim.log.levels.INFO)
    return
  end
  for _, p in ipairs (written) do
    vim.notify ("tangled -> " .. p, vim.log.levels.INFO)
  end
  vim.notify (
    string.format ("[down] tangled %d file(s)", #written),
    vim.log.levels.INFO
  )
end

--- Active src-edit buffers: edit_buf -> source metadata.
Code._edits = {}

--- Open the block at the cursor in an indirect scratch buffer with its native
--- filetype (org `C-c '` parity). `:w` writes the body back into the source
--- block; `:q` closes the scratch buffer.
---@param bufnr number
Code.edit = function (bufnr)
  bufnr = bufnr or 0
  local row = api.nvim_win_get_cursor (0)[1]
  local blocks = lib.parse_blocks (buf_text (bufnr))
  local b = block_at (blocks, row)
  if not b then
    vim.notify ("[down] no code block at cursor", vim.log.levels.WARN)
    return
  end
  local ebuf = api.nvim_create_buf (false, true)
  local body_lines = lib.split_lines (b.body)
  api.nvim_buf_set_lines (ebuf, 0, -1, false, body_lines)
  vim.bo[ebuf].filetype = Code.ft_for (b.lang)
  vim.bo[ebuf].buftype = "acwrite"
  vim.bo[ebuf].bufhidden = "wipe"
  local title = "down://src-edit/" .. b.lang .. "/" .. tostring (b.index)
  local ok = pcall (api.nvim_buf_set_name, ebuf, title)
  if not ok then
    -- name already taken; reuse a unique one
    title = title .. "." .. tostring (ebuf)
    pcall (api.nvim_buf_set_name, ebuf, title)
  end
  api.nvim_set_current_buf (ebuf)
  Code._edits[ebuf] = { src = bufnr, index = b.index, lang = b.lang }
  vim.notify (
    "[down] editing ["
      .. b.lang
      .. "] block #"
      .. b.index
      .. " — :w to write back",
    vim.log.levels.INFO
  )
end

--- Write a src-edit scratch buffer's contents back into its source block.
---@param ebuf number
Code.writeback = function (ebuf)
  local meta = Code._edits[ebuf]
  if not meta or not api.nvim_buf_is_valid (meta.src) then
    vim.notify ("[down] src-edit buffer has no source", vim.log.levels.WARN)
    return
  end
  local src = meta.src
  local blocks = lib.parse_blocks (buf_text (src))
  local b = nil
  for _, blk in ipairs (blocks) do
    if blk.index == meta.index then
      b = blk
      break
    end
  end
  if not b then
    vim.notify ("[down] source block vanished", vim.log.levels.WARN)
    return
  end
  local new_body = api.nvim_buf_get_lines (ebuf, 0, -1, false)
  -- body lines live strictly between the fences: rows start_line+1 .. end_line-1
  api.nvim_buf_set_lines (src, b.start_line, b.end_line - 1, false, new_body)
  vim.bo[ebuf].modified = false
  vim.schedule (function ()
    Code.schedule_refresh (src)
  end)
end

--- Enable codelens for the current buffer (set keymap + first refresh).
---@param bufnr number
Code.enable = function (bufnr)
  bufnr = bufnr or 0
  if
    not vim.tbl_contains ({ "markdown", "md", "down" }, vim.bo[bufnr].filetype)
  then
    return
  end
  local opts =
    { buffer = bufnr, silent = true, desc = "down: run code block at cursor" }
  vim.keymap.set ("n", Code.config.run_key, function ()
    Code.run_cursor (bufnr)
  end, opts)
  Code.schedule_refresh (bufnr)
end

Code.setup = function ()
  Code.setup_highlights ()
  local group = api.nvim_create_augroup ("down.mod.code", { clear = true })
  api.nvim_create_autocmd ({ "FileType", "BufEnter" }, {
    group = group,
    pattern = { "markdown", "md", "down" },
    callback = function (ev)
      Code.enable (ev.buf)
    end,
    desc = "Enable down code codelens for markdown buffers",
  })
  api.nvim_create_autocmd (
    { "TextChanged", "TextChangedI", "InsertLeave", "BufWritePost" },
    {
      group = group,
      pattern = { "markdown", "md", "down" },
      callback = function (ev)
        Code.schedule_refresh (ev.buf)
      end,
      desc = "Refresh down code codelens on buffer changes",
    }
  )
  api.nvim_create_autocmd ("BufWriteCmd", {
    group = group,
    pattern = "down://src-edit/*",
    callback = function (ev)
      Code.writeback (ev.buf)
    end,
    desc = "Write down src-edit buffer back into its source block",
  })
  return { loaded = true }
end

--- `:Down code` subcommands.
Code.commands = {
  code = {
    name = "code",
    args = 0,
    max_args = math.huge,
    callback = function (_e)
      -- `:Down code` with no subcommand runs the block at the cursor.
      Code.run_cursor (api.nvim_get_current_buf ())
    end,
    commands = {
      run = {
        name = "code.run",
        args = 0,
        max_args = math.huge,
        callback = function (e)
          local arg = e and e.body and e.body[1]
          local idx = arg and tonumber (arg)
          if idx then
            Code.run_index (api.nvim_get_current_buf (), idx)
          elseif arg then
            Code.run_all (api.nvim_get_current_buf (), arg)
          else
            Code.run_all (api.nvim_get_current_buf ())
          end
        end,
      },
      cursor = {
        name = "code.cursor",
        args = 0,
        callback = function ()
          Code.run_cursor (api.nvim_get_current_buf ())
        end,
      },
      list = {
        name = "code.list",
        args = 0,
        callback = function ()
          Code.list (api.nvim_get_current_buf ())
        end,
      },
      lens = {
        name = "code.lens",
        args = 0,
        max_args = 1,
        callback = function (e)
          local arg = e and e.body and e.body[1]
          if arg == "off" or arg == "disable" then
            Code.config.codelens = false
            for b in pairs (Code._timers) do
              if api.nvim_buf_is_valid (b) then
                api.nvim_buf_clear_namespace (b, ns, 0, -1)
              end
            end
            vim.notify ("[down] code codelens disabled", vim.log.levels.INFO)
          elseif arg == "on" or arg == "enable" then
            Code.config.codelens = true
            for _, b in ipairs (api.nvim_list_bufs ()) do
              if api.nvim_buf_is_loaded (b) then
                Code.schedule_refresh (b)
              end
            end
            vim.notify ("[down] code codelens enabled", vim.log.levels.INFO)
          else
            vim.notify (
              "[down] code codelens is "
                .. (Code.config.codelens and "on" or "off"),
              vim.log.levels.INFO
            )
          end
        end,
      },
      tangle = {
        name = "code.tangle",
        args = 0,
        max_args = 1,
        callback = function (e)
          local arg = e and e.body and e.body[1]
          Code.tangle (api.nvim_get_current_buf (), arg)
        end,
      },
      edit = {
        name = "code.edit",
        args = 0,
        callback = function ()
          Code.edit (api.nvim_get_current_buf ())
        end,
      },
      results = {
        name = "code.results",
        args = 0,
        max_args = 1,
        callback = function (e)
          local arg = e and e.body and e.body[1]
          if arg == "off" or arg == "disable" then
            Code.config.results = false
            vim.notify ("[down] code results off", vim.log.levels.INFO)
          elseif arg == "on" or arg == "enable" then
            Code.config.results = true
            vim.notify ("[down] code results on", vim.log.levels.INFO)
          else
            Code.config.results = not Code.config.results
            vim.notify (
              "[down] code results " .. (Code.config.results and "on" or "off"),
              vim.log.levels.INFO
            )
          end
        end,
      },
    },
  },
}

Code.maps = {
  {
    "n",
    "<leader>dx",
    "<CMD>Down code run<CR>",
    { desc = "down: run all code blocks" },
  },
  {
    "n",
    "<leader>dX",
    "<CMD>Down code cursor<CR>",
    { desc = "down: run code block at cursor" },
  },
  {
    "n",
    "<leader>dL",
    "<CMD>Down code list<CR>",
    { desc = "down: list code blocks" },
  },
  {
    "n",
    "<leader>de",
    "<CMD>Down code edit<CR>",
    { desc = "down: edit code block at cursor in native ft" },
  },
  {
    "n",
    "<leader>dt",
    "<CMD>Down code tangle<CR>",
    { desc = "down: tangle code blocks to files" },
  },
}

Code.handle = {}

Code.after = function ()
  -- nothing extra; setup did the wiring
end

return Code
