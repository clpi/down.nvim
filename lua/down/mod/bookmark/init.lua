local mod = require("down.mod")

---@class down.mod.Bookmark: down.Mod
local Bookmark = mod.new("bookmark")

Bookmark.setup = function()
  return { ---@type down.mod.Setup
    loaded = true,
    dependencies = { "cmd" },
  }
end

Bookmark.load = function() end

--- Fetches a URL and returns its title asynchronously
---@param url string
---@param callback fun(title: string|nil)
Bookmark.fetch_title = function(url, callback)
  vim.system({"curl", "-sL", url}, { text = true }, function(out)
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
      -- Unescape basic HTML entities
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
      title = title:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
    end

    vim.schedule(function()
      callback(title)
    end)
  end)
end

--- Prompts for URL and inserts a bookmark at cursor
Bookmark.add = function()
  vim.ui.input({ prompt = "Bookmark URL: " }, function(url)
    if not url or url == "" then
      return
    end

    -- Insert placeholder
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local placeholder = "> [!bookmark] Fetching " .. url .. "..."
    vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { placeholder })

    Bookmark.fetch_title(url, function(title)
      if not title or title == "" then
        title = url
      end

      local new_text = string.format("> [!bookmark] [%s](%s)", title, url)
      
      -- Replace placeholder with actual bookmark
      -- Since we don't know if the user moved the cursor or edited the line,
      -- we search for the placeholder in the current buffer.
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      for i, line in ipairs(lines) do
        local s, e = line:find(placeholder, 1, true)
        if s then
          local new_line = line:sub(1, s - 1) .. new_text .. line:sub(e + 1)
          vim.api.nvim_buf_set_lines(0, i - 1, i, false, { new_line })
          break
        end
      end
    end)
  end)
end

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
        max_args = 0,
        callback = function()
          Bookmark.add()
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
}

return Bookmark
