# Yazi 配置说明

这套配置面向日常高频文件浏览，目标是：界面好看、预览稳定、保留原有键位习惯，并尽量降低大文件 preview 对交互流畅度的影响。

当前配置通过 `~/.config/yazi -> ../dotfiles/yazi/.config/yazi` 生效。修改这里的文件会直接影响本机 Yazi。

## 目录结构

```text
.
├── README.md
├── bookmark
├── init.lua
├── keymap.toml
├── package.toml
├── starship.toml
├── theme.toml
├── yazi.toml
├── flavors/
│   ├── catppuccin-latte.yazi/
│   └── catppuccin-mocha.yazi/
└── plugins/
    ├── LICENSE
    ├── compress.yazi/
    ├── git.yazi/
    ├── mime-ext.yazi/
    ├── piper.yazi/
    ├── smart-enter.yazi/
    ├── starship.yazi/
    ├── toggle-pane.yazi/
    ├── yamb.yazi/
    ├── yaziline.yazi/
    └── zoom.yazi/
```

`flavors/` 和新增的部分 `plugins/` 是本地 vendored 资源，来自 `.tmp/yazi-beauty/` 中下载的参考仓库。这样做的好处是配置可以直接随 dotfiles 迁移，不依赖 `ya pkg install` 是否能写入 `~/.local/state/yazi/packages`。

## 视觉主题

主题入口在 `theme.toml`：

```toml
[flavor]
dark  = "catppuccin-mocha"
light = "catppuccin-latte"
```

`catppuccin-mocha` 用作暗色主题，`catppuccin-latte` 用作亮色主题。`theme.toml` 刻意只保留 `[flavor]`，因为 Yazi flavor 的 README 明确建议不要在 `theme.toml` 中继续覆盖局部颜色，否则会破坏主题整体一致性。

当前没有启用 `full-border`。原因是本机 Yazi 版本是 `26.1.22`，而当前 `full-border` 插件要求至少 `26.5.6`，强行加载会导致 Lua runtime failed。等 Yazi 升级后，可以重新评估：

```lua
require("full-border"):setup({
	type = ui.Border.ROUNDED,
})
```

## 状态栏与初始化

`init.lua` 保留现有插件：

- `yaziline`：状态栏美化，使用 curvy separator。
- `starship`：顶部路径和 Git 信息渲染，配置文件为 `starship.toml`。
- `git`：文件列表中的 Git 状态标记。
- `yamb`：书签管理，使用 `fzf` 作为交互选择器。
- 自定义 owner/group 信息：在状态栏右侧显示 hovered 文件的用户和用户组。

`starship.toml` 当前禁用了 `aws`、`gcloud`、`lua` 模块，避免顶部状态过于嘈杂。

## 预览策略

预览相关配置主要在 `yazi.toml`。

### 三栏比例

```toml
[mgr]
ratio = [1, 3, 5]
```

相比默认的 `[1, 3, 4]`，右侧 preview 面板更宽，适合查看图片、PDF、代码和表格。

### 图片与 PDF 预览

```toml
[preview]
max_width     = 1600
max_height    = 1600
image_quality = 90

[tasks]
image_alloc = 1073741824 # 1GB
```

图片上限保留为 1600px，用于大终端、`z P` 最大化预览和手动放大。内存上限提高到 1GB 是为了减少大图预览失败，但仍然保留边界，避免无限吃内存。

常见图片格式会先走本地修过的 `zoom 0` previewer。它把普通三栏下的初始图片控制在 preview 面板约 66% 的尺寸，给 `+` 留出继续放大的空间；`z P` 这类宽预览面板会使用约 86% 的初始填充，让最大化预览更接近铺满。

### 大文本预览

`prepend_previewers` 中把文本、JSON、CSV、TSV 交给 `piper`，用 `head` 截断后再交给 `bat` 高亮：

- `text/*`：只读前 800 行。
- `application/json` / `x-ndjson`：只读前 800 行。
- `*.csv` / `*.tsv`：只读前 300 行。

这样做是为了避免 Yazi 在 hover 到超大日志、导出表格或 NDJSON 文件时被完整 preview 拖慢。代价是 preview 不显示完整文件；需要完整内容时请直接打开编辑器或用搜索工具处理。

