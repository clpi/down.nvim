local U = {}

local c, f, a, ts = vim.cmd, vim.fn, vim.api, vim.treesitter

---@return down.Os
U.os = function()
  return string.lower(require("ffi").os)
end

U.sep = U.os() == "windows" and "\\" or "/"

U.tobool = function(str)
  local bool = false
  str = (str:gsub(" ", ""))
  if str == "true" then
    bool = true
  end
  return bool
end
--- Works just like pcall, except returns only a single value or nil (useful for ternary operations
--- which are not possible with a function like `pcall` that returns two values).
--- @generic T
--- @param func fun(...: any): T The function to invoke in a protected environment.
--- @param ... any The parameters to pass to `func`.
--- @return T? # The return value of the executed function or `nil`.
function U.inline_pcall(func, ...)
  local ok, ret = pcall(func, ...)

  if ok then
    return ret
  end

  -- return nil
end
U.version = vim.version() -- TODO: Move to a more local scope

--- A version agnostic way to call the neovim treesitter query parser
--- @param language string # Language to use for the query
--- @param query_string string # Query in s-expr syntax
--- @return ts.Query # Parsed query
function U.ts_parse_query(language, query_string)
  if ts.query.parse then
    return ts.query.parse(language, query_string)
  else
    ---@diagnostic disable-next-line
    return ts.parse_query(language, query_string)
  end
end

--- An OS agnostic way of querying the current user
--- @return string username
function U.get_username()
  local current_os = U.os()
  if not current_os then
    return ""
  end

  if current_os == "linux" or current_os == "mac" or current_os == "wsl" then
    return os.getenv("USER") or ""
  elseif current_os == "windows" then
    return os.getenv("username") or ""
  end

  return ""
end

function U.extend(t1, t2)
  return vim.tbl_deep_extend("force", t1, t2)
end

function U.dext(t1, t2)
  return vim.tbl_deep_extend("force", t1, t2)
end

function U.ext(t1, t2)
  return vim.tbl_extend("force", t1, t2)
end

--- Returns an array of strings, the array being a list of languages that down can inject.
---@param values boolean If set to true will return an array of strings, if false will return a key-value table.
---@return string[]|table<string, { type: "integration.treesitter"  |"syntax"|"null" }>
function U.get_language_list(values)
  local regex_files = {}
  local ts_files = {}

  -- Search for regex files in syntax and after/syntax.
  -- Its best if we strip out anything but the ft name.
  for _, lang in pairs(a.nvim_get_runtime_file("syntax/*.vim", true)) do
    local lang_name = f.fnamemodify(lang, ":t:r")
    table.insert(regex_files, lang_name)
  end

  for _, lang in pairs(a.nvim_get_runtime_file("after/syntax/*.vim", true)) do
    local lang_name = f.fnamemodify(lang, ":t:r")
    table.insert(regex_files, lang_name)
  end

  -- Search for available parsers
  for _, parser in pairs(a.nvim_get_runtime_file("parser/*.so", true)) do
    local parser_name = assert(f.fnamemodify(parser, ":t:r"))
    ts_files[parser_name] = true
  end

  local ret = {}

  for _, syntax in pairs(regex_files) do
    if ts_files[syntax] then
      ret[syntax] = { type = "integration.treesitter" }
    else
      ret[syntax] = { type = "syntax" }
    end
  end

  return values and vim.tbl_keys(ret) or ret
end

--- Gets a list of shorthands for a given language.
--- @param reverse_lookup boolean Whether to create a reverse lookup for the table.
--- @return LanguageList
function U.get_language_shorthands(reverse_lookup)
  ---@class LanguageList
  local langs = {
    ["bash"] = { "sh", "zsh" },
    ["c_sharp"] = { "csharp", "cs" },
    ["clojure"] = { "clj" },
    ["cmake"] = { "cmake.in" },
    ["commonlisp"] = { "cl" },
    ["cpp"] = { "hpp", "cc", "hh", "c++", "h++", "cxx", "hxx" },
    ["dockerfile"] = { "docker" },
    ["erlang"] = { "erl" },
    ["fennel"] = { "fnl" },
    ["fortran"] = { "f90", "f95" },
    ["go"] = { "golang" },
    ["godot"] = { "gdscript" },
    ["gomod"] = { "gm" },
    ["haskell"] = { "hs" },
    ["java"] = { "jsp" },
    ["javascript"] = { "js", "jsx" },
    ["julia"] = { "julia-repl" },
    ["kotlin"] = { "kt" },
    ["python"] = { "py", "gyp" },
    ["ruby"] = { "rb", "gemspec", "podspec", "thor", "irb" },
    ["rust"] = { "rs" },
    ["supercollider"] = { "sc" },
    ["typescript"] = { "ts" },
    ["verilog"] = { "v" },
    ["yaml"] = { "yml" },
  }

  -- TODO: `vim.tbl_add_reverse_lookup` deprecated: NO ALTERNATIVES
  -- GOOD JOB base DEVS
  -- <https://github.com/neovim/neovim/pull/27639>
  return reverse_lookup and vim.tbl_add_reverse_lookup(langs) or langs ---@diagnostic disable-line
