local log = require 'down.util.log'
local mod = require 'down.mod'
local vs = vim.snippet

---@class down.mod.code.Snippet: down.Mod
local Snippet = mod.new 'code.snippet'

Snippet.commands = {
  name = 'code.snippet',
  args = 0,
  max_args = 1,
  callback = function(e)
    log.trace 'Snippet callback'
  end,
  snippet = {
    commands = {
      add = {
        args = 0,
        name = 'code.snippet.add',
        max = 1,
        callback = function(e)
          log.trace 'Snippet.add callback'
        end,
      },
      edit = {
        name = 'code.snippet.edit',
        args = 0,
        max_args = 1,
        callback = function(e)
          log.trace 'Snippet edit callback'
        end,
      },
      remove = {
        name = 'code.snippet.remove',
        args = 0,
        max_args = 1,
        callback = function(e)
          log.trace 'Snippet remove callback'
        end,
      },
      update = {
        name = 'code.snippet.update',
        args = 0,
        max_args = 1,
        callback = function(e)
          log.trace 'Snippet update callback'
        end,
      },
    },
  },
}

Snippet.setup = function()
  return {
    loaded = true,
    dependencies = { 'workspace', 'cmd', 'data' },
  }
end

---@class down..code.snippet.Config
Snippet.config = {}

return Snippet
