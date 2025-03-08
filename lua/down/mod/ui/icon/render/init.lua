local icon = require("down.mod.ui.icon.render")
local ln = require("down.mod.edit.cursor.line")
local mark = require("down.mod.ui.icon.render.mark")
local script = require("down.mod.ui.icon.builtin.icons.script")
local tbl = require("down.util.table")
local util = require("down.mod.ui.icon.util")

local function get_ordered_index(bufid, prefix_node)
  -- TODO: calculate levels in one pass, since treesitter API implementation seems to have ridiculously high complexity
  local _, _, level = util.get_node_position_and_text_length(bufid, prefix_node)
  local header_node = prefix_node:parent()
  -- TODO: fix parser: `(ERROR)` on standalone prefix not followed by text, like `- `
  -- assert(header_node:type().."_prefix" == prefix_node:type())
  local sibling = header_node:prev_named_sibling()
  local count = 1

  while sibling and (sibling:type() == header_node:type()) do
    local _, _, sibling_level = util.get_node_position_and_text_length(
      bufid,
      util.get_header_prefix_node(sibling)
    )
    if sibling_level < level then
      break
    elseif sibling_level == level then
      count = count + 1
    end
    sibling = sibling:prev_named_sibling()
  end

  return count, (sibling or header_node:parent())
end
---@class down.mod.ui.icon.render
M = {
  buf = {},
  enabled = true,
  pretty = {},
}

M.icon = icon
M.mark = mark
M.icon_removers = {
  quote = function(_, bufid, node)
    for _, content in ipairs(node:field("content")) do
      local end_row, end_col = content:end_()

      -- This counteracts the issue where a quote can span onto the next
      -- line, even though it shouldn't.
      if end_col == 0 then
        end_row = end_row - 1
      end

      vim.api.nvim_buf_clear_namespace(
        bufid,
        M.mark.ns.icon.ns,
        (content:start()),
        end_row + 1
      )
    end
  end,
}

M.handle = function(event)
  if not M.enabled and (event.id ~= "cmd.events.icon.toggle") then
    return
  end
  return M.mark.handlers[event.id](event)
end

M.on_left = function(config, bufid, node)
  if not config.icon then
    return
  end
  local row_0b, col_0b, len =
    util.get_node_position_and_text_length(bufid, node)
  local text = (" "):rep(len - 1) .. config.icon
  mark.set(bufid, row_0b, col_0b, text, config.highlight)
end

M.multilevel_on_right = function(is_ordered)
  return function(config, bufid, node)
    if not config.icons then
      return
    end

    local row_0b, col_0b, len =
      util.get_node_position_and_text_length(bufid, node)
    local icon_pattern = tbl.orlast(config.icons, len)
    if not icon_pattern then
      return
    end

    local oi = get_ordered_index(bufid, node)

    local i = not is_ordered and icon_pattern or oi
    if not i then
      return
    end

    local text = (" "):rep(len - 1) .. icon

    local _, first_unicode_end =
      text:find("[%z\1-\127\194-\244][\128-\191]*", len)
    local highlight = config.highlights and tbl.orlast(config.highlights, len)
    mark.set(bufid, row_0b, col_0b, text:sub(1, first_unicode_end), highlight)
    if vim.fn.strcharlen(text) > len then
      mark.set(
        bufid,
        row_0b,
        col_0b + len,
        text:sub(first_unicode_end + 1),
        highlight,
        {
          virt_text_pos = "inline",
        }
      )
    end
  end
end

M.footnote_concealed = function(config, bufid, node)
  local link_title_node = node:next_named_sibling()
  local link_title = vim.treesitter.get_node_text(link_title_node, bufid)
  if config.numeric_superscript and link_title:match("^[-0-9]+$") then
    local t = {}
    for i = 1, #link_title do
      local d = link_title:sub(i, i)
      table.insert(t, script.super[d])
    end
    local superscripted_title = table.concat(t)
    local row_start_0b, col_start_0b, _, _ = link_title_node:range()
    local highlight = config.title_highlight
    mark.set(bufid, row_start_0b, col_start_0b, superscripted_title, highlight)
  end
end

---@param node TSNode
M.quote_concealed = function(config, bufid, node)
  if not config.icons then
    return
  end

  local prefix = node:named_child(0)

  local row_0b, col_0b, len =
    util.get_node_position_and_text_length(bufid, prefix)

  local last_icon, last_highlight

  for _, child in ipairs(node:field("content")) do
    local row_last_0b, col_last_0b = child:end_()

    -- Sometimes the parser overshoots to the next newline, breaking
    -- the range.
    -- To counteract this we correct the overshoot.
    if col_last_0b == 0 then
      row_last_0b = row_last_0b - 1
    end

    for line = row_0b, row_last_0b do
      if M.mark.ln.len(bufid, line) > len then
        for col = 1, len do
          if config.icons[col] ~= nil then
            last_icon = config.icons[col]
          end
          if not last_icon then
            goto continue
          end
          last_highlight = config.highlights[col] or last_highlight
          mark.set(bufid, line, col_0b + (col - 1), last_icon, last_highlight)
          ::continue::
        end
      end
    end
  end
end

M.fill_text = function(config, bufid, node)
  if not config.icon then
    return
  end
  local row_0b, col_0b, len =
    util.get_node_position_and_text_length(bufid, node)
  local text = config.icon:rep(len)
  mark.set(bufid, row_0b, col_0b, text, config.highlight)
end

M.fill_multiline_chop2 = function(config, bufid, node)
  if not config.icon then
    return
  end
  local row_start_0b, col_start_0b, row_end_0bin, col_end_0bex = node:range()
  for i = row_start_0b, row_end_0bin do
    local l = i == row_start_0b and col_start_0b + 1 or 0
    local r_ex = i == row_end_0bin and col_end_0bex - 1
      or util.get_line_length(bufid, i)
    mark.set(bufid, i, l, config.icon:rep(r_ex - l), config.highlight)
  end
end

-- M.render_horizontal_line = function(config, bufid, node)
--   if not config.icon then
--     return
--   end
--
--   local row_start_0b, col_start_0b, _, col_end_0bex = node:range()
--   local render_col_start_0b = config.left == "here" and col_start_0b or 0
--   local opt_textwidth = vim.bo[bufid].textwidth
--   local render_col_end_0bex = config.right == "textwidth"
--       and (opt_textwidth > 0 and opt_textwidth or 79)
--     or vim.api.nvim_win_get_width(assert(vim.fn.bufwinid(bufid)))
--   local len = math.max(
--     end
return M
