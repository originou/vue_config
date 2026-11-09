local M = {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local function get_git_root()
      local handle = io.popen("git rev-parse --show-toplevel 2> /dev/null")
      local result = handle:read("*a"):gsub("\n", "")
      handle:close()
      return result
    end

    local function file_path_from_git_root()
      local git_root = get_git_root()
      local file_path = vim.fn.expand("%:p")
      if git_root and file_path:find(git_root, 1, true) == 1 then
        return file_path:sub(#git_root + 2)
      else
        return vim.fn.expand("%:~:.")
      end
    end

    require("lualine").setup({
      options = {
        icons_enabled = true,
        -- theme = "gruvbox",
        theme = "iceberg_dark",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        disabled_filetypes = {
          statusline = {},
          winbar = {},
        },
        ignore_focus = {},
        always_divide_middle = true,
        globalstatus = false,
        refresh = {
          statusline = 1000,
          tabline = 1000,
          winbar = 1000,
        },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        -- lualine_c = { "filename" },
        lualine_c = {
          {
            file_path_from_git_root,
            color = { fg = "#ff9e64", gui = "bold" },
          },
        },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {
          {
            file_path_from_git_root,
            color = { fg = "#555555" },
          },
        },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },
      tabline = {},
      winbar = {},
      inactive_winbar = {},
      extensions = {},
    })
  end,
}

return M
