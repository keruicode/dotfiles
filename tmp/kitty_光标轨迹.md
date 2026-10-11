# Kitty 光标轨迹

## 当前结论

已在 `kitty/.config/kitty/kitty.conf` 启用 Kitty 原生文本光标轨迹。当前版本
`kitty 0.47.2` 支持该功能，无须第三方插件。它用于显示文本光标的跳转轨迹，不是
macOS 鼠标指针闪烁或 spotlight 特效。

当前配置：

```conf
cursor_trail 80
cursor_trail_decay 0.12 0.28
cursor_trail_start_threshold 2
cursor_trail_color #88e5f2
```

光标停留至少 80ms 后、跳转距离达到两个字符格时才显示轨迹；效果持续约
0.12-0.28 秒，颜色与 Nebula 配色的青色一致。把 `cursor_trail` 改为 `0` 即可关闭。

## TheNiceBoy 参考结果

已在 2026-09-12 拉取 `theniceboy/.config` 的当前 `master`（`e18047a`）。其
`kitty/kitty.conf` 仍为基础 Kitty + tmux + Dracula 配色，包含 `no-cursor` shell
integration、数字标签跳转和 powerline 标签栏，但没有 `cursor_trail`、鼠标闪烁或
shader 插件。

因此本仓库只保留其简洁配置思路；没有复制 Linux Homebrew tmux 路径、
LigaSauceCodePro 字体或 Dracula 色板。当前 Kitty 的 macOS、Colemak、WezTerm
Nebula 配色与 tmux 工作流保持不变。

## 已知边界

Kitty 新增的鼠标 spotlight、点击水波和 focus shader 仍处于 upstream RFC/夜间版
路径，不适合写入当前稳定版 Kitty `0.47.2`。这次未启用它们，以避免在 Yazi、tmux
和 LazyVim 中增加 GPU 重绘或视觉干扰。

## 验证

```text
kitty 0.47.2
parsed: cursor_trail=80, decay=(0.12, 0.28), threshold=2
```

Kitty 会自动重载配置；未即时出现时，新开一个 Kitty 窗口即可。
