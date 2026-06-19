local Schema = {}

Schema.field_types = {
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

Schema.default_schema = {
  title = { type = "title" },
  tags = { type = "multi_select", options = {} },
  created = { type = "date" },
}

Schema.validate_type = function(kind)
  return vim.tbl_contains(Schema.field_types, kind)
end

Schema.normalize = function(raw_schema)
  local schema = {}
  for key, def in pairs(raw_schema) do
    if type(def) == "string" then
      schema[key] = { type = def }
    elseif type(def) == "table" then
      schema[key] = vim.deepcopy(def)
      if not schema[key].type then
        schema[key].type = "text"
      end
    end
  end
  return schema
end

Schema.default_value = function(field)
  local kind = field.type or "text"
  if kind == "checkbox" then
    return false
  elseif kind == "number" then
    return 0
  elseif kind == "multi_select" then
    return {}
  elseif kind == "date" then
    return ""
  elseif kind == "title" then
    return ""
  end
  return ""
end

Schema.validate_field = function(value, field)
  local kind = field.type or "text"
  if kind == "title" or kind == "text" then
    return type(value) == "string" or type(value) == "number"
  elseif kind == "number" then
    return type(value) == "number" or (type(value) == "string" and tonumber(value) ~= nil)
  elseif kind == "select" then
    if field.options and not vim.tbl_contains(field.options, value) then
      return false, string.format("'%s' is not a valid option. Valid: %s", tostring(value), table.concat(field.options, ", "))
    end
    return true
  elseif kind == "multi_select" then
    if type(value) ~= "table" then
      return false, "multi_select must be a table"
    end
    if field.options then
      for _, v in ipairs(value) do
        if not vim.tbl_contains(field.options, v) then
          return false, string.format("'%s' is not a valid option", v)
        end
      end
    end
    return true
  elseif kind == "date" then
    if type(value) ~= "string" then
      return false, "date must be a string"
    end
    return value:match("^%d%d%d%d%-%d%d%-%d%d") ~= nil
  elseif kind == "checkbox" then
    return type(value) == "boolean", "checkbox must be boolean"
  elseif kind == "url" then
    return type(value) == "string" and value:match("^https?://") ~= nil
  elseif kind == "email" then
    return type(value) == "string" and value:match("^[%w.+-]+@[%w.-]+%.[%a]{2,}$") ~= nil
  elseif kind == "status" then
    if field.options and not vim.tbl_contains(field.options, value) then
      return false
    end
    return true
  end
  return true
end

return Schema
