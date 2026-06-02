local log = require ("down.log")
local mod = require ("down.mod")

---@class down.mod.mcp.Mcp: down.Mod
local Mcp = mod.new ("mcp")

---@class down.mod.mcp.Config
Mcp.config = {
  --- Enable auto-download of down.mcp binary
  auto_download = true,
  --- GitHub repo for down.mcp releases
  repo = "clpi/down.mcp",
  --- Binary name
  bin = "down-mcp",
  --- Custom binary path (overrides auto-download)
  cmd = nil,
  --- Transport mode: "stdio" or "sse"
  transport = "stdio",
  --- Port for SSE transport
  port = 3001,
  --- Enable knowledge graph operations via MCP
  knowledge_graph = true,
}

---@return down.mod.Setup
Mcp.setup = function ()
  return {
    loaded = true,
    dependencies = { "workspace", "data" },
  }
end

--- Get the install directory for the MCP binary
---@return string
Mcp.install_dir = function ()
  local dir = vim.fs.joinpath (vim.fn.stdpath ("data"), "down", "mcp")
  vim.fn.mkdir (dir, "p")
  return dir
end

--- Get the binary path
---@return string
Mcp.bin_path = function ()
  if Mcp.config.cmd then
    return Mcp.config.cmd
  end
  local bin = Mcp.config.bin
  if vim.fn.has ("win32") == 1 then
    bin = bin .. ".exe"
  end
  return vim.fs.joinpath (Mcp.install_dir (), bin)
end

--- Check if the binary is installed
---@return boolean
Mcp.is_installed = function ()
  return vim.fn.executable (Mcp.bin_path ()) == 1
end

--- Detect the platform for download
---@return string?
Mcp.platform = function ()
  local os_name = vim.loop.os_uname ().sysname
  local arch = vim.loop.os_uname ().machine
  if os_name == "Linux" then
    if arch == "x86_64" then
      return "linux-amd64"
    elseif arch == "aarch64" then
      return "linux-arm64"
    end
  elseif os_name == "Darwin" then
    if arch == "arm64" then
      return "darwin-arm64"
    else
      return "darwin-amd64"
    end
  elseif os_name == "Windows_NT" then
    return "windows-amd64"
  end
  return nil
end

--- Download and install the MCP server binary
---@param cb? fun(success: boolean)
Mcp.download = function (cb)
  local platform = Mcp.platform ()
  if not platform then
    log.warn ("down.mcp: unsupported platform for auto-download")
    if cb then
      cb (false)
    end
    return
  end

  local bin_name = Mcp.config.bin
  if vim.fn.has ("win32") == 1 then
    bin_name = bin_name .. ".exe"
  end

  vim.notify ("[down.nvim] Downloading down.mcp...", vim.log.levels.INFO)

  local install_dir = Mcp.install_dir ()
  local url = string.format (
    "https://github.com/%s/releases/latest/download/%s-%s",
    Mcp.config.repo,
    Mcp.config.bin,
    platform
  )
  local dest = vim.fs.joinpath (install_dir, bin_name)

  vim.fn.jobstart ({ "curl", "-sL", "-o", dest, url }, {
    on_exit = function (_, code)
      if code == 0 then
        vim.fn.setfperm (dest, "rwxr-xr-x")
        vim.schedule (function ()
          vim.notify (
            "[down.nvim] down.mcp installed successfully",
            vim.log.levels.INFO
          )
          if cb then
            cb (true)
          end
        end)
      else
        vim.schedule (function ()
          vim.notify (
            "[down.nvim] Failed to download down.mcp",
            vim.log.levels.WARN
          )
          if cb then
            cb (false)
          end
        end)
      end
    end,
  })
end

---@type number?
Mcp.job_id = nil

--- Start the MCP server process
Mcp.start = function ()
  if Mcp.job_id then
    return
  end
  if not Mcp.is_installed () then
    if Mcp.config.auto_download then
      Mcp.download (function (success)
        if success then
          vim.schedule (function ()
            Mcp.start ()
          end)
        end
      end)
    else
      log.info (
        "down.mcp not installed. Set config.mcp.auto_download = true or provide config.mcp.cmd"
      )
    end
    return
  end

  local cmd_path = Mcp.bin_path ()
  local args = { cmd_path, "serve" }
  if Mcp.config.transport == "sse" then
    table.insert (args, "--transport")
    table.insert (args, "sse")
    table.insert (args, "--port")
    table.insert (args, tostring (Mcp.config.port))
  end

  Mcp.job_id = vim.fn.jobstart (args, {
    on_exit = function (_, code)
      Mcp.job_id = nil
      if code ~= 0 then
        log.warn ("down.mcp exited with code: " .. code)
      end
    end,
    on_stderr = function (_, data)
      for _, line in ipairs (data) do
        if line ~= "" then
          log.trace ("down.mcp: " .. line)
        end
      end
    end,
  })
end

--- Stop the MCP server process
Mcp.stop = function ()
  if Mcp.job_id then
    vim.fn.jobstop (Mcp.job_id)
    Mcp.job_id = nil
  end
end

Mcp.commands = {
  mcp = {
    name = "mcp",
    args = 0,
    max_args = 1,
    callback = function (e)
      Mcp.start ()
    end,
    commands = {
      start = {
        name = "mcp.start",
        args = 0,
        callback = function ()
          Mcp.start ()
        end,
      },
      stop = {
        name = "mcp.stop",
        args = 0,
        callback = function ()
          Mcp.stop ()
        end,
      },
      install = {
        name = "mcp.install",
        args = 0,
        callback = function ()
          Mcp.download ()
        end,
      },
      status = {
        name = "mcp.status",
        args = 0,
        callback = function ()
          if Mcp.is_installed () then
            local running = Mcp.job_id and "running" or "stopped"
            vim.notify ("[down.nvim] down.mcp is installed (" .. running .. ")")
          else
            vim.notify ("[down.nvim] down.mcp is not installed")
          end
        end,
      },
    },
  },
}

Mcp.load = function ()
  vim.api.nvim_create_autocmd ("VimLeavePre", {
    callback = function ()
      Mcp.stop ()
    end,
  })
end

return Mcp
