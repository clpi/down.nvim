--- template - Template management with variable expansion.
--- Creates, lists, applies, and manages markdown templates
--- stored in .down/templates/ (and note/ for compatibility).

local log = require ("down.log")
local mod = require ("down.mod")

local Template = mod.new ("template")
Template.dep = { "cmd", "workspace", "note" }

Template.config = {
  --- Directories searched for templates (relative to workspace root)
  dirs = { ".down/templates", "templates", "note" },
  --- Whether to apply templates when creating new notes
  apply_on_note = true,
  --- Default template name for daily notes
  day = "daily",
  --- Default template name for meetings
  meeting = "meeting",
  --- Default template name for projects
  project = "project",
}

-- Standard variable expansions (mirrors Go engine).
local vars = {
  date = function ()
    return os.date ("%Y-%m-%d")
  end,
  time = function ()
    return os.date ("%H:%M:%S")
  end,
  datetime = function ()
    return os.date ("%Y-%m-%d %H:%M:%S")
  end,
  year = function ()
    return os.date ("%Y")
  end,
  month = function ()
    return os.date ("%m")
  end,
  day = function ()
    return os.date ("%d")
  end,
  weekday = function ()
    return os.date ("%A")
  end,
  timestamp = function ()
    return tostring (os.time ())
  end,
}

