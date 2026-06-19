local mod = require("down.mod")
local log = require("down.log")
local Frontmatter = require("down.mod.data.props.frontmatter")

---@class down.mod.Bookmark
local Bookmark = mod.new("bookmark")
Bookmark.dep = { "cmd" }

Bookmark.config = {
  store_file = "bookmarks.json",
  default_tags = {},
  auto_archive = false,
}

Bookmark.commands = {
  bookmark = {
    name = "bookmark",
    enabled = true,
    min_args = 0,
    max_args = 1,
    callback = function()
      Bookmark.add()
    end,
    commands = {
      add = {
        name = "bookmark.add",
        enabled = true,
        min_args = 0,
        max_args = 2,
        callback = function(e)
          local url = e.fargs and e.fargs[1]
          local tags = e.fargs and e.fargs[2]
          Bookmark.add(url, tags)
        end,
      },
      list = {
        name = "bookmark.list",
        enabled = true,
        min_args = 0,
        max_args = 1,
        callback = function(e)
          local tag_filter = e.fargs and e.fargs[1]
          Bookmark.list(tag_filter)
        end,
      },
      import = {
        name = "bookmark.import",
        enabled = true,
        min_args = 0,
        max_args = 1,
        callback = function(e)
          local file = e.fargs and e.fargs[1]
          Bookmark.import_bookmarks(file)
        end,
      },
      export = {
        name = "bookmark.export",
        enabled = true,
        min_args = 0,
        max_args = 1,
        callback = function(e)
          local format = e.fargs and e.fargs[1] or "json"
          Bookmark.export_bookmarks(format)
        end,
      },
      search = {
        name = "bookmark.search",
        enabled = true,
        min_args = 1,
        max_args = 1,
        callback = function(e)
          local query = e.fargs and e.fargs[1]
          if query then
            Bookmark.search(query)
          end
        end,
      },
    },
  },
}

Bookmark.maps = {
  {
    "n",
    ",db",
    "<ESC>:<C-U>Down bookmark add<CR>",
    { desc = "Down bookmark add", silent = true, noremap = false, nowait = true },
  },
  {
    "n",
    ",dl",
    "<ESC>:<C-U>Down bookmark list<CR>",
    { desc = "Down bookmark list", silent = true, noremap = false, nowait = true },
  },
  {
    "n",
    ",ds",
    "<ESC>:<C-U>Down bookmark search<CR>",
    { desc = "Down bookmark search", silent = true, noremap = false, nowait = true },
  },
}

Bookmark.fetch_title = function(url, callback)
  vim.system({ "curl", "-sL", "--max-time", "10", url }, { text = true }, function(out)
    if out.code ~= 0 or not out.stdout then
      vim.schedule(function()
        callback(nil)
      end)
      return
    end

    local title = out.stdout:match("<title>(.-)</title>")
    if not title then
      title = out.stdout:match("<title.->(.-)</title>")
    end

    if title then
      title = title:gsub("&#x(%x+);", function(hex)
        return string.char(tonumber(hex, 16))
      end)
      title = title:gsub("&#(%d+);", function(dec)
        return string.char(tonumber(dec))
      end)
      title = title:gsub("&amp;", "&")
      title = title:gsub("&lt;", "<")
      title = title:gsub("&gt;", ">")
      title = title:gsub("&quot;", '"')
      title = title:gsub("&apos;", "'")
      title = title:gsub("^%s*(.-)%s*$", "%1")
    end

    vim.schedule(function()
      callback(title)
    end)
  end)
end

Bookmark.add = function(url, tags)
  if not url then
    vim.ui.input({ prompt = "Bookmark URL: " }, function(input)
      if input and input ~= "" then
        Bookmark.insert_bookmark(input, tags)
      end
    end)
    return
  end

  Bookmark.insert_bookmark(url, tags)
end

Bookmark.insert_bookmark = function(url, tags)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local placeholder = "> [!bookmark] Fetching " .. url .. "..."
  vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { placeholder })

  Bookmark.fetch_title(url, function(title)
    if not title or title == "" then
      title = url:gsub("^https?://", ""):gsub("/$", "")
    end

    local timestamp = os.date("%Y-%m-%d %H:%M")
    local tag_str = ""

    if tags and tags ~= "" then
      local tag_list = vim.split(tags, ",")
      tag_str = " #" .. table.concat(tag_list, " #")
    end

    local new_text = string.format("> [!bookmark] [%s](%s)  \n> Saved: %s%s", title, url, timestamp, tag_str)

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i, line in ipairs(lines) do
      local s, e = line:find(placeholder, 1, true)
      if s then
        local new_line = line:sub(1, s - 1) .. new_text .. line:sub(e + 1)
        vim.api.nvim_buf_set_lines(0, i - 1, i, false, { new_line })
        break
      end
    end

    Bookmark.save_to_store({ url = url, title = title, tags = tags, saved = timestamp })
    vim.notify("[down.nvim] Bookmarked: " .. title)
  end)
end

