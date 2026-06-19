local mod = require("down.mod")

---@class down.mod.mcp.Mcp: down.Mod
local Mcp = mod.new("mcp")
Mcp.dep = { "lsp" }

Mcp.setup = function()
  return { loaded = true }
end

Mcp.get_bin_path = function()
  local lsp_mod = mod.get_mod("lsp")
  if lsp_mod and lsp_mod.bin_path then
    return lsp_mod.bin_path()
  end
  return vim.fn.stdpath("data") .. "/down/lsp/down"
end

Mcp.commands = {
  mcp = {
    name = "mcp",
    enabled = true,
    min_args = 0,
    max_args = 1,
    callback = function()
      vim.notify("[down.nvim] Use :Down mcp <enable|disable|config>", vim.log.levels.INFO)
    end,
    commands = {
      enable = {
        name = "mcp.enable",
        enabled = true,
        args = 0,
        callback = function()
          vim.notify("[down.nvim] down.mcp is a stdio server meant to be run by MCP clients.", vim.log.levels.INFO)
        end,
      },
      disable = {
        name = "mcp.disable",
        enabled = true,
        args = 0,
        callback = function()
          vim.notify("[down.nvim] disabled down.mcp", vim.log.levels.INFO)
        end,
      },
      config = {
        name = "mcp.config",
        enabled = true,
        args = 0,
        callback = function()
          local bin = Mcp.get_bin_path()
          local json = string.format([[
{
  "mcpServers": {
    "down.nvim": {
      "command": "%s",
      "args": ["mcp"]
    }
  }
}]], bin)
          vim.fn.setreg("+", json)
          vim.notify("[down.nvim] MCP config copied to clipboard!\n" .. json, vim.log.levels.INFO)
        end,
      },
    },
  },
}

return Mcp
