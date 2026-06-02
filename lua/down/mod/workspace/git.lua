--- Git sync module for down.nvim workspaces
--- Provides automatic git sync (commit, push, pull) for workspace directories
---@class down.mod.workspace.Git
local Git = {}

---@class down.mod.workspace.Git.Config
Git.default_config = {
  --- Enable git sync
  enabled = true,
  --- Auto-commit on save
  auto_commit = true,
  --- Auto-push after commit
  auto_push = false,
  --- Auto-pull on workspace open
  auto_pull = true,
  --- Commit message format (supports %date%, %time%, %file%, %workspace%)
  commit_message = "docs: update %file% (%date% %time%)",
  --- Commit message for batch commits
  batch_commit_message = "docs: sync workspace %workspace% (%date%)",
  --- Debounce time in ms before auto-commit (prevents commit spam)
  debounce_ms = 5000,
  --- Branch to sync with (nil = current branch)
  branch = nil,
  --- Remote name
  remote = "origin",
  --- Show notifications for sync operations
  notify = true,
  --- Sync interval in minutes (0 = disabled, only manual/on-save)
  sync_interval = 0,
  --- Paths to exclude from auto-commit (gitignore patterns)
  exclude = {},
  --- Initialize git repo if not present
  auto_init = false,
}

--- State tracking
---@class down.mod.workspace.Git.State
Git.state = {
  ---@type table<string, boolean> workspace -> has_git
  initialized = {},
  ---@type table<string, number> workspace -> last commit timestamp
  last_commit = {},
  ---@type table<string, number> workspace -> debounce timer
  timers = {},
  ---@type table<string, boolean> workspace -> is syncing
  syncing = {},
  ---@type table<string, string> workspace -> last known branch
  branches = {},
}

--- Check if a path is inside a git repository
---@param path string
---@return boolean
Git.is_git_repo = function(path)
  local git_dir = vim.fs.find(".git", {
    path = path,
    upward = true,
    type = "directory",
  })
  return #git_dir > 0
end

--- Get the git root for a path
---@param path string
---@return string|nil
Git.git_root = function(path)
  local root = vim.fs.root(path, ".git")
  return root
end

