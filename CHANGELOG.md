# Changelog

## Unreleased

### Added
- org-mode feature parity: execute fenced code blocks in markdown
  - `down code` CLI subcommand (Lua + Go) runs every runnable fenced block in a
    markdown file (`--lang`, `--list`, `--dry-run`, `--timeout`, `--cwd`)
  - `down.code` library: parse fences, detect runnable languages, run blocks
    via the matching interpreter (lua, python, bash, ruby, node, ts, go, rust,
    perl, php, R, julia, scheme, clojure, haskell, elixir, erlang, powershell,
    fish, zsh, awk)
  - `down.mod.code` Neovim mod with `:Down code run [lang|N]`, `:Down code
    cursor`, `:Down code list`, and `:Down code lens on|off`
  - Inline codelens: "▶ Run [lang]" virtual text on runnable blocks plus a
    buffer-local run key, refreshed on buffer changes
- org-babel feature parity (code blocks)
  - Header args: `:tangle FILE|yes`, `:mkdirp yes`, `:var NAME=VALUE`,
    `:noweb yes|tangle`, `:name NAME` parsed from the fence info string
  - Tangle: `down code tangle [options] <file>` (Lua + Go) and `:Down code
    tangle [dir]` write `:tangle` blocks to files
  - Noweb: `<<name>>` references expand from named blocks before running/tangling
  - Vars: `:var NAME=VALUE` (string/number/bool) injected per-language
  - Results: `--results` (CLI) / `:Down code results on|off` insert/replace
    `:down_result` blocks after each executed block
  - Src edit: `:Down code edit` opens the block at the cursor in an indirect
    scratch buffer with the native filetype; `:w` writes the body back into
    the source block (org `C-c '` parity)
- org-footnote parity: `down.mod.footnote` mod
  - `:Down footnote` jumps reference <-> definition, `:Down footnote add`
    creates a `[^N]` reference plus definition, `:Down footnote list` lists
    footnotes with reference counts
  - `<leader>dfo` / `<leader>dfa` / `<leader>dfl` keymaps

## 0.1.2-alpha (2024-12-15)

## 0.1.1-alpha

## 0.1.0-alpha.1

