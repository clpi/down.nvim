return {
  lsp = {
    name = 'lsp',
    condition = 'markdown',
    callback = function(e)
      log.trace 'lsp'
    end,
    subcommands = {
      restart = {
        args = 0,
        name = 'lsp.restart',
        condition = 'markdown',
        callback = function(e)
          log.trace 'lsp.restart'
        end,
      },
      start = {
        args = 0,
        name = 'lsp.start',
        condition = 'markdown',
        callback = function(e)
          log.trace 'lsp.start'
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
  -- actions = {
  --   args = 1,
  --   name = 'actions',
  --   condition = 'markdown',
  --   callback = function(e)
  --     log.trace 'actions'
  --   end,
  --   subcommands = {
  --     workspace = {
  --       args = 1,
  --       name = 'actions.workspace',
  --       condition = 'markdown',
  --       callback = function(e)
  --         log.trace 'actions.workspce'
  --       end,
  --     },
  --   },
  -- },
  -- rename = {
  --   args = 1,
  --   max_args = 1,
  --   name = 'rename',
  --   condition = 'markdown',
  --   subcommands = {
  --     workspace = {
  --       args = 0,
  --       name = 'rename.workspace',
  --       condition = 'markdown',
  --       callback = function(e)
  --         log.trace 'rename.workspace'
  --       end,
  --     },
  --     dir = {
  --       args = 0,
  --       name = 'rename.dir',
  --       condition = 'markdown',
  --       callback = function(e)
  --         log.trace 'rename.dir'
  --       end,
  --     },
  --     section = {
  --       args = 0,
  --       name = 'rename.section',
  --       condition = 'markdown',
  --       callback = function(e)
  --         log.trace 'rename.section'
  --       end,
  --     },
  --     file = {
  --       args = 0,
  --       name = 'rename.file',
  --       condition = 'markdown',
  --       callback = function(e)
  --         log.trace 'rename.file'
  --       end,
  --     },
  --   },
  -- },
}
