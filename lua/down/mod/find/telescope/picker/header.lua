local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")

--- Parse markdown headers from buffer
---@param bufnr number
---@return table
local function parse_headers(bufnr)
  local headers = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)

  for lnum, line in ipairs(lines) do
    -- Parse markdown headers: # Header
    local level, text = line:match("^(#+)%s+(.+)")
    if level and text then
      table.insert(headers, {
        text = text,
        line = lnum,
        col = 1,
        level = #level,
        indent = string.rep("  ", #level - 1),
        full_line = line,
      })
    end
  end

  return headers
end

--- Header picker for current buffer
---@param opts table
return function(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local headers = parse_headers(bufnr)

  if #headers == 0 then
    vim.notify("No headers found in current buffer", vim.log.levels.INFO)
    return
  end

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 10 },
      { remaining = true },
    },
  })

  local make_display = function(entry)
    return displayer({
      { entry.line .. ":" .. entry.col, "TelescopeResultsLineNr" },
      { entry.indent .. entry.text, "TelescopeResultsIdentifier" },
    })
  end

  pickers
    .new(opts, {
      prompt_title = "Headers",
      finder = finders.new_table({
        results = headers,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = entry.text,
            line = entry.line,
            col = entry.col,
            text = entry.text,
            indent = entry.indent,
            lnum = entry.line,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer({
        define_preview = function(self, entry, status)
          local preview_bufnr = self.state.bufnr
          vim.api.nvim_buf_set_lines(preview_bufnr, 0, -1, false, { entry.value.full_line })
          vim.api.nvim_buf_add_highlight(preview_bufnr, -1, "Search", 0, 0, -1)
        end,
      }),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            vim.api.nvim_win_set_cursor(0, { selection.line, selection.col - 1 })
            vim.cmd("normal! zz")
          end
        end)
        return true
      end,
    })
    :find()
end
