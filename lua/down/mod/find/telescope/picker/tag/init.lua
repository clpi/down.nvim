local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local sorters = require("telescope.sorters")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")

local function parse_tags(bufnr)
  local tags = {}
  local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
  local filepath = vim.api.nvim_buf_get_name(bufnr or 0)

  for lnum, line in ipairs(lines) do
    -- Parse tags: #tag or #tag-with-dashes
    for tag in line:gmatch("#([%w%-_]+)") do
      table.insert(tags, {
        tag = "#" .. tag,
        line = lnum,
        col = line:find("#" .. vim.pesc(tag)),
        text = line:match("^%s*(.-)%s*$"), -- trim whitespace
        file = filepath,
      })
    end
  end

  return tags
end

local function parse_workspace_tags()
  local mod = require("down.mod")
  local workspace_mod = mod.get_mod("workspace")

  if not workspace_mod then
    return {}
  end

  local ws_path = workspace_mod.get_current_workspace_path()
  if not ws_path then
    return {}
  end

  -- Find all markdown files in workspace
  local files = vim.fn.globpath(ws_path, "**/*.md", false, true)
  local all_tags = {}
  local tag_index = {} -- Track unique tags with their occurrences

  for _, file in ipairs(files) do
    local bufnr = vim.fn.bufadd(file)
    vim.fn.bufload(bufnr)
    local tags = parse_tags(bufnr)

    for _, tag_info in ipairs(tags) do
      -- Add to all tags list
      table.insert(all_tags, tag_info)

      -- Track unique tags
      if not tag_index[tag_info.tag] then
        tag_index[tag_info.tag] = {
          tag = tag_info.tag,
          count = 0,
          files = {},
        }
      end
      tag_index[tag_info.tag].count = tag_index[tag_info.tag].count + 1
      if not vim.tbl_contains(tag_index[tag_info.tag].files, file) then
        table.insert(tag_index[tag_info.tag].files, file)
      end
    end
  end

  return all_tags, tag_index
end

local function lsp_workspace_tags()
  local ok, down_mod = pcall(require, "down.mod")
  if not ok then
    return nil
  end
  local lsp = down_mod.get_mod("lsp")
  if not lsp or not lsp.get_client or not lsp.get_client() then
    return nil
  end
  local done, symbols = false, nil
  lsp.workspace_symbols("", function(result)
    symbols = vim.tbl_filter(function(sym)
      return sym.kind == lsp.symbol_kinds.tag
    end, result or {})
    done = true
  end)
  vim.wait(3000, function()
    return done
  end)
  return symbols
end

local function tag_picker(opts)
  opts = opts or {}
  opts.scope = opts.scope or "buffer" -- buffer, workspace, or all

  local tags = {}
  local tag_index = nil

  if opts.scope == "buffer" then
    tags = parse_tags(0)
  elseif opts.scope == "workspace" then
    local lsp_tags = lsp_workspace_tags()
    if lsp_tags and #lsp_tags > 0 then
      tags = {}
      tag_index = {}
      for _, sym in ipairs(lsp_tags) do
        local uri = (sym.location.uri or ""):gsub("^file://", "")
        local line = (sym.location.range.start.line or 0) + 1
        local col = (sym.location.range.start.character or 0) + 1
        local tag_name = sym.name
        table.insert(tags, {
          tag = "#" .. tag_name,
          line = line,
          col = col,
          text = tag_name,
          file = uri,
        })
        tag_index[tag_name] = (tag_index[tag_name] or 0) + 1
      end
    else
      tags, tag_index = parse_workspace_tags()
    end
  end

  if #tags == 0 then
    vim.notify("No tags found", vim.log.levels.INFO)
    return
  end

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 20 },
      { width = 10 },
      { remaining = true },
    },
  })

  local make_display = function(entry)
    local filename = vim.fn.fnamemodify(entry.file, ":t")
    return displayer({
      { entry.tag, "TelescopeResultsIdentifier" },
      { entry.line .. ":" .. entry.col, "TelescopeResultsLineNr" },
      { filename .. " - " .. entry.text, "TelescopeResultsComment" },
    })
  end

  pickers
    .new(opts, {
      prompt_title = "Tags (" .. opts.scope .. ")",
      finder = finders.new_table({
        results = tags,
        entry_maker = function(entry)
          return {
            value = entry,
            display = make_display,
            ordinal = entry.tag .. " " .. entry.text,
            tag = entry.tag,
            line = entry.line,
            col = entry.col,
            file = entry.file,
            text = entry.text,
            filename = entry.file,
            lnum = entry.line,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.vim_buffer_vimgrep.new(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            vim.cmd("edit " .. selection.file)
            vim.api.nvim_win_set_cursor(0, { selection.line, selection.col - 1 })
            vim.cmd("normal! zz")
          end
        end)
        return true
      end,
    })
    :find()
end

return tag_picker
