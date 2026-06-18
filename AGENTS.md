# AGENTS.md

## Repository overview

Two-file Neovim plugin. Implementation is split across:

- `lua/nvim-md-open-link/link.lua` — pure logic (testable, no side effects)
- `lua/nvim-md-open-link/init.lua` — side-effectful entry point (keymap, browser
  dispatch)

## Runtime dependency

Requires `nvim-treesitter` for its markdown/markdown_inline parsers. The
`nvim-treesitter.ts_utils` module is **not** used; the plugin queries the
`markdown_inline` injected child parser directly via
`vim.treesitter.get_parser()`.

## How the plugin works

- Entry point: `M.setup(options)` registers a normal-mode keymap (default `gb`).
- On keypress, `try_open_link()` calls `link.get_inline_node_at(row, col)` to
  get the deepest node from the `markdown_inline` injected treesitter tree, then
  passes it to `link.get_url_from_node(node)` to extract the URL.
- `get_url_from_node` walks up at most one level from the cursor node to find an
  `inline_link` node, then returns the text of its second named child
  (`link_destination`).
- The URL is validated with `link.is_valid_link(url)` (`http://` or `https://`
  only), then passed to `open_link(url)`.
- Browser priority: `qutebrowser` (if on `$PATH`) → `open` (macOS) →
  `xdg-open` (Linux) → `cmd /c start` (Windows). All launched via
  `vim.fn.jobstart()`.

## Why markdown_inline, not markdown

Treesitter parses markdown in two passes. The block-level `markdown` parser
only sees `inline` nodes; `inline_link` lives in the injected `markdown_inline`
grammar. `ts_utils.get_node_at_cursor()` returns block-level nodes and therefore
never finds `inline_link` — the plugin queries the injected child parser
directly.

## Only configurable option

```lua
opts = { keymap = "gb" }  -- default
```

## Running tests

One-time setup (requires luarocks):

```sh
task setup
```

Run all tests:

```sh
task test
```

Run a single spec file:

```sh
task test-file -- spec/link_spec.lua
```

Tests use [busted](https://lunarmodules.github.io/busted/) with
[nlua](https://github.com/mfussenegger/nlua) as the Lua interpreter. All
dependencies must be installed for **Lua 5.1 (LuaJIT)**; using a different Lua
version causes nlua to fail loading compiled `.so` files.

## Adding features — things to watch

- `inline_link` and `link_destination` are node types from the
  `markdown_inline` grammar. If extending to other link types (e.g. `image`,
  `autolink`), verify node type names against that grammar.
- `get_inline_node_at` iterates all trees from the `markdown_inline` child
  parser and picks the one whose range contains the cursor. If the cursor is
  not inside any inline content (e.g. blank line), it returns `nil`.
- `is_valid_link` only accepts `http://` and `https://` — `file://` and other
  schemes are silently rejected.
- `qute_browser_exist()` uses `command -v` (POSIX) or PowerShell on Windows;
  test both code paths if touching that function.
