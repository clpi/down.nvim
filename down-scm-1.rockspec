MODREV, SPECREV = 'scm', '-1'
maintainer_user = 'clpi'
license = 'MIT'
detailed = [[
  Extensibility of org, comfort of markdown, for everyone
]]
desc = [[
  Extensibility of org, comfort of markdown, for everyone
]]
labels = {
  'wiki',
  'neovim',
  'note',
  'capture',
  'obsidian',
  'org',
  'markdown',
  'vim',
  'nvim',
  'telekasten',
  'plugin',
  'org-mode',
}
summary = 'Extensibility of org, comfort of markdown, for everyone'
rockspec_format = '3.0'
version = MODREV .. SPECREV
branch = 'master'
tag = 'v0.1.1-alpha'
package_name = 'down.nvim'
github_url = 'https://github.com/' .. maintainer .. '/' .. package_name .. '.git'
github_wiki_url = 'https://github.com/' .. maintainer .. '/' .. package_name .. '/wiki'
github_issues_url = 'https://github.com/' .. maintainer .. '/' .. package_name .. '/issues'
github_git_url = 'git://github.com/' .. maintainer .. '/' .. package_name .. '.git'
maintainer_url = 'https://github.com/' .. maintainer_user
maintainer_email = 'clp@clp.is'
homepage = 'https://down.cli.st'
maintainer = 'Chris Pecunies <' .. maintainer_email .. '>'

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
  description = desc,
  summary = summary,
  url = github_url,
  labels = labels,
  maintainer = maintainer,
}

if MODREV == 'scm' then
  source = {
    url = github_git_url,
    branch = branch,
    homepage = homepage,
    version = version,
    tag = nil,
  }
end

dependencies = {
  'lua == 5.4',
  'nvim-nio ~> 1.7',
}

test_dependencies = {
  'nlua',
  'nvim-treesitter == 0.9.2',
}

test = {
  type = 'command',
  command = 'make test',
}
--
deploy = {
  wrap_bin_scripts = true,
}

build = {
  type = 'builtin',
  build_pass = false,
  modules = {},
  install = {
    bin = {
      downls = './scripts/bin/down-lsp.sh',
      down_lsp = './scripts/bin/down-lsp',
      down = './scripts/bin/down',
    },
  },
  copy_directories = {
    'queries',
    'plugin',
    'doc',
  },
}
--vim:ft=lua
