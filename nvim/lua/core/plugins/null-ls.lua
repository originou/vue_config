local M = {
  "nvimtools/none-ls.nvim",
  event = "BufReadPre",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("core.plugins.lsp.null-ls")
  end,
}

return M
