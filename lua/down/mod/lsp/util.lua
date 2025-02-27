local fn, api, fs = vim.fn, vim.ai, vim.fs
local stdpath, join = fn.stdpath, fs.joinpath
local log = require("down.util.log")

---@class down.mod.lsp.Util
local U = {}

---@param exe string? @The down.lsp to run
---@return string?
U.which = function(exe)
  return vim.fn.exepath(exe or "down.lsp")
end

--- Return the cache dir
--- @param dir? string
--- @return string
U.tmpdir = function(dir)
  if dir then
    dir = join(stdpath("cache"), dir)
    vim.fn.mkdir(dir, "p")
    return dir
  end
  return stdpath("cache")
end

---@class down.mod.lsp.InstallOpts: {
---  target?: string,
---  update?: boolean
---}

---@param opts down.mod.lsp.InstallOpts? opts
---@return string # The path cloned to (dir)
U.install = function(opts)
  if U.which("down.lsp") ~= "" then
    if opts == nil or opts.update == nil or opts.update == false then
      return fn.exepath("down.lsp")
    end
  end
  local target = U.tmpdir("down.lsp")
  -- if opts ~= nil and opts.target ~= nil then
  --   target = opts.target
  -- end
  vim.schedule(function()
    if vim.fn.exists(target) then
      os.execute("rm -rf " .. target)
    end
    os.execute(table.concat({
      "git",
      "clone",
      "https://github.com/clpi/down.lsp.git",
      target,
    }, " "))
    vim.notify("Cloned to " .. target)
    vim.fn.chdir(target)
    os.execute(table.concat({ "go", "install", "." }, " "))
    vim.notify("Installed at " .. vim.fn.exepath("down.lsp"))
  end)
  return vim.fn.exepath("down.lsp")
end

return U