Bookmark.save_to_store = function(entry)
  local ws = mod.get_mod("workspace")
  if not ws then
    return
  end

  local ws_path = ws.get(ws.current())
  if not ws_path then
    return
  end

  local store_path = vim.fs.joinpath(ws_path, Bookmark.config.store_file)
  local bookmarks = {}

  local f = io.open(store_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    if content and #content > 0 then
      local ok, decoded = pcall(vim.json.decode, content)
      if ok then
        bookmarks = decoded
      end
    end
  end

  table.insert(bookmarks, entry)

  local json = vim.json.encode(bookmarks)
  f = io.open(store_path, "w")
  if f then
    f:write(json)
    f:close()
  end
end

Bookmark.list = function(tag_filter)
  local ws = mod.get_mod("workspace")
  if not ws then
    return
  end

  local ws_path = ws.get(ws.current())
  if not ws_path then
    return
  end

  local store_path = vim.fs.joinpath(ws_path, Bookmark.config.store_file)
  local bookmarks = {}

  local f = io.open(store_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    if content and #content > 0 then
      local ok, decoded = pcall(vim.json.decode, content)
      if ok then
        bookmarks = decoded
      end
    end
  end

  if #bookmarks == 0 then
    vim.notify("[down.nvim] No bookmarks found")
    return
  end

  if tag_filter then
    local filtered = {}
    for _, bm in ipairs(bookmarks) do
      if bm.tags and bm.tags:find(tag_filter, 1, true) then
        table.insert(filtered, bm)
      end
    end
    bookmarks = filtered
  end

  vim.ui.select(bookmarks, {
    prompt = "Bookmarks" .. (tag_filter and " (" .. tag_filter .. ")" or ""),
    format_item = function(item)
      local parts = {}
      table.insert(parts, item.title or item.url)
      if item.saved then
        table.insert(parts, "[" .. item.saved .. "]")
      end
      if item.tags then
        table.insert(parts, "(" .. item.tags .. ")")
      end
      return table.concat(parts, " ")
    end,
  }, function(choice)
    if choice then
      vim.ui.open(choice.url)
    end
  end)
end

Bookmark.search = function(query)
  local ws = mod.get_mod("workspace")
  local ws_path = ws and ws.get(ws.current())
  if not ws_path then
    return
  end

  local store_path = vim.fs.joinpath(ws_path, Bookmark.config.store_file)
  local bookmarks = {}

  local f = io.open(store_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    if content and #content > 0 then
      local ok, decoded = pcall(vim.json.decode, content)
      if ok then
        bookmarks = decoded
      end
    end
  end

  local query_lower = query:lower()
  local results = {}
  for _, bm in ipairs(bookmarks) do
    local title = (bm.title or ""):lower()
    local url = (bm.url or ""):lower()
    local tag_str = (bm.tags or ""):lower()
    if title:find(query_lower, 1, true) or
      url:find(query_lower, 1, true) or
      tag_str:find(query_lower, 1, true) then
      table.insert(results, bm)
    end
  end

  if #results == 0 then
    vim.notify("[down.nvim] No bookmarks matching: " .. query)
  else
    vim.ui.select(results, {
      prompt = "Search: " .. query .. " (" .. #results .. " results)",
      format_item = function(item)
        return item.title .. " - " .. item.url
      end,
    }, function(choice)
      if choice then
        vim.ui.open(choice.url)
      end
    end)
  end
end

Bookmark.import_bookmarks = function(file_path)
  if not file_path then
    vim.ui.input({ prompt = "Import from file: " }, function(input)
      if input and #input > 0 then
        Bookmark.do_import(input)
      end
    end)
    return
  end
  Bookmark.do_import(file_path)
end

Bookmark.do_import = function(file_path)
  local f = io.open(file_path, "r")
  if not f then
    vim.notify("[down.nvim] Cannot open: " .. file_path, vim.log.levels.ERROR)
    return
  end

  local content = f:read("*a")
  f:close()

  local bookmarks = {}

  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then
    bookmarks = decoded
  else
    for line in content:gmatch("[^\n]+") do
      local url = line:match("(https?://%S+)")
      if url then
        local title = line:gsub(url, ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if title == "" then
          title = url
        end
        table.insert(bookmarks, {
          url = url,
          title = title,
          saved = os.date("%Y-%m-%d %H:%M"),
          tags = "",
        })
      end
    end
  end

  for _, bm in ipairs(bookmarks) do
    Bookmark.save_to_store(bm)
  end

  vim.notify("[down.nvim] Imported " .. #bookmarks .. " bookmarks")
end

Bookmark.export_bookmarks = function(format)
  format = format or "json"

  local ws = mod.get_mod("workspace")
  local ws_path = ws and ws.get(ws.current())
  if not ws_path then
    return
  end

  local store_path = vim.fs.joinpath(ws_path, Bookmark.config.store_file)
  local bookmarks = {}

  local f = io.open(store_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    if content and #content > 0 then
      local ok, decoded = pcall(vim.json.decode, content)
      if ok then
        bookmarks = decoded
      end
    end
  end

  if #bookmarks == 0 then
    vim.notify("[down.nvim] No bookmarks to export")
    return
  end

  local output_path = vim.fs.joinpath(ws_path, "bookmarks_export." .. format)
  local output = ""

  if format == "json" then
    output = vim.json.encode(bookmarks)
  elseif format == "md" or format == "markdown" then
    local lines = { "# Bookmarks", "" }
    for _, bm in ipairs(bookmarks) do
      table.insert(lines, string.format("- [%s](%s) _%s_", bm.title or bm.url, bm.url, bm.saved or ""))
    end
    output = table.concat(lines, "\n")
  else
    for _, bm in ipairs(bookmarks) do
      output = output .. bm.url .. "\n"
    end
  end

  f = io.open(output_path, "w")
  if f then
    f:write(output)
    f:close()
    vim.notify("[down.nvim] Exported " .. #bookmarks .. " bookmarks to " .. output_path)
  end
end

Bookmark.setup = function()
  return {
    loaded = true,
  }
end

return Bookmark
