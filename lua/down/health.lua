local H = {}

local h = vim.health
local start = vim.health.start
local ok, err, warn = h.ok, h.error, h.warn

local config = require("down.config")
local down = require("down")

H.cmds = function() end

H.lsp = {
  installed = function()
    if vim.fn.executable("down.lsp") == 0 then
      return h.error("down.lsp is not installed")
    end
    return h.ok("down.lsp is installed")
  end,
}

H.user = function()
  if config.user == nil then
    return h.error("config.mod is nil")
  end
  return h.ok("config.mod is not nil")
end

H.workspace = function()
  if config.user.workspace and config.user.workspace.workspaces == nil then
    h.error("config.mod.workspace.workspaces is nil")
  else
    h.ok("config.mod.workspace.workspaces is not nil")
  end
end

H.deps = {
  required = {
    ["nvim-treesitter"] = "nvim-treesitter/nvim-treesitter",
    ["plenary.nvim"] = "nvim-lua/plenary.nvim",
    ["nui.nvim"] = "MunifTanjim/nui.nvim",
  },
  optional = {
    ["fzf.lua"] = "",
    ["telescope.nvim"] = "nvim-telescope/telescope.nvim",
    ["snacks.nvim"] = "folke/snacks.nvim",
    ["mini.pick"] = "wuelnerdotexe/mini.pick",
    ["nvim-web-devicons"] = "kyazdani42/nvim-web-devicons",
    ["mini.icons"] = "wuelnerdotexe/mini.icons",
  },
  has_required = function()
    for dep, repo in pairs(H.deps.required) do
      if not H.check_dep(dep) then
        return h.error(dep .. " is not installed" .. repo)
      end
    end
    return h.ok("All required dependencies are installed")
  end,
}

H.icon = {
  ---@param provider? down.mod.ui.icon.Provider.Name
  has_provider = function(provider)
    if require("down.mod.ui.icon.util").has_provider(i) then
      return h.ok("Icon provider is available " .. i)
    end
    return h.ok("Icon provider is not available, defaulting to builtin")
  end,
}

H.check_dep = function(dep)
  local lazyok, lazy = pcall(require, "lazy.core.config")
  if lazyok then
    return lazy.plugins[dep] ~= nil
  else
    return package.loaded[dep] ~= nil
  end
end

H.check_optional = function()
  if H.check_dep("telescope.nvim") then
    h.ok(H.optional["telescope.nvim"] .. " is installed")
  else
    h.warn(H.optional["telescope.nvim"] .. " is not installed")
  end
  if H.check_dep("nvim-web-devicons") or H.check_dep("mini.icons") then
    h.warn(H.optional["mini.icons"] .. " is not installed")
  else
    h.warn(
      H.optional["mini.icons"]
        or H.optional["nvim-web-devicons"] .. " is not installed"
    )
  end
end

H.check_req = function()
  for dep, repo in pairs(H.deps) do
    if H.check_dep(dep) then
      h.ok(dep .. " is installed" .. repo)
    else
      h.error(dep .. " is not installed" .. repo)
    end
  end
end

H.check = function()
  h.start("down.nvim")
  H.lsp.installed()
  H.icon.has_provider("down")
  H.check_optional()
  H.check_req()
  H.user()
  H.workspace()
end

H.health = {}

return H
