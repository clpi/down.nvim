# Philosophy

## Workspaces: Markdown Context Inside Codebases

A **down workspace** is a `.down/` directory living inside an existing codebase.
It transforms any project directory into a self-documenting, AI-aware knowledge
environment without disrupting the codebase structure.

```
your-project/
├── src/                   # Your code (untouched)
├── .git/                  # Git history (untouched)
├── .down/                 # ← down workspace
│   ├── index.md           # Workspace home page
│   ├── down.json          # Workspace config
│   ├── .downignore        # Ignore patterns
│   ├── data/              # Ingested files (repomix-style compacted)
│   ├── knowledge/         # Knowledge graph index
│   ├── memory/            # Persistent AI memory entries
│   ├── context/           # AI context documents
│   ├── vector/            # Vector embeddings store
│   └── notes/             # Workspace-local notes
```

### Key Principles

**1. Markdown is the universal interface.** Every piece of information — notes,
tasks, database rows, knowledge graph entities, memory entries — lives as
markdown. This means everything is human-readable, git-versionable, and
AI-compatible.

**2. The codebase is the root.** Workspaces are nested inside projects, not
separate vaults. When you open a project, its `.down/` context is immediately
available. Your code documentation stays with your code.

**3. AI is first-class.** Every workspace feature is designed to be consumed by
both humans and AI agents:
- `down compact` produces repomix-style AI packs
- `down context` generates project context for AI coding
- `down memory` stores persistent AI memory
- The knowledge graph indexes entities for semantic search
- Vector embeddings enable similarity queries
- The MCP server exposes 12+ tools to AI agents

**4. Progressive enhancement.** A `.down/` directory is optional. Projects work
fine without one. Adding a workspace progressively enhances the project with
knowledge management, AI context, and automation.

## Workspace Types

### Code Workspace (default)
The standard mode. `.down/` lives alongside source code. Compact and export
smartly filter out vendored dependencies. Perfect for software projects.

### Wiki Workspace
Configured with `wiki: true` in `down.json`. Optimized for pure markdown
content — knowledge bases, wikis, journals, digital gardens. All commands
work identically, but defaults shift toward content management.

### Profile Workspaces
Managed via `~/.config/down/down.json`. Profiles group workspaces by
context (work, personal, project-specific). Switch profiles to load
different workspace sets.

## Data Flow

```
Source Code / Notes
       ↓
  .down/ workspace
       ↓
  ┌────┼────┬────────┬──────────┐
  │    │    │        │          │
data  know- memory  context   vector
      ledge
  │    │    │        │          │
  ↓    ↓    ↓        ↓          ↓
compact skills  memory  context   embed
 export  MCP    MCP     MCP      search
publish
```

## Compared to Other Tools

| Feature | down.nvim | Notion | Obsidian | org-mode |
|---------|-----------|--------|----------|----------|
| Lives in codebase | ✓ | ✗ | ✓ | ✓ |
| Git-versionable | ✓ | ✗ | ✓ | ✓ |
| AI-native (MCP/compact) | ✓ | Limited | Limited | ✗ |
| CLI-first | ✓ | ✗ | ✗ | Partial |
| Embedded in editor | ✓ (Neovim) | ✗ | ✗ | ✓ (Emacs) |
| Database views | ✓ | ✓ | Partial | Partial |
| Static site publish | ✓ | ✓ | ✓ | ✓ |

## Getting Started

```bash
# Initialize a workspace in any project
cd your-project
down init

# Add context files
down add README.md            # Compact existing files
down add https://docs.example.com  # Fetch web content
down add architecture          # Create new topic note

# Generate AI context
down context . -p "Explain this codebase"

# Sync all workspace data
down sync
```
