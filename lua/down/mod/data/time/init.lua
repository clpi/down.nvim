local util = require("down.util")
local mod = require("down.mod")

---@class down.mod.data.time.Time: down.Mod
local Time = mod.new("data.time")
Time.dep = { "cmd" }

--- Time zone list (used for timezone parsing)
local time_zones = {
  'ACDT', 'ACST', 'ACT', 'ACWST', 'ADT', 'AEDT', 'AEST', 'AET', 'AFT',
  'AKDT', 'AKST', 'ALMT', 'AMST', 'AMT', 'ANAT', 'AQTT', 'ART', 'AST', 'AWST',
  'AZOST', 'AZOT', 'AZT', 'BNT', 'BIOT', 'BIT', 'BOT', 'BRST', 'BRT', 'BST',
  'BTT', 'CAT', 'CCT', 'CDT', 'CEST', 'CET', 'CHADT', 'CHAST', 'CHOT', 'CHOST',
  'CHST', 'CHUT', 'CIST', 'CKT', 'CLST', 'CLT', 'COST', 'COT', 'CST', 'CT',
  'CVT', 'CWST', 'CXT', 'DAVT', 'DDUT', 'DFT', 'EASST', 'EAST', 'EAT', 'ECT',
  'EDT', 'EEST', 'EET', 'EGST', 'EGT', 'EST', 'ET', 'FET', 'FJT', 'FKST', 'FKT',
  'FNT', 'GALT', 'GAMT', 'GET', 'GFT', 'GILT', 'GIT', 'GMT', 'GST', 'GYT',
  'HDT', 'HAEC', 'HST', 'HKT', 'HMT', 'HOVST', 'HOVT', 'ICT', 'IDLW', 'IDT',
  'IOT', 'IRDT', 'IRKT', 'IRST', 'IST', 'JST', 'KALT', 'KGT', 'KOST', 'KRAT',
  'KST', 'LHST', 'LINT', 'MAGT', 'MART', 'MAWT', 'MDT', 'MET', 'MEST', 'MHT',
  'MIST', 'MIT', 'MMT', 'MSK', 'MST', 'MUT', 'MVT', 'MYT', 'NCT', 'NDT', 'NFT',
  'NOVT', 'NPT', 'NST', 'NT', 'NUT', 'NZDT', 'NZST', 'OMST', 'ORAT', 'PDT', 'PET',
  'PETT', 'PGT', 'PHOT', 'PHT', 'PHST', 'PKT', 'PMDT', 'PMST', 'PONT', 'PST', 'PWT',
  'PYST', 'PYT', 'RET', 'ROTT', 'SAKT', 'SAMT', 'SAST', 'SBT', 'SCT', 'SDT', 'SGT',
  'SLST', 'SRET', 'SRT', 'SST', 'SYOT', 'TAHT', 'THA', 'TFT', 'TJT', 'TKT', 'TLT',
  'TMT', 'TRT', 'TOT', 'TVT', 'ULAST', 'ULAT', 'UTC', 'UYST', 'UYT', 'UZT', 'VET',
  'VLAT', 'VOLT', 'VOST', 'VUT', 'WAKT', 'WAST', 'WAT', 'WEST', 'WET', 'WIB',
  'WIT', 'WITA', 'WGST', 'WGT', 'WST', 'YAKT', 'YEKT',
}

-- NOTE: Maybe encapsulate whole date parser in a single PEG grammar?
-- Use string matching for time pattern
local time_pattern = "(%d%d?):(%d%d)(%.%d%d?)?"

---@alias Date {weekday: {name: string, number: number}?, day: number?, month: {name: string, number: number}?, year: number?, timezone: string?, time: {hr: number, min: number, sec: number?}?}

Time.tostringable_date = function(datetb)
  return setmetatable(datetb, {
    __tostring = function()
      local function d(str)
        return str and (tostring(str) .. " ") or ""
      end

      return vim.trim(
        d(datetb.weekday and datetb.weekday.id)
        .. d(datetb.day)
        .. d(datetb.month and datetb.month.id)
        .. d(datetb.year and string.format("%04d", datetb.year))
        .. d(datetb.time and tostring(datetb.time))
        .. d(datetb.timezone)
      )
    end,
  })
end
--- Converts a parsed date with `parse_date` to a lua date.
---@param parsedt Date #The date to convert
---@return osdate #A Lua date
Time.to_lua_date = function(parsedt)
  local now = os.date("*t") --[[@as osdate]]
  local parsed = os.time(vim.tbl_deep_extend("force", now, {
    day = parsedt.day,
    month = parsedt.month and parsedt.month.number or nil,
    year = parsedt.year,
    hr = parsedt.time and parsedt.time.hr,
    min = parsedt.time and parsedt.time.min,
    sec = parsedt.time and parsedt.time.sec,
  }) --[[@as osdateparam]])
  return os.date("*t", parsed) --[[@as osdate]]
end

