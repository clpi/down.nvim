local down = require("down")
local log = require("down.util.log")
local mod = require("down.mod")
local util = require("down.util")
local api, bo, fn = vim.api, vim.bo, vim.fn

---@class down.mod.cmd.Cmd: down.Mod
local M = mod.new("cmd")

M.setup = function()
  return { loaded = true, dependencies = {} }
end

M.get_commands = function(m)
  local c = {}
  if m.commands then
    if type(c) == "table" then
      for cmd, cc in pairs(m.commands) do
        if type(cc) == "table" then
          if c.enabled ~= false then
            c[cmd] = cc
          end
        end
      end
    end
  end
  return c
end

M.commands = {
  cmd = {
    enabled = false,
    name = "cmd",
    args = 0,
    max_args = 1,
    callback = function(e)
      log.trace("Cmd callback")
    end,
    commands = {
      add = {
        enabled = true,
        name = "cmd.add",
        args = 0,
        max_args = 1,
        callback = function(e)
          log.trace("Cmd add callback")
        end,
      },
      edit = {
        name = "cmd.edit",
        args = 0,
        max_args = 1,
        callback = function(e)
          log.trace("Cmd edit callback")
        end,
      },
      remove = {
        name = "cmd.remove",
        args = 0,
        max_args = 1,
        callback = function(e)
          log.trace("Cmd remove callback")
        end,
      },
      update = {
        name = "cmd.update",
        args = 0,
        max_args = 1,
        callback = function(e)
          log.trace("Cmd update callback")
        end,
      },
    },
  },
}
M.cb = function(data)
  local args = data.fargs
  local buf = api.nvim_get_current_buf()
  local is_down = bo[buf].filetype == "markdown"

  local ref = { commands = M.commands }
  local argument_index = 0

  for i, cmd in ipairs(args) do
    if not ref.commands or vim.tbl_isempty(ref.commands) then
      break
    end
    ref = ref.commands[cmd]
    if not ref then
      log.error(
        ("Error when executing `:Down %s` - such a command does not exist!"):format(
          table.concat(vim.list_slice(args, 1, i), " ")
        )
      )
      return
    elseif not M.cond(ref.condition) then
      log.error(
        ("Error when executing `:Down %s` - the command is currently disabled. Some commands will only become available under certain conditions, e.g. being within a `.down` file!"):format(
          table.concat(vim.list_slice(args, 1, i), " ")
        )
      )
      return
    end

    argument_index = i
  end

  local argument_count = (#args - argument_index)

  if ref.args then
    ref.min_args = ref.args
    ref.max_args = ref.args
  elseif ref.min_args and not ref.max_args then
    ref.max_args = math.huge
  else
    ref.min_args = ref.min_args or 0
    ref.max_args = ref.max_args or 0
  end

  if #args == 0 or argument_count < ref.min_args then
    local completions =
      M.generate_completions(_, table.concat({ "Down ", data.args, " " }))
    M.select_next_cmd_arg(data.args, completions)
    return
  elseif argument_count > ref.max_args then
    log.error(
      ("Error when executing `:down %s` - too many arguments supplied! The command expects %s argument%s."):format(
        data.args,
        ref.max_args == 0 and "no" or ref.max_args,
        ref.max_args == 1 and "" or "s"
      )
    )
    return
  end

  if not ref.name then
    log.error(
      ("Error when executing `:down %s` - the ending command didn't have a `name` variable associated with it! This is an implementation error on the developer's side, so file a report to the author of the mod."):format(
        data.args
      )
    )
    return
  end
  if not M.events[ref.name] then
    M.events[ref.name] = mod.define_event(M, ref.name)
    if ref.callback then
      if not M.handle then
        M.handle = {}
      end
      if not M.handle["cmd"] then
        M.handle["cmd"] = {}
      end
      M.handle["cmd"][ref.name] = ref.callback
    end
  end

  local e = mod.new_event(
    M,
    table.concat({ "cmd.events.", ref.name }),
    vim.list_slice(args, argument_index + 1)
  )
  if ref.callback then
    log.trace("Cmd.cb: Running ", ref.name, " callback")
    ref.callback(e)
  else
    log.trace("Cmd.cb: Running ", ref.name, " broadcast")
    -- M.handle['cmd'][ref.name]
    mod.broadcast(e)
  end
end
--
-- --- Handles the calling of the appropriate function based on the command the user entered
-- M.cb = function(data)
--   local args = data.fargs
--   local buf = vim.api.nvim_get_current_buf()
--   local is_down = vim.bo[buf].filetype == "markdown"
--
--   local ref = { commands = M.commands }
--   local argument_index = 0
--
--   for i, cmd in ipairs(args) do
--     if not ref.commands or vim.tbl_isempty(ref.commands) then
--       break
--     end
--     if
--       ref.commands[cmd]
--       and ref.commands[cmd].enabled ~= nil
--       and ref.commands[cmd].enabled == false
--     then
--       break
--     end
--     ref = ref.commands[cmd]
--     if not ref then
--       log.error(
--         ("Error when executing `:Down %s` - such a command does not exist!"):format(
--           table.concat(vim.list_slice(args, 1, i), " ")
--         )
--       )
--       return
--     elseif not M.cond(ref.condition, buf, is_down) then
--       log.error(
--         ("Error when executing `:Down %s` - the command is currently disabled. Some commands will only become available under certain conditions, e.g. being within a `.down` file!"):format(
--           table.concat(vim.list_slice(args, 1, i), " ")
--         )
--       )
--       return
--     end
--
--     argument_index = i
--   end
--
--   local argument_count = (#args - argument_index)
--
--   if ref.args then
--     ref.min_args = ref.args
--     ref.max_args = ref.args
--   elseif ref.min_args and not ref.max_args then
--     ref.max_args = math.huge
--   else
--     ref.min_args = ref.min_args or 0
--     ref.max_args = ref.max_args or 0
--   end
--
--   if #args == 0 or argument_count < ref.min_args then
--     local completions =
--       M.generate_completions(_, table.concat({ "Down ", data.args, " " }))
--     M.select_next_cmd_arg(data.args, completions)
--     return
--   elseif argument_count > ref.max_args then
--     log.error(
--       ("Error when executing `:down %s` - too many arguments supplied! The command expects %s argument%s."):format(
--         data.args,
--         ref.max_args == 0 and "no" or ref.max_args,
--         ref.max_args == 1 and "" or "s"
--       )
--     )
--     return
--   end
--
--   if not ref.name then
--     log.error(
--       ("Error when executing `:down %s` - the ending command didn't have a `name` variable associated with it! This is an implementation error on the developer's side, so file a report to the author of the mod."):format(
--         data.args
--       )
--     )
--     return
--   end
--   if not M.events[ref.name] then
--     M.events[ref.name] = mod.define_event(M, ref.name)
--     if ref.callback then
--       if not M.handle then
--         M.handle = {}
--       end
--       if not M.handle["cmd"] then
--         M.handle["cmd"] = {}
--       end
--       M.handle["cmd"][ref.name] = ref.callback
--     end
--   end
--
--   local e = mod.new_event(
--     M,
--     table.concat({ "cmd.events.", ref.name }),
--     vim.list_slice(args, argument_index + 1)
--   )
--   if ref.callback then
--     log.trace("Cmd.cb: Running ", ref.name, " callback")
--     ref.callback(e)
--   else
--     log.trace("Cmd.cb: Running ", ref.name, " broadcast")
--     mod.broadcast(e)
--   end
-- end
--
M.cond = function(condition, buf, is_down)
  buf = buf or vim.api.nvim_get_current_buf()
  is_down = is_down or vim.bo[buf].filetype == "markdown"
  if condition == nil then
    return true
  end
  if condition == "markdown" and not is_down then
    return false
  end
  if type(condition) == "function" then
    return condition(buf, is_down)
  end
  return condition
end

--- This function returns all available commands to be used for the :down command
---@param _ nil #Placeholder variable
---@param command string #Supplied by nvim itself; the full typed out command
M.generate_completions = function(_, command)
  local current_buf = vim.api.nvim_get_current_buf()
  local is_down = vim.bo[current_buf].filetype == "markdown"

  command = command:gsub("^%s*", "")

  local splitcmd = vim.list_slice(
    vim.split(command, " ", {
      plain = true,
      trimempty = true,
    }),
    2
  )

  local ref = {
    commands = M.commands,
  }
  local last_valid_ref = ref
  local last_completion_level = 0

  for _, cmd in ipairs(splitcmd) do
    -- if ref.enabled ~= nil and ref.enabled == false then return end
    if not ref or not M.cond(ref.condition, current_buf, is_down) then
      break
    end

    ref = ref.commands or {}
    ref = ref[cmd]

    if ref then
      if ref.enabled ~= nil and ref.enabled == false then
        break
      end
      last_valid_ref = ref
      last_completion_level = last_completion_level + 1
    end
  end

  if last_valid_ref.enabled ~= nil and last_valid_ref.enabled == false then
    return
  end
  if not last_valid_ref.commands and last_valid_ref.complete then
    if type(last_valid_ref.complete) == "function" then
      last_valid_ref.complete = last_valid_ref.complete(current_buf, is_down)
    end

    if vim.endswith(command, " ") then
      local completions = last_valid_ref.complete[#splitcmd - last_completion_level + 1]
        or {}

      if type(completions) == "function" then
        completions = completions(current_buf, is_down) or {}
      end

      return completions
    else
      local completions = last_valid_ref.complete[#splitcmd - last_completion_level]
        or {}

      if type(completions) == "function" then
        completions = completions(current_buf, is_down) or {}
      end

      return vim.tbl_filter(function(key)
        return key:find(splitcmd[#splitcmd])
      end, completions)
    end
  end

  -- TODO: Fix `:down m <tab>` giving invalid completions
  local keys = ref and vim.tbl_keys(ref.commands or {})
    or (
      vim.tbl_filter(function(key)
        return key:find(splitcmd[#splitcmd])
      end, vim.tbl_keys(last_valid_ref.commands or {}))
    )
  table.sort(keys)
  do
    local commands = (ref and ref.commands or last_valid_ref.commands) or {}

    return vim.tbl_filter(function(key)
      if type(commands[key]) == "table" then
        return M.cond(commands[key].condition, current_buf, is_down)
      end
    end, keys)
  end
end

--- Queries the user to select next argument
---@param qargs table #A string of arguments previously supplied to the down command
---@param choices table #all possible choices for the next argument
M.select_next_cmd_arg = function(qargs, choices)
  local current = table.concat({ "Down ", qargs })

  local query

  if vim.tbl_isempty(choices) then
    query = function(...)
      vim.ui.input(...)
    end
  else
    query = function(...)
      vim.ui.select(choices, ...)
    end
  end

  query({
    prompt = current,
  }, function(choice)
    if choice ~= nil then
      vim.cmd(("%s %s"):format(current, choice))
    end
  end)
end

-- The table containing all the functions. This can get a tad complex so I recommend you read the wiki entry

---@param mod_name string #An absolute path to a loaded init with a mod.config.commands table following a valid structure
M.add_commands = function(mod_name)
  local mod_config = mod.get_mod(mod_name)

  if
    not mod_config
    or not mod_config.commands
    or (
      mod_config.commands.enabled ~= nil
      and mod_config.commands.enabled == false
    )
  then
    return
  end

  M.commands = vim.tbl_extend("force", M.commands, mod_config.commands)
end

M.enabled = function(c)
  return vim.iter(c):filter(function(v)
    return v.enabled == nil or (v.enabled ~= nil and v.enabled == true)
  end)
end

--- Recursively merges the provided table with the mod.config.commands table.
---@param f down.Command[] #A table that follows the mod.config.commands structure
M.add_commands_from_table = function(f)
  vim.tbl_extend("force", M.commands, f)
end

--- Rereads data from all mod and rebuild the list of available autocompletiinitinitons and commands
M.sync = function()
  for mn, lm in pairs(mod.mods) do
    for cn, c in pairs(lm.commands or {}) do
      if type(c) == "table" then
        M.commands[cn] = vim.tbl_extend("force", M.commands[cn] or {}, c)
      end
    end
  end
end

--- Defines a custom completion function to use for `base.cmd`.
---@param callback function
M.set_completion = function(callback)
  M.generate_completions = callback
end

M.load = function()
  vim.api.nvim_create_user_command("Down", M.cb, {
    desc = "The down command",
    range = 2,
    force = true,
    -- bang = true,
    nargs = "*",
    complete = M.generate_completions,
  })
end

---@class down.mod.cmd.Config
M.config = {}
---@class cmd

M.post_load = function()
  M.sync()
end

return M
