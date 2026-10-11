local is_remote = vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_TTY ~= nil

return {
  {
    "iamcco/markdown-preview.nvim",
    enabled = not is_remote,
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    build = function(plugin)
      require("lazy").load({ plugins = { "markdown-preview.nvim" } })
      vim.fn["mkdp#util#install"](true)
      local binary = plugin.dir .. "/app/bin/markdown-preview-" .. vim.fn["mkdp#util#get_platform"]()
      if vim.fn.executable(binary) ~= 1 then
        error("Markdown preview binary installation failed")
      end
    end,
    keys = {
      { "<leader>cp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown Preview" },
    },
    init = function()
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_open_to_the_world = 0
      vim.g.mkdp_refresh_slow = 0
      vim.g.mkdp_theme = "light"
    end,
    config = function()
      vim.cmd("do FileType")
    end,
  },
}
