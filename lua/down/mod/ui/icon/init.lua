local down = require('down')
local log, mod, utils = down.log, down.mod, down.utils
local u = require('down.mod.ui.icon.util')

local M = mod.new('ui.icon', {
  'basic',
  'complex',
  'diamond',
})

M.setup = function()
  return {
    loaded = true,
    dependencies = {
      'tool.treesitter',
    },
  }
end

local function set_mark(bufid, row_0b, col_0b, text, highlight, ext_opts)
  local ns_icon = M.ns_icon
  local opt = {
    virt_text = { { text, highlight } },
    virt_text_pos = 'overlay',
    virt_text_win_col = nil,
    hl_group = nil,
    conceal = nil,
    id = nil,
    end_row = row_0b,
    end_col = col_0b,
    hl_eol = nil,
    virt_text_hide = nil,
    hl_mode = 'combine',
    virt_lines = nil,
    virt_lines_above = nil,
    virt_lines_leftcol = nil,
    ephemeral = nil,
    right_gravity = nil,
    end_right_gravity = nil,
    priority = nil,
    strict = nil, -- default true
    sign_text = nil,
    sign_hl_group = nil,
    number_hl_group = nil,
    line_hl_group = nil,
    cursorline_hl_group = nil,
    spell = nil,
    ui_watched = nil,
    invalidate = true,
  }

  if ext_opts then
    u.table_extend_in_place(opt, ext_opts)
  end

  vim.api.nvim_buf_set_extmark(bufid, ns_icon, row_0b, col_0b, opt)
end

