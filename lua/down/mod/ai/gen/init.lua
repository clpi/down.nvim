--- ai.gen - AI content generation
--- Provides generation capabilities: summarize, expand, explain,
--- rewrite, translate, and template-based generation.

local Ai = require ("down.mod.ai")
local mod = require ("down.mod")
local log = require ("down.log")

---@class down.mod.ai.gen.Gen: down.Mod
local Gen = mod.new ("ai.gen")
Gen.dep = { "ai", "cmd", "workspace" }

Gen.config = {
  --- System prompts for each generation mode
  prompts = {
    summarize = "Summarize the following text concisely. Focus on key points and main ideas.",
    expand = "Expand the following text with more detail, examples, and explanation. Maintain the original tone.",
    explain = "Explain the following text clearly and simply, as if teaching a beginner. Break down complex concepts.",
    rewrite = "Rewrite the following text to be clearer and more concise. Fix any grammar issues.",
    formalize = "Rewrite the following text in a more formal, professional tone.",
    simplify = "Rewrite the following text to be simpler and easier to understand.",
    bullets = "Convert the following text into a well-organized bullet-point list.",
    outline = "Create a structured outline from the following content.",
    title = "Generate a concise, descriptive title for the following content. Output only the title, nothing else.",
    tags = "Extract 3-7 relevant tags from the following content. Output only the tags separated by commas.",
    code = "Generate code based on the following description. Include comments.",
    fix = "Fix any issues in the following text. Correct grammar, spelling, and formatting.",
  },
}

Gen.setup = function ()
  return { loaded = true }
end

--- Generate text based on a mode and input
---@param mode string The generation mode
---@param text string The input text
---@param opts? { instruction?: string, temperature?: number }
---@return string|nil, string|nil
function Gen.generate (mode, text, opts)
  opts = opts or {}
  local prompt = Gen.config.prompts[mode]
  if not prompt then
    if opts.instruction then
      prompt = opts.instruction
    else
      return nil, "unknown mode: " .. mode
    end
  end

  local messages = {
    { role = "system", content = prompt },
    { role = "user", content = text },
  }

  return Ai.complete (messages, { temperature = opts.temperature or 0.5 })
end

