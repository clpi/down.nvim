--- @ mention completion source for down.nvim
--- Provides Notion-like @ mentions for linking pages, dates, people, and more
---@class down.mod.lsp.completion.Mention
local Mention = {}

--- Built-in mention types (always available)
---@type table[]
Mention.builtins = {
  --- Date mentions
  {
    label = "@today",
    icon = "󰃭",
    detail = "Today's date",
    documentation = "Insert today's date as a link",
    insert_text = function ()
      return os.date ("%Y-%m-%d")
    end,
    kind = "Date",
    category = "Date",
  },
  {
    label = "@yesterday",
    icon = "󰃭",
    detail = "Yesterday's date",
    documentation = "Insert yesterday's date",
    insert_text = function ()
      return os.date ("%Y-%m-%d", os.time () - 86400)
    end,
    kind = "Date",
    category = "Date",
  },
  {
    label = "@tomorrow",
    icon = "󰃭",
    detail = "Tomorrow's date",
    documentation = "Insert tomorrow's date",
    insert_text = function ()
      return os.date ("%Y-%m-%d", os.time () + 86400)
    end,
    kind = "Date",
    category = "Date",
  },
  {
    label = "@now",
    icon = "󰅐",
    detail = "Current date and time",
    documentation = "Insert current datetime",
    insert_text = function ()
      return os.date ("%Y-%m-%d %H:%M")
    end,
    kind = "Date",
    category = "Date",
  },
  {
    label = "@monday",
    icon = "󰨞",
    detail = "Next Monday",
    documentation = "Insert date of next Monday",
    insert_text = function ()
      local t = os.time ()
      local wday = os.date ("*t", t).wday -- 1=Sun, 2=Mon, ...
      local days_until = (9 - wday) % 7
      if days_until == 0 then
        days_until = 7
      end
      return os.date ("%Y-%m-%d", t + days_until * 86400)
    end,
    kind = "Date",
    category = "Date",
  },
  {
    label = "@friday",
    icon = "󰨞",
    detail = "Next Friday",
    documentation = "Insert date of next Friday",
    insert_text = function ()
      local t = os.time ()
      local wday = os.date ("*t", t).wday
      local days_until = (13 - wday) % 7
      if days_until == 0 then
        days_until = 7
      end
      return os.date ("%Y-%m-%d", t + days_until * 86400)
    end,
    kind = "Date",
    category = "Date",
  },
  {
    label = "@next-week",
    icon = "󰨜",
    detail = "Start of next week",
    documentation = "Insert date of next week's Monday",
    insert_text = function ()
      local t = os.time ()
      local wday = os.date ("*t", t).wday
      local days_until = (9 - wday) % 7
      if days_until == 0 then
        days_until = 7
      end
      return os.date ("%Y-%m-%d", t + days_until * 86400)
    end,
    kind = "Date",
    category = "Date",
  },
  {
    label = "@date",
    icon = "󰃭",
    detail = "Today's date",
    documentation = "Insert today's date",
    insert_text = function ()
      return os.date ("%Y-%m-%d")
    end,
    kind = "Date",
    category = "Date",
  },
  {
    label = "@time",
    icon = "󰅐",
    detail = "Current time",
    documentation = "Insert current time",
    insert_text = function ()
      return os.date ("%H:%M")
    end,
    kind = "Date",
    category = "Date",
  },

  --- Workspace mentions
  {
    label = "@workspace",
    icon = "󱂬",
    detail = "Current workspace",
    documentation = "Insert current workspace name",
    insert_text = function ()
      local mod = require ("down.mod")
      local ws = mod.get_mod ("workspace")
      if ws then
        return ws.current () or "default"
      end
      return "default"
    end,
    kind = "Reference",
    category = "Workspace",
  },

  --- Special references
  {
    label = "@me",
    icon = "󰀄",
    detail = "Current user",
    documentation = "Insert current git user name",
    insert_text = function ()
      local name = vim.fn.system ({ "git", "config", "user.name" })
      if vim.v.shell_error == 0 and name then
        return vim.trim (name)
      end
      return "me"
    end,
    kind = "Person",
    category = "People",
  },
}

