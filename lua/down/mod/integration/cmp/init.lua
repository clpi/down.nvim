local log = require("down.log")
local mod = require("down.mod")

local cmpok, cmp = pcall(require, "cmp")

---@class down.mod.integration.Cmp: down.Mod
local M = mod.new("integration.cmp")
M.dep = { "workspace", "tag", "data" }

M.clean = function(s)
  if not s then
    return s
  end
  s = s:gsub("\n", " ")
  return s:gsub("%s%s+", " ")
end

--- Scan directory recursively for files
---@param dir string
---@param pattern? string
---@return string[]
local function scan_dir(dir, pattern)
  local files = {}
  pattern = pattern or "**/*"

  local scan_results = vim.fn.globpath(dir, pattern, true, true)
  for _, file in ipairs(scan_results) do
    if vim.fn.isdirectory(file) == 0 then
      table.insert(files, file)
    end
  end

  return files
end

---@class down.mod.integration.cmp.Config
M.config = {
  --- Enable slash command source
  slash = true,
  --- Enable @ mention source
  mention = true,
  --- Enable # tag source
  tag = true,
  --- Enable file linking source
  files = true,
}

---@return down.mod.Setup
M.setup = function()
  if cmpok then
    -- Register slash command source
    if M.config.slash then
      cmp.register_source("down_slash", M.slash_source().new())
    end

    -- Register mention source
    if M.config.mention then
      cmp.register_source("down_mention", M.mention_source().new())
    end

    -- Register tag source
    if M.config.tag then
      cmp.register_source("down_tag", M.tag_source().new())
    end

    -- Register file source
    if M.config.files then
      cmp.register_source("down_file", M.file_source().new())
    end

    -- Suggest adding sources to cmp config
    log.trace(
      "down.nvim: nvim-cmp sources registered. Add { name = 'down_slash' }, "
        .. "{ name = 'down_mention' }, { name = 'down_tag' }, { name = 'down_file' } "
        .. "to your cmp sources for markdown filetypes."
    )
    return {
      loaded = true,
    }
  else
    return { loaded = false }
  end
end

--- nvim-cmp source for slash commands (/)
---@return cmp.Source
M.slash_source = function()
  local source = {}
  local Slash = require("down.mod.lsp.completion.slash")

  source.new = function()
    return setmetatable({}, { __index = source })
  end

  source.get_trigger_characters = function()
    return { "/" }
  end

  source.is_available = function()
    local ft = vim.bo.filetype
    return ft == "markdown" or ft == "md" or ft == "down"
  end

  source.get_keyword_pattern = function()
    return [[\(/\)\k*]]
  end

  source.complete = function(self, request, callback)
    local context = request.context
    local cursor_before = context.cursor_before_line

    -- Only trigger when / is at beginning of line or after whitespace
    if not (cursor_before:match("^%s*/.?$") or cursor_before:match("%s/.?$")) then
      callback({ items = {}, isIncomplete = false })
      return
    end

    local query = cursor_before:match("/(%S*)$") or ""
    local items = Slash.get_items(M, query)
    local cmp_items = {}

    for _, item in ipairs(items) do
      local cmp_item = {
        label = item.label,
        kind = cmp.lsp.CompletionItemKind.Snippet,
        detail = item.detail,
        documentation = {
          kind = cmp.lsp.MarkupKind.Markdown,
          value = item.documentation or "",
        },
        insertText = item.insert_text or "",
        insertTextFormat = item.snippet and vim.lsp.protocol.InsertTextFormat.Snippet
          or vim.lsp.protocol.InsertTextFormat.PlainText,
        filterText = "/" .. (item.filter_text or ""),
        sortText = item.filter_text or item.label,
      }
      table.insert(cmp_items, cmp_item)
    end

    callback({ items = cmp_items, isIncomplete = false })
  end

  return source
end

--- nvim-cmp source for @ mentions
---@return cmp.Source
M.mention_source = function()
  local source = {}
  local Mention = require("down.mod.lsp.completion.mention")

  source.new = function()
    return setmetatable({}, { __index = source })
  end

  source.get_trigger_characters = function()
    return { "@" }
  end

  source.is_available = function()
    local ft = vim.bo.filetype
    return ft == "markdown" or ft == "md" or ft == "down"
  end

  source.complete = function(self, request, callback)
    local context = request.context
    local cursor_before = context.cursor_before_line
    local query = cursor_before:match("@(%S*)$") or ""

    local items = Mention.get_items(M, query)
    local cmp_items = {}

    for _, item in ipairs(items) do
      local cmp_item = {
        label = item.label,
        kind = cmp.lsp.CompletionItemKind.Reference,
        detail = item.detail,
        documentation = {
          kind = cmp.lsp.MarkupKind.Markdown,
          value = item.documentation or "",
        },
        insertText = item.insert_text or "",
        filterText = "@" .. (item.filter_text or ""),
        sortText = item.sort_text or item.filter_text or item.label,
      }
      table.insert(cmp_items, cmp_item)
    end

    callback({ items = cmp_items, isIncomplete = false })
  end

  return source
