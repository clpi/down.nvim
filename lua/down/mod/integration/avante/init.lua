local mod = require("down.mod")

---@class down.mod.integration.avante.Avante: down.Mod
local Avante = mod.new("integration.avante")

Avante.setup = function()
  return {
    loaded = true,
    dependencies = {},
  }
end

Avante.load = function()
  -- Ensure down.lsp attaches to AvanteInput so that down.nvim completions work inside Avante prompts
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "AvanteInput",
    callback = function(args)
      local lsp_mod = require("down.mod").get_mod("lsp")
      if lsp_mod and lsp_mod.attach then
        lsp_mod.attach()
      end
    end,
    desc = "Attach down.lsp to Avante prompt buffer",
  })
end

--- Helper function to append down.nvim workspace context to a system prompt
--- Can be used in Avante's system_prompt configuration.
--- @param original_prompt string
--- @return string
Avante.inject_system_prompt = function(original_prompt)
  local ws = require("down.mod").get_mod("workspace")
  if not ws then return original_prompt end
  
  local current_ws = ws.current()
  local ws_path = ws.get(current_ws)
  if not ws_path then return original_prompt end
  
  local context = "\n\nYou have access to the user's down.nvim workspace: " .. current_ws .. ".\n"
  context = context .. "Workspace path: " .. ws_path .. "\n"
  
  local files = vim.fn.globpath(ws_path, "**/*.md", true, true)
  context = context .. "Available markdown files:\n"
  for _, file in ipairs(files) do
    context = context .. "- " .. file:sub(#ws_path + 2) .. "\n"
  end
  
  return original_prompt .. context
end

return Avante
