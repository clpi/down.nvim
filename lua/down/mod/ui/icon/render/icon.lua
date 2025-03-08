local mark = require("down.mod.ui.icon.render.mark")
local tbl = require("down.util.table")
return {
  on_left = function(config, bufid, node)
    if not config.icon then
      return
    end
    local row_0b, col_0b, len = u.get_node_position_and_text_length(bufid, node)
    local text = (" "):rep(len - 1) .. config.icon
    mark.set(bufid, row_0b, col_0b, text, config.highlight)
  end,

  multilevel_on_right = function(is_ordered)
    return function(config, bufid, node)
      if not config.icons then
        return
      end

      local row_0b, col_0b, len =
        u.get_node_position_and_text_length(bufid, node)
      local icon_pattern = tbl.orlast(config.icons, len)
      if not icon_pattern then
        return
      end

      local icon = not is_ordered and icon_pattern
        or format_ordered_icon(icon_pattern, get_ordered_index(bufid, node))
      if not icon then
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
  end,

  footnote_concealed = function(config, bufid, node)
    local link_title_node = node:next_named_sibling()
    local link_title = vim.treesitter.get_node_text(link_title_node, bufid)
    if config.numeric_superscript and link_title:match("^[-0-9]+$") then
      local t = {}
      for i = 1, #link_title do
        local d = link_title:sub(i, i)
        table.insert(
          t,
          require("down.mod.ui.icon.builtin.icons.script").super[d]
        )
      end
      local superscripted_title = table.concat(t)
      local row_start_0b, col_start_0b, _, _ = link_title_node:range()
      local highlight = config.title_highlight
      mark.set(
        bufid,
        row_start_0b,
        col_start_0b,
        superscripted_title,
        highlight
      )
    end
  end,

  ---@param node TSNode
  quote_concealed = function(config, bufid, node)
    if not config.icons then
      return
    end

    local prefix = node:named_child(0)

    local row_0b, col_0b, len =
      u.get_node_position_and_text_length(bufid, prefix)

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
        if u.get_line_length(bufid, line) > len then
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
  end,

  fill_text = function(config, bufid, node)
    if not config.icon then
      return
    end
    local row_0b, col_0b, len = u.get_node_position_and_text_length(bufid, node)
    local text = config.icon:rep(len)
    mark.set(bufid, row_0b, col_0b, text, config.highlight)
  end,

  fill_multiline_chop2 = function(config, bufid, node)
    if not config.icon then
      return
    end
    local row_start_0b, col_start_0b, row_end_0bin, col_end_0bex = node:range()
    for i = row_start_0b, row_end_0bin do
      local l = i == row_start_0b and col_start_0b + 1 or 0
      local r_ex = i == row_end_0bin and col_end_0bex - 1
        or u.get_line_length(bufid, i)
      mark.set(bufid, i, l, config.icon:rep(r_ex - l), config.highlight)
    end
  end,

  render_horizontal_line = function(config, bufid, node)
    if not config.icon then
      return
    end

    local row_start_0b, col_start_0b, _, col_end_0bex = node:range()
    local render_col_start_0b = config.left == "here" and col_start_0b or 0
    local opt_textwidth = vim.bo[bufid].textwidth
    local render_col_end_0bex = config.right == "textwidth"
        and (opt_textwidth > 0 and opt_textwidth or 79)
      or vim.api.nvim_win_get_width(assert(vim.fn.bufwinid(bufid)))
    local len = math.max(
      col_end_0bex - col_start_0b,
      render_col_end_0bex - render_col_start_0b
    )
    mark.set(
      bufid,
      row_start_0b,
      render_col_start_0b,
      config.icon:rep(len),
      config.highlight
    )
  end,

  render_code_block = function(config, bufid, node)
    local tag_name = vim.treesitter.get_node_text(node:named_child(0), bufid)
    if not (tag_name == "code" or tag_name == "embed") then
      return
    end

    local row_start_0b, col_start_0b, row_end_0bin = node:range()
    assert(row_start_0b < row_end_0bin)
    local conceal_on = (vim.wo.conceallevel >= 2) and config.conceal

    if conceal_on then
      for _, row_0b in ipairs({ row_start_0b, row_end_0bin }) do
        vim.api.nvim_buf_set_extmark(
          bufid,
          M.ns_icon,
          row_0b,
          0,
          { end_col = u.get_line_length(bufid, row_0b), conceal = "" }
        )
      end
    end

    if conceal_on or config.content_only then
      row_start_0b = row_start_0b + 1
      row_end_0bin = row_end_0bin - 1
    end

    local line_lengths = {}
    local max_len = config.min_width or 0
    for row_0b = row_start_0b, row_end_0bin do
      local len = u.get_line_length(bufid, row_0b)
      if len > max_len then
        max_len = len
      end
      table.insert(line_lengths, len)
    end

    local to_eol = (config.width ~= "content")

    for row_0b = row_start_0b, row_end_0bin do
      local len = line_lengths[row_0b - row_start_0b + 1]
      local mark_col_start_0b = math.max(0, col_start_0b - config.padding.left)
      local mark_col_end_0bex = max_len + config.padding.right
      local priority = 101
      if len >= mark_col_start_0b then
        vim.api.nvim_buf_set_extmark(
          bufid,
          M.ns_icon,
          row_0b,
          mark_col_start_0b,
          {
            end_row = row_0b + 1,
            hl_eol = to_eol,
            hl_group = config.highlight,
            hl_mode = "blend",
            virt_text = not to_eol
                and {
                  { (" "):rep(mark_col_end_0bex - len), config.highlight },
                }
              or nil,
            virt_text_pos = "overlay",
            virt_text_win_col = len,
            spell = config.spell_check,
            priority = priority,
          }
        )
      else
        vim.api.nvim_buf_set_extmark(bufid, M.ns_icon, row_0b, len, {
          end_row = row_0b + 1,
          hl_eol = to_eol,
          hl_group = config.highlight,
          hl_mode = "blend",
          virt_text = {
            { (" "):rep(mark_col_start_0b - len) },
            {
              not to_eol and (" "):rep(mark_col_end_0bex - mark_col_start_0b)
                or "",
              config.highlight,
            },
          },
          virt_text_pos = "overlay",
          virt_text_win_col = len,
          spell = config.spell_check,
          priority = priority,
        })
      end
    end
  end,
}
