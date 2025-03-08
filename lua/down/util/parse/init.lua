-- from copilot
-- task_parser.lua
local Parse = {}

-- Helper function to parse date, time, datetime, etc.
Parse.datetime = function(text)
  local patterns = {
    { pattern = "by (%d+/%d+/%d+ %d+:%d+)", type = "datetime" },
    { pattern = "by (%d+/%d+/%d+)",         type = "date" },
    { pattern = "by (%d+:%d+)",             type = "time" },
    { pattern = "at (%d+/%d+/%d+ %d+:%d+)", type = "datetime" },
    { pattern = "at (%d+/%d+/%d+)",         type = "date" },
    { pattern = "at (%d+:%d+)",             type = "time" },
    { pattern = "tomorrow (%a+)",           type = "relative_time" },
    { pattern = "next (%a+)",               type = "relative_time" },
    { pattern = "in (%d+) (hours?)",        type = "duration" },
    { pattern = "in (%d+) (minutes?)",      type = "duration" },
    { pattern = "in (%d+) (seconds?)",      type = "duration" },
    { pattern = "in (%d+) (days?)",         type = "duration" },
    { pattern = "in (%d+) (weeks?)",        type = "duration" },
    { pattern = "in (%d+) (months?)",       type = "duration" },
    { pattern = "in (%d+) (years?)",        type = "duration" },
  }

  for _, p in ipairs(patterns) do
    local match = { text:match(p.pattern) }
    if #match > 0 then
      return { type = p.id, value = table.concat(match, " ") }
    end
  end

  return nil
end

-- Main function to parse task items
function Parse.task(item)
  local result = {}
  local datetime_info = Parse.datetime(item)
  if datetime_info then
    result.datetime = datetime_info
  end
  return result
end

local lpeg = vim.lpeg
local P, R, S, C, Ct, Cg = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cg

local digit = R("09")
local alpha = R("az", "AZ")
local space = S(" \t") ^ 0
local sep = S("/-")
local colon = P(":")
local time_unit = P("hours") + P("minutes") + P("seconds") + P("days") + P("weeks") + P("months") + P("years")
local day_part = P("morning") + P("afternoon") + P("evening") + P("night")
local weekday = P("sunday") + P("monday") + P("tuesday") + P("wednesday") + P("thursday") + P("friday") + P("saturday")

-- Define complex patterns
local date = digit ^ 1 * sep * digit ^ 1 * sep * digit ^ 1
local time = digit ^ 1 * colon * digit ^ 1
local datetime = date * space * time
local duration = digit ^ 1 * space * time_unit

-- Define capture patterns
local by_pattern = P("by") * space * C(datetime + date + time)
local at_pattern = P("at") * space * C(datetime + date + time)
local tomorrow_pattern = P("tomorrow") * space * C(day_part)
local next_pattern = P("next") * space * C(weekday)
local in_pattern = P("in") * space * C(duration)

-- Combine all patterns
local task_pattern = Ct(
  Cg(by_pattern, "by") +
  Cg(at_pattern, "at") +
  Cg(tomorrow_pattern, "tomorrow") +
  Cg(next_pattern, "next") +
  Cg(in_pattern, "in")
)

-- Main function to parse task items
function Parse.parsetask(item)
  local result = task_pattern:match(item)
  return result or {}
end

return Parse
