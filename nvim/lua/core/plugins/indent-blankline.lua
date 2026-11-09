local M = {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  event = "BufReadPre",
  opts = {
    -- indentLine_enabled = 1,
    indent = {
      char = "▏",
    },
    exclude = {
      filetypes = {
        "startify",
        "dashboard",
        "dotooagenda",
        "log",
        "fugitive",
        "gitcommit",
        "packer",
        "vimwiki",
        "markdown",
        "json",
        "txt",
        "vista",
        "help",
        "todoist",
        "NvimTree",
        "neo-tree",
        "peekaboo",
        "git",
        "TelescopePrompt",
        "undotree",
        "flutterToolsOutline",
        "", -- for all buffers without a file type
      },
      buftypes = {
        "terminal",
        "nofile",
      },
    },
    scope = {
      char = {
        "|",
        "¦",
        "┆",
        "┊",
      },
    },
    -- space_char = " ",
  },
}

return M
