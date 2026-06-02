--- # tag completion source for down.nvim
--- Provides tag autocomplete by scanning workspace for existing #tags
---@class down.mod.lsp.completion.Tag
local Tag = {}

--- Cache for workspace tags to avoid re-scanning on every keystroke
---@type table
Tag.cache = {
  ---@type table<string, number> tag -> count of occurrences
  tags = {},
  ---@type number timestamp of last full scan
  last_scan = 0,
  ---@type number cache TTL in seconds
  ttl = 30,
  ---@type boolean whether a scan is in progress
  scanning = false,
}

--- Pattern for matching tags in markdown text
--- Matches #word, #word-word, #word_word, #CamelCase, #word/nested
Tag.pattern = "#([%w][%w%-_/]*)"

--- Characters that are valid in a tag
Tag.valid_chars = "[%w%-_/]"

--- Scan a single buffer for tags
---@param bufnr number
---@return table<string, number> tags found with counts
Tag.scan_buffer = function(bufnr)
  local tags = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for i, line in ipairs(lines) do
    -- Skip lines that are headings (# Heading)
    if not line:match("^%s*#+%s") then
      -- Find all tags in line
      for tag in line:gmatch("#(" .. Tag.valid_chars .. "+)") do
        -- Validate: must start with a letter or number, not just symbols
        if tag:match("^%w") and #tag >= 2 then
          tags[tag] = (tags[tag] or 0) + 1
        end
      end
    end
  end

  return tags
end

--- Scan current buffer for tags (fast, no IO)
---@return table<string, number>
Tag.scan_current = function()
  return Tag.scan_buffer(0)
end

--- Scan all markdown files in workspace for tags
---@param parent table The completion module (has dep.workspace)
---@param cb? fun(tags: table<string, number>) Callback with results
Tag.scan_workspace = function(parent, cb)
  if Tag.cache.scanning then
    if cb then cb(Tag.cache.tags) end
    return
  end

  local mod = require("down.mod")
  local ws = mod.get_mod("workspace")
  if not ws then
    if cb then cb({}) end
    return
  end

  local current_ws = ws.current()
  local ws_path = ws.get(current_ws)
  if not ws_path then
    if cb then cb({}) end
    return
  end

  Tag.cache.scanning = true

  -- Use ripgrep for fast scanning if available
  if vim.fn.executable("rg") == 1 then
    Tag.scan_workspace_rg(ws_path, cb)
  else
    -- Fallback: scan with globpath + io
    Tag.scan_workspace_lua(ws_path, cb)
  end
end

--- Scan workspace using ripgrep (fast, async)
---@param ws_path string
---@param cb? fun(tags: table<string, number>)
Tag.scan_workspace_rg = function(ws_path, cb)
  local tags = {}

  vim.fn.jobstart({
    "rg",
    "--no-filename",
    "--no-line-number",
    "--only-matching",
    "--pcre2",
    "(?<!#)#[\\w][\\w\\-_/]{1,}",
    "--glob", "*.md",
    "--glob", "!.git",
    ws_path,
  }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line and line ~= "" then
            -- Remove the leading # for storage
            local tag = line:match("^#(.+)")
            if tag and tag:match("^%w") then
              tags[tag] = (tags[tag] or 0) + 1
            end
          end
        end
      end
    end,
    on_exit = function(_, code)
      Tag.cache.tags = vim.tbl_extend("force", Tag.cache.tags, tags)
      Tag.cache.last_scan = os.time()
      Tag.cache.scanning = false
      if cb then
        vim.schedule(function()
          cb(Tag.cache.tags)
        end)
      end
    end,
  })
end

