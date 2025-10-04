local Dirs = {}

Dirs.vim = {
  data = vim.fn.stdpath('data'),
  config = vim.fn.stdpath('config'),
  cache = vim.fn.stdpath('cache'),
  state = vim.fn.stdpath('state'),
  run = vim.fn.stdpath('run'),
  log = vim.fn.stdpath('log'),
}

Dirs.down = {
  dir = function(base, sub)
    return vim.fs.joinpath(vim.fn.stdpath(base or 'data'), sub or '')
  end,
}

--- Check if path exists
---@param path string
---@return boolean
local function path_exists(path)
  return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

--- Check if path is a directory
---@param path string
---@return boolean
local function is_dir(path)
  return vim.fn.isdirectory(path) == 1
end

--- Touch a file (create if doesn't exist)
---@param path string
local function touch_file(path)
  if vim.fn.filereadable(path) == 0 then
    vim.fn.writefile({}, path)
  end
end

Dirs.get_mkfile = function(file)
  if not path_exists(file) or is_dir(file) then
    touch_file(file)
  end
  return file
end

Dirs.get_mkdir = function(dir)
  if not path_exists(dir) or vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, 'p')
  end
  return dir
end

return Dirs
