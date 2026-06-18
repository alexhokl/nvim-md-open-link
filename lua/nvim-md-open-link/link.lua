local M = {}

--- Returns true if the URL has an http:// or https:// prefix.
---@param url string
---@return boolean
M.is_valid_link = function(url)
	if url:match("^https?://") then
		return true
	end
	return false
end

--- Returns the deepest named node in the markdown_inline injected tree at the
--- given (0-indexed) row and column in the current buffer, or nil if no
--- markdown_inline parser is attached.
---@param row integer 0-indexed row
---@param col integer 0-indexed column
---@return TSNode|nil
M.get_inline_node_at = function(row, col)
	local parser = vim.treesitter.get_parser(0, 'markdown')
	if parser == nil then
		return nil
	end
	parser:parse(true)
	local inline_parser = parser:children()['markdown_inline']
	if inline_parser == nil then
		return nil
	end
	for _, tree in ipairs(inline_parser:trees()) do
		local root = tree:root()
		local rs, cs, re, ce = root:range()
		-- Only search inside trees that contain this position
		if row >= rs and row <= re and
		   (row ~= rs or col >= cs) and
		   (row ~= re or col <= ce) then
			return root:named_descendant_for_range(row, col, row, col)
		end
	end
	return nil
end

--- Given a treesitter node from the markdown_inline tree, walks up at most one
--- level to find an inline_link node, then extracts and returns the URL text
--- (link_destination, named child 1).
--- Returns nil if no inline_link ancestor is found within one hop.
---@param node TSNode|nil
---@return string|nil
M.get_url_from_node = function(node)
	if node == nil then
		return nil
	end

	local link_node = nil

	if node:type() == "inline_link" then
		link_node = node
	else
		local parent = node:parent()
		if parent ~= nil and parent:type() == "inline_link" then
			link_node = parent
		end
	end

	if link_node == nil then
		return nil
	end

	local url_node = link_node:named_child(1)
	if url_node == nil then
		return nil
	end

	return vim.treesitter.get_node_text(url_node, 0)
end

return M
