---@class down.mod.data.bookmark.Bookmark: down.Mod
local Bookmark = {}

---@class down.mod..bookmark.Config
Bookmark.config = {
  workspace = "default",

  file = "bookmark",
}

---@class down.mod..bookmark.Data
Bookmark.bookmarks = {
  default = {},
}

---@return down.mod.Setup
Bookmark.setup = function()
  return {
    loaded = true,
    dependencies = {
      "data",
      "workspace",
      "cmd",
    },
  }
end

Bookmark.commands = {
  bookmark = {
    args = 1,
    name = "bookmark",
    callback = function(e) end,
    commands = {
      list = {
        name = "bookmark.list",
        args = 1,
        callback = function(e) end,
      },
      add = {
        name = "bookmark.add",
        args = 1,
        callback = function(e) end,
      },
      remove = {
        name = "bookmark.remove",
        args = 1,
        callback = function(e) end,
      },
    },
  },
}

Bookmark.load = function() end

-- Bookmark.handle = {
--   cmd = {
--     bookmark = {
--       __call = Bookmark.commands.bookmark.callback,
--       list = Bookmark.commands.bookmark.commands.list.callback,
--       remove = Bookmark.commands.bookmark.commands.remove.callback,
--       add = Bookmark.commands.bookmark.commands.add.callback,
--     },
--   },
-- }

return Bookmark