--- Run a git command asynchronously
---@param args string[] git command arguments
---@param cwd string working directory
---@param cb? fun(success: boolean, output: string) callback
Git.run = function(args, cwd, cb)
  local cmd = vim.list_extend({ "git" }, args)
  local output_lines = {}

  vim.fn.jobstart(cmd, {
    cwd = cwd,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(output_lines, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(output_lines, data)
      end
    end,
    on_exit = function(_, code)
      local output = table.concat(output_lines, "\n")
      if cb then
        vim.schedule(function()
          cb(code == 0, output)
        end)
      end
    end,
  })
end

--- Run a git command synchronously (for quick checks)
---@param args string[]
---@param cwd string
---@return boolean success
---@return string output
Git.run_sync = function(args, cwd)
  local cmd = vim.list_extend({ "git" }, args)
  local result = vim.fn.system(table.concat(cmd, " "))
  local success = vim.v.shell_error == 0
  return success, result or ""
end

--- Get current branch name
---@param cwd string
---@return string|nil
Git.current_branch = function(cwd)
  local ok, output = Git.run_sync({ "branch", "--show-current" }, cwd)
  if ok then
    return vim.trim(output)
  end
  return nil
end

--- Check if there are uncommitted changes
---@param cwd string
---@param cb fun(has_changes: boolean, status: string)
Git.has_changes = function(cwd, cb)
  Git.run({ "status", "--porcelain" }, cwd, function(ok, output)
    if ok then
      cb(vim.trim(output) ~= "", output)
    else
      cb(false, "")
    end
  end)
end

--- Check if there are unpushed commits
---@param cwd string
---@param remote string
---@param branch string
---@param cb fun(has_unpushed: boolean, count: number)
Git.has_unpushed = function(cwd, remote, branch, cb)
  Git.run(
    { "rev-list", "--count", remote .. "/" .. branch .. "..HEAD" },
    cwd,
    function(ok, output)
      if ok then
        local count = tonumber(vim.trim(output)) or 0
        cb(count > 0, count)
      else
        cb(false, 0)
      end
    end
  )
end

--- Check if remote has new commits
---@param cwd string
---@param remote string
---@param branch string
---@param cb fun(has_remote: boolean, count: number)
Git.has_remote_changes = function(cwd, remote, branch, cb)
  -- First fetch to update remote refs
  Git.run({ "fetch", remote, "--quiet" }, cwd, function(fetch_ok)
    if not fetch_ok then
      cb(false, 0)
      return
    end
    Git.run(
      { "rev-list", "--count", "HEAD.." .. remote .. "/" .. branch },
      cwd,
      function(ok, output)
        if ok then
          local count = tonumber(vim.trim(output)) or 0
          cb(count > 0, count)
        else
          cb(false, 0)
        end
      end
    )
  end)
end

--- Initialize a git repository in a workspace
---@param ws_path string
---@param config table
---@param cb? fun(success: boolean)
Git.init_repo = function(ws_path, config, cb)
  Git.run({ "init" }, ws_path, function(ok, output)
    if ok then
      -- Create .gitignore with sensible defaults
      local gitignore_path = vim.fs.joinpath(ws_path, ".gitignore")
      if vim.fn.filereadable(gitignore_path) == 0 then
        local gitignore = table.concat({
          "# OS files",
          ".DS_Store",
          "Thumbs.db",
          "",
          "# Editor files",
          "*.swp",
          "*.swo",
          "*~",
          ".netrwhist",
          "",
          "# Down.nvim data",
          ".down/cache/",
          "",
        }, "\n")
        local f = io.open(gitignore_path, "w")
        if f then
          f:write(gitignore)
          f:close()
        end
      end

      -- Initial commit
      Git.run({ "add", "-A" }, ws_path, function(add_ok)
        if add_ok then
          Git.run(
            { "commit", "-m", "Initial workspace commit" },
            ws_path,
            function(commit_ok)
              Git.state.initialized[ws_path] = true
              if config.notify then
                vim.notify("[down.nvim] Git initialized for workspace", vim.log.levels.INFO)
              end
              if cb then cb(commit_ok) end
            end
          )
        else
          if cb then cb(false) end
        end
      end)
    else
      if cb then cb(false) end
    end
  end)
end

--- Format a commit message using template
---@param template string
---@param file? string
---@param workspace? string
---@return string
Git.format_message = function(template, file, workspace)
  local msg = template
  msg = msg:gsub("%%date%%", os.date("%Y-%m-%d"))
  msg = msg:gsub("%%time%%", os.date("%H:%M"))
  msg = msg:gsub("%%file%%", file or "notes")
  msg = msg:gsub("%%workspace%%", workspace or "default")
  msg = msg:gsub("%%timestamp%%", tostring(os.time()))
  return msg
end

--- Stage and commit changes
---@param ws_path string
---@param config table
---@param file? string specific file to commit (nil = all changes)
---@param cb? fun(success: boolean, message: string)
Git.commit = function(ws_path, config, file, cb)
  if Git.state.syncing[ws_path] then
    if cb then cb(false, "Sync already in progress") end
    return
  end

  Git.state.syncing[ws_path] = true

  -- Stage changes
  local add_args = { "add" }
  if file then
    table.insert(add_args, file)
  else
    table.insert(add_args, "-A")
  end

  -- Apply excludes
  for _, pattern in ipairs(config.exclude or {}) do
    table.insert(add_args, ":(exclude)" .. pattern)
  end

  Git.run(add_args, ws_path, function(add_ok, add_output)
    if not add_ok then
      Git.state.syncing[ws_path] = false
      if cb then cb(false, "Failed to stage: " .. add_output) end
      return
    end

    -- Check if there's actually anything to commit
    -- Check if there's actually anything staged to commit
    Git.run({ "diff", "--cached", "--quiet" }, ws_path, function(has_staged)
      if has_staged then
        Git.state.syncing[ws_path] = false
        if cb then cb(true, "Nothing to commit") end
        return
      end

      -- Format commit message
      local ws_name = "default"
      local mod = require("down.mod")
      local ws_mod = mod.get_mod("workspace")
      if ws_mod then
        ws_name = ws_mod.current() or "default"
      end

      local msg
      if file then
        msg = Git.format_message(config.commit_message, vim.fn.fnamemodify(file, ":t"), ws_name)
      else
        msg = Git.format_message(config.batch_commit_message, nil, ws_name)
      end

      Git.run({ "commit", "-m", msg }, ws_path, function(commit_ok, commit_output)
        Git.state.syncing[ws_path] = false
        Git.state.last_commit[ws_path] = os.time()

        if commit_ok then
          if config.notify then
            vim.notify("[down.nvim] " .. msg, vim.log.levels.INFO)
          end
          if cb then cb(true, msg) end
        else
          if cb then cb(false, commit_output) end
        end
      end)
    end)
  end)
end

--- Push to remote
---@param ws_path string
---@param config table
---@param cb? fun(success: boolean, message: string)
Git.push = function(ws_path, config, cb)
  local branch = config.branch or Git.current_branch(ws_path) or "main"
  local remote = config.remote or "origin"

  Git.run({ "push", remote, branch }, ws_path, function(ok, output)
    if ok then
      if config.notify then
        vim.notify("[down.nvim] Pushed to " .. remote .. "/" .. branch, vim.log.levels.INFO)
      end
      if cb then cb(true, "Pushed successfully") end
    else
      -- Try setting upstream if push fails
      Git.run(
        { "push", "--set-upstream", remote, branch },
        ws_path,
        function(retry_ok, retry_output)
          if retry_ok then
            if config.notify then
              vim.notify("[down.nvim] Pushed to " .. remote .. "/" .. branch .. " (set upstream)", vim.log.levels.INFO)
            end
            if cb then cb(true, "Pushed with upstream set") end
          else
            if config.notify then
              vim.notify("[down.nvim] Push failed: " .. retry_output, vim.log.levels.WARN)
            end
            if cb then cb(false, retry_output) end
          end
        end
      )
    end
  end)
end

--- Pull from remote (with rebase to keep history clean)
---@param ws_path string
---@param config table
---@param cb? fun(success: boolean, message: string)
Git.pull = function(ws_path, config, cb)
  local branch = config.branch or Git.current_branch(ws_path) or "main"
  local remote = config.remote or "origin"

  -- Stash any uncommitted changes first
  Git.has_changes(ws_path, function(has_changes)
    local needs_stash = has_changes

    local do_pull = function()
      Git.run({ "pull", "--rebase", remote, branch }, ws_path, function(ok, output)
        if ok then
          -- Pop stash if we stashed
          if needs_stash then
            Git.run({ "stash", "pop" }, ws_path, function(stash_ok, stash_output)
              if not stash_ok then
                if config.notify then
                  vim.notify("[down.nvim] Pull succeeded but stash pop had conflicts: " .. stash_output, vim.log.levels.WARN)
                end
                if cb then cb(true, "Pulled with stash conflicts") end
              else
                if config.notify then
                  vim.notify("[down.nvim] Pulled from " .. remote .. "/" .. branch, vim.log.levels.INFO)
                end
                if cb then cb(true, "Pulled successfully") end
              end
            end)
          else
            if config.notify then
              vim.notify("[down.nvim] Pulled from " .. remote .. "/" .. branch, vim.log.levels.INFO)
            end
            if cb then cb(true, "Pulled successfully") end
          end
        else
          -- If rebase fails, abort and try merge
          Git.run({ "rebase", "--abort" }, ws_path, function()
            Git.run({ "pull", "--no-rebase", remote, branch }, ws_path, function(merge_ok, merge_output)
              if needs_stash then
                Git.run({ "stash", "pop" }, ws_path, function() end)
              end
              if merge_ok then
                if config.notify then
                  vim.notify("[down.nvim] Pulled (merged) from " .. remote .. "/" .. branch, vim.log.levels.INFO)
                end
                if cb then cb(true, "Pulled with merge") end
              else
                if config.notify then
                  vim.notify("[down.nvim] Pull failed: " .. merge_output, vim.log.levels.ERROR)
                end
                if cb then cb(false, merge_output) end
              end
            end)
          end)
        end
      end)
    end

    if needs_stash then
      Git.run({ "stash", "push", "-m", "down.nvim auto-stash before pull" }, ws_path, function(stash_ok)
        if stash_ok then
          do_pull()
        else
          if config.notify then
            vim.notify("[down.nvim] Failed to stash changes before pull", vim.log.levels.WARN)
          end
          if cb then cb(false, "Failed to stash") end
        end
      end)
    else
      do_pull()
    end
  end)
end

--- Full sync: pull then commit and push
---@param ws_path string
---@param config table
---@param cb? fun(success: boolean, message: string)
Git.sync = function(ws_path, config, cb)
  if Git.state.syncing[ws_path] then
    if cb then cb(false, "Sync already in progress") end
    return
  end
  Git.state.syncing[ws_path] = true

  -- Pull first
  Git.pull(ws_path, config, function(pull_ok, pull_msg)
    if not pull_ok then
      if cb then cb(false, "Pull failed: " .. pull_msg) end
      return
    end

    -- Then commit any local changes
    Git.commit(ws_path, config, nil, function(commit_ok, commit_msg)
      if not commit_ok and commit_msg ~= "Nothing to commit" then
        if cb then cb(false, "Commit failed: " .. commit_msg) end
        return
      end

      -- Then push
      if config.auto_push then
        Git.push(ws_path, config, function(push_ok, push_msg)
          if cb then cb(push_ok, push_msg) end
        end)
      else
        if cb then cb(true, "Synced (commit only)") end
      end
    end)
  end)
end

--- Get git status for display
---@param ws_path string
---@param cb fun(status: table)
Git.status = function(ws_path, cb)
  Git.run({ "status", "--porcelain", "--branch" }, ws_path, function(ok, output)
    if not ok then
      cb({ error = true, message = "Not a git repo" })
      return
    end

    local status = {
      error = false,
      branch = "",
      ahead = 0,
      behind = 0,
      staged = 0,
      modified = 0,
      untracked = 0,
      conflicts = 0,
    }

    for line in output:gmatch("[^\n]+") do
      if line:match("^##") then
        status.branch = line:match("^## (.+)") or ""
        local ahead = line:match("ahead (%d+)")
        local behind = line:match("behind (%d+)")
        status.ahead = tonumber(ahead) or 0
        status.behind = tonumber(behind) or 0
      elseif line:match("^[MADRC]") then
        status.staged = status.staged + 1
      elseif line:match("^ [MADRC]") then
        status.modified = status.modified + 1
      elseif line:match("^%?%?") then
        status.untracked = status.untracked + 1
      elseif line:match("^[UDA][UDA]") then
        status.conflicts = status.conflicts + 1
      end
    end

    cb(status)
  end)
end

--- Format status for display in statusline or notification
---@param status table
---@return string
Git.format_status = function(status)
  if status.error then
    return "⚠ " .. (status.message or "error")
  end

  local parts = {}
  table.insert(parts, " " .. status.branch)

  if status.ahead > 0 then
    table.insert(parts, "↑" .. status.ahead)
  end
  if status.behind > 0 then
    table.insert(parts, "↓" .. status.behind)
  end
  if status.staged > 0 then
    table.insert(parts, "●" .. status.staged)
  end
  if status.modified > 0 then
    table.insert(parts, "✱" .. status.modified)
  end
  if status.untracked > 0 then
    table.insert(parts, "+" .. status.untracked)
  end
  if status.conflicts > 0 then
    table.insert(parts, "✖" .. status.conflicts)
  end

  return table.concat(parts, " ")
end

--- Set up auto-commit on BufWritePost with debouncing
---@param ws_path string
---@param config table
Git.setup_auto_commit = function(ws_path, config)
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = vim.fs.joinpath(ws_path, "**"),
    callback = function(ev)
      if not config.auto_commit then
        return
      end

      local bufpath = vim.api.nvim_buf_get_name(ev.buf)
      if not bufpath or bufpath == "" then
        return
      end

      -- Check if file is in the workspace
      if not bufpath:find(ws_path, 1, true) then
        return
      end

      -- Debounce: cancel previous timer and set new one
      if Git.state.timers[ws_path] then
        vim.fn.timer_stop(Git.state.timers[ws_path])
      end

      Git.state.timers[ws_path] = vim.fn.timer_start(config.debounce_ms, function()
        Git.state.timers[ws_path] = nil
        Git.commit(ws_path, config, bufpath, function(ok, msg)
          if ok and config.auto_push then
            Git.push(ws_path, config)
          end
        end)
      end)
    end,
    desc = "down.nvim git auto-commit on save",
  })
