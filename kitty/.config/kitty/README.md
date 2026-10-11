# Kitty 配置

这套 Kitty 配置是当前 WezTerm 界面的轻量对应版本，使用相同的 Nebula 配色、
JetBrains Mono 26pt、霞鹜文楷中文回退、Nerd Font 图标和 Colemak 窗格导航。
普通文本明确使用 `JetBrainsMono-SemiBold`，粗体使用 `JetBrainsMono-Bold`，中文
使用 `LXGWWenKaiMono-Medium`，与 WezTerm 的 DemiBold/Medium 字重一致。安装所需
完整英文字体族：

```bash
brew install --cask font-jetbrains-mono
```

实际配置通过软链接生效：

```text
~/.config/kitty -> ~/dotfiles/kitty/.config/kitty
```

Kitty 默认自动重载配置。若某些 macOS 窗口选项没有即时变化，关闭并重新打开 Kitty。

## 光标轨迹

Kitty `0.47.2` 已内置文本光标轨迹，无需安装第三方插件。当 LazyVim、tmux 或 shell
中的文本光标跨越至少两个字符格时，落点会出现一条短暂的 Nebula 青色轨迹，方便在
长行、分屏和跳转后快速定位。它不是 macOS 鼠标指针特效，也不会在鼠标移动时闪烁。

当前参数只会在光标停留至少 `80ms` 后的跳转触发，持续约 `0.12-0.28s`，避免 TUI
刷新时产生拖影。设为 `cursor_trail 0` 可完全关闭。

参考核对：TheNiceBoy 当前仓库的 `kitty/kitty.conf`（2026-08-20 的 `e18047a`）仍是
基础 Kitty + tmux + Dracula 配置，未包含轨迹或鼠标特效；本配置保留其简洁的
`no-cursor` shell integration 思路，但不复制 Linux 路径、字体或配色。

## 快捷键

| 快捷键 | 功能 |
| --- | --- |
| `Cmd+t` / `Shift+Cmd+d` | 新建 / 关闭标签 |
| `Cmd+n` / `Cmd+i` | 上一个 / 下一个标签 |
| `Cmd+1` ... `Cmd+9` | 跳到指定标签 |
| `Cmd+\\` / `Shift+Cmd+\\` | 左右 / 上下分割窗格 |
| `Shift+Cmd+u/e/n/i` | 聚焦上/下/左/右窗格 |
| `Option+Cmd+u/e/n/i` | 调整窗格尺寸 |
| `Cmd+w` | 关闭当前窗格 |
| `Shift+Cmd+z` | 切换 stack 放大布局 |
| `Cmd+=` / `Cmd+-` / `Cmd+0` | 放大 / 缩小 / 重置字号 |
| `Shift+Cmd+y` | 在新标签中打开 Yazi |
| `F1` / `F2` / `F3` | 回滚历史 / 命令面板 / Yazi 浮层 |
| `Shift+Cmd+f` | 搜索回滚历史 |
| `Cmd+u` / `Cmd+p` | 选择并打开 URL / 路径 |

## Tmux 中复制

tmux 开启鼠标时，普通拖选由 tmux 接管。当前本地 tmux 已配置 `copy-command` 为
`/usr/bin/pbcopy`，普通拖选松手后自动复制到 macOS 剪贴板，可以直接粘贴。

要使用 `Cmd+C`，按住 **Shift** 拖动选择文字，再按 `Cmd+C`；Shift 可以绕过程序
对鼠标的接管，创建 Kitty 原生选区。`Cmd+C` 的 `copy_to_clipboard` 绑定只复制该原生
选区。复制当前可见文本时适用；tmux 历史内容仍可用 `Alt+v`、`v` 选区、`y` 复制。
参考 [Kitty 鼠标设置](https://sw.kovidgoyal.net/kitty/conf/#mouse-actions)。

## 文件

```text
kitty.conf    主配置、窗口行为和快捷键
nebula.conf   与 WezTerm 一致的颜色定义
tab_bar.py    标签标题清理和程序图标
```

为保证 Yazi、Lazygit、LazyVim 和 tmux 可读，透明度保持为轻微的 `0.96`，不使用
背景图片，也不把 TUI 的内部背景大面积设为透明。Kitty 还会清理从父终端继承的
`TMUX` 和 `NO_COLOR`，避免新窗口错误连接旧 tmux 或让 TUI 失去颜色。
