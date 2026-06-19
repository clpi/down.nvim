# CLI

The `down` command-line tool provides a standalone interface for working with
your down.nvim workspace and generating AI-friendly project dumps.

## Installation

```bash
# Link to a directory in your PATH
ln -s ./scripts/bin/down /usr/local/bin/down

# Or copy
cp ./scripts/bin/down /usr/local/bin/down
```

## Commands

### `down compact`

Pack a directory into an AI-friendly XML or markdown format, similar to repomix.
Respects `.gitignore`, excludes binary files, and generates a directory tree.

```bash
down compact [options] [directory]
```

| Option | Description |
|--------|-------------|
| `-o, --output FILE` | Write output to file (default: stdout) |
| `-f, --format FMT` | Output format: `xml` (default), `markdown` |
| `--no-tree` | Omit directory tree |
| `--no-tokens` | Omit token count |
| `-h, --help` | Show help |

**Examples:**

```bash
# Pack current directory to stdout in XML format
down compact .

# Pack to a file in markdown format
down compact . -f markdown -o project-pack.md

# Pack without directory tree
down compact /path/to/project --no-tree
```

### `down skills`

Generate a `SKILL.md` file for your project that describes its structure,
languages, dependencies, entry points, and conventions. Ideal for providing
context to AI coding agents.

```bash
down skills [options] [directory]
```

| Option | Description |
|--------|-------------|
| `-o, --output FILE` | Output path (default: `SKILL.md`) |
| `--no-arch` | Skip architecture section |
| `--no-deps` | Skip dependencies section |
| `--no-entries` | Skip entry points section |
| `--no-conventions` | Skip conventions section |
| `-h, --help` | Show help |

**Examples:**

```bash
# Generate SKILL.md in current directory
down skills .

# Generate with custom output path
down skills /path/to/project -o docs/SKILL.md
```

### `down workspace`

List and manage workspaces.

### `down init`

Initialize a new workspace.

### `down note`

Note-taking functionality.

### `down config`

View and set configuration values.

### `down serve`

Start the LSP server.

### `down run`

Run the LSP binary directly.

## Neovim Integration

The same functionality is available inside Neovim:

- `:Down compact` — Opens package output in a new buffer
- `:Down skills` — Opens generated SKILL.md in a new buffer
