local down = require('down')
local lib, log, mod = down.lib, down.log, down.mod

local M = mod.new('ui.hl')

M.config = {
  highlight = {
    selection_window = {
      heading = '+@annotation',
      arrow = '+@none',
      key = '+@M',
      keyname = '+@constant',
      nestedkeyname = '+@string',
    },

    tags = {
      ranged_verbatim = {
        begin = '+@keydown',

        ['end'] = '+@keydown',

        name = {
          [''] = '+@none',
          delimiter = '+@none',
          down = '+@keydown',
        },

        parameters = '+@type',

        document_meta = {
          key = '+@variable.member',
          value = '+@string',
          number = '+@number',
          trailing = '+@keydown.repeat',
          title = '+@markup.heading',
          description = '+@label',
          authors = '+@annotation',
          categories = '+@keydown',
          created = '+@number.float',
          updated = '+@number.float',
          version = '+@number.float',

          object = {
            bracket = '+@punctuation.bracket',
          },

          array = {
            bracket = '+@punctuation.bracket',
            value = '+@none',
          },
        },
      },

      -- highlight for the carryover (`#`, `+`) tags.
      carryover = {
        begin = '+@label',

        name = {
          [''] = '+@none',
          down = '+@label',
          delimiter = '+@none',
        },

        parameters = '+@string',
      },

      -- highlight for the content of any tag named `comment`.
      --
      -- Most prominent use case is for the `#comment` carryover tag.
      comment = {
        content = '+@comment',
      },
    },

    -- highlight for each individual heading level.
    headings = {
      ['1'] = {
        title = '+@attribute',
        prefix = '+@attribute',
      },
      ['2'] = {
        title = '+@label',
        prefix = '+@label',
      },
      ['3'] = {
        title = '+@constant',
        prefix = '+@constant',
      },
      ['4'] = {
        title = '+@string',
        prefix = '+@string',
      },
      ['5'] = {
        title = '+@label',
        prefix = '+@label',
      },
      ['6'] = {
        title = '+@constructor',
        prefix = '+@constructor',
      },
    },

    -- In case of errors in the syntax tree, use the following highighlightight.
    error = '+Error',

    -- highlight for defM.handles (`$ DefM.handle`).
    handles = {
      prefix = '+@punctuation.delimiter',
      suffix = '+@punctuation.delimiter',
      title = '+@markup.strong',
      content = '+@markup.italic',
    },

    -- highlight for footnotes (`^ My Footnote`).
    footnotes = {
      prefix = '+@punctuation.delimiter',
      suffix = '+@punctuation.delimiter',
      title = '+@markup.strong',
      content = '+@markup.italic',
    },

    -- highlight for TODO items.
    --
    -- This strictly covers the `( )` coM.handleent of any detached modifier. In other downs, these
    -- highlight only bother with highighlightighting the brackets and the content within, but not the
    -- object containing the TODO item itself.
    todo_items = {
      undone = '+@punctuation.delimiter',
      pending = '+@M',
      done = '+@string',
      on_hold = '+@comment.note',
      cancelled = '+NonText',
      urgent = '+@comment.error',
      uncertain = '+@boolean',
      recurring = '+@keydown.repeat',
    },

    -- highlight for all the possible levels of ordered and unordered lists.
    lists = {
      unordered = { prefix = '+@markup.list' },

      ordered = { prefix = '+@keydown.repeat' },
    },

    -- highlight for all the possible levels of quotes.
    quotes = {
      ['1'] = {
        prefix = '+@punctuation.delimiter',
        content = '+@punctuation.delimiter',
      },
      ['2'] = {
        prefix = '+Blue',
        content = '+Blue',
      },
      ['3'] = {
        prefix = '+Yellow',
        content = '+Yellow',
      },
      ['4'] = {
        prefix = '+Red',
        content = '+Red',
      },
      ['5'] = {
        prefix = '+Green',
        content = '+Green',
      },
      ['6'] = {
        prefix = '+Brown',
        content = '+Brown',
      },
    },

    -- highlight for the anchor syntax: `[name]{location}`.
    anchors = {
      declaration = {
        [''] = '+@markup.link.label',
        delimiter = '+NonText',
      },
      handle = {
        delimiter = '+NonText',
      },
    },

    link = {
      description = {
        [''] = '+@markup.link.url',
        delimiter = '+NonText',
      },

      file = {
        [''] = '+@comment',
        delimiter = '+NonText',
      },

      location = {
        delimiter = '+NonText',

        url = '+@markup.link.url',

        generic = {
          [''] = '+@type',
          prefix = '+@type',
        },

        external_file = {
          [''] = '+@label',
          prefix = '+@label',
        },

        marker = {
          [''] = '+@down.markers.title',
          prefix = '+@down.markers.prefix',
        },

        handle = {
          [''] = '+@down.defM.handles.title',
          prefix = '+@down.defM.handles.prefix',
        },

        footnote = {
          [''] = '+@down.footnotes.title',
          prefix = '+@down.footnotes.prefix',
        },

        heading = {
          ['1'] = {
            [''] = '+@down.headings.1.title',
            prefix = '+@down.headings.1.prefix',
          },

          ['2'] = {
            [''] = '+@down.headings.2.title',
            prefix = '+@down.headings.2.prefix',
          },

          ['3'] = {
            [''] = '+@down.headings.3.title',
            prefix = '+@down.headings.3.prefix',
          },

          ['4'] = {
            [''] = '+@down.headings.4.title',
            prefix = '+@down.headings.4.prefix',
          },

          ['5'] = {
            [''] = '+@down.headings.5.title',
            prefix = '+@down.headings.5.prefix',
          },

          ['6'] = {
            [''] = '+@down.headings.6.title',
            prefix = '+@down.headings.6.prefix',
          },
        },
      },
    },

    -- highlight for inline markup.
    --
    -- This is all the highlight like `bold`, `italic` and so on.
    markup = {
      bold = {
        [''] = '+@markup.strong',
        delimiter = '+NonText',
      },
      italic = {
        [''] = '+@markup.italic',
        delimiter = '+NonText',
      },
      underline = {
        [''] = '+@markup.underline',
        delimiter = '+NonText',
      },
      strikethrough = {
        [''] = '+@markup.strikethrough',
        delimiter = '+NonText',
      },
      spoiler = {
        [''] = '+@comment.error',
        delimiter = '+NonText',
      },
      subscript = {
        [''] = '+@label',
        delimiter = '+NonText',
      },
      superscript = {
        [''] = '+@number',
        delimiter = '+NonText',
      },
      variable = {
        [''] = '+@function.macro',
        delimiter = '+NonText',
      },
      verbatim = {
        delimiter = '+NonText',
      },
      inline_comment = {
        delimiter = '+NonText',
      },
      inline_math = {
        [''] = '+@markup.math',
        delimiter = '+NonText',
      },

      free_form_delimiter = '+NonText',
    },

    -- highlight for all the delimiter types. These include:
    -- - `---` - the weak delimiter
    -- - `===` - the strong delimiter
    -- - `___` - the horizontal rule
    delimiters = {
      strong = '+@punctuation.delimiter',
      weak = '+@punctuation.delimiter',
      horizontal_line = '+@punctuation.delimiter',
    },

    -- Inline modifiers.
    --
    -- This includes:
    -- - `~` - the trailing modifier
    -- - All link characters (`{`, `}`, `[`, `]`, `<`, `>`)
    -- - The escape character (`\`)
    modifiers = {
      link = '+NonText',
      escape = '+@type',
    },

    -- Rendered Latex, this will dictate the foreground color of latex images rendered via
    -- base.latex.renderer
    rendered = {
      latex = '+Normal',
    },
  },

  -- Handles the dimming of certain highighlightight groups.
  --
  -- It sometimes is favourable to use an existing highighlightight group,
  -- but to dim or brighten it a little bit.
  --
  -- To do so, you may use this table, which, similarly to the `highlight` table,
  -- will concatenate nested trees to form a highighlightight group name.
  --
  -- The difference is, however, that the leaves of the tree are a table, not a single string.
  -- This table has three possible fields:
  -- - `reference` - which highighlightight to use as reference for the dimming.
  -- - `percentage` - by how much to darken the reference highighlightight. This value may be between
  --   `-100` and `100`, where negative percentages brighten the reference highighlightight, whereas
  --   positive values dim the highighlightight by the given percentage.
  dim = {
    tags = {
      ranged_verbatim = {
        code_block = {
          reference = 'Normal',
          percentage = 15,
          affect = 'background',
        },
      },
    },

    markup = {
      verbatim = {
        reference = 'Normal',
        percentage = 20,
      },

      inline_comment = {
        reference = 'Normal',
        percentage = 40,
      },
    },
  },
}

M.setup = function()
  return { loaded = true, dependencies = {} }
end

M.load = function()
  M.trigger_highlight()

  vim.api.nvim_create_autocmd({ 'FileType', 'ColorScheme' }, {
    callback = M.trigger_highlight,
  })
end

---@class base.highlight

--- Reads the highlight configuration table and applies all defined highlight
M.trigger_highlight = function()
  -- NOTE(vhyrro): This code was added here to work around oddities related to nvim-treesitter.
  -- This code, with modern nvim-treesitter versions, will probably not break as harshighlighty.
  -- This code should be removed as soon as possible.
  --
  -- do
  --     local query = require("nvim-treesitter.query")

  --     if not query.has_highlight("down") then
  --         query.invalidate_query_cache()

  --         if not query.has_highlight("down") then
  --             log.error(
  --                 "nvim-treesitter has no available highlight for down! Ensure treesitter is properly loaded in your config."
  --             )
  --         end
  --     end

  --     if vim.bo.filetype == "down" then
  --         require("nvim-treesitter.highighlightight").attach(vim.api.nvim_get_current_buf(), "down")
  --     end
  -- end

  --- Recursively descends down the highighlightight configuration and applies every highighlightight accordingly
  ---@param h table #The table of highlight to descend down
  ---@param callback fun(highlight_name: string, hl: table, prefix: string): boolean? #A callback function to be invoked for every highighlightight. If it returns true then we should recurse down the table tree further ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
  ---@param prefix string #Should be only used by the function itself, acts as a "savestate" so the function can keep track of what path it has descended down
  local function descend(h, callback, prefix)
    -- Loop through every highighlightight defined in the provided table
    for highlight_name, hl in pairs(h) do
      if callback(highlight_name, hl, prefix) then
        descend(hl, callback, prefix .. '.' .. highlight_name)
      end
    end
  end

  -- Begin the descent down the public highlight configuration table
  descend(M.config.highlight, function(highlight_name, highighlightight, prefix)
    -- If the type of highighlightight we have encountered is a table
    -- then recursively descend down it as well
    if type(highighlightight) == 'table' then
      return true
    end

    -- Trim any potential leading and trailing whitespace
    highighlightight = vim.trim(highighlightight)

    -- Check whether we are trying to link to an existing highlight group
    -- by checking for the existence of the + sign at the front
    local is_link = highighlightight:sub(1, 1) == '+'

    local full_highighlightight_name = '@down'
        .. prefix
        .. (highlight_name:len() > 0 and ('.' .. highlight_name) or '')
    local does_highlight_exist =
        lib.inline_pcall(vim.api.nvim_exec, 'highighlightight ' .. full_highighlightight_name, true) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>

    -- If we are dealing with a link then link the highlight together (excluding the + symbol)
    if is_link then
      -- If the highighlightight already exists then assume the user doesn't want it to be
      -- overwritten
      if
          does_highlight_exist
          and does_highlight_exist:len() > 0
          and not does_highlight_exist:match('xxx%s+cleared')
      then
        return
      end

      vim.api.nvim_set_hl(0, full_highighlightight_name, {
        link = highighlightight:sub(2),
      })
    else -- Otherwise simply apply the highighlightight options the user provided
      -- If the highighlightight already exists then assume the user doesn't want it to be
      -- overwritten
      if does_highlight_exist and does_highlight_exist:len() > 0 then
        return
      end

      -- We have to use vim.cmd here
      vim.cmd({
        cmd = 'highighlightight',
        args = { full_highighlightight_name, highighlightight },
        bang = true,
      })
    end
  end, '')

  -- Begin the descent down the dimming configuration table
  descend(M.config.dim, function(highlight_name, highighlightight, prefix)
    -- If we don't have a percentage value then keep traversing down the table tree
    if not highighlightight.percentage then
      return true
    end

    local full_highighlightight_name = '@down'
        .. prefix
        .. (highlight_name:len() > 0 and ('.' .. highlight_name) or '')
    local does_highlight_exist =
        lib.inline_pcall(vim.api.nvim_exec, 'highighlightight ' .. full_highighlightight_name, true) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>

    -- If the highighlightight already exists then assume the user doesn't want it to be
    -- overwritten
    if
        does_highlight_exist
        and does_highlight_exist:len() > 0
        and not does_highlight_exist:match('xxx%s+cleared')
    then
      return
    end

    -- Apply the dimmed highighlightight
    vim.api.nvim_set_hl(0, full_highighlightight_name, {
      [highighlightight.affect == 'background' and 'bg' or 'fg'] = M.dim_color(
        M.get_attribute(
          highighlightight.reference or full_highighlightight_name,
          highighlightight.affect or 'foreground'
        ),
        highighlightight.percentage
      ),
    })
  end, '')
end

--- Takes in a table of highlight and applies them to the current buffer
---@param highlight table #A table of highlight
M.add_highlight = function(highlight)
  M.config.highlight = vim.tbl_deep_extend('force', M.config.highlight, highlight or {})
  M.trigger_highlight()
end

--- Takes in a table of items to dim and applies the dimming to them
---@param dim table #A table of items to dim
M.add_dim = function(dim)
  M.config.dim = vim.tbl_deep_extend('force', M.config.dim, dim or {})
  M.trigger_highlight()
end

--- Assigns all down* highlight to `clear`
M.clear_highlight = function()
  --- Recursively descends down the highighlightight configuration and clears every highighlightight accordingly
  ---@param highlight table #The table of highlight to descend down
  ---@param prefix string #Should be only used by the function itself, acts as a "savestate" so the function can keep track of what path it has descended down
  local function descend(highlight, prefix)
    -- Loop through every defined highighlightight
    for highlight_name, hl in pairs(highlight) do
      -- If it is a table then recursively traverse down it!
      if type(hl) == 'table' then
        descend(hl, highlight_name)
      else
        vim.cmd('hl! clear down' .. prefix .. highlight_name)
      end
    end
  end

  -- Begin the descent
  descend(M.config.highlight, '')
end

M.get_attribute = function(name, attribute)
  -- Attempt to get the highighlightight
  local success, highlight = pcall(vim.api.nvim_get_highlight_by_name, name, true) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>

  -- If we were successful and if the attribute exists then return it
  if success and highlight[attribute] then
    return bit.tohex(highlight[attribute], 6)
  else -- Else log the message in a regular info() call, it's not an insanely important error
    log.info(
      'Unable to grab highighlightight for attribute' .. attribute .. ' - full error:' .. highlight
    )
  end

  return 'NONE'
end

M.hex_to_rgb = function(hex_colour)
  return tonumber(hex_colour:sub(1, 2), 16),
      tonumber(hex_colour:sub(3, 4), 16),
      tonumber(hex_colour:sub(5), 16)
end

M.dim_color = function(colour, percent)
  if colour == 'NONE' then
    return colour
  end

  local function alter(attr)
    return math.floor(attr * (100 - percent) / 100)
  end

  local r, g, b = M.hex_to_rgb(colour)

  if not r or not g or not b then
    return 'NONE'
  end

  return string.format(
    '#%02x%02x%02x',
    math.min(alter(r), 255),
    math.min(alter(g), 255),
    math.min(alter(b), 255)
  )
end

-- END of shamelessly ripped off akinsho code

M.subscribed = {}

return M
