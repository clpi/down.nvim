--- down.add - Ingest files/dirs/URLs into .down/data/
--- Adds repomix-style markdown versions to the data directory.

local add = {}

--- Resolve PWD
---@return string
local function pwd()
  return io.popen("pwd"):read("*l")
end

--- Check if path exists and what type it is
---@param path string
---@return string|nil -- "dir", "file", or nil (not found)
local function path_type(path)
  local h = io.popen('test -d "' .. path .. '" && echo d || test -f "' .. path .. '" && echo f || echo x')
  if not h then return nil end
  local t = h:read("*l"):gsub("%s+$", "")
  h:close()
  if t == "d" then return "dir"
  elseif t == "f" then return "file"
  else return nil end
end

--- Check if string looks like a URL
---@param s string
---@return boolean
local function is_url(s)
  return s:match("^https?://") ~= nil or s:match("^www%.") ~= nil
end

--- Fetch URL content and convert to markdown
---@param url string
---@return string|nil, string|nil
local function fetch_url(url)
  if not url:match("^https?://") then url = "https://" .. url end
  local cmd = 'curl -sL --max-time 30 "' .. url .. '" 2>/dev/null'
  local h = io.popen(cmd)
  if not h then return nil, "curl failed" end
  local html = h:read("*a")
  h:close()
  if not html or html == "" then return nil, "empty response" end

  -- Basic HTML to text conversion
  local text = html
    :gsub("<[hH][eE][aA][dD].->.-</[hH][eE][aA][dD].->", "")
    :gsub("<[sS][tT][yY][lL][eE].->.-</[sS][tT][yY][lL][eE].->", "")
    :gsub("<[sS][cC][rR][iI][pP][tT].->.-</[sS][cC][rR][iI][pP][tT].->", "")
    :gsub("<[^>]+>", "")
    :gsub("&nbsp;", " ")
    :gsub("&amp;", "&")
    :gsub("&lt;", "<")
    :gsub("&gt;", ">")
    :gsub("&quot;", '"')
    :gsub("&#39;", "'")

  -- Strip excessive whitespace
  text = text:gsub("\n%s*\n%s*\n+", "\n\n")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")

  return "# " .. url .. "\n\n" .. text
end

--- Compact a file into repomix-style markdown
---@param path string
---@return string|nil
local function compact_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  local ext = path:match("%.(.+)$") or ""
  return "### " .. path:match("[^/]+$") .. "\n\n```" .. ext .. "\n" .. content .. "\n```\n"
end