--- Generate from the current visual selection
---@param mode string
---@param opts? table
function Gen.generate_selection (mode, opts)
  local start_pos = vim.fn.getpos ("'<")
  local end_pos = vim.fn.getpos ("'>")
  local lines = vim.api.nvim_buf_get_lines (0, start_pos[2] - 1, end_pos[2], false)

  if #lines == 0 then
    vim.notify ("Gen: no text selected", vim.log.levels.WARN)
    return
  end

  -- Handle partial lines
  if #lines == 1 then
    local start_col = start_pos[3]
    local end_col = end_pos[3]
    lines[1] = lines[1]:sub (start_col, end_col)
  else
    lines[1] = lines[1]:sub (start_pos[3])
    lines[#lines] = lines[#lines]:sub (1, end_pos[3])
  end

  local text = table.concat (lines, "\n")
  if text:match ("^%s*$") then
    vim.notify ("Gen: selection is empty", vim.log.levels.WARN)
    return
  end

  vim.notify ("Gen: generating " .. mode .. "...", vim.log.levels.INFO)
  local result, err = Gen.generate (mode, text, opts)

  if not result then
    vim.notify ("Gen failed: " .. (err or "unknown"), vim.log.levels.ERROR)
    return
  end

  -- Show result in a new buffer
  local buf = vim.api.nvim_create_buf (false, true)
  vim.api.nvim_buf_set_option (buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option (buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option (buf, "filetype", "markdown")

  local display_lines = { "# " .. mode:gsub ("^%l", string.upper), "" }
  for _, l in ipairs (vim.split (result, "\n")) do
    display_lines[#display_lines + 1] = l
  end
  vim.api.nvim_buf_set_lines (buf, 0, -1, false, display_lines)
  vim.api.nvim_buf_set_option (buf, "modified", false)

  vim.cmd ("vsplit")
  vim.api.nvim_win_set_buf (0, buf)
end

--- Replace the current selection with generated content
---@param mode string
---@param opts? table
function Gen.replace_selection (mode, opts)
  local start_pos = vim.fn.getpos ("'<")
  local end_pos = vim.fn.getpos ("'>")
  local lines = vim.api.nvim_buf_get_lines (0, start_pos[2] - 1, end_pos[2], false)

  if #lines == 0 then
    vim.notify ("Gen: no text selected", vim.log.levels.WARN)
    return
  end

  if #lines == 1 then
    lines[1] = lines[1]:sub (start_pos[3], end_pos[3])
  else
    lines[1] = lines[1]:sub (start_pos[3])
    lines[#lines] = lines[#lines]:sub (1, end_pos[3])
  end

  local text = table.concat (lines, "\n")
  if text:match ("^%s*$") then return end

  vim.notify ("Gen: generating " .. mode .. "...", vim.log.levels.INFO)
  local result, err = Gen.generate (mode, text, opts)

  if not result then
    vim.notify ("Gen failed: " .. (err or "unknown"), vim.log.levels.ERROR)
    return
  end

  local new_lines = vim.split (result, "\n")
  vim.api.nvim_buf_set_text (0, start_pos[2] - 1, start_pos[3] - 1, end_pos[2] - 1, end_pos[3], new_lines)
  vim.notify ("Gen: replaced with " .. mode .. "d text", vim.log.levels.INFO)
end

--- Generate from a prompt (free-form generation)
---@param instruction string
---@param opts? { temperature?: number }
---@return string|nil, string|nil
function Gen.prompt (instruction, opts)
  local messages = {
    { role = "system", content = "You are a helpful coding and writing assistant." },
    { role = "user", content = instruction },
  }
  return Ai.complete (messages, opts or {})
end

--- Insert generated content at cursor
---@param instruction string
---@param opts? table
function Gen.insert (instruction, opts)
  vim.notify ("Gen: generating...", vim.log.levels.INFO)
  local result, err = Gen.prompt (instruction, opts)
  if not result then
    vim.notify ("Gen failed: " .. (err or "unknown"), vim.log.levels.ERROR)
    return
  end
  local row, col = unpack (vim.api.nvim_win_get_cursor (0))
  local new_lines = vim.split (result, "\n")
  vim.api.nvim_buf_set_text (0, row - 1, col, row - 1, col, new_lines)
end

--- Command table: each mode gets its own :Down gen.<mode> command
Gen.commands = {
  gen = {
    enabled = true,
    args = 0,
    name = "gen",
    callback = function (_)
      vim.notify ("Gen: use :Down gen.<mode> (summarize, expand, explain, rewrite, etc.)", vim.log.levels.INFO)
    end,
    commands = {},
  },
}

-- Build commands for each mode
for mode, _ in pairs (Gen.config.prompts) do
  Gen.commands.gen.commands[mode] = {
    enabled = true,
    args = 0,
    name = "gen." .. mode,
    callback = function ()
      Gen.generate_selection (mode)
    end,
  }
end

-- Add replace variants
for mode, _ in pairs (Gen.config.prompts) do
  Gen.commands.gen.commands[mode .. "_replace"] = {
    enabled = true,
    args = 0,
    name = "gen." .. mode .. "_replace",
    callback = function ()
      Gen.replace_selection (mode)
    end,
  }
end

-- Add prompt command for free-form generation
Gen.commands.gen.commands.prompt = {
  enabled = true,
  args = 1,
  name = "gen.prompt",
  complete = function () return {} end,
  callback = function (e)
    local instruction = e.body and e.body[1] or ""
    if instruction == "" then
      vim.ui.input ({ prompt = "Gen prompt: " }, function (input)
        if input and input ~= "" then
          Gen.insert (input)
        end
      end)
    else
      Gen.insert (instruction)
    end
  end,
}

return Gen