--- Scan workspace using pure Lua (slower fallback)
---@param ws_path string
---@param cb? fun(tags: table<string, number>)
Tag.scan_workspace_lua = function(ws_path, cb)
  local tags = {}
  local files = vim.fn.globpath(ws_path, "**/*.md", true, true)

  for _, filepath in ipairs(files) do
    local f = io.open(filepath, "r")
    if f then
      local content = f:read("*a")
      f:close()

      if content then
        for line in content:gmatch("[^\n]+") do
          -- Skip headings
          if not line:match("^%s*#+%s") then
            for tag in line:gmatch("#(" .. Tag.valid_chars .. "+)") do
              if tag:match("^%w") and #tag >= 2 then
                tags[tag] = (tags[tag] or 0) + 1
              end
            end
          end
        end
      end
    end
  end

  Tag.cache.tags = tags
  Tag.cache.last_scan = os.time()
  Tag.cache.scanning = false

  if cb then
    vim.schedule(function()
      cb(tags)
    end)
  end
end

--- Check if cache is still valid
---@return boolean
Tag.cache_valid = function()
  return (os.time() - Tag.cache.last_scan) < Tag.cache.ttl
    and not vim.tbl_isempty(Tag.cache.tags)
end

--- Invalidate cache (call after tag operations)
Tag.invalidate = function()
  Tag.cache.last_scan = 0
  Tag.cache.tags = {}
end

--- Get all tag items for completion, optionally filtered
---@param parent table The parent completion module
---@param query? string Optional filter query
---@return table[]
Tag.get_items = function(parent, query)
  local items = {}

  -- Always include current buffer tags (fast)
  local buffer_tags = Tag.scan_current()

  -- Merge with cached workspace tags
  local all_tags = vim.tbl_extend("force", Tag.cache.tags, buffer_tags)

  -- If cache is stale, trigger background rescan
  if not Tag.cache_valid() then
    Tag.scan_workspace(parent)
  end

  -- Build completion items from all known tags
  for tag_name, count in pairs(all_tags) do
    local item = {
      label = "󰓹 #" .. tag_name,
      detail = string.format("Tag (%d use%s)", count, count == 1 and "" or "s"),
      documentation = "Insert tag #" .. tag_name,
      insert_text = "#" .. tag_name,
      kind = "Tag",
      category = "Tags",
      filter_text = tag_name:lower(),
      sort_text = string.format("%04d_%s", 9999 - count, tag_name:lower()),
    }

    -- Filter by query
    if query and query ~= "" then
      local q = query:lower()
      if item.filter_text:find(q, 1, true) then
        table.insert(items, item)
      end
    else
      table.insert(items, item)
    end
  end

  -- Add suggested common tags if no results and user is typing
  if #items == 0 and query and query ~= "" then
    -- Offer to create new tag
    table.insert(items, {
      label = "󰓹 #" .. query,
      detail = "Create new tag",
      documentation = "Create and insert new tag #" .. query,
      insert_text = "#" .. query,
      kind = "Tag",
      category = "New",
      filter_text = query:lower(),
      sort_text = "0000_" .. query:lower(),
    })
  end

  -- Add common tag suggestions when no query
  if not query or query == "" then
    local suggestions = {
      "todo", "idea", "important", "review", "draft",
      "done", "wip", "blocked", "question", "reference",
      "meeting", "project", "personal", "work", "followup",
    }
    for _, sug in ipairs(suggestions) do
      if not all_tags[sug] then
        table.insert(items, {
          label = "󰓻 #" .. sug,
          detail = "Suggested tag",
          documentation = "Common tag: #" .. sug,
          insert_text = "#" .. sug,
          kind = "Suggestion",
          category = "Suggested",
          filter_text = sug:lower(),
          sort_text = "zzzz_" .. sug, -- Sort after existing tags
        })
      end
    end
  end

  -- Sort: most used first, then alphabetical
  table.sort(items, function(a, b)
    return (a.sort_text or "") < (b.sort_text or "")
  end)

  -- Limit results
  local max = (parent and parent.config and parent.config.max_items) or 25
  if #items > max then
    local limited = {}
    for i = 1, max do
      limited[i] = items[i]
    end
    return limited
  end

  return items
end

return Tag
