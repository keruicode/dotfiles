return {
  {
    "lervag/vimtex",
    init = function()
      -- 核心推荐：遇到 Warning 绝对不自动弹窗，只有遇到真正的 Error 才弹窗
      vim.g.vimtex_quickfix_open_on_warning = 0

      -- 过滤掉你不关心的 VimTeX 编译警告（这些内容连 Quickfix 列表里都不会进）
      vim.g.vimtex_quickfix_ignore_filters = {
        [[Underfull \\hbox]],
        [[Overfull \\hbox]],
        [[LaTeX Font Warning: Font shape]],
        [[LaTeX Font Warning: Size substitutions]],
        [[LaTeX Warning: Float too large for page]],
        [[LaTeX Warning: Label(s) may have changed]],
        -- ↓ 新增：过滤掉 AMS 模板中关于 appendix 的特定警告
        [[Package appendix Warning]],
      }

      -- 如果你想干脆关掉它的自动弹出行为（连真正的报错 Error 也不弹），取消注释下面这行
      -- vim.g.vimtex_quickfix_mode = 0
    end,
  },
}
