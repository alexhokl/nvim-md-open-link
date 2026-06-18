# AGENTS.md

## Repository overview

Single-file Neovim plugin runtime implementation. Core code lives in
`lua/nvim-md-open-link.lua`, with tests in `spec/nvim-md-open-link_spec.lua`
and task automation in `Taskfile.yaml`. No build system, no CI, no lockfiles.

## Runtime dependency

Requires `nvim-treesitter` (`nvim-treesitter.ts_utils`). This is a hard
dependency — the `require` call is at module load time, not lazy-loaded.

## How the plugin works

- Entry point: `M.setup(options)` registers a normal-mode keymap (default `gb`).
- On keypress, `try_open_link()` uses treesitter to find an `inline_link` node
  at cursor, extracts the URL from `named_child(1)`, validates `http://` or
  `https://` prefix, then calls `open_link(url)`.
- Browser priority: `qutebrowser` (if on `$PATH`) → `open` (macOS) →
  `xdg-open` (Linux) → `cmd /c start` (Windows). All launched via
  `vim.fn.jobstart()`.

## Only configurable option

```lua
opts = { keymap = "gb" }  -- default
```

## Test tooling

- `task setup` installs `nlua` and `busted` via LuaRocks (Lua 5.1).
- `task test` runs the full test suite with the LuaRocks environment loaded.
- `task test:verbose` runs the suite with verbose output.
- `task test:file FILE=spec/xxx_spec.lua` runs one spec file.

The task commands load LuaRocks paths before running `busted`, so they work
even when `busted` is not on the default shell `PATH`.

## Manual runtime check

Manual runtime testing requires loading the plugin inside Neovim with
`nvim-treesitter` installed and a markdown file open.

## Testing caveat (nlua)

In specs, do not fully replace `_G.vim` with a plain table when running under
`nlua`; preserve the original `vim` table (for example via metatable fallback)
and override only needed fields. Replacing `_G.vim` can break internal
`vim._init_packages` expectations (for example missing `vim.api`).

## Adding features — things to watch

- The treesitter node type `"inline_link"` is specific to the markdown grammar.
  If extending to other link types (e.g. `link_destination`, `image`), verify
  node type names against the actual grammar.
- `is_valid_link` only accepts `http://` and `https://` — file:// and other
  schemes are silently rejected.
- `qute_browser_exist()` uses `command -v` (POSIX) or PowerShell on Windows;
  test both code paths if touching that function.