--- Find all template directories in the workspace.
---@return string[]
function Template.dirs ()
  local ws = Template.dep["workspace"]
  local root = ws and ws.root and ws.root ()
  if not root then
    return {}
  end
  local result = {}
  for _, d in ipairs (Template.config.dirs) do
    local full = root .. "/" .. d
    if vim.fn.isdirectory (full) == 1 then
      result[#result + 1] = full
    end
  end
  return result
end

--- List all available templates with metadata.
---@return { name: string, path: string, type: string, category: string, description: string }[]
function Template.list ()
  local tmpls = {}
  local seen = {}
  for _, dir in ipairs (Template.dirs ()) do
    for name, kind in vim.fs.dir (dir) do
      if kind == "file" and name:match ("%.md$") then
        local base = name:gsub ("%.md$", "")
        if not seen[base] then
          seen[base] = true
          local path = dir .. "/" .. name
          local t = Template.load_meta (path, base)
          t.source = dir
          tmpls[#tmpls + 1] = t
        end
      end
    end
  end
  table.sort (tmpls, function (a, b)
    return a.name < b.name
  end)
  return tmpls
end

--- Load template metadata from frontmatter.
---@param path string
---@param name string
---@return table
function Template.load_meta (path, name)
  local t = {
    name = name,
    path = path,
    type = "note",
    description = "",
    category = "",
    variables = {},
  }
  local f = io.open (path, "r")
  if not f then
    return t
  end
  local first = f:read ("*l")
  if not first or first:match ("^%s*$") or first ~= "---" then
    f:close ()
    return t
  end
  for line in f:lines () do
    if line:match ("^%s*$") or line == "---" then
      break
    end
    local key, val = line:match ("^([%w_]+)%s*:%s*(.+)")
    if key then
      val = val:gsub ("^%s+", ""):gsub ("%s+$", "")
      if key == "type" then
        t.type = val
      elseif key == "category" then
        t.category = val
      elseif key == "description" then
        t.description = val
      elseif key == "variables" then
        for v in val:gmatch ("[^,]+") do
          t.variables[#t.variables + 1] = v:match ("^%s*(.-)%s*$")
        end
      end
    end
  end
  f:close ()
  return t
end

--- Load the full content of a template.
---@param name string
---@return string|nil
function Template.load_content (name)
  for _, dir in ipairs (Template.dirs ()) do
    local path = dir .. "/" .. name .. ".md"
    local f = io.open (path, "r")
    if f then
      local content = f:read ("*a")
      f:close ()
      return content
    end
  end
  return nil
end

--- Expand template variables in content.
---@param content string
---@param extra? table<string, string>
---@return string
function Template.expand (content, extra)
  for var, fn in pairs (vars) do
    local placeholder = "{{" .. var .. "}}"
    if content:find (placeholder, 1, true) then
      content = content:gsub (placeholder, fn (), 1)
    end
  end
  if extra then
    for var, val in pairs (extra) do
      local placeholder = "{{" .. var .. "}}"
      content = content:gsub (placeholder, val, 1)
    end
  end
  return content
end

--- Apply a template by name, returning expanded content.
---@param name string
---@param extra? table<string, string>
---@return string|nil
function Template.apply (name, extra)
  local content = Template.load_content (name)
  if not content then
    -- Try built-in templates
    content = Template.builtin (name)
  end
  if not content then
    return nil
  end
  return Template.expand (content, extra)
end

--- Built-in templates (mirrors Go builtins).
---@param name string
---@return string|nil
function Template.builtin (name)
  local builtins = {
    daily = "# {{date}}\n\n## Morning\n\n## Work Log\n\n- \n\n## Evening\n\n## Gratitude\n\n- \n",
    meeting = "# Meeting: {{title}}\n\n**Date:** {{date}}\n**Time:** {{time}}\n**Attendees:** \n\n## Agenda\n\n- \n\n## Notes\n\n## Action Items\n\n- [ ] \n",
    project = "# Project: {{title}}\n\n**Status:** in-progress\n**Start:** {{date}}\n**Target:** \n\n## Goals\n\n- \n\n## Timeline\n\n| Phase | Status | Date |\n|-------|--------|------|\n| Planning | done | |\n| Execution | in-progress | |\n| Review | pending | |\n\n## Notes\n",
    note = "# {{title}}\n\n**Date:** {{date}}\n**Tags:** \n\n",
    weekly = "# Week {{week}}\n\n**{{date}}**\n\n## Highlights\n\n- \n\n## Monday\n## Tuesday\n## Wednesday\n## Thursday\n## Friday\n\n## Next Week\n",
    monthly = "# {{month}} {{year}} Review\n\n## Highlights\n\n- \n\n## By Week\n\n### Week 1\n### Week 2\n### Week 3\n### Week 4\n\n## Stats\n",
  }
  return builtins[name]
end

--- Create a new template file in the first template directory.
---@param name string
---@param type string
---@param description string
---@return string|nil
function Template.create (name, tp, description)
  tp = tp or "note"
  description = description or ""
  local dirs = Template.dirs ()
  if #dirs == 0 then
    vim.notify ("Template: no template directories found", vim.log.levels.WARN)
    return nil
  end
  local dir = dirs[1]
  if vim.fn.isdirectory (dir) == 0 then
    vim.fn.mkdir (dir, "p")
  end
  local path = dir .. "/" .. name .. ".md"
  local content = "---\ntype: "
    .. tp
    .. "\ndescription: "
    .. description
    .. "\n---\n\n# {{title}}\n\n"
  local f = io.open (path, "w")
  if f then
    f:write (content)
    f:close ()
    return path
  end
  return nil
end

--- Delete a template by name.
---@param name string
---@return boolean
function Template.delete (name)
  for _, dir in ipairs (Template.dirs ()) do
    local path = dir .. "/" .. name .. ".md"
    if os.remove (path) then
      return true
    end
  end
  return false
end

--- Apply a template to the current buffer or a new buffer.
---@param name string
---@param extra? table<string, string>
function Template.apply_to_buf (name, extra)
  local content = Template.apply (name, extra)
  if not content then
    vim.notify ("Template not found: " .. name, vim.log.levels.WARN)
    return
  end
  local buf = vim.api.nvim_create_buf (true, true)
  local lines = vim.split (content, "\n")
  vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
  vim.api.nvim_set_current_buf (buf)
  vim.bo[buf].filetype = "markdown"
end

Template.setup = function ()
  return { loaded = true }
end

Template.commands = {
  template = {
    enabled = true,
    args = 0,
    name = "template",
    callback = function (_)
      local tmpls = Template.list ()
      vim.notify (
        "Template: " .. #tmpls .. " templates available",
        vim.log.levels.INFO
      )
    end,
    commands = {
      list = {
        enabled = true,
        args = 0,
        name = "template.list",
        callback = function ()
          local tmpls = Template.list ()
          if #tmpls == 0 then
            vim.notify ("No templates found", vim.log.levels.INFO)
            return
          end
          local buf = vim.api.nvim_create_buf (false, true)
          vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
          vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
          local lines = { "# Templates (" .. #tmpls .. ")", "" }
          for _, t in ipairs (tmpls) do
            local kind = t.type
            if t.category ~= "" then
              kind = kind .. "/" .. t.category
            end
            lines[#lines + 1] = "## " .. t.name .. " (" .. kind .. ")"
            if t.description ~= "" then
              lines[#lines + 1] = t.description
            end
            lines[#lines + 1] = ""
          end
          vim.api.nvim_buf_set_lines (buf, 0, -1, false, lines)
          vim.api.nvim_set_current_buf (buf)
          vim.bo[buf].filetype = "markdown"
        end,
      },
      apply = {
        enabled = true,
        args = 1,
        min_args = 1,
        max_args = 2,
        name = "template.apply",
        complete = function ()
          local names = {}
          for _, t in ipairs (Template.list ()) do
            names[#names + 1] = t.name
          end
          return names
        end,
        callback = function (e)
          local name = e.body and e.body[1]
          local title = e.body and e.body[2]
          if not name then
            local tmpls = Template.list ()
            if #tmpls == 0 then
              vim.notify ("No templates available", vim.log.levels.WARN)
              return
            end
            local items = {}
            for _, t in ipairs (tmpls) do
              items[#items + 1] = t.name
                .. " ("
                .. (t.description or t.type)
                .. ")"
            end
            vim.ui.select (items, { prompt = "Template:" }, function (choice)
              if choice then
                local nm = choice:match ("^([%w_%-]+)")
                if nm then
                  vim.ui.input ({ prompt = "Title: " }, function (title)
                    Template.apply_to_buf (nm, { title = title or nm })
                  end)
                end
              end
            end)
            return
          end
          Template.apply_to_buf (name, { title = title or name })
        end,
      },
      create = {
        enabled = true,
        args = 1,
        min_args = 1,
        max_args = 3,
        name = "template.create",
        callback = function (e)
          local name = e.body and e.body[1]
          if not name then
            vim.ui.input ({ prompt = "Template name: " }, function (n)
              if n and n ~= "" then
                vim.ui.select (
                  { "note", "daily", "meeting", "project", "weekly", "monthly" },
                  { prompt = "Type:" },
                  function (tp)
                    if tp then
                      vim.ui.input ({ prompt = "Description: " }, function (desc)
                        local path = Template.create (n, tp, desc or "")
                        if path then
                          vim.notify ("Created: " .. path, vim.log.levels.INFO)
                          vim.cmd ("edit " .. path)
                        end
                      end)
                    end
                  end
                )
              end
            end)
            return
          end
          local path =
            Template.create (name, e.body[2] or "note", e.body[3] or "")
          if path then
            vim.notify ("Created: " .. path, vim.log.levels.INFO)
            vim.cmd ("edit " .. path)
          end
        end,
      },
      delete = {
        enabled = true,
        args = 1,
        min_args = 1,
        max_args = 1,
        name = "template.delete",
        complete = function ()
          local names = {}
          for _, t in ipairs (Template.list ()) do
            names[#names + 1] = t.name
          end
          return names
        end,
        callback = function (e)
          local name = e.body and e.body[1]
          if not name then
            return
          end
          if Template.delete (name) then
            vim.notify ("Deleted template: " .. name, vim.log.levels.INFO)
          else
            vim.notify ("Template not found: " .. name, vim.log.levels.WARN)
          end
        end,
      },
      init = {
        enabled = true,
        args = 0,
        name = "template.init",
        callback = function ()
          local dirs = Template.dirs ()
          if #dirs == 0 then
            local ws = Template.dep["workspace"]
            local root = ws and ws.root and ws.root ()
            if root then
              local dir = root .. "/.down/templates"
              vim.fn.mkdir (dir, "p")
              dirs = { dir }
            end
          end
          if #dirs == 0 then
            vim.notify ("Cannot find template directory", vim.log.levels.WARN)
            return
          end
          local defaults = {
            { "daily", "daily", "journal", "Daily journal entry" },
            { "meeting", "meeting", "work", "Meeting notes with agenda" },
            { "project", "project", "work", "Project overview with goals" },
            { "weekly", "weekly", "journal", "Weekly review and planning" },
            { "monthly", "monthly", "journal", "Monthly review" },
          }
          local dir = dirs[1]
          local created = 0
          for _, d in ipairs (defaults) do
            local path = dir .. "/" .. d[1] .. ".md"
            local f = io.open (path, "r")
            if f then
              f:close ()
            else
              Template.create (d[1], d[2], d[4])
              created = created + 1
            end
          end
          vim.notify (
            "Initialized " .. created .. " default templates",
            vim.log.levels.INFO
          )
        end,
      },
    },
  },
}

return Template
