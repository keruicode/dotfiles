local is_remote = vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_TTY ~= nil

return {
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      if is_remote then
        -- Built into Neovim and supplies cterm colours for the old IAP tmux.
        opts.colorscheme = "habamax"
      end
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if is_remote then
        -- Parser installation downloads sources from GitHub, which login02 cannot reach.
        opts.ensure_installed = {}
      end
    end,
  },
  {
    "mason-org/mason.nvim",
    enabled = not is_remote,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    enabled = not is_remote,
  },
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      if is_remote then
        opts.fuzzy = opts.fuzzy or {}
        opts.fuzzy.implementation = "lua"
      end
    end,
  },
}
