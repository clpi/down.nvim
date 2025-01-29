local uv = vim.uv or vim.loop

local W = {}

W.buf = function()

  -- local uri = vim.uri
end

W.time = function(fn)
  local timer = assert(vim.looop.new_timer())
  timer:start(1000, 0, vim.schedule_wrap(fn))
end

W.join = function(ph, ...)
  local path = vim.fn.resolve(vim.fs.normalize(ph or '', { expand_env = true}))
  if #{...} > 0 then vim.iter({...}):each(function(p) path = vim.fs.joinpath(path, p) end) end
  return path
end

W.path = function(p1, ...)
  local p = vim.fn.resolve(vim.fs.normalize(p1, { expand_env = true }))
  vim.iter({...}):each(function(path) p = vim.fs.joinpath(p, path) end)
  if not vim.fn.isdirectory(vim.fn.fnamemodify(p, ':h')) then
    vim.fn.mkdir(vim.fn.fnamemodify(p, ':h'), 'p')
  end
  return p
end

W.dir = function(p, ...)
  local par = vim.fn.resolve(vim.fs.dirname(W.path(p)))
  vim.fn.mkdir(par, 'p')
  return W.join(par, ...)
end



---@return down.Workspace
W.init = function()
  local pwd = vim.fn.getcwd()
  ---@type down.Workspace
  return {
    id = pwd,
    config = {
      init = {
      },
      rc = pwd .. "rc.down",
      dataDir = pwd .. ".down/"


    },
    uri = "file:",

    name = pwd,

  }
end


W.spl = function()
  return
end

return W
