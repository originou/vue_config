-- Tools installed by Mason on first start (no Nix here), in addition to the language packs of
-- community.lua (gopls, jdtls, ruff, rust-analyzer, bash-language-server, vtsls...):
-- - tree-sitter-cli: nvim-treesitter (main branch) builds its parsers with it (+ a C compiler)
-- - pyright: Python language server (the python.ruff pack only brings the linter / formatter)
---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = function(_, opts)
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, {
        "tree-sitter-cli",
        "pyright",
        "lua-language-server",
        "stylua",
        "shfmt",
      })
    end,
  },
}
