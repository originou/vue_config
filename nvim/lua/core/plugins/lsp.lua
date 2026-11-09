local M = {
  "neovim/nvim-lspconfig",
  dependencies = {
    "onsails/lspkind-nvim",
    { "folke/lazydev.nvim", ft = "lua", opts = {} },
  },
  config = function()
    require("core.plugins.lsp.lsp")
  end,
}

return M
