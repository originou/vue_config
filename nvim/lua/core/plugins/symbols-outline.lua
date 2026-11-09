local M = {
  "hedyhli/outline.nvim",
  cmd = "Outline",
  opts = {
    outline_window = {
      position = "right",
      width = 25,
      relative_width = true,
      auto_close = false,
    },
    outline_items = {
      show_symbol_details = true,
    },
    keymaps = {
      close = { "<Esc>", "q" },
      goto_location = "<Cr>",
      peek_location = "o",
      hover_symbol = "<C-space>",
      toggle_preview = "K",
      rename_symbol = "r",
      code_actions = "a",
      fold = "h",
      unfold = "l",
      fold_all = "W",
      unfold_all = "E",
      fold_reset = "R",
    },
  },
}

return M
