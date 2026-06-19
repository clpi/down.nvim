# CLI

The `down` command-line tool provides a standalone interface for working with
your down workspace. It runs as a native Go binary with all features available
from the terminal.

## Installation

```bash
# Build from source
cd ext/down && go build -o down .

# Or download from releases (auto-installed by plugin)
curl -L https://github.com/clpi/down.nvim/releases/latest/download/down-darwin-arm64.tar.gz | tar xz
```

## Global Configuration

- Config: `~/.config/down/` — profiles, settings
- Data: `~/.local/share/down/` — memory, cache, workspace data
- Cache: `~/.cache/down/` — logs, temp files

## Commands

### `down init [path]`

Initialize a new down workspace. Creates `.down/` with `index.md`, `down.json`,
`.downignore`, and `data/` directory.

```bash
down init                    # Init in current directory
down init /path/to/project   # Init in specific directory
down init --name myproject   # Set workspace name
```

### `down compact [directory]`

Pack a directory into an AI-friendly XML or markdown format. Respects
`.downignore` patterns, excludes binary files, and generates directory trees.

```bash
down compact .                          # XML to stdout
down compact . -f markdown -o pack.md   # Markdown to file
down compact . --no-tokens              # Omit token count
```

### `down skills [directory]`

Generate a project SKILL.md analyzing languages, dependencies, entry points,
structure, and conventions.

```bash
down skills .                           # To stdout
down skills . -o docs/SKILL.md          # To file
```

### `down add <source>`

Add files, directories, URLs, or named concepts to `.down/data/` as repomix-style
markdown with frontmatter metadata.

```bash
down add README.md              # File → compact markdown
down add src/                   # Directory → compact
down add https://example.com    # URL → markdown fetch
down add context                # Bare word → create context.md
down add notes/                 # Trailing / → create dir with index.md
```

### `down ignore <pattern>`

Append patterns to the nearest `.down/.downignore` file. Patterns use
gitignore-compatible glob syntax.

```bash
down ignore "*.log"
down ignore "tmp/" "*.bak"
```

### `down workspace <subcommand>`

Manage workspaces across profiles.

```bash
down workspace add myproj /path   # Add workspace
down workspace list               # List all (with active marker)
down workspace switch myproj      # Switch active workspace
down workspace remove myproj      # Remove workspace
```

### `down profile <subcommand>`

Manage profiles — named sets of workspaces.

```bash
down profile add work             # Create profile
down profile list                 # List profiles (with active marker)
down profile switch work          # Switch profile (loads its workspaces)
down profile remove work          # Delete profile
```

### `down memory <subcommand>`

Persistent AI memory store. Entries are stored as JSON files in
`~/.local/share/down/memory/`.

```bash
down memory add api-key "sk-xxx" --tag secrets    # Store with tags
down memory show api-key                           # Show entry
down memory search "api"                           # Search
down memory list                                   # List all
down memory delete api-key                         # Delete
down memory export memories.json                   # Export all
down memory import memories.json                   # Import from file
```

### `down context [directory]`

Generate a comprehensive AI project context document at `.down/context.md`.

```bash
down context .                                    # Generate context
down context . -p "Fix all bugs in this project"  # With task prompt
```

### `down mcp`

Start the Model Context Protocol server on stdio. Provides 12 tools for AI
agents: workspace management, note search/read, knowledge graph, memory,
tasks, and note creation.

```bash
down mcp    # Start MCP server
```

### `down serve`

Start the full LSP server (language server protocol).

### `down run`

Run the LSP binary directly.

### `down config`

View and set configuration values.

## Neovim Integration

All commands are available inside Neovim via `:Down`:

- `:Down init` — Initialize workspace
- `:Down compact` — Opens package output in a buffer
- `:Down skills` — Opens SKILL.md in a buffer
- `:Down add <source>` — Add to data dir
- `:Down ignore <pattern>` — Append to .downignore
- `:Down workspace add/list/switch/remove`
- `:Down profile add/list/switch/remove` — Switches workspace data
- `:Down memory add/show/list/search/delete`
- `:Down context` — Generate and open context
- `:Down chat` — AI chat interface
