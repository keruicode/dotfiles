# Neovim / LazyVim 使用手册

这是一套面向 Colemak 键位、LaTeX 写作、Skim PDF 预览和日常编程的
LazyVim 配置。本文记录的是本机实际配置与运行时最终生效的快捷键，不是
LazyVim 默认键位的完整转载。

## 1. 当前环境

| 项目 | 当前状态 |
|---|---|
| 配置目录 | `~/dotfiles/nvim/.config/nvim` |
| 生效链接 | `~/.config/nvim -> ~/dotfiles/nvim/.config/nvim` |
| Neovim | `0.12.2` |
| 配置框架 | LazyVim v8，插件由 `lazy-lock.json` 锁定 |
| LaTeX extra | `lazyvim.plugins.extras.lang.tex` |
| LaTeX 插件 | VimTeX，禁止 lazy-load，以保证反向搜索命令始终可用 |
| LaTeX LSP | TexLab，由 Mason 安装 |
| 编译器 | `latexmk 4.86a` |
| SyncTeX | `/Library/TeX/texbin/synctex` |
| PDF 阅读器 | `/Applications/Skim.app` |
| 补全 | `blink.cmp`，`enter` preset |
| Leader | `Space` |
| LocalLeader | `\` |

启动：

```bash
nvim
nvim main.tex
```

在普通模式按 `Space` 会打开 LazyVim/which-key 快捷键面板。在 TeX buffer
中按 `\`，再按 `l`，会看到 VimTeX 快捷键组。

常用自检：

```vim
:Lazy
:Mason
:checkhealth vimtex
:LspInfo
:VimtexInfo
```

## 2. Colemak 核心键位

这套配置对 Vim 原生键位做了较大改动。以下键位优先级高于 LazyVim
默认键位。

### 2.1 移动与编辑

| 模式 | 快捷键 | 实际动作 | 被替代的 Vim 原功能 |
|---|---:|---|---|
| Normal / Visual | `n` | 左移，等价于 `h` | 下一个搜索结果 |
| Normal / Visual | `e` | 下移，等价于 `j` | 移到单词末尾 |
| Normal / Visual | `u` | 上移，等价于 `k` | 撤销 |
| Normal / Visual | `i` | 右移，等价于 `l` | 进入 Insert |
| Normal / Visual | `U` | 上移 5 行 | 撤销当前行修改 |
| Normal / Visual | `E` | 下移 5 行 | 大写单词末尾 |
| Normal / Visual | `N` | 行首，等价于 `0` | 上一个搜索结果 |
| Normal / Visual | `I` | 行尾，等价于 `$` | 行首进入 Insert |
| Normal | `l` | 撤销，等价于原生 `u` | 右移 |
| Normal | `k` | 在光标前进入 Insert，等价于原生 `i` | 上移 |
| Normal | `K` | 行首进入 Insert，等价于原生 `I` | keywordprg |
| Normal / Visual / Operator | `=` | 下一个搜索结果 | 自动缩进操作符 |
| Normal / Visual / Operator | `-` | 上一个搜索结果 | 上一行首个非空字符 |
| Normal / Visual | `;` | 进入命令行，等价于 `:` | 重复 `f/t` 搜索 |
| Normal | `Q` | 关闭当前 window，等价于 `:q` | Ex mode |
| Normal | `S` | 保存；TeX 中还会正向同步 Skim | 替换整行 |
| Normal | `r` | 保存并按文件类型编译/运行 | 替换单字符 |
| Visual | `Y` | 复制到 macOS 系统剪贴板 | 按行复制 |

重要差异：

- `u/e/n/i` 只在 Normal 和 Visual 模式重映射。输入 `d`、`c`、`y` 后进入
  Operator-pending 模式时，并不会自动变成 Colemak 方向键。
- `l` 在 Normal 模式是撤销；但配置也把 Visual 模式的 `l` 映射到原生
  `u`，其实际效果是把选中文本转为小写，不是撤销。
- `k` 在 Normal 模式进入 Insert；Visual 模式下对应原生 `i`，会等待一个
  text object，而不是直接进入 Insert。
- `K` 是全局“行首插入”，但只要当前 buffer 附加了 LSP，buffer-local 的
  `K = Hover` 优先级更高。当前 LaTeX/TexLab buffer 中，`K` 显示悬浮文档。
- `r` 和 `S` 已不再保留 Vim 原始语义。需要单字符替换时可使用命令行、
  Visual 选择或重新定义临时映射。

### 2.2 搜索

| 快捷键 | 功能 |
|---|---|
| `/pattern` | 向后搜索 |
| `?pattern` | 向前搜索 |
| `=` | 下一个匹配项 |
| `-` | 上一个匹配项 |
| `Esc` | 清除搜索高亮，并退出当前 snippet |
| `Space ur` | 重绘、清除高亮、刷新 diff |

## 3. 保存、退出与剪贴板

| 快捷键 | 功能 |
|---|---|
| `S` | 保存；TeX 中额外执行 `VimtexView` |
| `Ctrl+s` | LazyVim 标准保存，只执行 `:write` |
| `Q` | 关闭当前 window；有未保存修改时会拒绝 |
| `Space q` | 关闭当前 split/window |
| `Space qq` | 退出全部 Neovim window |
| Visual `Y` | 复制到系统剪贴板 `+` register |
| `"+p` | 从系统剪贴板粘贴 |
| `p` | 从 Neovim 内部 register 粘贴 |

