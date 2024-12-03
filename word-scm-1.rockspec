local MODREV, SPECREV = "scm", "-1"
maintainer = "clpi"
license = "MIT"
detailed = [[
  Extensibility of org, comfort of markdown, for everyone
]]
description = [[
  Extensibility of org, comfort of markdown, for everyone
]]
labels = {
  "wiki",
  "neovim",
  "note",
  "capture",
  "obsidian",
  "org",
  "markdown",
  "vim",
  "nvim",
  "telekasten",
  "plugin",
  "org-mode",
}
summary = "Extensibility of org, comfort of markdown, for everyone"
rockspec_format = "3.0"
version = MODREV .. SPECREV
branch = "master"
tag = "v0.1.1-alpha"
local package_name = "word.lua"
local github_url = "https://github.com/"
  .. maintainer
  .. "/"
  .. package_name
  .. ".git"
local github_wiki_url = "https://github.com/"
  .. maintainer
  .. "/"
  .. package_name
  .. "/wiki"
local github_issues_url = "https://github.com/"
  .. maintainer
  .. "/"
  .. package_name
  .. "/issues"
local github_git_url = "git://github.com/"
  .. maintainer
  .. "/"
  .. package_name
  .. ".git"
local maintainer_url = "https://github.com/" .. maintainer
homepage = "https://word.cli.st"

source = {
  url = github_url,
  branch = branch,
  homepage = homepage,
  version = version,
  tag = version,
}

description = {
  homepage = homepage,
  package = package_name,
  issues_url = github_issues_url,
  version = version,
  detailed = detailed,
  description = description,
  summary = summary,
  url = github_url,
  labels = labels,
  maintainer = maintainer_url,
}

if MODREV == "scm" then
  source = {
    url = github_git_url,
    branch = branch,
    homepage = homepage,
    version = version,
    tag = nil,
  }
end

dependencies = {
  "lua == 5.4",
  "pathlib.nvim ~> 2.2",
  "nvim-nio ~> 1.7",
  "plenary.nvim == 0.1.4",
  "nui.nvim == 0.3.0",
}

test_dependencies = {
  "nlua",
  "nvim-treesitter == 0.9.2",
}

test = {
  type = "command",
  command = "make test",
}
--
deploy = {
  wrap_bin_scripts = true,
}

build = {
  type = "builtin",
  build_pass = false,
  modules = {},
  install = {
    bin = {
      wordls = "scripts/bin/wordls",
      word_lsp = "scripts/bin/word-lsp",
      word = "scripts/bin/word",
    },
  },
  copy_directories = {
    "queries",
    "plugin",
    "doc",
  },
}
--vim:ft=lua
