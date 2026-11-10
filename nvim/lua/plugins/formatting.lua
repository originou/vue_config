-- Saving does not format the file. Format on demand: <Leader>lf (file or selection).
-- Turn format on save back on: <Leader>uF (everywhere) or <Leader>uf (this buffer), until Neovim
-- is closed.
---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@param opts AstroLSPOpts
  opts = function(_, opts)
    opts.formatting = opts.formatting or {}
    opts.formatting.format_on_save = opts.formatting.format_on_save or {}
    opts.formatting.format_on_save.enabled = false
  end,
}