如果当前环境没有 `bat`，命令会自动退回到普通 `head`，不会直接报错。

### SQLite 预览

SQLite 文件会尝试显示 schema：

```sh
sqlite3 "$1" ".schema --indent"
```

如果环境没有 `sqlite3`，会退回到 `file -bL "$1"`。

### MIME 快速识别

启用了 `mime-ext.local` 和 `mime-ext.remote`：

```toml
{ id = "mime", url = "local://*",  run = "mime-ext.local",  prio = "high", group = "mime" }
{ id = "mime", url = "remote://*", run = "mime-ext.remote", prio = "high", group = "mime" }
```

它主要根据扩展名判断 MIME，速度比频繁调用 `file(1)` 更稳，适合大目录浏览。准确性略低于内容探测，但对日常文件管理更合适。

## 快捷键

保留原来的键位体系，并新增以下 preview 相关快捷键：

| 快捷键 | 功能 |
| --- | --- |
| `z h` | 显示或隐藏隐藏文件 |
| `z p` | 显示或隐藏 preview 面板 |
| `z P` | 最大化或恢复 preview 面板 |
| `z r` | 恢复三栏面板布局 |
| `+` | 放大当前图片预览 |
| `-` | 缩小当前图片预览 |
| `z =` | 重置当前图片预览缩放 |

已有常用键位示例：

| 快捷键 | 功能 |
| --- | --- |
| `i` / `<Enter>` | smart-enter |
| `' a` | 保存书签 |
| `' '` | 通过 fzf 跳转书签 |
| `' r` | 删除书签 |
| `<C-g>` | 打开 lazygit |
| `F` | 使用 ripgrep 搜索内容 |
| `f` | 智能过滤当前目录 |
| `c a` | 压缩选中文件 |

## 插件来源与维护

当前本地 vendored 的新增资源：

| 路径 | 来源 | 用途 |
| --- | --- | --- |
| `flavors/catppuccin-mocha.yazi` | `yazi-rs/flavors:catppuccin-mocha` | 暗色主题 |
| `flavors/catppuccin-latte.yazi` | `yazi-rs/flavors:catppuccin-latte` | 亮色主题 |
| `plugins/mime-ext.yazi` | `yazi-rs/plugins:mime-ext` | MIME 快速识别 |
| `plugins/piper.yazi` | `yazi-rs/plugins:piper` | 自定义 shell previewer |
| `plugins/toggle-pane.yazi` | `yazi-rs/plugins:toggle-pane` | 切换/最大化面板 |
| `plugins/zoom.yazi` | `yazi-rs/plugins:zoom` | 图片预览缩放 |

注意：`plugins/LICENSE` 不能随便删除。新插件目录里的 `LICENSE` 是指向 `../LICENSE` 的符号链接，父级 LICENSE 缺失时会产生断链。

`package.toml` 仍保留历史 `ya pkg` 依赖记录，但新增主题和插件是直接放在配置目录中的。如果后续想改回 package manager 管理，可以在网络和权限正常时执行类似命令：

```sh
ya pkg add yazi-rs/flavors:catppuccin-mocha
ya pkg add yazi-rs/flavors:catppuccin-latte
ya pkg add yazi-rs/plugins:mime-ext
ya pkg add yazi-rs/plugins:piper
ya pkg add yazi-rs/plugins:toggle-pane
ya pkg add yazi-rs/plugins:zoom
```

但在当前环境中，`ya pkg list` 曾因为无法创建 `~/.local/state/yazi/packages` 而失败，所以本配置优先采用 vendored 方式。

## 更新主题

如果想换主题：

1. 把新的 flavor 目录放入 `flavors/<name>.yazi/`。
2. 修改 `theme.toml`：

```toml
[flavor]
dark  = "<name>"
light = "catppuccin-latte"
```

3. 执行：

```sh
yazi --debug
```

确认 `Dark/light flavor` 显示为新值。

## 验证命令

改配置后建议跑：

```sh
yazi --debug
yazi yazi/.config/yazi/yazi.toml
```

第一条验证配置解析、依赖和 flavor 是否被识别。第二条实际触发文本 preview，能验证 `piper` 和 `bat/head` 路径。

