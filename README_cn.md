# xiaoxiaotu 的 dotfiles

[English version](./README.md)

这是一套用 GNU Stow 管理的 macOS 终端与编辑器配置，核心包括 WezTerm、Kitty、tmux、
Codex、Neovim/LazyVim、Yazi 和 zsh；常用移动键尽量按 Colemak 布局设计。

## 配置包

| 配置包 | 部署位置 | 用途 |
| --- | --- | --- |
| `wezterm` | `~/.config/wezterm` | 终端界面、标签、窗格、GPU 渲染与本地背景图 |
| `kitty` | `~/.config/kitty` | Nebula 终端界面、Colemak 窗格和轻量备用终端 |
| `tmux` | `~/.tmux.conf`、`~/.config/tmux` | 持久会话、Codex 面板、IAP 重连与冷恢复 |
| `nvim` | `~/.config/nvim` | LazyVim、LaTeX/VimTeX、Skim 与科研写作 |
| `yazi` | `~/.config/yazi` | 文件管理、预览、主题与图片缩放 |
| `zsh` | `~/.config/zsh` | 共用别名与终端颜色环境 |
| `codex` | `~/.codex/AGENTS.md` | 全局 Codex 工作流与科学代码规范 |

详细说明分别位于 [kitty/README.md](./kitty/.config/kitty/README.md)、
[tmux/README.md](./tmux/README.md)、
[nvim/.config/nvim/README.md](./nvim/.config/nvim/README.md) 和
[yazi/.config/yazi/README.md](./yazi/.config/yazi/README.md)。

## 部署

先在 macOS 安装主要工具：

```bash
brew install stow tmux neovim yazi lazygit starship
brew install --cask wezterm kitty font-jetbrains-mono
```

克隆仓库，再把所需配置包链接到 Home：

```bash
git clone git@github.com:keruicode/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow codex kitty nvim tmux wezterm yazi zsh
```

新增文件后可以重复运行 `stow`。如果目标位置已经有未管理的同名文件，应先检查；
`stow --adopt` 会把目标文件移动进仓库，不适合在不确认内容时直接执行。

## WezTerm

当前配置采用模块化结构：`wezterm.lua` 组合 `config/` 中的选项、`events/` 中的
界面事件和 `utils/` 中的工具。界面使用 Nebula 配色、WebGPU/Metal、JetBrains
Mono 与霞鹜文楷等回退字体、较长滚动历史、路径感知的紧凑标签胶囊，以及适配
Colemak 的移动方式。

### 主要快捷键

| 快捷键 | 功能 |
| --- | --- |
| `Cmd+t` / `Shift+Cmd+D` | 新建 / 关闭标签 |
| `Cmd+n` / `Cmd+i` | 上一个 / 下一个标签 |
| `Cmd+1` ... `Cmd+9` | 直接跳到指定标签 |
| `Cmd+\\` / `Shift+Cmd+\\` | 垂直 / 水平分割窗格 |
| `Shift+Cmd+u/e/n/i` | 聚焦上/下/左/右窗格 |
| `Cmd+w` | 关闭当前窗格 |
| `F1` / `F2` / `F3` | 复制模式 / 命令面板 / 启动器 |
| `Ctrl+Cmd+Space` 后按 `f` | 字号调整模式（`k`、`j`、`r`） |
| `Ctrl+Cmd+Space` 后按 `p` | 窗格尺寸模式（`h`、`j`、`k`、`l`） |

### 背景图

背景图片明确不进入 Git。公开场合可用的图片放在
`~/.config/wezterm/backdrops/public/`，私人图片放在
`~/.config/wezterm/backdrops/private/`。PNG、JPEG 等文件既可以是普通文件，也
可以是指向图片库的软链接；仓库只保留两个目录的占位文件。

| 快捷键 | 功能 |
| --- | --- |
| `Cmd+/` | 随机背景图 |
| `Cmd+,` / `Cmd+.` | 上一张 / 下一张 |
| `Ctrl+Cmd+/` | 搜索当前分类中的图片 |
| `Ctrl+Cmd+b` | 循环 Public / Private / Like |
| `Shift+Ctrl+Cmd+b` | 分类、收藏当前图片、删除当前图片 |
| `Cmd+b` | 切换图片 / 专注纯色背景 |

也可以在 shell 中使用 `wezbg public`、`wezbg private`、`wezbg random`、
`wezbg focus` 等命令控制当前窗口。

新增 `wezbg like`（收藏轮播）、`wezbg favorite`（收藏当前图片）、`wezbg delete`
（确认后移出轮播）。目录及恢复方式见 [WezTerm README](wezterm/README.md)。

本机专用 SSH 域写在 `~/.config/wezterm/config/domains_local.lua`，可从
[domains_local.example.lua](./wezterm/.config/wezterm/config/domains_local.example.lua)
复制。该文件已被忽略，不会把主机名、用户名和密钥路径上传到 GitHub。

## 终端工作流

- 运行 `tmux` 创建或接入会话，前缀键是 `Ctrl+s`。
- `C-s ?` 打开 tmux 快捷键面板，`C-s T` 查看 Codex 任务状态。
- `ra` 启动 Yazi，`lg` 启动 Lazygit；两者在 tmux 内保留 true color。
- `nvim` 启动 LazyVim；LaTeX 项目通过 VimTeX 与 Skim 进行编译预览和正反向跳转。
- `iap` 应从真实交互式终端窗格运行，用于带自动重连的远端 tmux；VPN 与恢复细节
  见 tmux 说明。

## 仅保留在本机的数据

仓库会忽略 `.tmp/`、背景图、本机 WezTerm SSH 域、凭证、生成缓存，以及旧命名的
`Codex_resume.md`。当前 `Codex_resume_*.md` 交接文件继续由 Git 管理，用于在网络
或进程中断后凭准确 thread ID 和本地 session log 恢复工作。

## 致谢

WezTerm 模块保留
[KevinSilvester/wezterm-config](https://github.com/KevinSilvester/wezterm-config)
的 MIT 许可证；中英文仓库说明的组织方式参考
[theniceboy/.config](https://github.com/theniceboy/.config)。Yazi 主题和插件继续保留
各自目录中的上游许可证。
