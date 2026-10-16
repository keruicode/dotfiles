# WezTerm 背景图 / Backdrops

配置源码位于本目录的隐藏子目录 `.config/wezterm/`，采用 Stow 目录结构。
整个 `~/.config/wezterm` 目录通过软链接指向 `~/dotfiles/wezterm/.config/wezterm`；
配置、背景图目录和本机专用配置的实际文件均位于 dotfiles，图片及本机文件由 Git 忽略。
Finder 可按 `Cmd+Shift+.` 显示隐藏目录。

- [配置入口](.config/wezterm/wezterm.lua)
- [背景管理实现](.config/wezterm/utils/backdrops.lua)
- [快捷键](.config/wezterm/config/bindings.lua)
- [图片目录结构](.config/wezterm/backdrops/)

收藏和删除读取当前窗口实际显示的背景，菜单标题显示文件名。纯色模式下没有
可收藏的图片。配置重载或其他窗口换图不会改变当前窗口收藏的对象。

macOS 菜单快捷键：`Ctrl+Cmd+Shift+b`。另保留 `Ctrl+Alt+Shift+b` 作为同功能入口。

- `Public`：公开图片及其收藏。
- `Private`：私人图片及其收藏。
- `Like`：仅循环两个分类中的收藏，**包含私人图片**。
- 收藏当前图片：移动到所属分类的 `like/`，保持当前图片显示。
- 删除当前图片：确认后移动到所属分类的 `deleted/`，立即换下一张。

```text
~/.config/wezterm/backdrops/
├── public/
│   ├── *.png / *.jpg
│   ├── like/
│   └── deleted/
└── private/
    ├── *.png / *.jpg
    ├── like/
    └── deleted/
```

`deleted/` 永不参与 Public、Private、Like 或 All 扫描。删除不是永久擦除，
可手动移回原分类根目录或 `like/`。收藏也可通过手动移动文件调整；整理后重新
选择一次分类即可刷新列表。空分类显示纯色，不会自动切到其他分类。

图片和软链接均保持本地，不上传 Git。移动相对软链接时会保留指向原图的关系，
不移动或删除原始图库；同名文件自动加数字前缀，不覆盖已有文件。

```bash
wezbg select    # 菜单
wezbg public
wezbg private
wezbg like      # 收藏轮播，包含私人收藏
wezbg favorite  # 收藏当前图片
wezbg delete    # 确认后移到 deleted/
wezbg next
wezbg prev
wezbg random
```

配置一般自动重载；若菜单仍是旧版本，使用 WezTerm 的 Reload Configuration，
不必关闭 tmux 或 Codex。回归测试：`lua wezterm/tests/test_backdrops.lua`。

## English

Open the menu with `Ctrl+Cmd+Shift+b` (also `Ctrl+Alt+Shift+b`). Favorite moves
the current image into its category's `like/`; Delete asks for confirmation and
moves it into `deleted/`, which is excluded from every rotation. Like combines
public and private favorites. Empty categories never fall back to private images.
Move files back manually to restore them, then reselect the category to refresh.
Symlink targets and original image libraries are not deleted.
