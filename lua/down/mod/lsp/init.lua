local log = require ("down.log")
local mod = require ("down.mod")

---@class down.mod.lsp.Lsp: down.Mod
local Lsp = mod.new ("lsp")

---@class down.mod.lsp.Config
Lsp.config = {
  --- Enable auto-download of down.lsp binary
  auto_download = true,
  --- GitHub repo for down.lsp releases
  repo = "clpi/down.lsp",
  --- Binary name
  bin = "down-lsp",
  --- Custom binary path (overrides auto-download)
  cmd = nil,
  --- Additional LSP settings to pass
  settings = {},
  --- Filetypes to attach LSP
  filetypes = { "markdown" },
  --- Root directory markers
  root_markers = { ".down", ".git", "index.md" },
}

---@return down.mod.Setup
Lsp.setup = function ()
  return {
    loaded = true,
    dependencies = { "workspace" },
  }
end

--- Get the install directory for the LSP binary
---@return string
Lsp.install_dir = function ()
  local dir = vim.fs.joinpath (vim.fn.stdpath ("data"), "down", "lsp")
  vim.fn.mkdir (dir, "p")
  return dir
end

--- Get the binary path
---@return string
Lsp.bin_path = function ()
  if Lsp.config.cmd then
    return Lsp.config.cmd
  end
  local bin = Lsp.config.bin
  if vim.fn.has ("win32") == 1 then
    bin = bin .. ".exe"
  end
  return vim.fs.joinpath (Lsp.install_dir (), bin)
end

--- Check if the binary is installed
---@return boolean
Lsp.is_installed = function ()
  return vim.fn.executable (Lsp.bin_path ()) == 1
end

--- Detect the platform for download
---@return string?
Lsp.platform = function ()
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

--- Download and install the LSP binary
---@param cb? fun(success: boolean)
Lsp.download = function (cb)
  local platform = Lsp.platform ()
  if not platform then
    log.warn ("down.lsp: unsupported platform for auto-download")
    if cb then
      cb (false)
    end
    return
  end

  local bin_name = Lsp.config.bin
  if vim.fn.has ("win32") == 1 then
    bin_name = bin_name .. ".exe"
  end

  vim.notify ("[down.nvim] Downloading down.lsp...", vim.log.levels.INFO)

  local install_dir = Lsp.install_dir ()
  local url = string.format (
    "https://github.com/%s/releases/latest/download/%s-%s",
    Lsp.config.repo,
    Lsp.config.bin,
    platform
  )
  local dest = vim.fs.joinpath (install_dir, bin_name)

  vim.fn.jobstart ({ "curl", "-sL", "-o", dest, url }, {
    on_exit = function (_, code)
      if code == 0 then
        vim.fn.setfperm (dest, "rwxr-xr-x")
        vim.schedule (function ()
          vim.notify (
            "[down.nvim] down.lsp installed successfully",
            vim.log.levels.INFO
          )
          if cb then
            cb (true)
          end
        end)
      else
        vim.schedule (function ()
          vim.notify (
            "[down.nvim] Failed to download down.lsp",
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

--- Get workspace folders from workspace module
---@return lsp.WorkspaceFolder[]
Lsp.workspace_folders = function ()
  local ws = mod.get_mod ("workspace")
  if ws and ws.as_lsp_workspaces then
    return ws.as_lsp_workspaces ()
  end
  return {
    {
      name = "default",
      uri = vim.uri_from_fname (vim.fn.getcwd ()),
    },
  }
end

--- Start the LSP client
Lsp.start = function ()
  if not Lsp.is_installed () then
    if Lsp.config.auto_download then
      Lsp.download (function (success)
        if success then
          vim.schedule (function ()
            Lsp.attach ()
          end)
        end
      end)
    else
      log.info (
        "down.lsp not installed. Set config.lsp.auto_download = true or provide config.lsp.cmd"
      )
    end
    return
  end
  Lsp.attach ()
end

--- Attach LSP to current buffer
Lsp.attach = function ()
  local cmd_path = Lsp.bin_path ()
  if vim.fn.executable (cmd_path) ~= 1 then
    return
  end

  local client_id = vim.lsp.start ({
    name = "down-lsp",
    cmd = { cmd_path, "serve" },
    filetypes = Lsp.config.filetypes,
    root_dir = vim.fs.root (0, Lsp.config.root_markers) or vim.fn.getcwd (),
    workspace_folders = Lsp.workspace_folders (),
    settings = Lsp.config.settings,
    capabilities = vim.lsp.protocol.make_client_capabilities (),
  })

  if client_id then
    vim.lsp.buf_attach_client (0, client_id)
  end
end

Lsp.commands = {
  lsp = {
    name = "lsp",
    args = 0,
    max_args = 1,
    callback = function (e)
      Lsp.start ()
    end,
    commands = {
      start = {
        name = "lsp.start",
        args = 0,
        callback = function ()
          Lsp.start ()
        end,
      },
      install = {
        name = "lsp.install",
        args = 0,
        callback = function ()
          Lsp.download ()
        end,
      },
      status = {
        name = "lsp.status",
        args = 0,
        callback = function ()
          if Lsp.is_installed () then
            vim.notify (
              "[down.nvim] down.lsp is installed at: " .. Lsp.bin_path ()
            )
          else
            vim.notify ("[down.nvim] down.lsp is not installed")
          end
        end,
      },
    },
  },
}

Lsp.load = function ()
  vim.api.nvim_create_autocmd ("FileType", {
    pattern = Lsp.config.filetypes,
    callback = function ()
      Lsp.start ()
    end,
    desc = "Start down.lsp for markdown files",
  })
end

return Lsp
