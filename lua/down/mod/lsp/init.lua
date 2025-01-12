local mod = require 'down.mod'
local log = require 'down.util.log'
local settings = require 'down.mod.lsp.settings'
local lsp = vim.lsp
local lspu = vim.lsp.util
local cwd = vim.fn.getcwd
local exp = vim.fn.expand
local ft = vim.bo.filetype
local trc, inf, err, wrn = log.trace, log.info, log.error, log.warn

---@class down.mod.Lsp: down.Mod
local Lsp = mod.new 'lsp'

---@return down.mod.Setup
Lsp.setup = function()
  ---@type down.mod.Setup
  return {
    loaded = true,
    dependencies = {
      'cmd',
      'workspace',
    },
  }
end

Lsp.commands = {
  lsp = {
    name = 'lsp',
    condition = 'markdown',
    callback = function(e)
      trc('lsp', e)
    end,
    subcommands = {
      restart = {
        args = 0,
        name = 'lsp.restart',
        condition = 'markdown',
        callback = function(e)
          log.trace('lsp.restart', e)
        end,
      },
      start = {
        args = 0,
        name = 'lsp.start',
        condition = 'markdown',
        callback = function(e)
          log.trace('lsp.start', e)
        end,
      },
      status = {
        args = 0,
        name = 'lsp.status',
        condition = 'markdown',
        callback = function(e)
          log.trace 'lsp.status'
        end,
      },
      stop = {
        args = 0,
        name = 'lsp.stop',
        condition = 'markdown',
        callback = function(e)
          log.trace 'lsp.stop'
        end,
      },
    },
  },
  actions = {
    args = 1,
    name = 'actions',
    condition = 'markdown',
    callback = function(e)
      log.trace 'actions'
    end,
    subcommands = {
      workspace = {
        args = 1,
        name = 'actions.workspace',
        condition = 'markdown',
        callback = function(e)
          trc('actions.workspce', e)
        end,
      },
    },
  },
  rename = {
    args = 1,
    max_args = 1,
    name = 'rename',
    condition = 'markdown',
    subcommands = {
      workspace = {
        args = 0,
        name = 'rename.workspace',
        condition = 'markdown',
        callback = function(e)
          trc('rename.workspace', e)
        end,
      },
      dir = {
        args = 0,
        name = 'rename.dir',
        condition = 'markdown',
        callback = function(e)
          trc(e, 'rename.dir')
        end,
      },
      section = {
        args = 0,
        name = 'rename.section',
        condition = 'markdown',
        callback = function(e)
          trc(e, 'rename.section')
        end,
      },
      file = {
        args = 0,
        name = 'rename.file',
        condition = 'markdown',
        callback = function(e)
          log.trace 'rename.file'
        end,
      },
    },
  },
}

Lsp.load = function()
  local autocmd = Lsp.ft 'markdown'
end

---@class down.mod.lsp.Config
Lsp.info = {
  name = 'down-lsp',
  cmd = { 'down', '--stdio', 'lsp' },
  root_dir = cwd(),
  settings = settings,
}

function Lsp.run()
  local ext = vim.fn.expand '%:e'
  if ext == 'md' or ext == 'dn' or ext == 'dd' or ext == 'down' or ext == 'downrc' then
    lsp.start(Lsp.info)
  end
end

function Lsp.augroup()
  return vim.api.nvim_create_augroup('down.lsp', {
    clear = true,
  })
end

function Lsp.serve()
  lsp.start {
    name = 'downls',
    cmd = { 'down', '--stdio', 'lsp' },
    root_dir = cwd(),
    settings = Lsp.config.settings,
  }
end

Lsp.autocmd = function(fty)
  return vim.api.nvim_create_autocmd({ 'BufEnter', 'BufNewFile' }, {
    pattern = fty or '*',
    callback = Lsp.serve,
    desc = 'Run downls',
  })
end

Lsp.ft = function(fty)
  return vim.api.nvim_create_autocmd({ 'FileType' }, {
    pattern = fty or '*',
    callback = Lsp.serve,
    desc = 'Run downls',
  })
end

-- ---@param e down.Event
-- Lsp.handle = {
--   cmd = {
--     ['rename'] = function(e) end,
--     ['action'] = function(e) end,
--     ['lsp'] = function(e) end,
--   },
-- }

return Lsp
