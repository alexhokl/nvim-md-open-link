package.path = table.concat({
	"./lua/?.lua",
	"./lua/?/init.lua",
	"./spec/?.lua",
	package.path,
}, ";")

local function make_node(node_type, parent, children)
	local node = {}
	node._type = node_type
	node._parent = parent
	node._children = children or {}

	function node:type()
		return self._type
	end

	function node:parent()
		return self._parent
	end

	function node:named_child(index)
		return self._children[index + 1]
	end

	return node
end

describe("nvim-md-open-link", function()
	local recorded
	local cursor_node
	local module
	local original_io
	local original_vim

	before_each(function()
		original_io = _G.io
		original_vim = _G.vim
		recorded = {
			jobstart_calls = {},
			keymap_calls = {},
			prints = {},
		}

		cursor_node = nil

		_G.vim = setmetatable({
			loop = {
				os_uname = function()
					return { sysname = "Linux" }
				end,
			},
			fn = {
				jobstart = function(cmd, opts)
					table.insert(recorded.jobstart_calls, { cmd = cmd, opts = opts })
					return 1
				end,
			},
			keymap = {
				set = function(mode, lhs, rhs, opts)
					table.insert(recorded.keymap_calls, {
						mode = mode,
						lhs = lhs,
						rhs = rhs,
						opts = opts,
					})
				end,
			},
			treesitter = {
				get_node_text = function(node, _)
					return node and node._text or nil
				end,
			},
			tbl_deep_extend = function(_, defaults, options)
				local merged = {}
				for k, v in pairs(defaults) do
					merged[k] = v
				end
				for k, v in pairs(options or {}) do
					merged[k] = v
				end
				return merged
			end,
			print = function(msg)
				table.insert(recorded.prints, msg)
			end,
		}, { __index = original_vim })

		package.loaded["nvim-treesitter.ts_utils"] = {
			get_node_at_cursor = function()
				return cursor_node
			end,
		}

		package.loaded["nvim-md-open-link"] = nil
		module = require("nvim-md-open-link")
	end)

	after_each(function()
		package.loaded["nvim-md-open-link"] = nil
		package.loaded["nvim-treesitter.ts_utils"] = nil
		_G.vim = original_vim
		_G.io = original_io
	end)

	it("registers default keymap", function()
		module.setup()

		assert.are.equal(1, #recorded.keymap_calls)
		assert.are.equal("n", recorded.keymap_calls[1].mode)
		assert.are.equal("gb", recorded.keymap_calls[1].lhs)
		assert.is_true(recorded.keymap_calls[1].opts.noremap)
		assert.is_function(recorded.keymap_calls[1].rhs)
	end)

	it("registers configured keymap", function()
		module.setup({ keymap = "go" })

		assert.are.equal("go", recorded.keymap_calls[1].lhs)
	end)

	it("validates supported links", function()
		assert.is_true(module._test.is_valid_link("http://example.com"))
		assert.is_true(module._test.is_valid_link("https://example.com"))
		assert.is_false(module._test.is_valid_link("mailto:test@example.com"))
		assert.is_false(module._test.is_valid_link(nil))
	end)

	it("resolves inline link node from current node", function()
		local inline = make_node("inline_link")
		assert.are.equal(inline, module._test.resolve_inline_link_node(inline))
	end)

	it("resolves inline link node from parent", function()
		local inline = make_node("inline_link")
		local child = make_node("link_text", inline)

		assert.are.equal(inline, module._test.resolve_inline_link_node(child))
	end)

	it("returns nil when no inline link node exists", function()
		local parent = make_node("paragraph")
		local child = make_node("text", parent)

		assert.is_nil(module._test.resolve_inline_link_node(child))
		assert.is_nil(module._test.resolve_inline_link_node(nil))
	end)

	it("extracts URL from inline link node", function()
		local url_node = { _text = "https://example.com" }
		local inline = make_node("inline_link", nil, { nil, url_node })

		assert.are.equal("https://example.com", module._test.extract_url_from_link_node(inline))
	end)

	it("returns nil when URL child is missing", function()
		local inline = make_node("inline_link")

		assert.is_nil(module._test.extract_url_from_link_node(inline))
		assert.is_nil(module._test.extract_url_from_link_node(nil))
	end)

	it("builds command for supported OS combinations", function()
		assert.are.same(
			{ "qutebrowser", "https://example.com" },
			module._test.browser_command_for("Linux", true, "https://example.com")
		)
		assert.are.same(
			{ "open", "https://example.com" },
			module._test.browser_command_for("Darwin", false, "https://example.com")
		)
		assert.are.same(
			{ "xdg-open", "https://example.com" },
			module._test.browser_command_for("Linux", false, "https://example.com")
		)
		assert.are.same(
			{ "cmd", "/c", "start", "https://example.com" },
			module._test.browser_command_for("Windows", false, "https://example.com")
		)
		assert.are.same(
			{ "cmd", "/c", "start", "https://example.com" },
			module._test.browser_command_for("Windows_NT", false, "https://example.com")
		)
		assert.is_nil(module._test.browser_command_for("Plan9", false, "https://example.com"))
	end)

	it("checks qutebrowser on posix", function()
		local popen_calls = {}

		_G.io = {
			popen = function(cmd)
				table.insert(popen_calls, cmd)
				return {
					read = function()
						return "/usr/bin/qutebrowser\n"
					end,
					close = function()
					end,
				}
			end,
		}

		assert.is_true(module._test.qute_browser_exist("Linux"))
		assert.are.same({ "command -v qutebrowser" }, popen_calls)
	end)

	it("checks qutebrowser on windows powershell", function()
		local popen_calls = {}

		_G.io = {
			popen = function(cmd)
				table.insert(popen_calls, cmd)
				return {
					read = function()
						return ""
					end,
					close = function()
					end,
				}
			end,
		}

		assert.is_false(module._test.qute_browser_exist("Windows"))
		assert.are.same({ "(Get-Command qutebrowser).Source" }, popen_calls)
	end)

	it("prints when no node found", function()
		module._test.try_open_link()

		assert.are.same({ "No link found" }, recorded.prints)
		assert.are.equal(0, #recorded.jobstart_calls)
	end)

	it("prints when node is not a link", function()
		cursor_node = make_node("text", make_node("paragraph"))

		module._test.try_open_link()

		assert.are.same({ "No link found" }, recorded.prints)
		assert.are.equal(0, #recorded.jobstart_calls)
	end)

	it("prints when URL is invalid", function()
		local url_node = { _text = "ftp://example.com" }
		local inline = make_node("inline_link", nil, { nil, url_node })
		cursor_node = inline

		module._test.try_open_link()

		assert.are.same({ "Invalid link" }, recorded.prints)
		assert.are.equal(0, #recorded.jobstart_calls)
	end)

	it("opens using OS fallback command", function()
		local popen_calls = {}

		_G.io = {
			popen = function(cmd)
				table.insert(popen_calls, cmd)
				return {
					read = function()
						return ""
					end,
					close = function()
					end,
				}
			end,
		}

		local url_node = { _text = "https://example.com" }
		cursor_node = make_node("inline_link", nil, { nil, url_node })

		module._test.try_open_link()

		assert.are.equal(1, #recorded.jobstart_calls)
		assert.are.same({ "xdg-open", "https://example.com" }, recorded.jobstart_calls[1].cmd)
		assert.is_nil(recorded.jobstart_calls[1].opts)
		assert.are.same({ "command -v qutebrowser" }, popen_calls)
	end)

	it("opens with qutebrowser and handles non-zero exit", function()
		_G.io = {
			popen = function()
				return {
					read = function()
						return "/usr/bin/qutebrowser\n"
					end,
					close = function()
					end,
				}
			end,
		}

		local url_node = { _text = "https://example.com" }
		cursor_node = make_node("inline_link", nil, { nil, url_node })

		module._test.try_open_link()

		assert.are.equal(1, #recorded.jobstart_calls)
		assert.are.same({ "qutebrowser", "https://example.com" }, recorded.jobstart_calls[1].cmd)
		assert.is_table(recorded.jobstart_calls[1].opts)
		recorded.jobstart_calls[1].opts.on_exit(nil, 1)
		assert.are.same({ "Failed to open link in qutebrowser" }, recorded.prints)
	end)
end)
