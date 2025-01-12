---@class down.mod..Bookmark: down.Mod
local B = {}

---@class down.mod..bookmark.Config
B.config = {
  workspace = 'default',

  file = 'bookmark',
}

---@class down.mod..bookmark.Data
B.bookmarks = {
  default = {},
}

---@return down.mod.Setup
B.setup = function()
  return {
    loaded = true,
    dependencies = {
      'data',
      'workspace',
      'cmd',
    },
  }
end

B.commands = {
  bookmark = {
    args = 1,
    name = 'bookmark',
    callback = function(e) end,
    subcommands = {
      list = {
        name = 'bookmark.list',
        args = 1,
        callback = function(e) end,
      },
      add = {
        name = 'bookmark.add',
        args = 1,
        callback = function(e) end,
      },
      remove = {
        name = 'bookmark.remove',
        args = 1,
        callback = function(e) end,
      },
    },
  },
}

B.load = function() end

-- B.handle = {
--   cmd = {
--     bookmark = {
--       __call = B.commands.bookmark.callback,
--       list = B.commands.bookmark.subcommands.list.callback,
--       remove = B.commands.bookmark.subcommands.remove.callback,
--       add = B.commands.bookmark.subcommands.add.callback,
--     },
--   },
-- }

return B