全局 `clipboard` 被明确设为空，因此普通 `y/d/p` 与 macOS 系统剪贴板相互
独立。只有 Visual `Y` 或显式使用 `"+` register 才访问系统剪贴板。

## 4. Window、buffer 与 tab

### 4.1 创建 split

| 快捷键 | 功能 |
|---|---|
| `su` | 在上方创建水平 split |
| `se` | 在下方创建水平 split |
| `sn` | 在左侧创建垂直 split |
| `si` | 在右侧创建垂直 split |
| `Space -` | 在下方创建水平 split |
| `Space` 后按 `|` | 在右侧创建垂直 split |

### 4.2 Colemak window 导航

| 快捷键 | 功能 |
|---|---|
| `Space wn` | 聚焦左侧 window |
| `Space we` | 聚焦下方 window |
| `Space wu` | 聚焦上方 window |
| `Space wi` | 聚焦右侧 window |
| `Space wm` | 临时最大化/恢复当前 Neovim window |
| `Space q` | 关闭当前 window |

LazyVim 还保留 `Ctrl+h/j/k/l` 窗口导航和 `Ctrl+方向键` 调整尺寸，但它们
使用的是 Vim 原始方向语义，不是 Colemak 的 `n/e/u/i`。

### 4.3 Buffer

| 快捷键 | 功能 |
|---|---|
| `Shift+h` / `[b` | 上一个 buffer |
| `Shift+l` / `]b` | 下一个 buffer |
| `Space bb` | 切回另一个 buffer |
| `Space bd` | 删除当前 buffer |
| `Space bo` | 删除其他 buffer |

### 4.4 Tab

按 `Space Tab` 后查看 which-key。常用键：

| 快捷键 | 功能 |
|---|---|
| `Space Tab Tab` | 新建 tab |
| `Space Tab ]` | 下一个 tab |
| `Space Tab [` | 上一个 tab |
| `Space Tab d` | 关闭 tab |
| `Space Tab o` | 只保留当前 tab |

## 5. 文件、搜索与 Snacks Explorer

| 快捷键 | 功能 |
|---|---|
| `Space Space` / `Space ff` | 在项目根目录查找文件 |
| `Space fg` | 查找 Git 跟踪文件 |
| `Space /` / `Space sg` | 在项目根目录全文搜索 |
| `Space sw` | 搜索光标下单词或 Visual 选择 |
| `Space sb` | 搜索当前 buffer 的行 |
| `Space e` | 打开项目根目录 Explorer |
| `Space E` | 打开当前工作目录 Explorer |

Snacks picker 与 Explorer 也使用 Colemak 导航：

| 场景 | `u` | `e` | `n` | `i` | `/` |
|---|---|---|---|---|---|
| 普通搜索列表 | 上一项 | 下一项 | 关闭 | 确认 | 聚焦输入框 |
| Explorer | 上一项 | 下一项 | 折叠/返回父级 | 展开/打开 | 搜索 |

## 6. LSP、诊断与格式化

