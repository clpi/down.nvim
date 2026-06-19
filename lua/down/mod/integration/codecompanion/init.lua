local mod = require("down.mod")

---@class down.mod.integration.codecompanion.Codecompanion: down.Mod
local Codecompanion = mod.new("integration.codecompanion")

Codecompanion.setup = function()
  return {
    loaded = true, -- Expose tools even if CC is not loaded yet
    dependencies = {},
  }
end

Codecompanion.slash_commands = {
  workspace = {
    description = "Insert down.nvim workspace context",
    callback = function(chat)
      local ws = require("down.mod").get_mod("workspace")
      if not ws then return end
      
      local current_ws = ws.current()
      local ws_path = ws.get(current_ws)
      if not ws_path then return end
      
      local files = vim.fn.globpath(ws_path, "**/*.md", true, true)
      local context = "## down.nvim Workspace: " .. current_ws .. "\n\nFiles in workspace:\n"
      for _, file in ipairs(files) do
        context = context .. "- " .. file:sub(#ws_path + 2) .. "\n"
      end
      
      chat:add_message({
        role = "user",
        content = context,
      }, { visible = false })
      
      vim.notify("[down.nvim] Workspace context added to CodeCompanion chat", vim.log.levels.INFO)
    end,
  }
}

Codecompanion.load = function()
  -- Try to inject automatically if codecompanion config is already available
  pcall(function()
    local cc = require("codecompanion.config")
    if cc and cc.strategies and cc.strategies.chat then
      cc.strategies.chat.slash_commands = cc.strategies.chat.slash_commands or {}
      cc.strategies.chat.slash_commands["down"] = Codecompanion.slash_commands.workspace
    end
  end)
end

return Codecompanion
