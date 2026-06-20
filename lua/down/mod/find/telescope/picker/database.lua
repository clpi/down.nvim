local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")

local function load_databases()
  local mod = require("down.mod")
  local db_mod = mod.get_mod("data.database")
  if not db_mod or not db_mod.scan_workspace then
    return {}
  end
  local ws = mod.get_mod("workspace")
  local root = ws and ws.get(ws.current()) or vim.loop.cwd()
  local items = db_mod.scan_workspace(root)
  return items or {}
end

local function open_database(path, cmd)
  if not path or path == "" then
    return
  end
  vim.cmd(cmd .. " " .. vim.fn.fnameescape(path))
end

return function(opts)
  opts = opts or {}
  local items = load_databases()
  if #items == 0 then
    vim.notify("[down.nvim] No databases found in workspace", vim.log.levels.INFO)
    return
  end

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 28 },
      { width = 8 },
      { remaining = true },
    },
  })

  local make_display = function(entry)
    return displayer({
      { entry.title, "TelescopeResultsIdentifier" },
      { tostring(entry.rows) .. " rows", "TelescopeResultsNumber" },
      { entry.rel or entry.path, "TelescopeResultsComment" },
    })
  end

  pickers.new(opts, {
    prompt_title = opts.prompt or "Databases",
    finder = finders.new_table({
      results = items,
      entry_maker = function(entry)
        return {
          value = entry,
          display = make_display,
          ordinal = (entry.title or "") .. " " .. (entry.rel or entry.path or ""),
          path = entry.path,
          title = entry.title,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      local function selected_path()
        local selection = action_state.get_selected_entry()
        return selection and selection.path
      end

      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        open_database(selected_path(), "edit")
      end)

      map("i", "<C-v>", function()
        actions.close(prompt_bufnr)
        open_database(selected_path(), "vsplit")
      end)

      map("i", "<C-s>", function()
        actions.close(prompt_bufnr)
        open_database(selected_path(), "split")
      end)

      map("i", "<C-t>", function()
        actions.close(prompt_bufnr)
        local path = selected_path()
        if not path then
          return
        end
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        vim.schedule(function()
          local db_mod = require("down.mod").get_mod("data.database")
          if db_mod and db_mod.show_view then
            db_mod.show_view("table")
          end
        end)
      end)

      map("i", "<C-b>", function()
        actions.close(prompt_bufnr)
        local path = selected_path()
        if not path then
          return
        end
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        vim.schedule(function()
          local db_mod = require("down.mod").get_mod("data.database")
          if db_mod and db_mod.show_view then
            db_mod.show_view("board")
          end
        end)
      end)

      return true
    end,
  }):find()
end
