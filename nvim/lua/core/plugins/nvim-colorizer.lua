local M = {
  "norcalli/nvim-colorizer.lua",
  event = "BufReadPre",
  config = function()
    require("colorizer").setup({
      "*", -- Activer pour tous les fichiers
    }, {
      mode = "background", -- Afficher les couleurs en background
    })
  end,
}
return M