--- Converts a lua `osdate` to a down date.
---@param osdate osdate #The date to convert
---@param incltime boolean? #Whether to include the time (hh::mm.ss) in the output.
---@return Date #The converted date
Time.to_date = function(osdate, incltime)
  -- TODO: Extract into a function to get weekdays (have to hot recalculate every time because the user may change locale
  local weekdays = {}
  for i = 1, 7 do
    table.insert(
      weekdays,
      os.date("%A", os.time({ year = 2000, month = 5, day = i })):lower()
    ) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
  end

  local months = {}
  for i = 1, 12 do
    table.insert(
      months,
      os.date("%B", os.time({ year = 2000, month = i, day = 1 })):lower()
    ) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
  end

  -- os.date("*t") returns wday with Sunday as 1, needs to be
  -- converted to Monday as 1
  local converted_weekday = util.number_wrap(osdate.wday - 1, 1, 7)

  return Time.tostringable_date({
    weekday = osdate.wday and {
      number = converted_weekday,
      name = util.title(weekdays[converted_weekday]),
    } or nil,
    day = osdate.day,
    month = osdate.month and {
      number = osdate.month,
      name = util.title(months[osdate.month]),
    } or nil,
    year = osdate.year,
    time = osdate.hr and setmetatable({
      hr = osdate.hr,
      min = osdate.min or 0,
      sec = osdate.sec or 0,
    }, {
      __tostring = function()
        if not incltime then
          return ""
        end

        return tostring(osdate.hr)
            .. ":"
            .. tostring(string.format("%02d", osdate.min))
            .. (osdate.sec ~= 0 and ("." .. tostring(osdate.sec)) or "")
      end,
    }) or nil,
  })
end

--- Parses a date and returns a table representing the date
---@param input string #The input which should follow the date specification found in the down spec.
---@return Date|string #The data extracted from the input or an error message
Time.parse_date = function(input)
  local weekdays = {}
  for i = 1, 7 do
    table.insert(
      weekdays,
      os.date("%A", os.time({ year = 2000, month = 5, day = i })):lower()
    ) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
  end

  local months = {}
  for i = 1, 12 do
    table.insert(
      months,
      os.date("%B", os.time({ year = 2000, month = i, day = 1 })):lower()
    ) ---@diagnostic disable-line -- TODO: type error workaround <pysan3>
  end

  local output = {}

  for d in vim.gsplit(input, "%s+") do
    if d:len() == 0 then
      goto continue
    end

    if d:match("^-?%d%d%d%d+$") then
      output.year = tonumber(d)
    elseif d:match("^%d+%w*$") then
      output.day = tonumber(d:match("%d+"))
    else
      -- Check for time pattern hh:mm or hh:mm.ss
      local hr, min, sec = d:match("(%d%d?):(%d%d)(%.%d%d?)?")
      if hr and min then
        output.time = setmetatable({
          hr = tonumber(hr),
          min = tonumber(min),
          sec = sec and tonumber(sec:gsub("^%.", "")) or nil,
        }, {
          __tostring = function()
            return d
          end,
        })

        goto continue
      end
    end

    do

      do
        local valid_months = {}

        -- Check for month abbreviation
        for i, month in ipairs(months) do
          if vim.startswith(month, d:lower()) then
            valid_months[month] = i
          end
        end

        local count = vim.tbl_count(valid_months)
        if count > 1 then
          return "Ambiguous month name! Possible interpretations: "
              .. table.concat(vim.tbl_keys(valid_months), ",")
        elseif count == 1 then
          local valid_month_name, valid_month_number = next(valid_months)

          output.month = {
            name = util.title(valid_month_name),
            number = valid_month_number,
          }

          goto continue
        end
      end

      do
        local parsed_d = d:match("^([^,]+),?$")

        local valid_weekdays = {}

        -- Check for weekday abbreviation
        for i, weekday in ipairs(weekdays) do
          if vim.startswith(weekday, parsed_d:lower()) then
            valid_weekdays[weekday] = i
          end
        end

        local count = vim.tbl_count(valid_weekdays)
        if count > 1 then
          return "Ambiguous weekday name! Possible interpretations: "
              .. table.concat(vim.tbl_keys(valid_weekdays), ",")
        elseif count == 1 then
          local valid_weekday_name, valid_weekday_number = next(valid_weekdays)

          output.weekday = {
            name = util.title(valid_weekday_name),
            number = valid_weekday_number,
          }

          goto continue
        end
      end

      return "Unidentified string: `"
          .. d
          .. "` - make sure your locale and language are set correctly if you are using a language other than English!"
    end

    ::continue::
  end

  return Time.tostringable_date(output)
end

Time.insert_date = function(ins)
  local function cb(input)
    if input == "" or not input then
      return
    end

    local output

    if type(input) == "table" then
      output = tostring(Time.to_date(input))
    else
      output = Time.parse_date(input)

      if type(output) == "string" then
        util.notify(output, vim.log.levels.ERROR)

        vim.ui.input({
          prompt = "Date: ",
          default = input,
        }, cb)

        return
      end

      output = tostring(output)
    end

    vim.api.nvim_put({ "{@ " .. output .. "}" }, "c", false, true)

    if ins then
      vim.cmd.startinsert()
    end
  end

  if mod.is_loaded("ui.calendar") then
    vim.cmd.stopinsert()
    mod.get_mod("ui.calendar").select({ cb = vim.schedule_wrap(cb) })
  else
    vim.ui.input({
      prompt = "Date: ",
    }, cb)
  end
end

Time.maps = {
  {
    "i",
    "<Plug>(down.time.insert-date)",
    util.wrap(Time.insert_date, true),
    "Insert date",
  },
  {
    "i",
    "<Plug>(down.time.insert-date.insert-mode)",
    util.wrap(Time.insert_date, false),
    "Insert date",
  },
}

function Time.setup()
  return {
    loaded = true,
  }
end

return Time
