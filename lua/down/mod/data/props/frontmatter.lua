local Frontmatter = {}

Frontmatter.delimiter = "---"

Frontmatter.parse = function(lines, start_line)
  start_line = start_line or 1
  local in_frontmatter = false
  local fm_start = nil
  local fm_end = nil

  for i = start_line, #lines do
    local line = lines[i]
    if not in_frontmatter then
      if line:match("^%-%-%-%s*$") then
        in_frontmatter = true
        fm_start = i
      else
        return nil, nil
      end
    else
      if line:match("^%-%-%-%s*$") then
        fm_end = i
        break
      end
    end
  end

  if not fm_start or not fm_end then
    return nil, nil
  end

  local yaml_lines = {}
  for i = fm_start + 1, fm_end - 1 do
    table.insert(yaml_lines, lines[i])
  end

  local result = Frontmatter.parse_yaml(yaml_lines)
  return result, { start = fm_start, ["end"] = fm_end }
end

Frontmatter.parse_yaml = function(lines)
  if not lines or #lines == 0 then
    return {}
  end

  local result = {}
  local i = 1
  local context = { result }
  local context_keys = { nil }
  local context_indent = { -1 }
  local current_list_key = nil
  local current_list = nil
  local multiline_key = nil
  local multiline_lines = {}
  local multiline_indent = nil

  while i <= #lines do
    local line = lines[i]
    local stripped = line:gsub("^%s+", "")
    local indent = #line - #stripped

    if multiline_key then
      if indent > multiline_indent and stripped ~= "" then
        table.insert(multiline_lines, stripped)
      else
        local merged = table.concat(multiline_lines, "\n")
        Frontmatter.set_scalar(context[#context], multiline_key, merged)
        multiline_key = nil
        multiline_lines = {}
        multiline_indent = nil
      end
    end

    if multiline_key then
      i = i + 1
    elseif stripped == "" or stripped:match("^#") then
      i = i + 1
    else
      if stripped:match("^%-%s") then
        local value = stripped:match("^%-%s+(.*)")
        if value == "" then
          value = nil
        end

        if current_list_key then
          if not current_list then
            current_list = {}
            Frontmatter.set_scalar(context[#context], current_list_key, current_list)
          end
          if value then
            table.insert(current_list, Frontmatter.coerce_value(value))
          else
            local sub_obj = {}
            table.insert(current_list, sub_obj)
            table.insert(context, sub_obj)
            table.insert(context_keys, nil)
            table.insert(context_indent, indent)
          end
        else
          if value then
            table.insert(result, Frontmatter.coerce_value(value))
          end
        end
        i = i + 1
      else
        local key, value = stripped:match("^([%w_%-]+)%s*:%s*(.*)")
        if key then
          if indent <= context_indent[#context] then
            while #context > 1 and indent <= context_indent[#context] do
              table.remove(context)
              table.remove(context_keys)
              table.remove(context_indent)
            end
            current_list_key = nil
            current_list = nil
          end

          value = value:gsub("^%s+", ""):gsub("%s+$", "")

          if value == "|" or value == ">" then
            multiline_key = key
            multiline_lines = {}
            multiline_indent = indent
          elseif value == "" or value == "~" then
            local parent = context[#context]
            table.insert(context, {})
            table.insert(context_keys, key)
            table.insert(context_indent, indent)
            parent[key] = context[#context]

            current_list_key = nil
            current_list = nil
          else
            local parent = context[#context]
            if indent > context_indent[#context] and context[#context - 1] then
              local parent_key = context_keys[#context]
              if parent_key then
                if value:match("^%-%s") then
                  if not parent[parent_key] then
                    parent[parent_key] = {}
                  end
                  local list_val = value:match("^%-%s+(.*)")
                  table.insert(parent[parent_key], Frontmatter.coerce_value(list_val))
                else
                  Frontmatter.set_scalar(parent, parent_key, Frontmatter.coerce_value(value))
                end
                current_list_key = nil
                current_list = nil
              end
            else
              if value:match("^%-%s") then
                local list_val = value:match("^%-%s+(.*)")
                parent[key] = parent[key] or {}
                table.insert(parent[key], Frontmatter.coerce_value(list_val))
                current_list_key = key
                current_list = parent[key]
              else
                Frontmatter.set_scalar(parent, key, Frontmatter.coerce_value(value))
                current_list_key = nil
                current_list = nil
              end
            end
          end
        end
        i = i + 1
      end
    end
  end

  if multiline_key then
    local merged = table.concat(multiline_lines, "\n")
    Frontmatter.set_scalar(context[#context], multiline_key, merged)
  end

  return result
end

Frontmatter.set_scalar = function(tbl, key, value)
  if value == "true" then
    tbl[key] = true
  elseif value == "false" then
    tbl[key] = false
  elseif value == "null" or value == "~" then
    tbl[key] = nil
  elseif value:match("^'(.+)'$") or value:match('^"(.+)"$') then
    tbl[key] = value:sub(2, -2)
  else
    tbl[key] = value
  end
end

Frontmatter.coerce_value = function(value)
  if not value then
    return nil
  end
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  if value == "true" then
    return true
  elseif value == "false" then
    return false
  elseif value == "null" or value == "~" then
    return nil
  elseif value:match("^'(.+)'$") or value:match('^"(.+)"$') then
    return value:sub(2, -2)
  elseif tonumber(value) then
    return tonumber(value)
  end
  return value
end

Frontmatter.write = function(data, indent)
  indent = indent or 0
  local lines = {}
  table.insert(lines, "---")

  local function write_value(key, value, depth)
    local prefix = string.rep("  ", depth)
    if type(value) == "table" then
      local is_array = true
      local count = 0
      for _ in pairs(value) do
        count = count + 1
        if type(_) ~= "number" then
          is_array = false
        end
      end

      if is_array and count > 0 then
        if key then
          table.insert(lines, prefix .. key .. ":")
        end
        for _, item in ipairs(value) do
          if type(item) == "table" then
            table.insert(lines, prefix .. "  -")
            write_value(nil, item, depth + 2)
          else
            local item_str = Frontmatter.value_to_yaml(item)
            table.insert(lines, prefix .. "  - " .. item_str)
          end
        end
      elseif count > 0 then
        if key then
          table.insert(lines, prefix .. key .. ":")
        end
        for k, v in pairs(value) do
          if type(v) == "table" then
            write_value(k, v, depth + 1)
          else
            table.insert(lines, prefix .. "  " .. k .. ": " .. Frontmatter.value_to_yaml(v))
          end
        end
      elseif key then
        table.insert(lines, prefix .. key .. ":")
      end
    else
      local v_str = Frontmatter.value_to_yaml(value)
      if key then
        table.insert(lines, prefix .. key .. ": " .. v_str)
      end
    end
  end

  for k, v in pairs(data) do
    write_value(k, v, 0)
  end

  table.insert(lines, "---")
  return lines
end

Frontmatter.value_to_yaml = function(value)
  if value == nil then
    return "null"
  elseif type(value) == "boolean" then
    return value and "true" or "false"
  elseif type(value) == "number" then
    return tostring(value)
  elseif type(value) == "string" then
    if value:match("[%:%{%}%[%],%#&%*%!%|%>%<%s\"']") or value == "" then
      return '"' .. value:gsub('"', '\\"') .. '"'
    end
    return value
  end
  return tostring(value)
end

Frontmatter.get_buffer_frontmatter = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  if #lines == 0 then
    return nil, nil
  end

  local first_line = lines[1]:gsub("%s+$", "")
  if first_line ~= "---" then
    return nil, nil
  end

  return Frontmatter.parse(lines, 1)
end

Frontmatter.set_buffer_frontmatter = function(bufnr, data)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local _, pos = Frontmatter.parse(lines, 1)

  local new_lines = Frontmatter.write(data)

  if pos then
    vim.api.nvim_buf_set_lines(bufnr, pos.start - 1, pos["end"], false, new_lines)
  elseif #lines > 0 and lines[1]:gsub("%s+$", "") == "---" then
    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, new_lines)
  else
    table.insert(new_lines, "")
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, new_lines)
  end
end

Frontmatter.update_property = function(bufnr, key, value)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local data, _ = Frontmatter.get_buffer_frontmatter(bufnr)
  if not data then
    data = {}
  end
  if value == nil then
    data[key] = nil
  else
    data[key] = value
  end
  Frontmatter.set_buffer_frontmatter(bufnr, data)
end

Frontmatter.get_property = function(bufnr, key)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local data, _ = Frontmatter.get_buffer_frontmatter(bufnr)
  if not data then
    return nil
  end
  return data[key]
end

return Frontmatter
