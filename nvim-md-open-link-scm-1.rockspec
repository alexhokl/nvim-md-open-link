rockspec_format = "3.0"
package = "nvim-md-open-link"
version = "scm-1"

source = { url = "git+https://github.com/alexhokl/nvim-md-open-link" }

dependencies = { "lua >= 5.1" }

test_dependencies = { "nlua", "busted" }

test = { type = "busted" }

build = {
  type = "builtin",
  modules = {
    ["nvim-md-open-link"]      = "lua/nvim-md-open-link/init.lua",
    ["nvim-md-open-link.link"] = "lua/nvim-md-open-link/link.lua",
  },
}
