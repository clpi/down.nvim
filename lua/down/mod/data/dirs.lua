local Dirs = {}

local path = require('plenary.path')
local ctx = require 'plenary.context_manager'
local async = require 'plenary.async_lib'

Dirs.vim = {
  data = vim.fn.stdpath('data'),
  config = vim.fn.stdpath('config'),
  cache = vim.fn.stdpath('cache'),
  state = vim.fn.stdpath('state'),
  run = vim.fn.stdpath('run'),
  log = vim.fn.stdpath('log'),
}

Dirs.down = {
  dir = function(base, sub)
    return vim.fs.joinpath(vim.fn.stdpath(base or 'data'), sub or '')
  end,
}

Dirs.get_mkfile = function(file)
  local f = path:new(file)
  if not f:exists() or f:is_dir() then
    file:touch()
  end
  return file
end

Dirs.get_mkdir = function(dir)
  local d = path:new(dir)
  if not d:exists() or d:is_file() then
    dir:mkdir()
  end
  return dir
end

return Dirs
