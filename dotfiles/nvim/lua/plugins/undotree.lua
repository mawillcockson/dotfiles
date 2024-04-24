return {
  "mbbill/undotree",
  branch = "master",
  version = "*",
  lazy = true,
  keys = {
    {
      "<leader>u",
      -- "<cmd>UndoreeToggle<cr>",
      vim.cmd.UndotreeToggle,
      desc = "Undotree",
    },
  },
}
