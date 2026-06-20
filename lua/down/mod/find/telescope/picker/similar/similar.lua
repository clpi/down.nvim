local actions = require ("telescope.actions")
local astate = require ("telescope.actions.state")
local finders = require ("telescope.finders")
local pick = require ("telescope.pickers")
local conf = require ("telescope.config").values

--- Find semantically similar files (via down similar CLI)
---@param opts table
return function (opts)
  opts = opts or {}

  local mod = require ("down.mod")
  local ws_mod = mod.get_mod ("workspace")

  if not ws_mod then
    vim.notify ("Workspace module not loaded", vim.log.levels.ERROR)
    return
  end

  local ws_path = ws_mod.get_current_workspace_path ()
  if not ws_path then
    vim.notify ("No active workspace", vim.log.levels.WARN)
    return
  end

  -- Use current file as target
  local current = vim.fn.expand ("%:p")
  if current == "" or not vim.fn.filereadable (current) then
    vim.notify ("No current file to find similar for", vim.log.levels.WARN)
    return
  end

  -- Run down similar and parse output
  local bin = vim.fn.stdpath ("data") .. "/down/bin/down"
  if vim.fn.executable (bin) == 0 then
    bin = "down"
  end
  local cmd = { bin, "similar", current }
  local result = vim.fn.system (cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify ("Similar command failed", vim.log.levels.ERROR)
    return
  end

  local entries = {}
  for line in result:gmatch ("[^\n]+") do
    local score, path = line:match ("%[([%d.]+)%]%s+(.+)")
    if score and path then
      local full = vim.fs.joinpath (ws_path, path)
      table.insert (entries, {
        path = full,
        name = path,
        score = tonumber (score),
        display = string.format ("[%.4f] %s", tonumber (score), path),
      })
    end
  end

  if #entries == 0 then
    vim.notify ("No similar files found", vim.log.levels.INFO)
    return
  end

  pick
    .new (opts, {
      prompt_title = "Similar Files",
      finder = finders.new_table ({
        results = entries,
        entry_maker = function (entry)
          return {
            value = entry,
            display = entry.display,
            ordinal = entry.name,
            path = entry.path,
          }
        end,
      }),
      sorter = conf.generic_sorter (opts),
      attach_mappings = function (prompt_bufnr, _)
        actions.select_default:replace (function ()
          actions.close (prompt_bufnr)
          local selection = astate.get_selected_entry ()
          if selection then
            vim.cmd ("edit " .. selection.path)
          end
        end)
        return true
      end,
    })
    :find ()
end
