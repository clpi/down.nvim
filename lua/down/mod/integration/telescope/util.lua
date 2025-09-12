local Util = {}

Util.mod = function(module)
  local ok, pc = pcall(require, 'down.mod.' .. module)
  if ok then
    return pc
  else
    return nil
  end
end

Util.telescope = function(module)
  local ok, pc = pcall(require, 'telescope.' .. module)
  if ok then
    return pc
  else
    return nil
  end
end

return Util