LaTeX extra 会为 TeX buffer 启动 TexLab。以下是当前运行态常用映射：

| 快捷键 | 功能 |
|---|---|
| `gd` | 跳转定义 |
| `gr` | 查找引用 |
| `gI` | 跳转实现 |
| `gy` | 跳转类型定义 |
| `K` | Hover 文档 |
| `Space cr` | 重命名符号 |
| `Space cs` | 符号列表 |
| `Space cf` | 强制格式化 |
| `Space cd` | 当前行诊断 |
| `[d` / `]d` | 上一个/下一个诊断 |
| `[e` / `]e` | 上一个/下一个 error |
| `[w` / `]w` | 上一个/下一个 warning |
| `Space xq` | 打开/关闭 Quickfix |
| `[q` / `]q` | 上一个/下一个 Quickfix 项 |

## 7. 补全与 LaTeX snippet

当前使用 `blink.cmp` 的 `enter` preset：

| Insert 快捷键 | 功能 |
|---|---|
| `Ctrl+Space` | 打开补全/文档窗口 |
| `Ctrl+n` / `Ctrl+p` | 下一项/上一项 |
| `Enter` | 接受当前候选；没有候选时正常换行 |
| `Ctrl+y` | 选择并接受候选 |
| `Ctrl+e` | 取消补全 |
| `Tab` / `Shift+Tab` | 下一个/上一个 snippet 占位符 |
| `Ctrl+b` / `Ctrl+f` | 向上/向下滚动补全文档 |
| `Ctrl+k` | 显示/隐藏函数签名 |

本地 `snippets/tex.json` 提供：

```text
eql -> 带 \label 的 equation 环境
```

展开后用 `Tab` 在 label 名称和公式正文之间移动。

## 8. 一键编译/运行：`r`

`r` 总会先保存当前文件，再根据 `filetype` 执行：

| filetype | 行为 |
|---|---|
| `tex` | 执行 `VimtexCompile`，启动/切换 continuous compile |
| `python` | 水平 split 中运行 `python3 当前文件` |
| `c` | `gcc` 编译后运行 |
| `cpp` | `g++ -std=c++11 -Wall` 编译后运行 |
| `java` | `javac` 后运行 class |
| `sh` | `time bash 当前文件` |
| `ncl` | `ncl 当前文件` |
| `go` | `go run .` |
| `javascript` | 在当前目录执行 `node --trace-warnings .` |
| `racket` | `racket 当前文件` |

除 TeX 外，大部分任务会新建水平 terminal split 并进入 Terminal Insert 模式。
当前实现没有 shell-quote 文件名，路径或文件名包含空格时可能运行失败。

## 9. LaTeX、VimTeX 与 Skim

### 9.1 组件关系

```text
Neovim / LazyVim
  ├─ TexLab：LSP 补全、定义、引用、诊断
  ├─ VimTeX：项目识别、latexmk、Quickfix、SyncTeX
  ├─ latexmk：持续编译 .tex -> .pdf + .synctex.gz
  └─ Skim：查看 PDF，并通过 SyncTeX 与 Neovim 双向跳转
```

VimTeX 被设置为 `lazy = false`。这是必要的，因为 Skim 反向搜索会启动一个
headless Neovim，再用 `:VimtexInverseSearch` 寻找已经打开目标项目的
Neovim server；如果 VimTeX 尚未加载，该命令不存在。

LaTeX Treesitter parser 已安装，但 LaTeX Treesitter highlight 被 LazyVim
关闭，主要语法高亮交给 VimTeX。当前配置还把 TeX 的 `conceallevel` 固定为
0，因此 `\alpha`、数学命令和引号不会被替换成隐藏字符。

### 9.2 推荐工作流

```text
1. nvim main.tex
2. 按 r 或 \ll，启动 latexmk continuous compile
3. 正常编辑
4. 按 S：保存，并让 Skim 正向跳到当前光标位置
5. 在 Skim 中按住 Shift+Command 点击 PDF：反向跳回 .tex
6. 用 \le 查看错误，\lk 停止持续编译
```

首次按 `r` 或 `\ll` 通常启动 continuous compile。`VimtexCompile` 在持续编译
已运行时是 toggle，因此再次按 `r`/`\ll` 可能停止编译。之后只需要保存，
`latexmk` 会自动重编译。

