-- kulala.nvim (HTTP requests in .http files, community.lua): pinned to v5.3.4, the last release
-- that only needs curl. Since v6 (2026-05) it runs a closed-source backend ("kulala-core"),
-- downloaded on first use, that asks for a license token.
---@type LazySpec
return {
  "mistweaverco/kulala.nvim",
  tag = "v5.3.4",
}
