local H = {}

local h = vim.health
local start = vim.health.start

H.check = function ()
  h.start ("down.nvim")

  -- Check Neovim version
  if vim.fn.has ("nvim-0.10") == 1 then
    h.ok ("Neovim >= 0.10")
  else
    h.error ("down.nvim requires Neovim >= 0.10")
  end

  -- Check plugin loaded
  local ok, down = pcall (require, "down")
  if ok then
    h.ok ("down.nvim loaded successfully")
  else
    h.error ("Failed to load down.nvim: " .. tostring (down))
    return
  end

  -- Check config
  if down.config.started then
    h.ok ("Plugin is initialized")
  else
    h.warn ("Plugin is not yet initialized (call require('down').setup())")
  end

  -- Check LSP
  h.start ("down.lsp")
  local lsp_ok, lsp_mod = pcall (require, "down.mod.lsp")
  if lsp_ok and lsp_mod then
    if lsp_mod.is_installed () then
      h.ok ("down.lsp binary installed at: " .. lsp_mod.bin_path ())
    else
      h.warn ("down.lsp not installed (will auto-download on first use)")
    end
  else
    h.warn ("LSP module not available")
  end

  -- Check MCP
  h.start ("down.mcp")
  local mcp_ok, mcp_mod = pcall (require, "down.mod.mcp")
  if mcp_ok and mcp_mod then
    if mcp_mod.is_installed () then
      local running = mcp_mod.job_id and "running" or "stopped"
      h.ok ("down.mcp binary installed (" .. running .. ")")
    else
      h.warn ("down.mcp not installed (will auto-download on first use)")
    end
  else
    h.warn ("MCP module not available")
  end

  -- Check dependencies
  h.start ("Dependencies")
  local deps = {
    { "nvim-treesitter", true },
    { "telescope.nvim", false },
    { "snacks.nvim", false },
  }
  for _, dep in ipairs (deps) do
    local name, required = dep[1], dep[2]
    local has = H.check_dep (name)
    if has then
      h.ok (name .. " installed")
    elseif required then
      h.error (name .. " is required but not installed")
    else
      h.info (name .. " not installed (optional)")
    end
  end

  -- Check modules
  h.start ("Modules")
  local mod = require ("down.mod")
  local loaded_count = vim.tbl_count (mod.mods)
  if loaded_count > 0 then
    h.ok (loaded_count .. " modules loaded")
    for name, _ in pairs (mod.mods) do
      h.info ("  • " .. name)
    end
  else
    h.warn ("No modules loaded yet")
  end
end

H.check_dep = function (dep)
  local lazyok, lazy = pcall (require, "lazy.core.config")
  if lazyok then
    return lazy.plugins[dep] ~= nil
  else
    return package.loaded[dep] ~= nil
  end
end

return H
