# AGENTS.md

## Repository overview

Single-file Neovim plugin (~96 lines). Entire implementation lives in
`lua/nvim-md-open-link.lua`. No build system, no tests, no CI, no lockfiles.

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

## No tooling to run

There are no lint, test, format, or build commands — none exist. Manual
testing requires loading the plugin inside Neovim with `nvim-treesitter`
installed and a markdown file open.

## Adding features — things to watch

- The treesitter node type `"inline_link"` is specific to the markdown grammar.
  If extending to other link types (e.g. `link_destination`, `image`), verify
  node type names against the actual grammar.
- `is_valid_link` only accepts `http://` and `https://` — file:// and other
  schemes are silently rejected.
- `qute_browser_exist()` uses `command -v` (POSIX) or PowerShell on Windows;
  test both code paths if touching that function.