end

--- Checks whether Neovim is running at least at a specific version.
--- @param major number The major release of Neovim.
--- @param minor number The minor release of Neovim.
--- @param patch number The patch number (in case you need it).
--- @return boolean # Whether Neovim is running at the same or a higher version than the one given.
function U.is_minimum_version(major, minor, patch)
  if major ~= version.major then
    return major < version.major
  end
  if minor ~= version.minor then
    return minor < version.minor
  end
  if patch ~= version.patch then
    return patch < version.patch
  end
  return true
end

--- Parses a version string like "0.4.2" and provides back a table like { major = <number>, minor = <number>, patch = <number> }
--- @param version_string string The input string.
--- @return table? # The parsed version string, or `nil` if a failure occurred during parsing.
function U.parse_version_string(version_string)
  if not version_string then
    return
  end

  -- Define variables that split the version up into 3 slices
  local split_version, versions, ret =
    vim.split(version_string, ".", { plain = true }),
    { "major", "minor", "patch" },
    { major = 0, minor = 0, patch = 0 }

  -- If the sliced version string has more than 3 elements error out
  if #split_version > 3 then
    log.warn(
      "Attempt to parse version:",
      version_string,
      "failed - too many version numbers provided. Version should follow this layout: <major>.<minor>.<patch>"
    )
    return
  end

  -- Loop through all the versions and check whether they are valid numbers. If they are, add them to the return table
  for i, ver in ipairs(versions) do
    if split_version[i] then
      local num = tonumber(split_version[i])

      if not num then
        log.warn(
          "Invalid version provided, string cannot be converted to integral type."
        )
        return
      end

      ret[ver] = num
    end
  end

  return ret
end
--- Capitalizes the first letter of each down in a given string.
--- @param str string The string to capitalize.
--- @return string # The capitalized string.
function U.title(str)
  local result = {}

  for w in str:gmatch("[^%s]+") do
    local lower = w:sub(2):lower()

    table.insert(result, w:sub(1, 1):upper() .. lower)
  end
  return table.concat(result, " ")
end

--- Lazily concatenates a string to prevent runtime errors where an object may not exist
--- Consider the following example:
---
---     lib.when(str ~= nil, str.." extra text", "")
---
--- This would fail, simply because the string concatenation will still be evaluated in order
--- to be placed inside the variable. You may use:
---
---     lib.when(str ~= nil, lib.lazy_string_concat(str, " extra text"), "")
---
--- To mitigate this issue directly.
--- @param ... string An unlimited number of strings.
--- @return string # The result of all the strings concatenated.
function U.lazy_string_concat(...)
  return table.concat({ ... })
end
--- Constructs a new key-pair table by running a callback on all elements of an array.
--- @param keys string[] A string array with the keys to iterate over.
--- @param cb fun(key: string): any? A function that gets invoked with each key and returns a value to be placed in the output table.
--- @return table # The newly constructed table.
function U.construct(keys, cb)
  local result = {}

  for _, key in ipairs(keys) do
    result[key] = cb(key)
  end

  return result
end

--- If `val` is a function, executes it with the desired arguments, else just returns `val`.
--- @param val function|any Either a function or any other value.
--- @param ... any Potential arguments to give `val` if it is a function.
--- @return any # The returned evaluation of `val`.
function U.eval(val, ...)
  if type(val) == "function" then
    return val(...)
  end

  return val
end
--- Wraps a number so that it fits within a given range.
--- @param value number The number to wrap.
--- @param min number The lower bound.
--- @param max number The higher bound.
--- @return number # The wrapped number, guarantees `min <= value <= max`.
function U.number_wrap(value, min, max)
  local range = max - min + 1
  local wrapped_value = ((value - min) % range) + min

  if wrapped_value < min then
    wrapped_value = wrapped_value + range
  end

  return wrapped_value
end

