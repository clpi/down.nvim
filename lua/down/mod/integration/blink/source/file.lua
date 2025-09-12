---@class down.mod.integration.blink.source.FileOptions
---@field pre_min_len? number: min
---@field public cmd? fun(ctx: blink.cmp.Context, pre: string): string[]
---@field public pre? fun(ctx: blink.cmp.Context): string[]

local vim = require("vim")
local Fs = {}

---@return blink.cmp.Source
---@param opt down.mod.integration.blink.source.FileOptions
function Fs:new(opt)
  ---@type down.mod.integration.blink.source.FileOptions
  opt = opt or {}
  return setmetatable({
    pre_min_len = opt.pre_min_len or 3,
    cmd = opt.cmd or function(_, pre)
      return {
        "rg",
        "--no-config",
        "--json",
        "--down-regexp",
        "--ignore-case",
        "--",
        pre .. "[\\w_-]+",
        vim.fs.root(0, ".git") or vim.fn.getcwd(),
      }
    end,
    pre = opt.pre or function(ctx)
      return ctx.line:sub(1, ctx.cursor[2]):match("[%w_-]+$") or ""
    end,
  }, { __index = Fs })
end

function Fs:get_completions(ctx, cb)
  local p = self.pre(ctx)
  if string.len(p) < self.pre_min_len then
    cb()
    return
  end
  vim.system(self.cmd(ctx, p), nil, function(r)
    if r.code ~= 0 then
      cb()
      return
    end
    --- ,,,
  end)
end

return Fs
