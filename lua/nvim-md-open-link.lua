local M = {}

local ts_utils = require("nvim-treesitter.ts_utils")

local default_options = {
	-- Keymap to open the link
	keymap = "gb",
}

local function is_windows(os_name)
	return os_name == "Windows" or os_name == "Windows_NT"
end

local function is_valid_link(url)
	if type(url) ~= "string" then
		return false
	end

	if url:match("^https?://") then
		return true
	end

	return false
end

local function resolve_inline_link_node(node)
	if node == nil then
		return nil
	end

	if node:type() == "inline_link" then
		return node
	end

	local parent = node:parent()
	if parent ~= nil and parent:type() == "inline_link" then
		return parent
	end

	return nil
end

local function qute_browser_exist(os_name)
	local check_cmd = "command -v qutebrowser"
	if is_windows(os_name) then
		check_cmd = "(Get-Command qutebrowser).Source"
	end

	-- checks if command qutebrowser exists
	local handle = io.popen(check_cmd)
	if handle == nil then
		return false
	end
	local result = handle:read("*a")
	handle:close()

	return result ~= ""
end

local function browser_command_for(os_name, has_qute_browser, url)
	if has_qute_browser then
		return { "qutebrowser", url }
	end

	if os_name == "Darwin" then
		return { "open", url }
	end

	if os_name == "Linux" then
		return { "xdg-open", url }
	end

	if is_windows(os_name) then
		return { "cmd", "/c", "start", url }
	end

	return nil
end

local function extract_url_from_link_node(link_node)
	if link_node == nil then
		return nil
	end

	local url_node = link_node:named_child(1)
	if url_node == nil then
		return nil
	end

	return vim.treesitter.get_node_text(url_node, 0)
end

local function open_link(url)
	local os_name = vim.loop.os_uname().sysname
	local has_qute_browser = qute_browser_exist(os_name)
	local command = browser_command_for(os_name, has_qute_browser, url)

	if command == nil then
		return
	end

	if has_qute_browser then
		vim.fn.jobstart(command, {
			on_exit = function(_, code)
				if code ~= 0 then
					vim.print("Failed to open link in qutebrowser")
				end
			end,
		})
		return
	end

	vim.fn.jobstart(command)
end

local function try_open_link()
	local node = ts_utils.get_node_at_cursor()
	local link_node = resolve_inline_link_node(node)

	if link_node == nil then
		vim.print("No link found")
		return
	end

	local url = extract_url_from_link_node(link_node)
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

M._test = {
	browser_command_for = browser_command_for,
	extract_url_from_link_node = extract_url_from_link_node,
	is_valid_link = is_valid_link,
	qute_browser_exist = qute_browser_exist,
	resolve_inline_link_node = resolve_inline_link_node,
	try_open_link = try_open_link,
}

return M
