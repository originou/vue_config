-- yamlls / jsonls get the SchemaStore schemas (OpenAPI for openapi.yaml / *.openapi.yaml, GitHub
-- Actions, docker-compose, k8s kustomization, package.json...): completion, hover docs and
-- validation. The yaml / json packs (community.lua) pass them through on_new_config, which
-- Neovim 0.11's vim.lsp.config no longer calls: the schemas are put in the settings here.
-- Other file name: first line `# yaml-language-server: $schema=<url>` (yaml) or a "$schema" key.
---@type LazySpec
return {
  "AstroNvim/astrolsp",
  dependencies = { "b0o/schemastore.nvim" },
  ---@param opts AstroLSPOpts
  opts = function(_, opts)
    local schemastore = require("schemastore")
    opts.config = opts.config or {}
    opts.config.yamlls = vim.tbl_deep_extend("force", opts.config.yamlls or {}, {
      settings = { yaml = { schemaStore = { enable = false, url = "" }, schemas = schemastore.yaml.schemas() } },
    })
    opts.config.jsonls = vim.tbl_deep_extend("force", opts.config.jsonls or {}, {
      settings = { json = { schemas = schemastore.json.schemas(), validate = { enable = true } } },
    })
  end,
}
