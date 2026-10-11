# Tmux 选择与复制

## 2026-09-30：复制设置已生效

已补齐 tmux 到系统剪贴板的复制通道，并通过实际复制测试。无需重启。

- **普通拖选**：松开鼠标即自动复制，可直接 `Cmd+V` 粘贴。
- **要用 `Cmd+C`**：按住 **Shift** 拖选，松开后按 `Cmd+C`。这是 Kitty 原生选区。[官方说明](https://sw.kovidgoyal.net/kitty/conf/#mouse-actions)
- **键盘选历史内容**：`Alt+v` → `v` 开始选区 → `y` 复制。

此前普通拖选属于 tmux，Kitty 的 `Cmd+C` 看不到那个选区。两种操作现在都写入 macOS 剪贴板。