local function table_get_default_last(tbl, index)
  return tbl[index] or tbl[#tbl]
end

local function get_ordered_index(bufid, prefix_node)
  -- TODO: calculate levels in one pass, since treesitter API implementation seems to have ridiculously high complexity
  local _, _, level = get_node_position_and_text_length(bufid, prefix_node)
  local header_node = prefix_node:parent()
  -- TODO: fix parser: `(ERROR)` on standalone prefix not followed by text, like `- `
  -- assert(header_node:type().."_prefix" == prefix_node:type())
  local sibling = header_node:prev_named_sibling()
  local count = 1

  while sibling and (sibling:type() == header_node:type()) do
    local _, _, sibling_level =
        get_node_position_and_text_length(bufid, get_header_prefix_node(sibling))
    if sibling_level < level then
      break
    elseif sibling_level == level then
      count = count + 1
    end
    sibling = sibling:prev_named_sibling()
  end

  return count, (sibling or header_node:parent())
end

local function tbl_reverse(tbl)
  local result = {}
  for i = 1, #tbl do
    result[i] = tbl[#tbl - i + 1]
  end
  return result
end

local function tostring_lowercase(n)
  local t = {}
  while n > 0 do
    t[#t + 1] = string.char(0x61 + (n - 1) % 26)
    n = math.floor((n - 1) / 26)
  end
  return table.concat(t):reverse()
end

local roman_numerals = {
  { 'i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix' },
  { 'x', 'xx', 'xxx', 'xl', 'l', 'lx', 'lxx', 'lxxx', 'xc' },
  { 'c', 'cc', 'ccc', 'cd', 'd', 'dc', 'dcc', 'dccc', 'cm' },
  { 'm', 'mm', 'mmm' },
}

local function tostring_roman_lowercase(n)
  if n >= 4000 then
    -- too large to render
    return
  end

  local result = {}
  local i = 1
  while n > 0 do
    result[#result + 1] = roman_numerals[i][n % 10]
    n = math.floor(n / 10)
    i = i + 1
  end
  return table.concat(tbl_reverse(result))
end

local ordered_icon_table = {
  ['0'] = function(i)
    return tostring(i - 1)
  end,
  ['1'] = function(i)
    return tostring(i)
  end,
  ['a'] = function(i)
    return tostring_lowercase(i)
  end,
  ['A'] = function(i)
    return tostring_lowercase(i):upper()
  end,
  ['i'] = function(i)
    return tostring_roman_lowercase(i)
  end,
  ['I'] = function(i)
    return tostring_roman_lowercase(i):upper()
  end,
  ['Ⅰ'] = {
    'Ⅰ',
    'Ⅱ',
    'Ⅲ',
    'Ⅳ',
    'Ⅴ',
    'Ⅵ',
    'Ⅶ',
    'Ⅷ',
    'Ⅸ',
    'Ⅹ',
    'Ⅺ',
    'Ⅻ',
  },
  ['ⅰ'] = {
    'ⅰ',
    'ⅱ',
    'ⅲ',
    'ⅳ',
    'ⅴ',
    'ⅵ',
    'ⅶ',
    'ⅷ',
    'ⅸ',
    'ⅹ',
    'ⅺ',
    'ⅻ',
  },
  ['⒈'] = {
    '⒈',
    '⒉',
    '⒊',
    '⒋',
    '⒌',
    '⒍',
    '⒎',
    '⒏',
    '⒐',
    '⒑',
    '⒒',
    '⒓',
    '⒔',
    '⒕',
    '⒖',
    '⒗',
    '⒘',
    '⒙',
    '⒚',
    '⒛',
  },
  ['⑴'] = {
    '⑴',
    '⑵',
    '⑶',
    '⑷',
    '⑸',
    '⑹',
    '⑺',
    '⑻',
    '⑼',
    '⑽',
    '⑾',
    '⑿',
    '⒀',
    '⒁',
    '⒂',
    '⒃',
    '⒄',
    '⒅',
    '⒆',
    '⒇',
  },
  ['①'] = {
    '①',
    '②',
    '③',
    '④',
    '⑤',
    '⑥',
    '⑦',
    '⑧',
    '⑨',
    '⑩',
    '⑪',
    '⑫',
    '⑬',
    '⑭',
    '⑮',
    '⑯',
    '⑰',
    '⑱',
    '⑲',
    '⑳',
  },
  ['⒜'] = {
    '⒜',
    '⒝',
    '⒞',
    '⒟',
    '⒠',
    '⒡',
    '⒢',
    '⒣',
    '⒤',
    '⒥',
    '⒦',
    '⒧',
    '⒨',
    '⒩',
    '⒪',
    '⒫',
    '⒬',
    '⒭',
    '⒮',
    '⒯',
    '⒰',
    '⒱',
    '⒲',
    '⒳',
    '⒴',
    '⒵',
  },
  ['Ⓐ'] = {
    'Ⓐ',
    'Ⓑ',
    'Ⓒ',
    'Ⓓ',
    'Ⓔ',
    'Ⓕ',
    'Ⓖ',
    'Ⓗ',
    'Ⓘ',
    'Ⓙ',
    'Ⓚ',
    'Ⓛ',
    'Ⓜ',
    'Ⓝ',
    'Ⓞ',
    'Ⓟ',
    'Ⓠ',
    'Ⓡ',
    'Ⓢ',
    'Ⓣ',
    'Ⓤ',
    'Ⓥ',
    'Ⓦ',
    'Ⓧ',
    'Ⓨ',
    'Ⓩ',
  },
  ['ⓐ'] = {
    'ⓐ',
    'ⓑ',
    'ⓒ',
    'ⓓ',
    'ⓔ',
    'ⓕ',
    'ⓖ',
    'ⓗ',
    'ⓘ',
    'ⓙ',
    'ⓚ',
    'ⓛ',
    'ⓜ',
    'ⓝ',
    'ⓞ',
    'ⓟ',
    'ⓠ',
    'ⓡ',
    'ⓢ',
    'ⓣ',
    'ⓤ',
    'ⓥ',
    'ⓦ',
    'ⓧ',
    'ⓨ',
    'ⓩ',
  },
}

local memoized_ordered_icon_generator = {}

local function format_ordered_icon(pattern, index)
  if type(pattern) == 'function' then
    return pattern(index)
  end

  local gen = memoized_ordered_icon_generator[pattern]
  if gen then
    return gen(index)
  end

  for char_one, number_table in pairs(ordered_icon_table) do
    local l, r = pattern:find(char_one:find('%w') and '%f[%w]' .. char_one .. '%f[%W]' or char_one)
    if l then
      gen = function(index_)
        local icon = type(number_table) == 'function' and number_table(index_)
            or number_table[index_]
        return icon and pattern:sub(1, l - 1) .. icon .. pattern:sub(r + 1)
      end
      break
    end
  end

  gen = gen or function(_) end

  memoized_ordered_icon_generator[pattern] = gen
  return gen(index)
end

local superscript_digits = {
  ['0'] = '⁰',
  ['1'] = '¹',
  ['2'] = '²',
  ['3'] = '³',
  ['4'] = '⁴',
  ['5'] = '⁵',
  ['6'] = '⁶',
  ['7'] = '⁷',
  ['8'] = '⁸',
  ['9'] = '⁹',
  ['-'] = '⁻',
}

---@class down.ui.icon.Data
M.ns_icon = vim.api.nvim_create_namespace('down/icon')
M.ns_prettify_flag = vim.api.nvim_create_namespace('down/icon.prettify-flag')
M.rerendering_scheduled_bufids = {}
M.enabled = true
M.cursor_record = {}
M.icon_renderers = {
  on_left = function(config, bufid, node)
    if not config.icon then
      return
    end
    local row_0b, col_0b, len = u.get_node_position_and_text_length(bufid, node)
    local text = (' '):rep(len - 1) .. config.icon
    set_mark(bufid, row_0b, col_0b, text, config.highlight)
  end,

  multilevel_on_right = function(is_ordered)
    return function(config, bufid, node)
      if not config.icons then
        return
      end

      local row_0b, col_0b, len = u.get_node_position_and_text_length(bufid, node)
      local icon_pattern = table_get_default_last(config.icons, len)
      if not icon_pattern then
        return
      end

      local icon = not is_ordered and icon_pattern
          or format_ordered_icon(icon_pattern, get_ordered_index(bufid, node))
      if not icon then
        return
      end

      local text = (' '):rep(len - 1) .. icon

      local _, first_unicode_end = text:find('[%z\1-\127\194-\244][\128-\191]*', len)
      local highlight = config.highlights and table_get_default_last(config.highlights, len)
      set_mark(bufid, row_0b, col_0b, text:sub(1, first_unicode_end), highlight)
      if vim.fn.strcharlen(text) > len then
        set_mark(bufid, row_0b, col_0b + len, text:sub(first_unicode_end + 1), highlight, {
          virt_text_pos = 'inline',
        })
      end
    end
  end,

  footnote_concealed = function(config, bufid, node)
    local link_title_node = node:next_named_sibling()
    local link_title = vim.treesitter.get_node_text(link_title_node, bufid)
    if config.numeric_superscript and link_title:match('^[-0-9]+$') then
      local t = {}
      for i = 1, #link_title do
        local d = link_title:sub(i, i)
        table.insert(t, superscript_digits[d])
      end
      local superscripted_title = table.concat(t)
      local row_start_0b, col_start_0b, _, _ = link_title_node:range()
      local highlight = config.title_highlight
      set_mark(bufid, row_start_0b, col_start_0b, superscripted_title, highlight)
    end
  end,

  ---@param node TSNode
  quote_concealed = function(config, bufid, node)
    if not config.icons then
      return
    end

    local prefix = node:named_child(0)

    local row_0b, col_0b, len = u.get_node_position_and_text_length(bufid, prefix)

    local last_icon, last_highlight

    for _, child in ipairs(node:field('content')) do
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
            set_mark(bufid, line, col_0b + (col - 1), last_icon, last_highlight)
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
    set_mark(bufid, row_0b, col_0b, text, config.highlight)
  end,

  fill_multiline_chop2 = function(config, bufid, node)
    if not config.icon then
      return
    end
    local row_start_0b, col_start_0b, row_end_0bin, col_end_0bex = node:range()
    for i = row_start_0b, row_end_0bin do
      local l = i == row_start_0b and col_start_0b + 1 or 0
      local r_ex = i == row_end_0bin and col_end_0bex - 1 or u.get_line_length(bufid, i)
      set_mark(bufid, i, l, config.icon:rep(r_ex - l), config.highlight)
    end
  end,

  render_horizontal_line = function(config, bufid, node)
    if not config.icon then
      return
    end

    local row_start_0b, col_start_0b, _, col_end_0bex = node:range()
    local render_col_start_0b = config.left == 'here' and col_start_0b or 0
    local opt_textwidth = vim.bo[bufid].textwidth
    local render_col_end_0bex = config.right == 'textwidth'
        and (opt_textwidth > 0 and opt_textwidth or 79)
        or vim.api.nvim_win_get_width(assert(vim.fn.bufwinid(bufid)))
    local len = math.max(col_end_0bex - col_start_0b, render_col_end_0bex - render_col_start_0b)
    set_mark(bufid, row_start_0b, render_col_start_0b, config.icon:rep(len), config.highlight)
  end,

  render_code_block = function(config, bufid, node)
    local tag_name = vim.treesitter.get_node_text(node:named_child(0), bufid)
    if not (tag_name == 'code' or tag_name == 'embed') then
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
          { end_col = u.get_line_length(bufid, row_0b), conceal = '' }
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

    local to_eol = (config.width ~= 'content')

    for row_0b = row_start_0b, row_end_0bin do
      local len = line_lengths[row_0b - row_start_0b + 1]
      local mark_col_start_0b = math.max(0, col_start_0b - config.padding.left)
      local mark_col_end_0bex = max_len + config.padding.right
      local priority = 101
      if len >= mark_col_start_0b then
        vim.api.nvim_buf_set_extmark(bufid, M.ns_icon, row_0b, mark_col_start_0b, {
          end_row = row_0b + 1,
          hl_eol = to_eol,
          hl_group = config.highlight,
          hl_mode = 'blend',
          virt_text = not to_eol and {
            { (' '):rep(mark_col_end_0bex - len), config.highlight },
          } or nil,
          virt_text_pos = 'overlay',
          virt_text_win_col = len,
          spell = config.spell_check,
          priority = priority,
        })
      else
        vim.api.nvim_buf_set_extmark(bufid, M.ns_icon, row_0b, len, {
          end_row = row_0b + 1,
          hl_eol = to_eol,
          hl_group = config.highlight,
          hl_mode = 'blend',
          virt_text = {
            { (' '):rep(mark_col_start_0b - len) },
            {
              not to_eol and (' '):rep(mark_col_end_0bex - mark_col_start_0b) or '',
              config.highlight,
            },
          },
          virt_text_pos = 'overlay',
          virt_text_win_col = len,
          spell = config.spell_check,
          priority = priority,
        })
      end
    end
  end,
}

M.icon_removers = {
  quote = function(_, bufid, node)
    for _, content in ipairs(node:field('content')) do
      local end_row, end_col = content:end_()

      -- This counteracts the issue where a quote can span onto the next
      -- line, even though it shouldn't.
      if end_col == 0 then
        end_row = end_row - 1
      end

      vim.api.nvim_buf_clear_namespace(bufid, M.ns_icon, (content:start()), end_row + 1)
    end
  end,
}
---@class down.ui.icon.Config
M.config = {
  -- Which icon preset to use.
  --
  -- The currently available icon presets are:
  -- - "basic" - use a mixture of icons (includes cute flower icons!)
  -- - "diamond" - use diamond shapes for headings
  -- - "varied" - use a mix of round and diamond shapes for headings; no cute flower icons though :(
  icon = 'basic',

  -- If true, down will enable folding by default for `.down` documents.
  -- You may use the inbuilt Neovim folding options like `foldnestmax`,
  -- `foldlevelstart` and others to then tune the behaviour to your liking.
  --
  -- Set to `false` if you do not want down setting anything.
  folds = true,

  -- When set to `auto`, down will open all folds when opening new documents if `foldlevel` is 0.
  -- When set to `always`, down will always open all folds when opening new documents.
  -- When set to `never`, down will not do anything.
  mod_open_folds = 'auto',

  -- Configuration for icons.
  --
  -- This table contains the full configuration set for each icon, including
  -- its query (where to be placed), render functions (how to be placed) and
  -- characters to use.
  --
  -- For most use cases, the only values that you should be changing is the `icon`/`icons` field.
  -- `icon` is a string, while `icons` is a table of strings for multilevel elements like
  -- headings, lists, and quotes.
  --
  -- To disable part of the config, replace the table with `false`, or prepend `false and` to it.
  -- For example: `done = false` or `done = false and { ... }`.
  icons = {
    todo = {
      done = {
        icon = '󰄬',
        nodes = { 'todo_item_done' },
        render = M.icon_renderers.handle_left,
      },
      pending = {
        icon = '󰥔',
        nodes = { 'todo_item_pending' },
        render = M.icon_renderers.handle_left,
      },
      undone = {
        icon = ' ',
        nodes = { 'todo_item_undone' },
        render = M.icon_renderers.handle_left,
      },
      uncertain = {
        icon = '',
        nodes = { 'todo_item_uncertain' },
        render = M.icon_renderers.handle_left,
      },
      on_hold = {
        icon = '',
        nodes = { 'todo_iteM.handle_hold' },
        render = M.icon_renderers.handle_left,
      },
      cancelled = {
        icon = '',
        nodes = { 'todo_item_cancelled' },
        render = M.icon_renderers.handle_left,
      },
      recurring = {
        icon = '↺',
        nodes = { 'todo_item_recurring' },
        render = M.icon_renderers.handle_left,
      },
      urgent = {
        icon = '⚠',
        nodes = { 'todo_item_urgent' },
        render = M.icon_renderers.handle_left,
      },
    },

    list = {
      icons = { '•' },
      nodes = {
        -- "unordered_list1_prefix",
        -- "unordered_list2_prefix",
        -- "unordered_list3_prefix",
        -- "unordered_list4_prefix",
        -- "unordered_list5_prefix",
        -- "unordered_list6_prefix",
      },
      render = M.icon_renderers.multilevel_on_right(false),
    },
    ordered = {
      icons = { '1.', 'A.', 'a.', '(1)', 'I.', 'i.' },
      nodes = {
        -- "ordered_list1_prefix",
        -- "ordered_list2_prefix",
        -- "ordered_list3_prefix",
        -- "ordered_list4_prefix",
        -- "ordered_list5_prefix",
        -- "ordered_list6_prefix",
      },
      render = M.icon_renderers.multilevel_on_right(true),
    },
    quote = {
      icons = { '│' },
      nodes = {
        -- "quote1",
        -- "quote2",
        -- "quote3",
        -- "quote4",
        -- "quote5",
        -- "quote6",
      },
      highlights = {
        '@down.quotes.1.prefix',
        '@down.quotes.2.prefix',
        '@down.quotes.3.prefix',
        '@down.quotes.4.prefix',
        '@down.quotes.5.prefix',
        '@down.quotes.6.prefix',
      },
      render = M.icon_renderers.quote_concealed,
      clear = M.icon_removers.quote,
    },
    heading = {
      icons = { '◉', '◎', '○', '✺', '▶', '⤷' },
      highlights = {
        '@down.headings.1.prefix',
        '@down.headings.2.prefix',
        '@down.headings.3.prefix',
        '@down.headings.4.prefix',
        '@down.headings.5.prefix',
        '@down.headings.6.prefix',
      },
      nodes = {
        -- "heading1_prefix",
        -- "heading2_prefix",
        -- "heading3_prefix",
        -- "heading4_prefix",
        -- "heading5_prefix",
        -- "heading6_prefix",
        concealed = {
          --   "link_target_heading1",
          --   "link_target_heading2",
          --   "link_target_heading3",
          --   "link_target_heading4",
          --   "link_target_heading5",
          --   "link_target_heading6",
        },
      },
      render = M.icon_renderers.multilevel_on_right(false),
    },
    definition = {
      single = {
        icon = '≡',
        nodes = {
          'single_definition_prefix',
          concealed = { 'link_target_definition' },
        },
        render = M.icon_renderers.handle_left,
      },
      multi_prefix = {
        icon = '⋙ ',
        nodes = { 'multi_definition_prefix' },
        render = M.icon_renderers.handle_left,
      },
      multi_suffix = {
        icon = '⋘ ',
        nodes = { 'multi_definition_suffix' },
        render = M.icon_renderers.handle_left,
      },
    },

    footnote = {
      single = {
        icon = '⁎',
        -- When set to true, footnote link with numeric title will be
        -- concealed to superscripts.
        numeric_superscript = true,
        title_highlight = '@down.footnotes.title',
        nodes = {
          'single_footnote_prefix',
          concealed = { 'link_target_footnote' },
        },
        render = M.icon_renderers.handle_left,
        render_concealed = M.icon_renderers.footnote_concealed,
      },
      multi_prefix = {
        icon = '⁑ ',
        nodes = { 'multi_footnote_prefix' },
        render = M.icon_renderers.handle_left,
      },
      multi_suffix = {
        icon = '⁑ ',
        nodes = { 'multi_footnote_suffix' },
        render = M.icon_renderers.handle_left,
      },
    },

    delimiter = {
      weak = {
        icon = '⟨',
        highlight = '@down.delimiters.weak',
        nodes = { 'weak_paragraph_delimiter' },
        render = M.icon_renderers.fill_text,
      },
      strong = {
        icon = '⟪',
        highlight = '@down.delimiters.strong',
        nodes = { 'strong_paragraph_delimiter' },
        render = M.icon_renderers.fill_text,
      },
      horizontal_line = {
        icon = '─',
        highlight = '@down.delimiters.horizontal_line',
        nodes = { 'horizontal_line' },
        -- The starting position of horizontal lines:
        -- - "window": the horizontal line starts from the first column, reaching the left of the window
        -- - "here": the horizontal line starts from the node column
        left = 'here',
        -- The ending position of horizontal lines:
        -- - "window": the horizontal line ends at the last column, reaching the right of the window
        -- - "textwidth": the horizontal line ends at column `textwidth` or 79 when it's set to zero
        right = 'window',
        render = M.icon_renderers.render_horizontal_line,
      },
    },

    markup = {
      spoiler = {
        icon = '•',
        highlight = '@down.markup.spoiler',
        nodes = { 'spoiler' },
        render = M.icon_renderers.fill_multiline_chop2,
      },
    },

    -- Options that control the behaviour of code block dimming
    -- (placing a darker background behind `@code` tags).
    code_block = {
      -- If true will only dim the content of the code block (without the
      -- `@code` and `@end` lines), not the entirety of the code block itself.
      content_only = true,

      -- The width to use for code block backgrounds.
      --
      -- When set to `fullwidth` (the default), will create a background
      -- that spans the width of the buffer.
      --
      -- When set to `content`, will only span as far as the longest line
      -- within the code block.
      width = 'fullwidth',

      -- When set to a number, the code block background will be at least
      -- this many chars wide. Useful in conjunction with `width = "content"`
      min_width = nil,

      -- Additional padding to apply to either the left or the right. Making
      -- these values negative is considered undefined behaviour (it is
      -- likely to work, but it's not officially supported).
      padding = {
        left = 0,
        right = 0,
      },

      -- If `true` will conceal (hide) the `@code` and `@end` portion of the code
      -- block.
      conceal = false,

      -- If `false` will disable spell check on code blocks when 'spell' option is switched on.
      spell_check = true,

      nodes = { 'ranged_verbatim_tag' },
      highlight = '@down.tags.ranged_verbatim.code_block',
      render = M.icon_renderers.render_code_block,
      insert_enabled = true,
    },
  },
}

local function pos_eq(pos1, pos2)
  return (pos1.x == pos2.x) and (pos1.y == pos2.y)
end

local function pos_le(pos1, pos2)
  return pos1.x < pos2.x or (pos1.x == pos2.x and pos1.y <= pos2.y)
end

-- local function pos_lt(pos1, pos2)
--     return pos1.x < pos2.x or (pos1.x == pos2.x and pos1.y < pos2.y)
-- end

local function remove_extmarks(bufid, pos_start_0b_0b, pos_end_0bin_0bex)
  assert(pos_le(pos_start_0b_0b, pos_end_0bin_0bex))
  if pos_eq(pos_start_0b_0b, pos_end_0bin_0bex) then
    return
  end

  local ns_icon = M.ns_icon
  for _, result in
  ipairs(vim.api.nvim_buf_get_extmarks(bufid, ns_icon, { pos_start_0b_0b.x, pos_start_0b_0b.y }, {
    pos_end_0bin_0bex.x - ((pos_end_0bin_0bex.y == 0) and 1 or 0),
    pos_end_0bin_0bex.y - 1,
  }, {}))
  do
    local extmark_id = result[1]
    -- TODO: Optimize
    -- local node_pos_0b_0b = { x = result[2], y = result[3] }
    -- assert(
    --     pos_le(pos_start_0b_0b, node_pos_0b_0b) and pos_le(node_pos_0b_0b, pos_end_0bin_0bex),
    --     ("start=%s, end=%s, node=%s"):format(
    --         vim.inspect(pos_start_0b_0b),
    --         vim.inspect(pos_end_0bin_0bex),
    --         vim.inspect(node_pos_0b_0b)
    --     )
    -- )
    vim.api.nvim_buf_del_extmark(bufid, ns_icon, extmark_id)
  end
end

local function is_inside_example(_)
  -- TODO: waiting for parser fix
  return false
end

local function should_skip_prettify(mode, current_row_0b, node, config, row_start_0b, row_end_0bex)
  local result
  if config.insert_enabled then
    result = false
  elseif (mode == 'i') and u.in_range(current_row_0b, row_start_0b, row_end_0bex) then
    result = true
  elseif is_inside_example(node) then
    result = true
  else
    result = false
  end
  return result
end

local function query_get_nodes(query, document_root, bufid, row_start_0b, row_end_0bex)
  local result = {}
  local concealed_node_ids = {}
  for id, node in query:iter_captures(document_root, bufid, row_start_0b, row_end_0bex) do
    if node:missing() then
      goto continue
    end
    if query.captures[id] == 'icon-concealed' then
      concealed_node_ids[node:id()] = true
    end
    table.insert(result, node)
    ::continue::
  end
  return result, concealed_node_ids
end

local function check_min(xy, x_new, y_new)
  if (x_new < xy.x) or (x_new == xy.x and y_new < xy.y) then
    xy.x = x_new
    xy.y = y_new
  end
end

local function check_max(xy, x_new, y_new)
  if (x_new > xy.x) or (x_new == xy.x and y_new > xy.y) then
    xy.x = x_new
    xy.y = y_new
  end
end

local function add_prettify_flag_line(bufid, row)
  local ns_prettify_flag = M.ns_prettify_flag
  vim.api.nvim_buf_set_extmark(bufid, ns_prettify_flag, row, 0, {})
end

local function add_prettify_flag_range(bufid, row_start_0b, row_end_0bex)
  for row = row_start_0b, row_end_0bex - 1 do
    add_prettify_flag_line(bufid, row)
  end
end

local function remove_prettify_flag_on_line(bufid, row_0b)
  -- TODO: optimize
  local ns_prettify_flag = M.ns_prettify_flag
  vim.api.nvim_buf_clear_namespace(bufid, ns_prettify_flag, row_0b, row_0b + 1)
end

local function remove_prettify_flag_range(bufid, row_start_0b, row_end_0bex)
  -- TODO: optimize
  local ns_prettify_flag = M.ns_prettify_flag
  vim.api.nvim_buf_clear_namespace(bufid, ns_prettify_flag, row_start_0b, row_end_0bex)
end

local function remove_prettify_flag_all(bufid)
  remove_prettify_flag_range(bufid, 0, -1)
end

local function get_visible_line_range(winid)
  local row_start_1b = vim.fn.line('w0', winid)
  local row_end_1b = vim.fn.line('w$', winid)
  return (row_start_1b - 1), row_end_1b
end

local function get_parsed_query_lazy()
  if M.prettify_query then
    return M.prettify_query
  end

  local keys = { 'config', 'icons' }
  local function traverse_config(config, f)
    if config == false then
      return
    end
    if config.nodes then
      f(config)
      return
    end
    if type(config) ~= 'table' then
      log.warn(('unsupported icon config: %s = %s'):format(table.concat(keys, '.'), config))
      return
    end
    local key_pos = #keys + 1
    for key, sub_config in pairs(config) do
      keys[key_pos] = key
      traverse_config(sub_config, f)
      keys[key_pos] = nil
    end
  end

  local config_by_node_name = {}
  local queries = { '[' }

  traverse_config(M.config.icons, function(config)
    for _, node_type in ipairs(config.nodes) do
      table.insert(queries, ('(%s)@icon'):format(node_type))
      config_by_node_name[node_type] = config
    end
    for _, node_type in ipairs(config.nodes.concealed or {}) do
      table.insert(queries, ('(%s)@icon-concealed'):format(node_type))
      config_by_node_name[node_type] = config
    end
  end)

  table.insert(queries, ']')
  local query_combined = table.concat(queries, ' ')
  M.prettify_query = utils.ts_parse_query('markdown', query_combined)
  assert(M.prettify_query)
  M.config_by_node_name = config_by_node_name
  return M.prettify_query
end

local function prettify_range(bufid, row_start_0b, row_end_0bex)
  -- in case there's undo/removal garbage
  -- TODO: optimize
  row_end_0bex = math.min(row_end_0bex + 1, vim.api.nvim_buf_line_count(bufid))

  local tsm = M.dep['tool.treesitter']
  local document_root = tsm.get_document_root(bufid)
  assert(document_root)

  local nodes, concealed_node_ids =
      query_get_nodes(get_parsed_query_lazy(), document_root, bufid, row_start_0b, row_end_0bex)

  local winid = vim.fn.bufwinid(bufid)
  assert(winid > 0)
  local current_row_0b = vim.api.nvim_win_get_cursor(winid)[1] - 1
  local current_mode = vim.api.nvim_get_mode().mode
  local conceallevel = vim.wo[winid].conceallevel
  local concealcursor = vim.wo[winid].concealcursor

  assert(document_root)

  for _, node in ipairs(nodes) do
    local node_row_start_0b, node_col_start_0b, node_row_end_0bin, node_col_end_0bex = node:range()
    local node_row_end_0bex = node_row_end_0bin + 1
    local config = M.config_by_node_name[node:type()]

    if config.clear then
      config:clear(bufid, node)
    else
      local pos_start_0b_0b, pos_end_0bin_0bex =
          { x = node_row_start_0b, y = node_col_start_0b },
          { x = node_row_end_0bin, y = node_col_end_0bex }

      check_min(pos_start_0b_0b, node:start())
      check_max(pos_end_0bin_0bex, node:end_())

      remove_extmarks(bufid, pos_start_0b_0b, pos_end_0bin_0bex)
    end

    remove_prettify_flag_range(bufid, node_row_start_0b, node_row_end_0bex)
    add_prettify_flag_range(bufid, node_row_start_0b, node_row_end_0bex)

    if
        should_skip_prettify(
          current_mode,
          current_row_0b,
          node,
          config,
          node_row_start_0b,
          node_row_end_0bex
        )
    then
      goto continue
    end

    local has_conceal = (
      concealed_node_ids[node:id()]
      and (not config.check_conceal or config.check_conceal(node))
      and u.is_concealing_on_row_range(
        current_mode,
        conceallevel,
        concealcursor,
        current_row_0b,
        node_row_start_0b,
        node_row_end_0bex
      )
    )

    if has_conceal then
      if config.render_concealed then
        config:render_concealed(bufid, node)
      end
    else
      config:render(bufid, node)
    end

    ::continue::
  end
end

local function render_window_buffer(bufid)
  local ns_prettify_flag = M.ns_prettify_flag
  local winid = vim.fn.bufwinid(bufid)
  local row_start_0b, row_end_0bex = get_visible_line_range(winid)
  local prettify_flags_0b = vim.api.nvim_buf_get_extmarks(
    bufid,
    ns_prettify_flag,
    { row_start_0b, 0 },
    { row_end_0bex - 1, -1 },
    {}
  )
  local row_nomark_start_0b, row_nomark_end_0bin
  local i_flag = 1
  for i = row_start_0b, row_end_0bex - 1 do
    while i_flag <= #prettify_flags_0b and i > prettify_flags_0b[i_flag][2] do
      i_flag = i_flag + 1
    end

    if i_flag <= #prettify_flags_0b and i == prettify_flags_0b[i_flag][2] then
      i_flag = i_flag + 1
    else
      assert(i < (prettify_flags_0b[i_flag] and prettify_flags_0b[i_flag][2] or row_end_0bex))
      row_nomark_start_0b = row_nomark_start_0b or i
      row_nomark_end_0bin = i
    end
  end

  assert((row_nomark_start_0b == nil) == (row_nomark_end_0bin == nil))
  if row_nomark_start_0b then
    prettify_range(bufid, row_nomark_start_0b, row_nomark_end_0bin + 1)
  end
end

local function render_all_scheduled_and_done()
  for bufid, _ in pairs(M.rerendering_scheduled_bufids) do
    if vim.fn.bufwinid(bufid) >= 0 then
      render_window_buffer(bufid)
    end
  end
  M.rerendering_scheduled_bufids = {}
end

local function schedule_rendering(bufid)
  local not_scheduled = vim.tbl_isempty(M.rerendering_scheduled_bufids)
  M.rerendering_scheduled_bufids[bufid] = true
  if not_scheduled then
    vim.schedule(render_all_scheduled_and_done)
  end
end

local function mark_line_changed(bufid, row_0b)
  remove_prettify_flag_on_line(bufid, row_0b)
  schedule_rendering(bufid)
end

local function mark_line_range_changed(bufid, row_start_0b, row_end_0bex)
  remove_prettify_flag_range(bufid, row_start_0b, row_end_0bex)
  schedule_rendering(bufid)
end

local function mark_all_lines_changed(bufid)
  if not M.enabled then
    return
  end

  remove_prettify_flag_all(bufid)
  schedule_rendering(bufid)
end

local function clear_all_extmarks(bufid)
  local ns_icon = M.ns_icon
  local ns_prettify_flag = M.ns_prettify_flag
  vim.api.nvim_buf_clear_namespace(bufid, ns_icon, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufid, ns_prettify_flag, 0, -1)
end

local function get_table_default_empty(tbl, key)
  if not tbl[key] then
    tbl[key] = {}
  end
  return tbl[key]
end

local function update_cursor(event)
  local cursor_record = get_table_default_empty(M.cursor_record, event.buffer)
  cursor_record.row_0b = event.cursor_position[1] - 1
  cursor_record.col_0b = event.cursor_position[2]
  cursor_record.line_content = event.line_content
end

local function handle_mod_event(event)
  assert(vim.api.nvim_win_is_valid(event.window))
  update_cursor(event)

  local function on_line_callback(
      tag,
      bufid,
      _changedtick, ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
      row_start_0b,
      _row_end_0bex, ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
      row_updated_0bex,
      _n_byte_prev ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
  )
    assert(tag == 'lines')

    if not M.enabled then
      return
    end

    mark_line_range_changed(bufid, row_start_0b, row_updated_0bex)
  end

  local attach_succeeded =
      vim.api.nvim_buf_attach(event.buffer, true, { on_lines = on_line_callback })
  assert(attach_succeeded)
  local language_tree = vim.treesitter.get_parser(event.buffer, 'markdown')

  local bufid = event.buffer
  -- used for detecting non-local (multiline) changes, like spoiler / code block
  -- TODO: exemption in certain cases, for example when changing only heading followed by pure texts,
  -- in which case all its descendents would be unnecessarily re-concealed.
  local function on_changedtree_callback(ranges)
    -- TODO: abandon if too large
    for i = 1, #ranges do
      local range = ranges[i]
      local row_start_0b = range[1]
      local row_end_0bex = range[3] + 1
      remove_prettify_flag_range(bufid, row_start_0b, row_end_0bex)
    end
  end

  language_tree:register_cbs({ on_changedtree = on_changedtree_callback })
  mark_all_lines_changed(event.buffer)

  if
      M.config.folds
      and vim.api.nvim_win_is_valid(event.window)
      and vim.api.nvim_buf_is_valid(event.buffer)
  then
    vim.api.nvim_buf_call(event.buffer, function()
      -- NOTE(vhyrro): `vim.wo` only supports `wo[winid][0]`,
      -- hence the `buf_call` here.
      local wo = vim.wo[event.window][0]
      wo.foldmethod = 'expr'
      wo.foldexpr = vim.treesitter.foldexpr and 'v:lua.vim.treesitter.foldexpr()'
          or 'nvim_treesitter#foldexpr()'
      wo.foldtext = ''

      local mod_open_folds = M.config.mod_open_folds
      local function open_folds()
        vim.cmd('normal! zR')
      end

      if mod_open_folds == 'always' then
        open_folds()
      elseif mod_open_folds == 'never' then -- luacheck:ignore 542
        -- do nothing
      else
        if mod_open_folds ~= 'auto' then
          log.warn('"mod_open_folds" must be "auto", "always", or "never"')
        end

        if wo.foldlevel == 0 then
          open_folds()
        end
      end
    end)
  end
end

local function handle_insert_toggle(event)
  mark_line_changed(event.buffer, event.cursor_position[1] - 1)
end

local function handle_insertenter(event)
  handle_insert_toggle(event)
end

local function handle_insertleave(event)
  handle_insert_toggle(event)
end

local function handle_toggle_prettifier(event)
  -- FIXME: M.enabled should be a map from bufid to boolean
  M.enabled = not M.enabled
  if M.enabled then
    mark_all_lines_changed(event.buffer)
  else
    M.rerendering_scheduled_bufids[event.buffer] = nil
    clear_all_extmarks(event.buffer)
  end
end

local function is_same_line_movement(event)
  -- some operations like dd / u cannot yet be listened reliably
  -- below is our best approximation
  local cursor_record = M.cursor_record
  return (
    cursor_record
    and cursor_record.row_0b == event.cursor_position[1] - 1
    and cursor_record.col_0b ~= event.cursor_position[2]
    and cursor_record.line_content == event.line_content
  )
end

local function handle_cursor_moved(event)
  if not is_same_line_movement(event) then
    local cursor_record = M.cursor_record[event.buffer]
    if cursor_record then
      mark_line_changed(event.buffer, cursor_record.row_0b)
    end
    local current_row_0b = event.cursor_position[1] - 1
    mark_line_changed(event.buffer, current_row_0b)
  end
  update_cursor(event)
end

local function handle_cursor_moved_i(event)
  return handle_cursor_moved(event)
end

local function handle_winscrolled(event)
  schedule_rendering(event.buffer)
end

local function handle_filetype(event)
  handle_mod_event(event)
end

local event_handlers = {
  ['cmd.events.icon.toggle'] = handle_toggle_prettifier,
}

M.handle = function(event)
  if not M.enabled and (event.id ~= 'cmd.events.icon.toggle') then
    return
  end
  return event_handlers[event.id](event)
end

M.load = function()
  local icon = M.import[M.id .. '.' .. M.config.icon].config['icon_' .. M.config.icon]
  if not icon then
    log.error(
      ("Unable to load icon preset '%s' - such a preset does not exist"):format(M.config.icon)
    )
    return
  end

  M.config = vim.tbl_deep_extend('force', M.config, { icons = icon }, M.config.custom or {})

  -- M.dep["core.autocommands"].enable_autocommand("BufNewFile")

  M.commands = {
    toggle = {
      enabled = false,
      name = 'icon.toggle',
      args = 0,
      condition = 'markdown',
    },
  }

  vim.api.nvim_create_autocmd('OptionSet', {
    pattern = 'conceallevel',
    callback = function()
      local bufid = vim.api.nvim_get_current_buf()
      if vim.bo[bufid].ft ~= 'markdown' then
        return
      end
      mark_all_lines_changed(bufid)
    end,
  })
end

M.subscribed = {
  cmd = {
    ['icon.toggle'] = true,
  },
}

return M