end

--- nvim-cmp source for # tags
---@return cmp.Source
M.tag_source = function()
  local source = {}
  local TagCompletion = require("down.mod.lsp.completion.tag")

  source.new = function()
    return setmetatable({}, { __index = source })
  end

  source.get_trigger_characters = function()
    return { "#" }
  end

  source.is_available = function()
    local ft = vim.bo.filetype
    if not (ft == "markdown" or ft == "md" or ft == "down") then
      return false
    end
    -- Don't trigger in headings
    local line = vim.api.nvim_get_current_line()
    return not line:match("^%s*#+%s")
  end

  source.complete = function(self, request, callback)
    local context = request.context
    local cursor_before = context.cursor_before_line

    -- Don't complete if this looks like a heading
    if cursor_before:match("^%s*#+%s") then
      callback({ items = {}, isIncomplete = false })
      return
    end

    local query = cursor_before:match("#(%S*)$") or ""

    local items = TagCompletion.get_items(M, query)
    local cmp_items = {}

    for _, item in ipairs(items) do
      local cmp_item = {
        label = item.label,
        kind = cmp.lsp.CompletionItemKind.Keyword,
        detail = item.detail,
        documentation = {
          kind = cmp.lsp.MarkupKind.Markdown,
          value = item.documentation or "",
        },
        insertText = item.insert_text or "",
        filterText = "#" .. (item.filter_text or ""),
        sortText = item.sort_text or item.filter_text or item.label,
      }
      table.insert(cmp_items, cmp_item)
    end

    callback({ items = cmp_items, isIncomplete = false })
  end

  return source
end

--- nvim-cmp source for file linking
---@return cmp.Source
M.file_source = function()
  local source = {}

  source.new = function()
    return setmetatable({}, { __index = source })
  end

  source.get_trigger_characters = function()
    return { "[" }
  end

  source.is_available = function()
    local ft = vim.bo.filetype
    return ft == "markdown" or ft == "md" or ft == "down"
  end

  source.complete = function(self, request, callback)
    local context = request.context
    local cursor_before = context.cursor_before_line

    -- Only trigger inside [[ for wiki links
    if not cursor_before:match("%[%[$") and not cursor_before:match("%[%[%S*$") then
      callback({ items = {}, isIncomplete = false })
      return
    end

    local ws = M.dep["workspace"]
    if not ws then
      callback({ items = {}, isIncomplete = false })
      return
    end

    local current_ws = ws.current()
    local ws_path = ws.get(current_ws)
    if not ws_path then
      callback({ items = {}, isIncomplete = false })
      return
    end

    local ext = ws.config.ext or ".md"
    local files = scan_dir(ws_path, "**/*" .. ext)
    local cmp_items = {}

    for _, filepath in ipairs(files) do
      local rel = filepath:sub(#ws_path + 2)
      local name = rel:match("(.+)%" .. ext .. "$") or rel
      local basename = name:match("[^/]+$") or name

      local cmp_item = {
        label = "󰎞 " .. basename,
        kind = cmp.lsp.CompletionItemKind.File,
        detail = rel,
        documentation = {
          kind = cmp.lsp.MarkupKind.Markdown,
          value = "Link to: " .. rel,
        },
        insertText = basename .. "]]",
        filterText = "[[" .. basename:lower(),
        sortText = basename:lower(),
      }
      table.insert(cmp_items, cmp_item)
    end

    callback({ items = cmp_items, isIncomplete = false })
  end

  return source
end

--- Register all sources with nvim-cmp
--- Files source (legacy compat)
M.files = function()
  local items = {}
  local ws = M.dep["workspace"]
  if not ws then
    return items
  end

  local current_ws = ws.current()
  local root = ws.get(current_ws)
  if not root then
    return items
  end

  local ext = ws.config.ext or ".md"
  local files = scan_dir(root, "**/*" .. ext)

  for _, path in ipairs(files) do
    local item = {
      path = path,
      label = path:match("([^/^\\]+)%" .. ext .. "$"),
      kind = cmp.lsp.CompletionItemKind.File,
    }
    if item.label then
      item.insertText = "[" .. item.label .. "](" .. path .. ")"
      local binary = io.open(item.path, "rb")
      if binary then
        local kb = binary:read(1024)
        item.documentation = {
          kind = cmp.lsp.MarkupKind.Markdown,
          value = kb or "",
        }
        binary:close()
      end
      table.insert(items, item)
    end
  end
  return items
end

return M