### 9.3 `S` 的实际同步顺序

在 TeX buffer 中，`S` 会：

```text
write 当前 .tex
  -> 若 latexmk continuous compile 已运行，后台开始重编译
  -> 立即 VimtexView，Skim 先跳到当前源代码位置
  -> 编译成功触发 VimtexEventCompileSuccess
  -> autocmd 再执行一次 VimtexView，使用新 PDF 重新同步
```

因此 `S` 既是保存键，也是主要的“保存并同步 Skim”键。普通 `Ctrl+s` 只保存；
但 continuous compile 成功后，当前 autocmd 仍会执行一次正向同步。

### 9.4 正向搜索：Neovim -> Skim

| 快捷键 | 功能 |
|---|---|
| `S` | 保存并执行 `VimtexView` |
| `\lv` | 手动打开 PDF/正向跳转 |
| 编译成功 | 自动执行 `VimtexView` |

当前 `vimtex_view_method = "skim"`。`vimtex_view_skim_activate` 使用默认值 0，
所以正向跳转会更新/显示 Skim，但通常不会强行把键盘焦点从 Neovim 抢走。

### 9.5 反向搜索：Skim -> Neovim

Skim 中使用：

```text
Shift + Command + 点击 PDF 文本
```

Skim 设置位置：

```text
Skim -> Settings -> Sync
Preset: Custom
Command: /opt/homebrew/bin/nvim
Arguments: --headless -c "VimtexInverseSearch %line '%file'"
```

VimTeX 收到跳转后会定位到对应 `.tex` 行。当前 autocmd 监听
`VimtexEventViewReverse`，随后执行 `open -a 'WezTerm'`，让 WezTerm 回到前台。

本机目前读到的 Skim 值是：

```text
Command: /usr/bin/env
Arguments: nvim /opt/homebrew/bin/nvim --headless -c "VimtexInverseSearch %line '%file'"
```

它比官方配置多了一个 `nvim` 和一个可执行文件参数，属于冗余的非标准写法。
命令本身可以退出，但不应把它当成稳定的反向搜索配置。建议在 Skim 的 Sync
面板改成上面的 `Command` 和 `Arguments` 两项。

反向搜索还有两个前提：

1. 目标 `.tex` 必须属于某个仍在运行的 VimTeX project。
2. 该项目必须已经在 Neovim 中打开；没有活跃 server 时，headless 命令会
   正常退出，但不会有可跳转的窗口。

VimTeX 的 Neovim server 清单位于：

```text
~/.cache/vimtex/nvim_servernames.log
```

### 9.6 VimTeX 快捷键

