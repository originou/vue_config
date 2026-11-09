local M = {
  "folke/which-key.nvim",
  config = function()
    local icons = require("core.utils.icons")

    require("which-key").setup({
      icons = {
        breadcrumb = icons.arrows.DoubleArrowRight,
        separator = icons.arrows.SmallArrowRight,
        group = icons.ui.Plus,
      },
      win = {
        border = "none",
        padding = { 1, 2 },
      },
      layout = {
        spacing = 6,
        align = "center",
      },
      plugins = {
        marks = true,
        registers = true,
        spelling = {
          enabled = true,
          suggestions = 10,
        },
        presets = {
          operators = true,
          motions = true,
          text_objects = true,
          windows = true,
          nav = true,
          z = true,
          g = true,
        },
      },
    })
  end,
}

return M