--- Returns the item that matches the first item in statements.
--- @param value any The value to compare against.
--- @param compare? fun(lhs: any, rhs: any): boolean A custom comparison function.
--- @return fun(statements: table<any, any>): any # A function to invoke with a table of potential matches.
function U.match(value, compare)
  -- Returning a function allows for such syntax:
  -- match(something) { ...atches...}
  return function(statements)
    if value == nil then
      return
    end

    -- Set the comparison function
    -- A comparison function may be dep for more complex
    -- data types that need to be compared against another static value.
    -- The default comparison function compares booleans as strings to ensure
    -- that boolean comparisons work as intended.
    compare = compare
      or function(lhs, rhs)
        if type(lhs) == "boolean" then
          return tostring(lhs) == rhs
        end

        return lhs == rhs
      end

    -- Go through every statement, compare it, and perform the desired action
    -- if the comparison was successful
    for case, action in pairs(statements) do
      -- If the case statement is a list of data then compare that
      if type(case) == "table" and vim.tbl_islist(case) then
        for _, subcase in ipairs(case) do
          if compare(value, subcase) then
            -- The action can be a function, in which case it is invoked
            -- and the return value of that function is returned instead.
            if type(action) == "function" then
              return action(value)
            end

            return action
          end
        end
      end

      if compare(value, case) then
        -- The action can be a function, in which case it is invoked
        -- and the return value of that function is returned instead.
        if type(action) == "function" then
          return action(value)
        end

        return action
      end
    end

    -- If we've fallen through all statements to check and haven't found
    -- a single match then see if we can fall back to a `_` clause instead.
    if statements._ then
      local action = statements._

      if type(action) == "function" then
        return action(value)
      end

      return action
    end
  end
end
--- Wrapped around `match()` that performs an action based on a condition.
--- @param comparison boolean The comparison to perform.
--- @param when_true function|any The value to return when `comparison` is true.
--- @param when_false function|any The value to return when `comparison` is false.
--- @return any # The value that either `when_true` or `when_false` returned.
--- @see down.core.lib.match
function U.when(comparison, when_true, when_false)
  if type(comparison) ~= "boolean" then
    comparison = (comparison ~= nil)
  end

  return U.match(
    type(comparison) == "table" and unpack(comparison) or comparison
  )({
    ["true"] = when_true,
    ["false"] = when_false,
  })
end

--- Custom down notifications. Wrapper around `vim.notify`.
--- @param msg string Message to send.
--- @param log_level integer? Log level in `vim.log.levels`.
function U.notify(msg, log_level)
  vim.notify(msg, log_level, { title = "down" })
end

--- Opens up an array of files and runs a callback for each opened file.
--- @param files (string)[] An array of files to open.
--- @param callback fun(buffer: integer, filename: string) The callback to invoke for each file.
function U.read_files(files, callback)
  for _, file in ipairs(files) do
    file = tostring(file)
    local bufnr = vim.uri_to_bufnr(vim.uri_from_fname(file))

    local should_delete = not a.nvim_buf_is_loaded(bufnr)

    f.bufload(bufnr)
    callback(bufnr, file)
    if should_delete then
      a.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

-- following https://gist.github.com/kylechui/a5c1258cd2d86755f97b10fc921315c3
function U.set_operatorfunc(f)
  U._down_operatorfunc = f
  vim.go.operatorfunc = "v:lua.require'down'.U._down_operatorfunc"
end

function U.wrap_dotrepeat(callback)
  return function(...)
    if a.nvim_get_mode().mode == "i" then
      callback(...)
      return
    end

    local args = { ... }
    U.set_operatorfunc(function()
      callback(unpack(args))
    end)
    c("normal! g@l")
  end
end
--- Wraps a function in a callback.
--- @generic T: function, A
--- @param function_pointer T The function to wrap.
--- @param ... A The arguments to pass to the wrapped function.
--- @return fun(...: A): T # The wrapped function in a callback.
function U.wrap(function_pointer, ...)
  local params = { ... }

  if type(function_pointer) ~= "function" then
    local prev = function_pointer

    -- luacheck: push ignore
    function_pointer = function()
      return prev, unpack(params)
    end
    -- luacheck: pop
  end

  return function()
    return function_pointer(unpack(params))
  end
end

local strcharpt, strwidth, strchars = f.strcharpart, a.nvim_strwidth, f.strchars
--- Truncate input string to fit inside the `col_limit` when displayed. Takes non-ascii chars into account.
--- @param str string The string to limit.
--- @param col_limit integer `str` will be cut so that when displayed, the display length does not exceed this limit.
--- @return string # Substring of input str
function U.truncate_by_cell(str, col_limit)
  if str and str:len() == strwidth(str) then
    return strcharpt(str, 0, col_limit)
  end
  local short = strcharpt(str, 0, col_limit)
  if strwidth(short) > col_limit then
    while strwidth(short) > col_limit do
      short = strcharpt(short, 0, strchars(short) - 1)
    end
  end
  return short
end

---@return down.Os
function U.get_os()
  local os = (vim.loop or vim.uv).os_uname().sysname:lower()
  if os:find("windows_nt") then
    return "windows"
  elseif os == "darwin" then
    return "mac"
  elseif os == "linux" then
    local f = io.open("/proc/version", "r")
    if f ~= nil then
      local version = f:read("*all")
      f:close()
      if version:find("WSL2") then
        return "wsl2"
      elseif version:find("microsoft") then
        return "wsl"
      end
    end
    return "linux"
  elseif os:find("bsd") then
    return "bsd"
  end
  error("[down]: Unable to determine the currently active operating system!")
end

U.log = require("down.util.log")
U.string = require("down.util.string")

return U