TeX buffer 中 LocalLeader 是反斜杠 `\`。例如 `\ll` 表示依次按：
`\`、`l`、`l`。

| 快捷键 | 功能 |
|---|---|
| `\li` | 项目信息 |
| `\lI` | 完整项目信息 |
| `\lt` | 打开目录/结构树 |
| `\lT` | 切换目录/结构树 |
| `\lv` | 打开 PDF 或正向搜索 |
| `\ll` | 启动/切换 continuous compile |
| `\lL` | 编译 Visual 选择 |
| `\lS` | 单次编译 |
| `\lk` | 停止当前编译 |
| `\lK` | 停止全部 VimTeX 编译 |
| `\le` | 打开编译错误 Quickfix |
| `\lo` | 查看完整编译输出 |
| `\lg` | 查看当前编译状态 |
| `\lG` | 查看所有项目编译状态 |
| `\lc` | 清理辅助文件 |
| `\lC` | 完整清理，包括输出文件 |
| `\lm` | 查看 VimTeX Insert-mode mappings |
| `\lx` | 重新加载 VimTeX |
| `\lX` | 重新加载 VimTeX state |
| `\ls` | 把当前文件切换为主文件 |
| `\la` | VimTeX context menu |

`\lC` 可能删除 PDF，使用前确认不需要保留当前输出。

### 9.7 编译警告策略

当前配置：

- warning 不自动弹出 Quickfix；真正的 error 仍会弹出。
- `Underfull/Overfull \hbox`、字体替换、float 过大、label 变化和 appendix
  warning 会从 VimTeX Quickfix 中过滤。
- 需要查看被过滤前的完整日志时，使用 `\lo` 或直接打开 `.log`。

## 10. 其他常用 LazyVim 功能

| 快捷键 | 功能 |
|---|---|
| `Space l` | Lazy 插件管理器 |
| `Space cm` | Mason 工具/LSP 管理器 |
| `Space gg` | Lazygit，项目根目录 |
| `Ctrl+/` | 打开/聚焦项目根目录浮动终端 |
| `Space ft` | 项目根目录终端 |
| `Space fT` | 当前工作目录终端 |
| `Space us` | 切换拼写检查 |
| `Space uw` | 切换自动换行 |
| `Space ul` | 切换行号 |
| `Space uL` | 切换相对行号 |

## 11. 当前编辑选项

| 选项 | 当前值/影响 |
|---|---|
| `tabstop/shiftwidth/softtabstop` | 2 |
| `expandtab` | `false`，Tab 写入真实制表符 |
| `wrap` | 开启 |
| `scrolloff` | 4 |
| `colorcolumn` | 100 |
| `list` | 显示 Tab 和行尾空白 |
| `clipboard` | 空，不自动同步系统剪贴板 |
| `timeoutlen` | 0 |
| TeX `conceallevel` | 0 |

`timeoutlen=0` 很激进。如果 `Space ...`、`su/se/sn/si` 或 `\l...` 偶尔只执行
第一个键，应先检查这一项；多键序列需要连续输入，which-key 也可能来不及
显示完整提示。

## 12. 故障排查

### PDF 不更新

```vim
:VimtexStatus
:VimtexCompile
:VimtexCompileOutput
```

也可以按 `\lg` 看状态。若 continuous compile 未运行，按一次 `r` 或 `\ll`。

### Skim 打开但没有跳到光标位置

1. 确认编译生成了 `.synctex.gz`。
2. 按 `\lv` 手动测试正向搜索。
3. 用 `:VimtexInfo` 确认 `root` 和主 `.tex` 文件是否正确。
4. 多文件项目不要随意把章节文件设为主文件；需要时用 `\ls`。

### Skim 反向点击没有回到 Neovim

1. 把 Skim Sync 的 Command/Arguments 改成本文的标准值。
2. 使用 `Shift+Command+点击`，不是普通双击。
3. 确认目标项目仍在 Neovim 中打开。
4. 检查 `~/.cache/vimtex/nvim_servernames.log` 是否存在活跃 socket。
5. 执行 `:checkhealth vimtex`。

### LaTeX warning 看不到

这是当前设计。warning 不自动弹窗，且常见排版 warning 被过滤。使用 `\lo`
查看完整 latexmk/LaTeX 输出。

### 快捷键实际行为与本文不一致

在目标 buffer 中执行：

```vim
:verbose nmap r
:verbose nmap S
:verbose nmap K
:verbose nmap \ll
:map <key>
```

buffer-local LSP/VimTeX 映射会覆盖全局映射，因此必须在实际 TeX buffer 中
检查。

## 13. 配置文件索引

| 文件 | 责任 |
|---|---|
| `init.lua` | 启动 LazyVim |
| `lazyvim.json` | 启用 LaTeX extra |
| `lua/config/keymaps.lua` | Colemak、`r`、`S`、window 映射 |
| `lua/config/options.lua` | Skim、缩进、剪贴板、wrap 等选项 |
| `lua/config/autocmds.lua` | NCL、TeX conceal、Skim 正反向同步 |
| `lua/plugins/extend-vimtex.lua` | VimTeX warning/Quickfix 策略 |
| `lua/plugins/snacks.lua` | Picker/Explorer 的 Colemak 导航 |
| `lua/plugins/smear-cursor.lua` | 光标动画 |
| `lua/plugins/vim-ncl.lua` | NCL 插件 |
| `snippets/tex.json` | 本地 LaTeX snippet |
| `lazy-lock.json` | 插件版本锁 |

更新插件前建议先备份 `lazy-lock.json`。更新后至少验证：

```text
Space which-key
u/e/n/i 与 l/k
r 与 S
\ll / \lv / \le
Skim 正向和反向搜索
Snacks Explorer 的 u/e/n/i
```
