return {
  spec = {import = "plugins"},
  concurrency = vim.g.max_nproc or vim.g.max_nproc_default or 1,
}