--- Get workspace files for page linking
---@param parent table The completion module
---@return table[]
Mention.get_pages = function (parent)
  local items = {}
  local mod = require ("down.mod")
  local ws = mod.get_mod ("workspace")

  if not ws then
    return items
  end

  local current_ws = ws.current ()
  local ws_path = ws.get (current_ws)

  if not ws_path then
    return items
  end

  -- Get all markdown files in workspace
  local files = vim.fn.globpath (ws_path, "**/*.md", true, true)

  for _, filepath in ipairs (files) do
    -- Get relative path from workspace root
    local rel_path = filepath:sub (#ws_path + 2) -- +2 for trailing / and 1-index
    -- Get file name without extension for display
    local name = rel_path:match ("(.+)%.md$") or rel_path
    -- Get just the filename for label
    local basename = name:match ("[^/]+$") or name

    table.insert (items, {
      label = "@" .. basename,
      icon = "󰎞",
      detail = "Page: " .. rel_path,
      documentation = "Link to " .. rel_path,
      insert_text = "[[" .. basename .. "]]",
      kind = "Page",
      category = "Pages",
      filter_text = basename:lower (),
      sort_text = "1_" .. basename:lower (), -- Pages sort first
    })
  end

  return items
end

--- Get recent files for quick access
---@return table[]
Mention.get_recent = function ()
  local items = {}
  local oldfiles = vim.v.oldfiles or {}

  local count = 0
  for _, filepath in ipairs (oldfiles) do
    if filepath:match ("%.md$") and vim.fn.filereadable (filepath) == 1 then
      local basename = vim.fn.fnamemodify (filepath, ":t:r")
      local rel = vim.fn.fnamemodify (filepath, ":~:.")

      table.insert (items, {
        label = "@" .. basename,
        icon = "󰋚",
        detail = "Recent: " .. rel,
        documentation = "Link to recently opened " .. rel,
        insert_text = "[" .. basename .. "](" .. rel .. ")",
        kind = "Recent",
        category = "Recent",
        filter_text = basename:lower (),
        sort_text = "2_" .. string.format ("%04d", count), -- Recent sorted by recency
      })

      count = count + 1
      if count >= 10 then
        break
      end
    end
  end

  return items
end

--- Get headings from current workspace for section linking
---@param parent table
---@return table[]
Mention.get_headings = function (parent)
  local items = {}
  local buf_lines = vim.api.nvim_buf_get_lines (0, 0, -1, false)

  for i, line in ipairs (buf_lines) do
    local heading = line:match ("^(#+)%s+(.+)")
    if heading then
      local level = #line:match ("^(#+)")
      local text = line:match ("^#+%s+(.+)")
      if text then
        -- Create anchor from heading text
        local anchor = text:lower ():gsub ("%s+", "-"):gsub ("[^%w%-]", "")

        table.insert (items, {
          label = "@" .. text,
          icon = level == 1 and "󰉫" or level == 2 and "󰉬" or "󰉭",
          detail = "H" .. level .. " in current doc",
          documentation = "Link to heading: " .. text,
          insert_text = "[" .. text .. "](#" .. anchor .. ")",
          kind = "Heading",
          category = "Headings",
          filter_text = text:lower (),
          sort_text = "3_" .. string.format ("%04d", i),
        })
      end
    end
  end

  return items
end

--- Get all mention items, optionally filtered
---@param parent table The parent completion module
---@param query? string Optional filter query
---@return table[]
Mention.get_items = function (parent, query)
  local items = {}

  -- Add built-in date/reference mentions
  for _, builtin in ipairs (Mention.builtins) do
    local insert_text = builtin.insert_text
    if type (insert_text) == "function" then
      insert_text = insert_text ()
    end

    table.insert (items, {
      label = (builtin.icon or "") .. " " .. builtin.label,
      detail = builtin.detail,
      documentation = builtin.documentation,
      insert_text = insert_text,
      kind = builtin.kind,
      category = builtin.category,
      filter_text = builtin.label:lower (),
      sort_text = "0_" .. builtin.label:lower (),
    })
  end

  -- Add workspace pages
  local pages = Mention.get_pages (parent)
  for _, page in ipairs (pages) do
    page.label = (page.icon or "") .. " " .. page.label
    table.insert (items, page)
  end

  -- Add headings from current document
  local headings = Mention.get_headings (parent)
  for _, heading in ipairs (headings) do
    heading.label = (heading.icon or "") .. " " .. heading.label
    table.insert (items, heading)
  end

  -- Add recent files
  local recent = Mention.get_recent ()
  for _, rec in ipairs (recent) do
    rec.label = (rec.icon or "") .. " " .. rec.label
    table.insert (items, rec)
  end

  -- Filter by query
  if query and query ~= "" then
    local q = query:lower ()
    local filtered = {}
    for _, item in ipairs (items) do
      if
        (item.filter_text and item.filter_text:find (q, 1, true))
        or (item.detail and item.detail:lower ():find (q, 1, true))
        or (item.category and item.category:lower ():find (q, 1, true))
      then
        table.insert (filtered, item)
      end
    end
    items = filtered
  end

  -- Sort by sort_text, then alphabetical
  table.sort (items, function (a, b)
    local sa = a.sort_text or a.filter_text or ""
    local sb = b.sort_text or b.filter_text or ""
    return sa < sb
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

return Mention
