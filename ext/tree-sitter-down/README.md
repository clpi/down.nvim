# tree-sitter-down

> [tree-sitter](https://tree-sitter.github.io/) grammar for the [down](https://github.com/clpi/down.nvim) markup language.

`down` is a markdown superset for developer-focused note-taking. It extends CommonMark with tags (`@tag`, `#tag`), wiki links (`[[target]]`), embeds (`![[file]]`), task markers (`~~todo~~`), and line/block comments (`--`, `-/ ... /-`).

## Building

```sh
npm install
npx tree-sitter generate
npx tree-sitter build-wasm   # optional: for wasm output
```

## Using with Neovim

```lua
-- After building, copy the shared object to your parser path:
-- ~/.local/share/nvim/lazy/nvim-treesitter/parser/down.so
-- and copy queries/ to ~/.local/share/nvim/lazy/nvim-treesitter/queries/down/
```

## Using with Helix

Copy the compiled shared library and `queries/` into your Helix runtime:

```sh
cp libdown.so ~/.config/helix/runtime/grammars/down.so
cp -r queries/ ~/.config/helix/runtime/queries/down/
```

## License

MIT
