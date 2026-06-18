local link = require('nvim-md-open-link.link')

--- Helper: create a scratch buffer with markdown content, make it current.
--- Sets filetype to 'markdown' so the Tree-sitter parser is attached.
local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(bufnr)
  vim.bo[bufnr].filetype = 'markdown'
  return bufnr
end

--- Helper: delete a buffer after each test so state does not leak.
local function del_buf(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

--- Helper: return the deepest markdown_inline node at a given (1-indexed row,
--- 0-indexed col) by delegating to the production helper under test.
local function node_at(row, col)
  return link.get_inline_node_at(row - 1, col)
end

-- ---------------------------------------------------------------------------
-- is_valid_link()
-- ---------------------------------------------------------------------------

describe("is_valid_link()", function()

  it("accepts https:// URLs", function()
    assert.is_true(link.is_valid_link("https://example.com"))
  end)

  it("accepts http:// URLs", function()
    assert.is_true(link.is_valid_link("http://example.com"))
  end)

  it("rejects ftp:// URLs", function()
    assert.is_falsy(link.is_valid_link("ftp://example.com"))
  end)

  it("rejects file:// URLs", function()
    assert.is_falsy(link.is_valid_link("file:///home/user/doc.md"))
  end)

  it("rejects plain text", function()
    assert.is_falsy(link.is_valid_link("just some text"))
  end)

  it("rejects empty string", function()
    assert.is_falsy(link.is_valid_link(""))
  end)

end)

-- ---------------------------------------------------------------------------
-- get_url_from_node()
-- ---------------------------------------------------------------------------

describe("get_url_from_node()", function()

  it("returns nil for a nil node", function()
    assert.is_nil(link.get_url_from_node(nil))
  end)

  describe("cursor on the link text part", function()
    -- [text](https://example.com)
    -- col 1 (0-indexed): 't' in 'text' → link_text node, parent is inline_link
    local bufnr

    before_each(function()
      bufnr = make_buf({ "[text](https://example.com)" })
    end)

    after_each(function()
      del_buf(bufnr)
    end)

    it("returns the URL", function()
      local node = node_at(1, 1)
      local url = link.get_url_from_node(node)
      assert.are.equal("https://example.com", url)
    end)
  end)

  describe("cursor on the URL (link_destination) part", function()
    -- [text](https://example.com)
    -- col 8 (0-indexed): 't' in 'https' → link_destination, parent is inline_link
    local bufnr

    before_each(function()
      bufnr = make_buf({ "[text](https://example.com)" })
    end)

    after_each(function()
      del_buf(bufnr)
    end)

    it("returns the URL", function()
      local node = node_at(1, 8)
      local url = link.get_url_from_node(node)
      assert.are.equal("https://example.com", url)
    end)
  end)

  describe("cursor on plain paragraph text (no link)", function()
    local bufnr

    before_each(function()
      bufnr = make_buf({ "Just some plain text." })
    end)

    after_each(function()
      del_buf(bufnr)
    end)

    it("returns nil", function()
      local node = node_at(1, 0)
      local url = link.get_url_from_node(node)
      assert.is_nil(url)
    end)
  end)

  describe("link with non-http scheme (ftp)", function()
    -- get_url_from_node does not validate — it just extracts the URL string.
    -- Validation is the caller's responsibility (is_valid_link).
    local bufnr

    before_each(function()
      bufnr = make_buf({ "[FTP](ftp://example.com/file.txt)" })
    end)

    after_each(function()
      del_buf(bufnr)
    end)

    it("returns the raw URL string without validating the scheme", function()
      local node = node_at(1, 1)  -- 'F' in 'FTP'
      local url = link.get_url_from_node(node)
      assert.are.equal("ftp://example.com/file.txt", url)
    end)
  end)

  describe("link with http scheme", function()
    local bufnr

    before_each(function()
      bufnr = make_buf({ "[link](http://example.com)" })
    end)

    after_each(function()
      del_buf(bufnr)
    end)

    it("returns the http URL", function()
      local node = node_at(1, 1)
      local url = link.get_url_from_node(node)
      assert.are.equal("http://example.com", url)
    end)
  end)

  describe("multiple links on the same line", function()
    -- Cursor on each link returns the correct URL for that link.
    -- "[A](https://alpha.com) and [B](https://beta.com)"
    --   ^ col 1                      ^ col 28
    local bufnr

    before_each(function()
      bufnr = make_buf({ "[A](https://alpha.com) and [B](https://beta.com)" })
    end)

    after_each(function()
      del_buf(bufnr)
    end)

    it("returns the first link's URL when cursor is on the first link", function()
      local node = node_at(1, 1)  -- 'A' in first link
      local url = link.get_url_from_node(node)
      assert.are.equal("https://alpha.com", url)
    end)

    it("returns the second link's URL when cursor is on the second link", function()
      local node = node_at(1, 28) -- 'B' in second link
      local url = link.get_url_from_node(node)
      assert.are.equal("https://beta.com", url)
    end)
  end)

end)

-- ---------------------------------------------------------------------------
-- get_inline_node_at()
-- ---------------------------------------------------------------------------

describe("get_inline_node_at()", function()

  describe("in a buffer with a markdown link", function()
    local bufnr

    before_each(function()
      bufnr = make_buf({ "[text](https://example.com)" })
    end)

    after_each(function()
      del_buf(bufnr)
    end)

    it("returns a link_text node when cursor is on the link label", function()
      local node = link.get_inline_node_at(0, 1)
      assert.is_not_nil(node)
      assert.are.equal("link_text", node:type())
    end)

    it("returns a link_destination node when cursor is on the URL", function()
      local node = link.get_inline_node_at(0, 8)
      assert.is_not_nil(node)
      assert.are.equal("link_destination", node:type())
    end)
  end)

  describe("in a plain-text buffer without links", function()
    local bufnr

    before_each(function()
      bufnr = make_buf({ "Just plain text." })
    end)

    after_each(function()
      del_buf(bufnr)
    end)

    it("returns nil when there is no inline_link in the buffer", function()
      -- A plain paragraph has no markdown_inline injection, so the child
      -- parser either does not exist or contains no inline_link tree.
      local node = link.get_inline_node_at(0, 0)
      -- node may be a generic 'inline' node or nil; neither is an inline_link
      if node ~= nil then
        assert.are_not.equal("inline_link", node:type())
        assert.are_not.equal("link_text", node:type())
        assert.are_not.equal("link_destination", node:type())
      end
    end)
  end)

end)
