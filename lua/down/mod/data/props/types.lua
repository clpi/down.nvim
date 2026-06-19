local Types = {}

Types.kinds = {
  "title",
  "text",
  "number",
  "select",
  "multi_select",
  "date",
  "checkbox",
  "url",
  "email",
  "phone",
  "formula",
  "relation",
  "rollup",
  "created_time",
  "last_edited_time",
  "status",
  "files",
  "person",
}

Types.detect = function(value)
  if type(value) == "boolean" then
    return "checkbox"
  elseif type(value) == "number" then
    return "number"
  elseif type(value) == "string" then
    if value:match("^https?://") then
      return "url"
    elseif value:match("^[%w.+-]+@[%w.-]+%.[%a]{2,}$") then
      return "email"
    elseif value:match("^%d%d%d%d%-%d%d%-%d%d") then
      return "date"
    elseif value:match("^[%+%d%s%(%)%-]+$") and #value >= 7 then
      return "phone"
    end
    return "text"
  elseif type(value) == "table" then
    local all_strings = true
    for _, v in ipairs(value) do
      if type(v) ~= "string" then
        all_strings = false
        break
      end
    end
    if all_strings and #value > 0 then
      return "multi_select"
    end
    return nil
  end
  return nil
end

Types.validate = {}

Types.validate.text = function(v)
  return true
end

Types.validate.number = function(v)
  return type(v) == "number" or (type(v) == "string" and tonumber(v) ~= nil)
end

Types.validate.select = function(v, options)
  if not options then
    return true
  end
  return vim.tbl_contains(options, v)
end

Types.validate.multi_select = function(v, options)
  if type(v) ~= "table" then
    return false
  end
  if not options or #options == 0 then
    return true
  end
  for _, item in ipairs(v) do
    if not vim.tbl_contains(options, item) then
      return false
    end
  end
  return true
end

Types.validate.date = function(v)
  if type(v) ~= "string" then
    return false
  end
  return v:match("^%d%d%d%d%-%d%d%-%d%d") ~= nil
end

Types.validate.checkbox = function(v)
  return type(v) == "boolean"
end

Types.validate.url = function(v)
  if type(v) ~= "string" then
    return false
  end
  return v:match("^https?://") ~= nil
end

Types.validate.email = function(v)
  if type(v) ~= "string" then
    return false
  end
  return v:match("^[%w.+-]+@[%w.-]+%.[%a]{2,}$") ~= nil
end

Types.validate.phone = function(v)
  if type(v) ~= "string" then
    return false
  end
  return v:match("^[%+%d%s%(%)%-]+$") ~= nil and #v >= 7
end

Types.format = {}

Types.format.text = function(v)
  return tostring(v)
end

Types.format.number = function(v)
  return tostring(tonumber(v) or v)
end

Types.format.select = function(v)
  return tostring(v)
end

Types.format.multi_select = function(v)
  if type(v) == "table" then
    return table.concat(v, ", ")
  end
  return tostring(v)
end

Types.format.date = function(v)
  return tostring(v)
end

Types.format.checkbox = function(v)
  return v and "Yes" or "No"
end

Types.format.url = function(v)
  return tostring(v)
end

Types.format.email = function(v)
  return tostring(v)
end

Types.format.phone = function(v)
  return tostring(v)
end

return Types
