return {
  "nvim-tree/nvim-tree.lua",
  branch = "master",
  version = "*",
  lazy = true,
  keys = {
    { "<leader>fb", "<cmd>NvimTreeToggle<cr>", desc = "NvimTree" },
  },
  config = true,
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
}
