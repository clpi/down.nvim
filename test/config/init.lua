local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end
vim.opt.runtimepath = vim.opt.runtimepath:append(lazypath)
vim.opt.runtimepath = vim.opt.runtimepath:append(".")
vim.wo.foldmethod = "expr"
vim.wo.foldenable = false
vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.rtp:prepend(lazypath)
vim.opt.termguicolors = true
vim.opt.nu = true
vim.opt.relativenumber = true

vim.o.swapfile = false
vim.bo.swapfile = false
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true
vim.o.swapfile = false
vim.opt.conceallevel = 2
vim.opt.winbar = [[down.nvim]]
vim.opt.signcolumn = [[yes:2]]
vim.bo.swapfile = false
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.o.splitbelow = true
vim.o.splitright = true
vim.opt.inccommand = "nosplit"

vim.opt.updatetime = 100
vim.opt.termguicolors = true

vim.opt.scrolloff = 8

-- vim.o.completeopt = { "menu", "menuone", "noselect", "popup" }
vim.g.mapleader = " "
vim.g.maplocalleader = ","

vim.keymap.set("i", "kj", "<Esc>")

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

vim.keymap.set("x", "<leader>p", [["_dP]])

vim.keymap.set("n", "Q", "<nop>")

vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

vim.opt.cursorline = true

-- Line settings
vim.opt.wrap = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.statuscolumn = "%s%=%{v:relnum?v:relnum:v:lnum} "

-- Mode is already in status line plugin
vim.opt.showmode = true
vim.opt.number = true
vim.opt.conceallevel = 2
vim.opt.concealcursor = [[nv]]
vim.opt.winbar = "down.nvim"
vim.opt.signcolumn = "yes:2"
vim.cmd([[
nno L <CMD>bn<CR>
nno H <CMD>bp<CR>
nno ; :
]])
vim.o.updatetime = 100

require("lazy").setup({
  "JoosepAlviste/nvim-ts-context-commentstring",
  {
    "folke/tokyonight.nvim",
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require("tokyonight").setup({ style = "night" })
      vim.cmd.colorscheme("tokyonight")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        sections = {
          lualine_a = { "mode" },
          lualine_b = { { "filename", path = 0 } },
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = { "location" },
        },
      })
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    opts = {},
  },
  "JoosepAlviste/nvim-ts-context-commentstring",
  {
    dir = "~/clp/down.nvim",
    lazy = false,
    version = false,

    dependencies = {
      { "nvim-telescope/telescope.nvim" },
      { "nvim-treesitter/nvim-treesitter" },
    },
    opts = {
      workspace = {
        default = "wiki",
        workspaces = {
          notes = "~/notes",
          wiki = "~/wiki",
          book = "~/w/book/src/",
          clp = "~/clp",
        },
      },
    },
    {
      "echasnovski/mini.doc",
      version = false,
      config = function()
        require("mini.doc").setup({})
      end,
    },
    {
      "saghen/blink.cmp",
      enabled = true,
      lazy = false, -- lazy loading handled internally
      -- optional: provides snippets for the snippet source
      dependencies = "rafamadriz/friendly-snippets",

      -- use a release tag to download pre-built binaries
      version = "v0.*",
      -- OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
      -- build = 'cargo build --release',
      -- If you use nix, you can build from source using latest nightly rust with:
      -- build = 'nix run .#build-plugin',

      ---@module 'blink.cmp'
      ---@type blink.cmp.Config
      opts = {
        keymap = {
          ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
          ["<Up>"] = { "select_prev", "fallback" },
          ["<Down>"] = { "select_next", "fallback" },
          ["<C-N>"] = { "select_next", "show" },
          ["<C-P>"] = { "select_prev", "show" },
          ["<C-J>"] = { "select_next", "fallback" },
          ["<C-K>"] = { "select_prev", "fallback" },
          ["<C-U>"] = { "scroll_documentation_up", "fallback" },
          ["<C-D>"] = { "scroll_documentation_down", "fallback" },
          ["<C-e>"] = { "hide", "fallback" },
          ["<CR>"] = { "accept", "fallback" },
          --   ["<Tab>"] = {
          --     function(cmp)
          --       if cmp.windows.autocomplete.win:is_open() then
          --         return cmp.select_next()
          --       elseif cmp.is_in_snippet() then
          --         return cmp.snippet_forward()
          --       elseif has_words_before() then
          --         return cmp.show()
          --       end
          --     end,
          --     "fallback",
          --   },
          --   ["<S-Tab>"] = {
          --     function(cmp)
          --       if cmp.windows.autocomplete.win:is_open() then
          --         return cmp.select_prev()
          --       elseif cmp.is_in_snippet() then
          --         return cmp.snippet_backward()
          --       end
          --     end,
          --     "fallback",
          --   },
        },
        sources = {
          completion = {
            enabled_providers = { "lsp", "path", "snippets", "buffer" },
          },
          -- lazydev = {
          --
          --   name = "LazyDev",
          --   module = "lazydev.integration.blink",
          -- },

          providers = {
            lsp = {
              name = "LSP",
              module = "blink.cmp.sources.lsp",
              -- fallback_for = { "lazydev" },

              --- *All* of the providers have the following options available
              --- NOTE: All of these options may be functions to get dynamic behavior
              --- See the type definitions for more information
              enabled = true, -- whether or not to enable the provider
              transform_items = nil, -- function to transform the items before they're returned
              should_show_items = true, -- whether or not to show the items
              max_items = nil, -- maximum number of items to return
              min_keyword_length = 0, -- minimum number of characters to trigger the provider
              fallback_for = {}, -- if any of these providers return 0 items, it will fallback to this provider
              score_offset = 0, -- boost/penalize the score of the items
              override = nil, -- override the source's functions
            },
            path = {
              name = "Path",
              module = "blink.cmp.sources.path",
              score_offset = 3,
              opts = {
                trailing_slash = false,
                label_trailing_slash = true,
                get_cwd = function(context)
                  return vim.fn.expand(("#%d:p:h"):format(context.bufnr))
                end,
                show_hidden_files_by_default = false,
              },
            },
            snippets = {
              name = "Snippets",
              enabled = false,
              module = "blink.cmp.sources.snippets",
              score_offset = -3,
              opts = {
                friendly_snippets = true,
                search_paths = { vim.fn.stdpath("config") .. "/snippets" },
                global_snippets = { "all" },
                extended_filetypes = {},
                ignored_filetypes = {},
              },

              --- Example usage for disabling the snippet provider after pressing trigger characters (i.e. ".")
              -- enabled = function(ctx) return ctx ~= nil and ctx.trigger.kind == vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter end,
            },
            buffer = {
              enabled = false,
              name = "Buffer",
              module = "blink.cmp.sources.buffer",
              fallback_for = { "lsp" },
            },
          },
        },
        signature_help = {
          enabled = true,
        },
        nerd_font_variant = "normal",
        highlight = {
          -- sets the fallback highlight groups to nvim-cmp's highlight groups
          -- useful for when your theme doesn't support blink.cmp
          -- will be removed in a future release, assuming themes add support
          use_nvim_cmp_as_default = true,
        },
        -- set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- adjusts spacing to ensure icons are aligned

        -- experimental auto-brackets support
        accept = { auto_brackets = { enabled = true } },

        -- experimental signature help support
        trigger = { signature_help = { enabled = true } },
      },
      opts_extend = {
        "sources.completion.enabled_providers",
      },
      specs = {
        {
          "folke/lazydev.nvim",
          optional = true,
          specs = {
            {
              "Saghen/blink.cmp",
              opts = function(_, opts)
                if pcall(require, "lazydev.integrations.blink") then
                  -- return require("astrocore").extend_tbl(opts, {
                  -- sources = {
                  -- add lazydev to your completion providers
                  -- },
                  -- })
                end
              end,
            },
          },
        },
      },
    },
  },
})
-- vim.lsp.handle_attach(function(client, bufnr)
--   local opts = { buffer = bufnr, remap = false }
--
--   if client.name == "eslint" then
--     vim.cmd.LspStop('eslint')
--     return
--   end
--
--   vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
--   vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
--   vim.keymap.set("n", "<leader>vws", vim.lsp.buf.workspace_symbol, opts)
--   vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float, opts)
--   vim.keymap.set("n", "[d", vim.diagnostic.goto_next, opts)
--   vim.keymap.set("n", "]d", vim.diagnostic.goto_prev, opts)
--   vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action, opts)
--   vim.keymap.set("n", "<leader>vrr", vim.lsp.buf.references, opts)
--   vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename, opts)
--   vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, opts)
-- end)
