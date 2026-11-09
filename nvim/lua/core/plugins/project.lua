local M = {
  "ahmedkhalf/project.nvim",
  event = "VeryLazy",
  -- can't use 'opts' because module has non standard name 'project_nvim'
  config = function()
    require("project_nvim").setup({
      -- The cwd (and neo-tree's root, bind_to_cwd) becomes the nearest parent holding one of
      -- these. Only repository markers: package.json, go.mod, pyproject.toml... of a sub-project
      -- (frontend/ + backend/ of one repo) would shrink the cwd and the tree to that sub-project
      patterns = {
        ".exercism",
        ".git",
      },
      -- detection_methods = { "lsp", "pattern" },
      detection_methods = { "pattern" },
    })
  end,
}

return M
