local M = {}

local link = require("nvim-md-open-link.link")

local default_options = {
	-- Keymap to open the link
	keymap = "gb",
}

local qute_browser_exist = function()
	local os = vim.loop.os_uname().sysname
	local check_cmd = "command -v qutebrowser"
	if os == "Windows" then
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

local open_link = function(url)
	local has_qute_browser = qute_browser_exist()
	if has_qute_browser then
		vim.fn.jobstart({ "qutebrowser", url }, {
			on_exit = function(_, code)
				if code ~= 0 then
					vim.print("Failed to open link in qutebrowser")
				end
			end,
		})
		return
	end

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
	local cursor = vim.api.nvim_win_get_cursor(0)
	-- nvim_win_get_cursor returns 1-indexed row; convert to 0-indexed
	local node = link.get_inline_node_at(cursor[1] - 1, cursor[2])
	local url = link.get_url_from_node(node)

	if url == nil then
		vim.print("No link found")
		return
	end

	if not link.is_valid_link(url) then
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
