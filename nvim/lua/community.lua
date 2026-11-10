-- AstroCommunity: language packs (LSP + formatter + treesitter parser + debugger for each language)
---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.go" },
  { import = "astrocommunity.pack.java" },
  -- python: only ruff from the pack (its pip-based tools need python3-venv, absent on Ubuntu)
  { import = "astrocommunity.pack.python.ruff" },
  { import = "astrocommunity.pack.rust" },
  { import = "astrocommunity.pack.bash" },
  { import = "astrocommunity.pack.typescript" },
  -- yaml / json: yamlls / jsonls with the SchemaStore schemas (OpenAPI, GitHub Actions, k8s...)
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.programming-language-support.kulala-nvim" }, -- .http files: HTTP requests (<Leader>r)
  -- quickfix list (references, ...) with a floating preview of the line under the cursor
  { import = "astrocommunity.quickfix.nvim-bqf" },
}