在 Codex 或某些非完整 TTY 环境里，Yazi 可能显示：

```text
Terminal response timeout
```

这通常是 PTY 无法响应 Yazi 的终端探测，不等于配置失败。是否有 Lua runtime failed、plugin version error、preview command error 才是关键。

## 故障排查

### 启动时报 `Plugin ... requires at least Yazi ...`

说明插件版本比本机 Yazi 新。处理方式：

1. 升级 Yazi。
2. 或删除/停用该插件。

`full-border` 就是因此未启用：当前本机 Yazi 是 `26.1.22`，而下载到的 `full-border` 要求至少 `26.5.6`。

### preview 仍然卡

优先检查 hover 的文件类型：

- 超大纯文本：当前只读前 800 行，通常不会卡；如果仍卡，可能是 MIME 没有识别为 `text/*`。
- 超大 CSV/TSV：当前只读前 300 行。
- 超大图片/PDF：可能仍受 ImageMagick、pdftoppm 或终端图像协议限制影响。
- 视频：依赖 `ffmpeg/ffprobe`。

可以用：

```sh
yazi --debug
file -bL <path>
```

确认依赖和 MIME 类型。

### 图像预览不显示或质量低

`yazi --debug` 中会显示终端图像协议识别情况。本机 WezTerm 在 Codex PTY 里可能被识别为 unknown，这不一定代表真实终端里不可用。实际以你自己的终端窗口打开 Yazi 为准。

`+` / `-` 只对图片 preview 生效。常见图片格式默认使用本地修过的 `zoom 0` previewer，普通三栏初始尺寸约为当前 preview 面板的 66%，宽预览面板约为 86%；每次缩放约 15%，所以按一次 `+` 不会直接顶满，`-` 会从放大状态逐级退回初始尺寸，但不会继续缩到初始尺寸以下。`z =` 可以把当前图片重置回 0 级。用 `z P` 最大化 preview 或 `z r` 恢复布局后，可以继续用 `+` / `-` 调整当前图片。

`zoom` 的状态会在按键时立即更新，后台 `magick` 任务结束时只允许最新手动缩放级别显示；普通图片 preview 和 `z P` 触发的重新渲染会直接显示，避免被状态检查误拦截。这样连续按 `+` / `-` 时，较慢完成的旧任务不会把新结果覆盖掉。

如果 Yazi/终端没有返回真实 cell pixel size，`zoom` 会按每列约 10px、每行约 20px 保守估算 preview 面板尺寸，避免第一次按 `+` 就按 `max_width` 生成一张过大的图。

如果误按 `z p` 把 preview 面板隐藏了，再按 `+` / `-` 会提示 preview 已隐藏；按一次 `z p` 或 `z r` 恢复面板即可。

### tmux 重连后出现 terminal response timeout

Yazi 启动时会用 DA1/DSR 请求探测终端能力。若 tmux 在隐藏 pane 中同时启动多个 Yazi，WezTerm 的响应可能超时，甚至被另一个 shell 当成输入，scrollback 中会出现 `WezTerm ...`、`22c`、破损 `cd` 或 `bad pattern`。

当前 tmux 已启用 `allow-passthrough on`，也没有绑定会截获 CSI 前导符的 `M-[`。SR 恢复时只恢复所有目录；Yazi 等到对应 pane 真正获得 client 焦点后才启动，并且切换 session/detach 不再反复退出和重开 Yazi。历史 scrollback 里的旧 timeout 会继续存在，以最新一次启动后是否新增报错为准。

官方排查说明：<https://yazi-rs.github.io/docs/faq/#how-to-troubleshoot-terminal-response-timeout-errors>

### 主题没有生效

检查：

```sh
yazi --debug
```

输出中应有：

```text
Dark/light flavor: "catppuccin-mocha" / "catppuccin-latte"
```

如果为空，说明 `theme.toml` 没被读取，或 flavor 目录名称不匹配。

## 参考来源

- <https://github.com/yazi-rs/flavors>
- <https://github.com/yazi-rs/plugins>
- <https://github.com/BennyOe/tokyo-night.yazi>
- <https://github.com/dangooddd/kanagawa.yazi>
- <https://yazi-rs.github.io/docs/flavors/overview>
