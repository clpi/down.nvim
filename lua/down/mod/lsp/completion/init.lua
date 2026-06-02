--- Completion sources for down.nvim
--- Provides Notion-like completion menus triggered by /, @, and #
local mod = require("down.mod")
local log = require("down.log")

---@class down.mod.lsp.completion.Completion: down.Mod
local Completion = mod.new("lsp.completion")

---@class down.mod.lsp.completion.Config
Completion.config = {
  --- Enable slash commands
  slash = true,
  --- Enable @ mentions
  mention = true,
  --- Enable # tag completion
  tag = true,
  --- Max items to show in completion menu
  max_items = 20,
  --- Enable fuzzy matching
  fuzzy = true,
}

---@return down.mod.Setup
Completion.setup = function()
  return {
    loaded = true,
    dependencies = { "workspace", "tag", "cmd" },
  }
end

--- Sources
Completion.sources = {}

Completion.load = function()
  Completion.sources.slash = require("down.mod.lsp.completion.slash")
  Completion.sources.mention = require("down.mod.lsp.completion.mention")
  Completion.sources.tag = require("down.mod.lsp.completion.tag")

  -- Set up omnifunc for markdown buffers as fallback
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown", "md", "down" },
    callback = function(ev)
      vim.bo[ev.buf].omnifunc = "v:lua.require'down.mod.lsp.completion'.omnifunc"
    end,
    desc = "Set down.nvim omnifunc for completions",
  })

  -- Set up inline completion triggers via InsertCharPre
  vim.api.nvim_create_autocmd("InsertCharPre", {
    pattern = { "*.md", "*.markdown", "*.down" },
    callback = function()
      local char = vim.v.char
      if char == "/" or char == "@" or char == "#" then
        vim.schedule(function()
          Completion.trigger(char)
        end)
      end
    end,
    desc = "Trigger down.nvim completion on special characters",
  })
end

--- Trigger completion for a given character
---@param trigger string The trigger character (/, @, #)
Completion.trigger = function(trigger)
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]

  -- Only trigger at beginning of line or after whitespace for / commands
  if trigger == "/" then
    local before = line:sub(1, col)
    if before:match("^%s*/$") or before:match("%s/$") then
      Completion.show_menu("slash")
    end
  elseif trigger == "@" then
    Completion.show_menu("mention")
  elseif trigger == "#" then
    local before = line:sub(1, col)
    -- Don't trigger inside a markdown heading
    if not before:match("^#+%s") then
      Completion.show_menu("tag")
    end
  end
end

--- Show completion menu using vim.ui.select or native completion
---@param source_name string
Completion.show_menu = function(source_name)
  local source = Completion.sources[source_name]
  if not source then
    return
  end

  local items = source.get_items(Completion)
  if not items or #items == 0 then
    return
  end

  -- Use native completion menu (pumvisible)
  local complete_items = {}
  for _, item in ipairs(items) do
    table.insert(complete_items, {
      word = item.insert_text or item.label,
      abbr = item.label,
      kind = item.kind or "",
      menu = item.detail or source_name,
      info = item.documentation or "",
      user_data = item,
    })
  end

  vim.fn.complete(vim.fn.col("."), complete_items)
end

--- Omnifunc implementation for fallback completion
---@param findstart number
---@param base string
---@return number|table
Completion.omnifunc = function(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]

    -- Find the start of the completion trigger
    local start = col
    while start > 0 do
      local char = line:sub(start, start)
      if char == "/" or char == "@" or char == "#" then
        return start - 1
      elseif char:match("%s") then
        break
      end
      start = start - 1
    end
    return -3 -- cancel completion
  end

  -- Determine which source to use based on prefix
  local trigger = base:sub(1, 1)
  local query = base:sub(2)
  local source_name

  if trigger == "/" then
    source_name = "slash"
  elseif trigger == "@" then
    source_name = "mention"
  elseif trigger == "#" then
    source_name = "tag"
  else
    return {}
  end

  local source = Completion.sources[source_name]
  if not source then
    return {}
  end

  local items = source.get_items(Completion, query)
  local results = {}
  for _, item in ipairs(items or {}) do
    table.insert(results, {
      word = item.insert_text or item.label,
      abbr = item.label,
      kind = item.kind or "",
      menu = item.detail or source_name,
      info = item.documentation or "",
    })
  end

  return results
end

return Completion