end

--- Set up periodic sync timer
---@param ws_path string
---@param config table
Git.setup_periodic_sync = function(ws_path, config)
  if config.sync_interval <= 0 then
    return
  end

  local interval_ms = config.sync_interval * 60 * 1000

  vim.fn.timer_start(interval_ms, function()
    Git.sync(ws_path, config)
  end, { ["repeat"] = -1 }) -- repeat indefinitely
end

--- Initialize git sync for a workspace
---@param ws_path string
---@param config? table
Git.setup_workspace = function(ws_path, config)
  config = vim.tbl_deep_extend("force", Git.default_config, config or {})

  if not config.enabled then
    return
  end

  -- Check if workspace is a git repo
  if not Git.is_git_repo(ws_path) then
    if config.auto_init then
      Git.init_repo(ws_path, config, function(ok)
        if ok then
          Git.setup_auto_commit(ws_path, config)
          Git.setup_periodic_sync(ws_path, config)
        end
      end)
    end
    return
  end

  Git.state.initialized[ws_path] = true

  -- Auto-pull on setup
  if config.auto_pull then
    Git.pull(ws_path, config)
  end

  -- Set up auto-commit
  Git.setup_auto_commit(ws_path, config)

  -- Set up periodic sync
  Git.setup_periodic_sync(ws_path, config)
end

return Git
