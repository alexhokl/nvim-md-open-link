local M = {}

local ts_utils = require("nvim-treesitter.ts_utils")

local default_options = {
	-- Keymap to open the link
	keymap = "gb",
}

local is_valid_link = function(url)
	if url:match("^https?://") then
		return true
	end
end

local open_link = function(url)
	local os = vim.loop.os_uname().sysname
	if os == "Darwin" then
		vim.fn.jobstart({ "open", url })
		return
	elseif os == "Linux" then
		vim.fn.jobstart({ "xdg-open", url })
		return
	elseif os == "Windows" then
		vim.fn.jobstart({ "cmd", "/c", "start", url })
		return
	end
end

local try_open_link = function()
	local node = ts_utils.get_node_at_cursor()
	if node == nil then
		vim.print("No link found")
		return
	end

	local parent = node:parent()
	local link_node = nil

	if node:type() == "inline_link" then
		link_node = node
	elseif parent ~= nil and parent:type() == "inline_link" then
		link_node = parent
	end

	if link_node == nil then
		vim.print("No link found")
		return
	end

	local url_node = link_node:named_child(1)
	local url = vim.treesitter.get_node_text(url_node, 0)
	if not is_valid_link(url) then
		vim.print("Invalid link")
		return
	end

	open_link(url)
end

M.setup = function(options)
	M.options = vim.tbl_deep_extend("force", default_options, options or {})
	vim.keymap.set("n", M.options.keymap, try_open_link, { noremap = true })
end

return M