--- Compact a directory recursively (reuse compact module logic)
---@param path string
---@return string|nil
local function compact_dir(path)
  local ok, compact = pcall(require, "down.compact")
  if ok then
    compact.config.format = "markdown"
    compact.config.tree = true
    compact.config.tokens = false
    compact.config.output = nil
    return compact.pack(path)
  end
  -- Fallback: simple tree
  local out = { "# " .. path:match("[^/]+$"), "" }
  local function walk(dir, prefix)
    local h = io.popen('ls -A "' .. dir .. '" 2>/dev/null')
    if not h then return end
    for name in h:lines() do
      local full = dir .. "/" .. name
      if name ~= ".git" and name ~= "node_modules" and name ~= ".down" then
        local pt = path_type(full)
        if pt == "dir" then
          out[#out + 1] = prefix .. "  - " .. name .. "/"
          walk(full, prefix .. "  ")
        else
          local fc = io.open(full, "r")
          if fc then
            local content = fc:read("*a")
            fc:close()
            local ext = name:match("%.(.+)$") or ""
            out[#out + 1] = "### " .. name
            out[#out + 1] = ""
            out[#out + 1] = "```" .. ext
            out[#out + 1] = content
            out[#out + 1] = "```"
            out[#out + 1] = ""
          end
        end
      end
    end
    h:close()
  end
  walk(path, "")
  return table.concat(out, "\n")
end

--- Find .down/data/ directory (walks up from current dir)
---@param start string
---@return string|nil
local function find_data_dir(start)
  local dir = start
  while dir and dir ~= "/" do
    local d = dir .. "/.down/data"
    local h = io.open(d .. "/.downignore", "r")  -- sentinel check
    if h then h:close() return d end
    -- check if directory exists
    local h2 = io.popen('test -d "' .. d .. '" && echo y')
    if h2 then
      local r = h2:read("*l")
      h2:close()
      if r == "y" then return d end
    end
    dir = dir:match("^(.*)/[^/]+$")
  end
  return nil
end

--- Add content to .down/data/
---@param source string -- file path, dir path, URL, or name
---@param opts? { workspace?: string, title?: string }
---@return string|nil, string|nil -- output path, error
function add.ingest(source, opts)
  opts = opts or {}
  local root = opts.workspace or pwd()
  local data_dir = find_data_dir(root)

  -- If no .down/data/ exists, create it
  if not data_dir then
    os.execute('mkdir -p "' .. root .. '/.down/data" 2>/dev/null')
    data_dir = root .. "/.down/data"
  end

  local content = nil
  local filename = nil
  local full_source = source

  -- Case 1: URL
  if is_url(source) then
    local domain = source:match("https?://([^/]+)") or source
    filename = (domain:gsub("%.", "_")) .. ".md"
    local ok, err = fetch_url(source)
    if ok then content = ok else return nil, "URL fetch failed: " .. (err or "unknown") end

  -- Case 2: Existing file
  elseif path_type(source) == "file" then
    local fname = source:match("[^/]+$") or source
    local abs = source
    if not source:match("^/") then abs = root .. "/" .. source end
    content = compact_file(abs)
    if not content then return nil, "cannot read file: " .. abs end
    filename = fname:gsub("%.", "_") .. ".md"

  -- Case 3: Existing directory
  elseif path_type(source) == "dir" then
    local dname = source:match("[^/]+$") or source
    content = compact_dir(source)
    filename = dname .. "_compact.md"

  -- Case 4: Path ending with / (explicitly wants a directory created)
  elseif source:match("/$") then
    local clean = source:gsub("/$", "")
    local dname = clean:match("[^/]+$") or clean
    local dir_path = root .. "/" .. clean
    os.execute('mkdir -p "' .. dir_path .. '" 2>/dev/null')
    local idx_path = dir_path .. "/index.md"
    local idx = io.open(idx_path, "r")
    if not idx then
      local f = io.open(idx_path, "w")
      if f then f:write("# " .. dname .. "\n\nIndex for " .. dname .. "\n") f:close() end
    else idx:close() end
    content = compact_dir(dir_path)
    filename = dname .. "_compact.md"

  -- Case 5: Bare word or non-existent path -> create .md
  else
    local fname = source:match("[^/]+$") or source
    local md_path = root .. "/" .. source .. ".md"
    local exists = io.open(md_path, "r")
    if exists then
      exists:close()
      content = compact_file(md_path)
      filename = source .. ".md"
    else
      local data_md = data_dir .. "/" .. source .. ".md"
      local d_exists = io.open(data_md, "r")
      if d_exists then
        d_exists:close()
        filename = source .. "_index.md"
        content = "# " .. source .. "\n\nSee: " .. source .. ".md\n"
      else
        local f = io.open(md_path, "w")
        if f then f:write("# " .. source .. "\n\n") f:close() end
        content = "# " .. source .. "\n\nAdded: " .. os.date("%Y-%m-%d %H:%M") .. "\n"
        filename = source .. ".md"
      end
    end
  end

  if not content then
    return nil, "could not process: " .. source
  end

  -- Add header with metadata
  local header = "---\n"
  header = header .. "source: " .. source .. "\n"
  header = header .. "date: " .. os.date("%Y-%m-%d %H:%M") .. "\n"
  if opts.title then header = header .. "title: " .. opts.title .. "\n" end
  header = header .. "---\n\n"
  content = header .. content

  -- Write to data dir
  local out_path = data_dir .. "/" .. filename
  local f = io.open(out_path, "w")
  if not f then return nil, "cannot write: " .. out_path end
  f:write(content)
  f:close()

  return out_path, nil
end

--- CLI handler for `down add <arg> [options]`
---@param args table
function add.cli(args)
  local source = nil
  local title = nil
  local workspace = nil
  local i = 1
  while i <= #args do
    local a = args[i]
    if a == "--title" or a == "-t" then
      i = i + 1
      title = args[i]
    elseif a == "--workspace" or a == "-w" then
      i = i + 1
      workspace = args[i]
    elseif a == "--help" or a == "-h" then
      print([[down add - Add files/dirs/URLs to .down/data/

Usage: down add [options] <source>

SOURCE can be:
  file.md       Compact existing file to repomix-style markdown
  dir/          Compact directory
  https://...   Fetch URL, convert to markdown
  <name>        Create or use <name>.md in data dir
  <name>/       Create directory with index.md

Options:
  -t, --title TITLE    Set title for the output
  -w, --workspace DIR  Target workspace directory
  -h, --help           Show this help]])
      return true
    elseif a:sub(1, 1) ~= "-" then
      source = a
    end
    i = i + 1
  end

  if not source then
    print("Error: no source specified. Use `down add --help` for usage.")
    return true
  end

  local out_path, err = add.ingest(source, { title = title, workspace = workspace })
  if out_path then
    print("Added: " .. source)
    print("  -> " .. out_path)
  else
    print("Error: " .. (err or "unknown"))
  end
  return true
end

return add
