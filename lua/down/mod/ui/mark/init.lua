---@class down.mod.ui.Markark: down.Markod
local Mark = {
  namespace = 'down.mod.ui.mark',
}

---@class down.mod.ui.mark.Data
Mark.queries = {}

Mark.query = function(lang, q)
  local out = Mark.queries[q]
  if out == nil then
    out = vim.treesitter.query.parse(lang, q)
    Mark.queries[q] = out
  end
  return out
end

Mark.hl = {}

Mark.marks = {}

Mark.add_mark = function(name, query)
  vim.api.nvim_buf_set_extmark(0, Mark.ns)
end

Mark.markdown.query = function()
  Mark.query(
    'markdown',
    [[
    (section) @section
    [
      (atx_heading)
      (setext_heading)
    ] @heading
    (section (paragraph) @paragraph)
    (fenced_code_block) @code
    [
      (thematic_break)
      (minus_metadata)
      (plus_metadata)
    ] @dash
    (list_item) @list_item
    [
      (task_list_marker_unchecked)
      (task_list_marker_checked)
    ] @checkbox
    (block_quote) @quote
    (pipe_table) @table
  ]]
  )
end

Mark.markdown.inline.query = function()
  Mark.query(
    'markdown_inline',
    [[
    (code_span) @code_inline
    (shortcut_link) @shortcut
    [
      (uri_autolink)
      (email_autolink)
      (image)
      (inline_link)
      (full_reference_link)
    ] @link
    ((inline) @inline_highlight
      (#lua-match? @inline_highlight "==[^=]+=="))
  ]]
  )
end

return Mark
