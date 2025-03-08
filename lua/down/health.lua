local H = {}

local h = vim.health
local start = vim.health.start
local ok, err, warn = h.ok, h.error, h.warn

H.user = function()
  if require("down.config").user == nil then
    h.error("config.mod is nil")
  else
    h.ok("config.mod is not nil")
  end
end

H.workspace = function()
  if require("down.config").user.workspace.config.workspaces == nil then
    h.error("config.mod.workspace.workspaces is nil")
  else
    h.ok("config.mod.workspace.workspaces is not nil")
  end
end

H.deps = {
  ["nvim-treesitter"] = "nvim-treesitter/nvim-treesitter",
  ["plenary.nvim"] = "nvim-lua/plenary.nvim",
  ["nui.nvim"] = "MunifTanjim/nui.nvim",
}

H.optional = {
  ["telescope.nvim"] = "nvim-telescope/telescope.nvim",
  ["nvim-web-devicons"] = "kyazdani42/nvim-web-devicons",
  ["mini.icons"] = "wuelnerdotexe/mini.icons",
}

---@param i? down.mod.ui.icon.Provider.Name
H.has_icon_provider = function(i)
  if require("down.mod.ui.icon.util").has_provider(i) then
    return h.ok("Icon provider is available")
  end
end

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
  H.check_optional()
  H.check_req()
  H.user()
  H.workspace()
end

H.health = {}

return H
