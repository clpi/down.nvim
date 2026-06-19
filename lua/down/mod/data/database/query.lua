local Query = {}

Query.operators = {
  eq = "=",
  neq = "!=",
  gt = ">",
  gte = ">=",
  lt = "<",
  lte = "<=",
  contains = "contains",
  does_not_contain = "does_not_contain",
  starts_with = "starts_with",
  ends_with = "ends_with",
  is_empty = "is_empty",
  is_not_empty = "is_not_empty",
  in = "in",
  not_in = "not_in",
  before = "before",
  after = "after",
  on_or_before = "on_or_before",
  on_or_after = "on_or_after",
}

Query.filter = function(rows, filters)
  if not filters or #filters == 0 then
    return rows
  end

  local result = {}
  for _, row in ipairs(rows) do
    if Query.matches(row, filters) then
      table.insert(result, row)
    end
  end
  return result
end

Query.matches = function(row, filters)
  if filters.and then
    for _, f in ipairs(filters.and) do
      if not Query.matches(row, { or = { f } }) then
        return false
      end
    end
    return true
  elseif filters.or then
    for _, f in ipairs(filters.or) do
      if Query.matches(row, { and = { f } }) then
        return true
      end
    end
    return #filters.or == 0
  end

  local property = filters.property
  local operator = filters.operator or "eq"
  local value = filters.value
  local comparator = filters.comparator

  if not property then
    return true
  end

  local row_value = row[property]

  if operator == "is_empty" then
    return row_value == nil or row_value == "" or (type(row_value) == "table" and next(row_value) == nil)
  elseif operator == "is_not_empty" then
    return row_value ~= nil and row_value ~= "" and not (type(row_value) == "table" and next(row_value) == nil)
  end

  if row_value == nil then
    return false
  end

  if comparator == "string" then
    row_value = tostring(row_value)
    value = tostring(value)
  elseif comparator == "number" then
    row_value = tonumber(row_value) or 0
    value = tonumber(value) or 0
  elseif comparator == "date" then
    row_value = Query.parse_date(row_value)
    value = Query.parse_date(value)
    if not row_value or not value then
      return false
    end
  end

  if operator == "eq" then
    return row_value == value
  elseif operator == "neq" then
    return row_value ~= value
  elseif operator == "gt" then
    return row_value > value
  elseif operator == "gte" then
    return row_value >= value
  elseif operator == "lt" then
    return row_value < value
  elseif operator == "lte" then
    return row_value <= value
  elseif operator == "contains" then
    if type(row_value) == "table" then
      return vim.tbl_contains(row_value, value)
    end
    return tostring(row_value):find(tostring(value), 1, true) ~= nil
  elseif operator == "does_not_contain" then
    if type(row_value) == "table" then
      return not vim.tbl_contains(row_value, value)
    end
    return tostring(row_value):find(tostring(value), 1, true) == nil
  elseif operator == "starts_with" then
    return tostring(row_value):find("^" .. vim.pesc(tostring(value))) ~= nil
  elseif operator == "ends_with" then
    return tostring(row_value):find(vim.pesc(tostring(value)) .. "$") ~= nil
  elseif operator == "in" then
    if type(value) == "table" then
      return vim.tbl_contains(value, row_value)
    end
    return false
  elseif operator == "not_in" then
    if type(value) == "table" then
      return not vim.tbl_contains(value, row_value)
    end
    return true
  elseif operator == "before" then
    return row_value < value
  elseif operator == "after" then
    return row_value > value
  elseif operator == "on_or_before" then
    return row_value <= value
  elseif operator == "on_or_after" then
    return row_value >= value
  end

  return false
end

Query.sort = function(rows, sorts)
  if not sorts or #sorts == 0 then
    return rows
  end

  local sorted = vim.deepcopy(rows)
  table.sort(sorted, function(a, b)
    for _, s in ipairs(sorts) do
      local prop = s.property
      local dir = s.direction or "ascending"
      local comparator = s.comparator or "string"

      local va, vb = a[prop], b[prop]
      if va == nil then
        va = dir == "ascending" and "" or 0
      end
      if vb == nil then
        vb = dir == "ascending" and "" or 0
      end

      if comparator == "number" then
        va = tonumber(va) or 0
        vb = tonumber(vb) or 0
      end

      if va ~= vb then
        if dir == "ascending" then
          return va < vb
        else
          return va > vb
        end
      end
    end
    return false
  end)

  return sorted
end

Query.group = function(rows, property)
  if not property then
    return { ["No Group"] = rows }
  end

  local groups = {}
  for _, row in ipairs(rows) do
    local val = row[property]
    if type(val) == "table" then
      for _, v in ipairs(val) do
        local group_key = tostring(v)
        groups[group_key] = groups[group_key] or {}
        table.insert(groups[group_key], row)
      end
    else
      local group_key = tostring(val or "")
      if group_key == "" then
        group_key = "No " .. property
      end
      groups[group_key] = groups[group_key] or {}
      table.insert(groups[group_key], row)
    end
  end

  return groups
end

Query.parse_date = function(date_str)
  if type(date_str) ~= "string" then
    return nil
  end
  local year, month, day = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
  if year and month and day then
    return os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) })
  end
  return nil
end

Query.sum = function(rows, property)
  local total = 0
  for _, row in ipairs(rows) do
    local val = tonumber(row[property])
    if val then
      total = total + val
    end
  end
  return total
end

Query.count = function(rows, property)
  if property then
    local count = 0
    for _, row in ipairs(rows) do
      if row[property] ~= nil and row[property] ~= "" then
        count = count + 1
      end
    end
    return count
  end
  return #rows
end

Query.average = function(rows, property)
  local total, count = 0, 0
  for _, row in ipairs(rows) do
    local val = tonumber(row[property])
    if val then
      total = total + val
      count = count + 1
    end
  end
  if count == 0 then
    return 0
  end
  return total / count
end

Query.min = function(rows, property)
  local min_val = nil
  for _, row in ipairs(rows) do
    local val = tonumber(row[property])
    if val and (min_val == nil or val < min_val) then
      min_val = val
    end
  end
  return min_val
end

Query.max = function(rows, property)
  local max_val = nil
  for _, row in ipairs(rows) do
    local val = tonumber(row[property])
    if val and (max_val == nil or val > max_val) then
      max_val = val
    end
  end
  return max_val
end

Query.aggregate = function(rows, property, fn_name)
  if fn_name == "sum" then
    return Query.sum(rows, property)
  elseif fn_name == "count" then
    return Query.count(rows, property)
  elseif fn_name == "average" or fn_name == "avg" then
    return Query.average(rows, property)
  elseif fn_name == "min" then
    return Query.min(rows, property)
  elseif fn_name == "max" then
    return Query.max(rows, property)
  end
  return nil
end

Query.rollup = function(rows, relation_property, target_property, fn_name)
  local vals = {}
  for _, row in ipairs(rows) do
    local rel = row[relation_property]
    if rel then
      if type(rel) == "table" then
        for _, r in ipairs(rel) do
          table.insert(vals, r[target_property])
        end
      elseif type(rel) == "string" then
        table.insert(vals, row[target_property])
      end
    end
  end
  return Query.aggregate(vals, target_property, fn_name)
end

return Query
