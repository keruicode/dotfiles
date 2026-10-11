# Neovim Markdown 预览

## 2026-10-02

CW 的公开配置是在 **Neovim 普通模式按 `r`**，调用 `InstantMarkdownPreview` 打开浏览器预览。[配置来源](https://github.com/theniceboy/nvim/blob/master/init.vim)

已给你的本地 Neovim 接好浏览器预览：

- 重新打开 Neovim，编辑 `.md`，按 **`r`**：保存并预览。
- **`Space c p`**：切换预览开关。
- **`:MarkdownPreviewStop`**：停止预览服务。

支持公式、图片、表格；不改原来的 LaTeX 编译键。实际服务启动和停止测试通过。
这是 **Neovim 的 `r`**，Yazi 的 `r` 仍是选择打开方式；IAP 配置未改。

操作已写入 [Neovim README](/Users/xiaoxiaotu/dotfiles/nvim/.config/nvim/README.md:247)。
