local mod = require("down.mod")

---@type down.Mod
local M = mod.new("integration.blink")
M.dep = { "workspace", "tag" }

local has_blink, blink = pcall(require, "blink.cmp")

---@class down.integration.blink.Config
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
  if has_blink then
    return {
      loaded = true,
    }
  else
    return { loaded = false }
  end
end

---@class down.integration.blink.Data
M.source = require("down.mod.integration.blink.source")
M.format = require("down.mod.integration.blink.format")

--- Create a blink.cmp source for slash commands
---@return blink.cmp.Source
M.slash_source = function()
  local Slash = require("down.mod.lsp.completion.slash")

  ---@type blink.cmp.Source
  local src = {}

  function src:get_trigger_characters()
    return { "/" }
  end

  function src:get_completions(ctx, cb)
    local line = ctx.line
    local cursor = ctx.cursor

    -- Only trigger at beginning of line or after whitespace
    local before = line:sub(1, cursor[2])
    if not (before:match("^%s*/$") or before:match("%s/$") or before:match("^%s*/%S*$") or before:match("%s/%S*$")) then
      cb({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
      return
    end

    local query = before:match("/(%S*)$") or ""
    local items = Slash.get_items(M, query)
    local blink_items = {}

    for _, item in ipairs(items) do
      table.insert(blink_items, {
        label = item.label,
        kind = require("blink.cmp.types").CompletionItemKind.Snippet,
        detail = item.detail,
        documentation = item.documentation,
        insertText = item.insert_text or "",
        insertTextFormat = item.snippet and 2 or 1, -- 2=Snippet, 1=PlainText
        filterText = "/" .. (item.filter_text or ""),
        sortText = item.filter_text or item.label,
        source_name = "down_slash",
      })
    end

    cb({
      items = blink_items,
      is_incomplete_forward = false,
      is_incomplete_backward = false,
    })
  end

  return src
end

--- Create a blink.cmp source for @ mentions
---@return blink.cmp.Source
M.mention_source = function()
  local Mention = require("down.mod.lsp.completion.mention")

  ---@type blink.cmp.Source
  local src = {}

  function src:get_trigger_characters()
    return { "@" }
  end

  function src:get_completions(ctx, cb)
    local line = ctx.line
    local cursor = ctx.cursor
    local before = line:sub(1, cursor[2])
    local query = before:match("@(%S*)$") or ""

    local items = Mention.get_items(M, query)
    local blink_items = {}

    for _, item in ipairs(items) do
      table.insert(blink_items, {
        label = item.label,
        kind = require("blink.cmp.types").CompletionItemKind.Reference,
        detail = item.detail,
        documentation = item.documentation,
        insertText = item.insert_text or "",
        filterText = "@" .. (item.filter_text or ""),
        sortText = item.sort_text or item.filter_text or "",
        source_name = "down_mention",
      })
    end

    cb({
      items = blink_items,
      is_incomplete_forward = false,
      is_incomplete_backward = false,
    })
  end

  return src
end

--- Create a blink.cmp source for # tags
---@return blink.cmp.Source
M.tag_source = function()
  local TagCompletion = require("down.mod.lsp.completion.tag")

  ---@type blink.cmp.Source
  local src = {}

  function src:get_trigger_characters()
    return { "#" }
  end

  function src:get_completions(ctx, cb)
    local line = ctx.line
    local cursor = ctx.cursor
    local before = line:sub(1, cursor[2])

    -- Don't trigger in headings
    if before:match("^%s*#+%s") then
      cb({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
      return
    end

    local query = before:match("#(%S*)$") or ""

    local items = TagCompletion.get_items(M, query)
    local blink_items = {}

    for _, item in ipairs(items) do
      table.insert(blink_items, {
        label = item.label,
        kind = require("blink.cmp.types").CompletionItemKind.Keyword,
        detail = item.detail,
        documentation = item.documentation,
        insertText = item.insert_text or "",
        filterText = "#" .. (item.filter_text or ""),
        sortText = item.sort_text or item.filter_text or "",
        source_name = "down_tag",
      })
    end

    cb({
      items = blink_items,
      is_incomplete_forward = false,
      is_incomplete_backward = false,
    })
  end

  return src
end

--- Get recommended sources for blink.cmp depending on context.
--- Provides LSP completions for code blocks in markdown files.
--- Example usage in blink.cmp config:
--- sources = { default = require('down.mod.integration.blink').sources_default }
---@param ctx table
---@return string[]
M.sources_default = function(ctx)
  local success, node = pcall(vim.treesitter.get_node)
  
  -- Support for different code block languages injected in markdown
  if success and node then
    local lang = node:tree():lang()
    if lang and lang ~= "markdown" and lang ~= "markdown_inline" then
      if vim.tbl_contains({ 'comment', 'line_comment', 'block_comment' }, node:type()) then
        return { 'buffer' }
      end
      return { 'lsp', 'path', 'snippets', 'buffer' }
    end
  end

  -- Native filetype context
  if vim.bo.filetype == 'lua' then
    return { 'lsp', 'path' }
  end

  return { 'lsp', 'path', 'snippets', 'buffer' }
end

return M
