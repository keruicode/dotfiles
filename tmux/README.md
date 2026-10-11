# Tmux + Codex 工作流

> 当前状态：`tmux base`、自动快照恢复、Codex 续接和 IAP 远端 tmux 重连均已在本机启用。本文是配置说明和后续决策记录，不是 B 站视频逐字稿。

## 快速入口

继续当前 Codex 配置任务：

```bash
codex resume 019f3c6f-d910-7183-b5e4-3b95f53ba179
```

若使用本机 `code` 别名：

```bash
code resume 019f3c6f-d910-7183-b5e4-3b95f53ba179
```

详细中断交接见 [`Codex_resume_dotfiles.md`](../Codex_resume_dotfiles.md)，新记录追加在文末；固定第 10 行为续接命令，可直接运行 `head Codex_resume_dotfiles.md` 查看。实际配置入口是 [`.tmux.conf`](./.tmux.conf)，辅助脚本位于 [`.config/tmux/scripts/`](./.config/tmux/scripts/)。

## 结论

当前方案吸收 theniceboy 配置里值得保留的部分，但不照搬整套 `agent-tracker`：

- 保留 `C-s` prefix、Colemak 方向键、编号 session、快速 window/pane 操作。
- 保留好看的 pane 标题和状态栏，并与当前 WezTerm Nebula 配色一致。
- 删除 Claude、agent-tracker、opencode 和未安装 TPM 插件的耦合。
- 第一阶段 base 已稳定；当前已加入会话快照、自动恢复、Codex thread 续接和 IAP 远端 tmux 重连。
- 配置由 `/Users/xiaoxiaotu/dotfiles/tmux/` 管理，通过 GNU Stow 链接到家目录。

## 资料来源

- 视频：[同时开 10 个 AI 写代码：AI 工作流中必备软件 TMUX](https://www.bilibili.com/video/BV1ePBHBCEcE/)
- theniceboy：[.tmux.conf](https://github.com/theniceboy/.config/blob/master/.tmux.conf)
- theniceboy：[agent-tracker](https://github.com/theniceboy/.config/tree/master/agent-tracker)
- tmux：[官方 wiki](https://github.com/tmux/tmux/wiki)
- tmux-resurrect：[官方仓库](https://github.com/tmux-plugins/tmux-resurrect)
- tmux-continuum：[官方仓库](https://github.com/tmux-plugins/tmux-continuum)
- WezTerm：[Keyboard Encoding](https://wezterm.org/config/key-encoding.html)

视频公开接口没有返回字幕，因此这里只整理可核查的配置和工作流，不冒充逐句视频总结。

## 当前机器状态

已确认：

```text
tmux       3.6a
WezTerm    20240203-110809-5046fc22
Codex CLI  0.147.0
GNU Stow   已安装
fzf        已安装
starship   已安装
rainbarf   已安装
jq         已安装
```

未安装：

```text
terminal-notifier
ccusage
Claude CLI
```

你只使用 Codex，因此后续不会增加 Claude 状态、Claude hooks 或 Claude 用量模块。

session 会继续使用 `1-name`、`2-name` 的内部命名，以支持 `Ctrl+数字` 切换；底栏保留 session 段，但只显示剥离编号后的 `name`。

当前生效入口：

```text
~/.tmux.conf -> /Users/xiaoxiaotu/dotfiles/tmux/.tmux.conf
~/.config/tmux/scripts/*.sh -> /Users/xiaoxiaotu/dotfiles/tmux/.config/tmux/scripts/
```

历史文件 `~/.config/.tmux.conf`、`~/.config/tmux-conf` 和 `~/.config/config/tmux/` 仍保留，但不是当前 tmux 的加载入口。

## Ctrl+1/2/3/4 为什么失效

不是 WezTerm 主配置抢占导致的。

运行态检查显示当前 tmux 客户端是：

```text
TERM=xterm-256color
terminal features: extkeys, RGB, clipboard, focus, sixel, title, ...
```

这说明 WezTerm 与 tmux 已经协商了扩展按键。旧配置真正的问题是：

```tmux
bind -n C-1 ...
# ... 省略 C-2 到 C-9
```

“省略”只是注释，不会创建绑定。当时当前 session 又是 `1-test`，所以 `Ctrl+1` 即便成功，也没有可见变化；`Ctrl+2/3/4` 则确实没有绑定。

新配置已创建完整的九条绑定：

```text
Ctrl+1 ... Ctrl+9 -> 切换第 1 ... 9 个 session
```

若实机复测仍有某个 `Ctrl+数字` 不能到达 tmux，再在 WezTerm 中增加显式 F13-F21 转发；现在没有必要先引入这层兼容代码。

## Session、Window、Pane

tmux 的层级是：

```text
tmux server
└── session：一个项目或工作上下文
    └── window：同一项目中的任务页
        └── pane：同一页中的终端分区
```

实用理解：

- session 类似工作区，例如 `forecast`、`paper`、`dotfiles`。
- window 类似工作区中的标签页，例如 `editor`、`server`、`logs`。
- pane 是一个 window 内并排显示的 shell、Codex、Yazi 或日志。

Codex 并行工作时，优先让一个项目对应一个 session，一个独立任务对应一个 window；只有需要同时观察的内容才拆成 pane。

## Zoom 是什么

tmux zoom 是“临时让当前 pane 占满整个 window”。它是开关，不是不断放大的缩放倍率：

```text
第一次按：当前 pane 暂时铺满 window
再按一次：恢复原来的 pane 布局和尺寸
```

它不会：

- 改变 WezTerm 字号；
- 删除或暂停其他 pane；
- 改变进程状态；
- 永久改写布局。

本配置提供两个完全相同的入口：

```text
Alt+f       zoom / unzoom
C-s z       zoom / unzoom
```

zoom 时 pane 顶部会显示 `ZOOM`。Yazi 图片预览有时会在 pane 尺寸变化后重新绘制，这只是 zoom 触发了终端重排，不代表图片本身被放大。配置已启用 `allow-passthrough`，便于 Yazi 在 tmux 中传递图像协议。

IAP pane 是本地 tmux 套远端 tmux。连接脚本使用前台 OpenSSH，让 SSH 直接从本地 PTY 接收窗口尺寸变化；远端启用 `aggressive-resize`。因此在本地 tmux 内执行 `iap` 后，`Alt+f` 放大和恢复会同步改变远端 client、window、pane 和 shell 的尺寸。

`Alt+f` 是本地 tmux 快捷键。若直接在普通 WezTerm shell 中执行 `iap`，进程链里没有本地 tmux，`Alt+f` 不具备 zoom 功能；应在本地 tmux pane 中运行 `iap` 才能使用该快捷键。终端已有的窄行不会因放大而重新换行，判断当前尺寸应看新输出或执行 `stty size`。

## 第一阶段快捷键

对用户而言，逻辑 `prefix` 是 `Ctrl+s`。tmux 的内建 prefix 已设为 `None`，这样裸 `Ctrl+s` 才能先打开提示面板；面板再把下一键送入原有 `prefix` key table。下文 `C-s x` 表示先按 `Ctrl+s`，松开后再按 `x`。

直接按 `Ctrl+s` 会在右下角打开一个类似 LazyVim which-key 的快捷键面板。面板打开后再按 `c`、`z`、`U` 等键，会关闭面板并执行原来的 tmux prefix 绑定；按 `Esc` 只关闭面板。没有列在面板中的旧绑定也会原样转发。LazyVim 的 `Space c` 会继续展开 `code` 子组，而当前 tmux 快捷键只有一层，所以 `C-s c` 会直接新建 window。

### Session

| 快捷键 | 功能 |
|---|---|
| `Ctrl+1...9` | 直接切换第 1...9 个 session |
| `Alt+s` | 打开 session 选择树 |
| `C-s s` | 打开 session 选择树 |
| `Alt+Shift+s` | 从当前目录新建 session |
| `C-s Ctrl+c` | 从当前目录新建 session |
| `C-s .` | 重命名当前 session |
| `C-s l / y` | session 向左 / 向右调整编号 |
| 鼠标左键点击底栏 Session | 直接切换到对应 session |
| `Alt+a` 或 `C-s a` | 右上角打开 Codex Tasks 面板 |

session 名会维护为 `1-name`、`2-name`、`3-name`，因此 `Ctrl+数字` 的顺序稳定；编号只用于内部定位，不在底栏展示。

### Codex Tasks 面板

`Alt+a` 或 `C-s a` 会在右上角打开一个临时面板，汇总所有 tmux session 中仍存在的 Codex pane。它不依赖 Claude、opencode 或常驻 agent-tracker 服务。

```text
● 运行中    当前 Codex turn 仍在推理、执行工具或等待后台命令
✓ 已完成    最近一个 turn 已完成，Codex 正在等待下一条输入
! 待处理    Codex 正在等待批准、确认或其他用户操作
○ 就绪      Codex 进程存在，但暂时没有可识别的 turn 记录
storage    该 Codex pane 的 cwd 位于 /Volumes/storage
```

面板操作：

| 按键 | 功能 |
|---|---|
| `Ctrl+u` / `Ctrl+e` 或方向键 | 上下选择 Codex |
| `Enter` 或鼠标双击 | 关闭面板并直接跳到对应 session/window/pane |
| 输入文字 | 按 session、window 或路径过滤 |
| `Esc` | 关闭面板 |

下半部分显示所选 pane 的最近输出，便于在跳转前判断任务内容。也可在 shell 中运行 `codex-status` 查看纯文字汇总，运行 `codex-panel` 打开面板。

状态优先读取对应 thread JSONL 中的 `task_started` / `task_complete`，再用 Codex TUI 的 `Working (... esc to interrupt)` 和交互提示作实时补充。因此它能区分“Codex 进程还开着但上一轮已经做完”和“当前仍在工作”。

## 当前视觉规则

- pane 顶部标题居中显示为胶囊；focus 只改变胶囊颜色。当前 pane 与当前 session 共用浅青色，非当前 pane 使用中性深灰。
- Codex 包装进程若被 tmux 报告为 `expect`，仅在标题显示层改写为 `codex`。
- active 和 inactive pane 使用相同的中性钢灰粗边框，不让整条边框随 focus 变色。
- 底栏左侧保留所有 session 段，只显示去掉排序前缀后的名称，不拼接 `index:name`。
- 每个 session 段都带真实 session ID 的鼠标范围，可以直接点击切换。
- session 当前项使用青色块；其后的 window 只显示名称，不显示 window 索引。
- 当前 window 使用珊瑚红文字强调，不使用整块高亮背景。
- window 之间使用低对比度圆点分隔。
- 右下角保留一个与当前 session 同色的 `mbp` 尾块：左侧尖角、右侧贴边；不显示完整主机名、日期或时间。恢复或自动保存期间，仅在 `mbp` 左侧临时显示灰紫色小字 `restore` 或 `save`。
- `C-s U`、`C-s I` 和 `C-s S` 的操作结果会在 `mbp` 左侧显示约 5 秒：绿色 `OK` 表示成功，金色 `!` 表示等待处理，珊瑚红 `ERR` 表示失败。它不会进入 tmux 全屏命令输出页。
- 按 `C-s` 时，快捷键总览固定在右下角临时弹出；按下下一键执行操作后自动关闭，不改变 pane 布局和 focus。
- 状态栏可见内容保持静态；Continuum 只追加不可见的保存检查，实际快照间隔为 5 分钟。

### Window

| 快捷键 | 功能 |
|---|---|
| `Alt+1...9` | 直接切换当前 session 的 window |
| `C-s 1...9` | 切换当前 session 的 window |
| `Alt+o` | 在当前目录新建 window |
| `Alt+l / y` | 上一个 / 下一个 window |
| `C-s Ctrl+p / Ctrl+n` | 上一个 / 下一个 window |
| `C-s ,` | 重命名 window |
| `C-s W` | window 选择树 |

### Pane

Colemak 方向约定：

```text
n = left    e = down    u = up    i = right
```

| 快捷键 | 功能 |
|---|---|
| `C-s n/e/u/i` | 向左/下/上/右分割 pane |
| `Alt+n/e/u/i` | 移动 pane 焦点 |
| `Alt+N/E/U/I` | 每次 3 格调整 pane 大小 |
| `Alt+f` 或 `C-s z` | zoom / 恢复当前 pane |
| `C-s Space` | 切换到下一个布局 |
| `C-s > / <` | 交换 pane |
| `Alt+Shift+q` | 关闭当前 pane |
| `C-s x` | 确认后关闭 pane |
| `C-s Ctrl+g` | 开关同步输入 |

### Copy mode

| 快捷键 | 功能 |
|---|---|
| `Alt+v` | 进入 copy mode |
| `n/e/u/i` | 左/下/上/右移动 |
| `v` | 开始选择 |
| `Ctrl+v` | 矩形选择 |
| `y` | 复制到 tmux buffer 和 macOS 剪贴板 |
| `U / E` | 向上 / 向下滚动 5 行 |
| `Ctrl+Shift+v` | 粘贴系统剪贴板 |

鼠标普通拖选属于 tmux 的选区，松手后自动复制到系统剪贴板，并退出 copy mode；
双击选词、三击选行和 copy mode 中按 Enter 也通过 `/usr/bin/pbcopy` 复制。
此通道由 `copy-command` 指定，不依赖终端处理 OSC 52。

若要像 macOS 应用一样保留选区再按 `Cmd+C`，在 Kitty 中按住 **Shift** 拖动鼠标，
松开后按 `Cmd+C`。这创建 Kitty 自己的选区；普通 tmux 拖选不属于 Kitty，
所以原生 `Cmd+C` 无法直接复制它。全屏程序占用鼠标时也可用 Shift 拖选当前可见文本。
见 [Kitty 鼠标设置](https://sw.kovidgoyal.net/kitty/conf/#mouse-actions)。

### 持久化

| 快捷键 / 命令 | 功能 |
|---|---|
| `C-s S` | 生成并校验一个版本化 checkpoint |
| `C-s P` | 在新鲜 tmux server 中恢复当前选定快照 |
| `tmux-save-all` | 与 `C-s S` 相同，供 Zsh 使用 |
| `tmux-snapshots` | 列出可恢复 checkpoint 及其拓扑数量 |

Continuum 每 5 分钟保存一次，当前保存内容包括：

- session、window、pane、布局、活动项和工作目录；
- 完整的 pane scrollback，不再只保存进程与布局；
- Codex 的准确 `resume <thread-id>` 命令、Yazi、Lazygit 和 IAP 重连命令；
- 最多 90 天的 Resurrect 布局快照。

`C-s S` 还会验证当前 session/window/pane 数量与保存结果完全一致，再把布局、匹配的 scrollback 压缩包、校验和及 storage 状态复制到：

```text
~/.local/share/tmux/resurrect/checkpoints/
```

这比只依赖 `last` 稳妥：中断后产生的缩水拓扑可能成为新的自动保存 `last`，但版本化 checkpoint 不会被后续自动保存覆盖。

自动保存的 scrollback 压缩包只保留最新一份；只有手动 `C-s S` 和弹盘前 checkpoint 会把“该时刻的布局 + 匹配的 scrollback”长期绑定保存。

#### 保存超时与失败保护

`tmux snapshot failed · command timed out` 表示保存任务超过 120 秒，
不等于 tmux session 或 Codex 会话已经丢失。大量历史、系统负载或睡眠唤醒期间
都可能延长保存；具体原因需要查看当次日志，不能仅凭提示判断。

保存现在先写入独立临时目录，校验布局数量、非空面板的历史文件和压缩包后，
才更新正式 `last`。超时会终止本次保存的独立进程组，不影响 tmux server 或 pane
里的 Codex、SSH 等进程；失败保留上一份正式快照。checkpoint 复制与保存共用锁，
自动保存遇到长时间锁占用会跳过本次，手动保存则明确提示稍后重试。
macOS 保存期间使用 `caffeinate -i` 防止空闲睡眠；它不保证合盖后持续运行。

诊断日志自动轮转，不记录 pane 正文：

```bash
tail -n 60 ~/.local/state/tmux/snapshot.log
tmux-save-all
tmux-snapshots
```

日志包含保存开始/校验完成时间、拓扑数量及失败阶段。弹盘入口留出 180 秒等待
保存和清理；保存失败时仍取消弹盘，不绕过占用检查。无需重启现有 tmux。

tmux 仍不能冻结任意程序的内存。scrollback 恢复的是可查看文本，不是可继续交互的 TUI 状态；未保存的编辑器 buffer、程序内未落盘数据和已经退出且没有恢复策略的进程不能保证恢复。Codex 能续接是因为另存了 thread ID，真正进度仍以 Codex session JSONL 和已落盘文件为准。

普通关闭 WezTerm、client detach 或网络断开不会终止仍在运行的 tmux server，此时只需：

```bash
tmux attach
```

只有 tmux server 或机器进程真正退出时才需要 Resurrect。若自动恢复结果明显缩水，不要在已有多 pane server 上直接按 `C-s P`，否则可能产生重复 session。先运行 `tmux-snapshots` 找到正确 checkpoint；只有确认当前 server 没有需保留的进程，并重新进入仅含一个 pane 的新鲜 tmux 后，才执行：

```bash
~/.config/tmux/scripts/tmux_snapshot.py prepare <checkpoint-name>
# 然后按 C-s P
```

`prepare` 在已有多个 session 或 pane 时会拒绝执行。中断前的完整布局已额外固化为 `20260814T153053-pre-interruption-full-layout`，包含 4 session、15 window、32 pane；因为当时未启用内容捕获，它只有布局和恢复命令，没有 scrollback。不要把它直接恢复到目前仍运行 Codex 的 server 上。

### 外置硬盘 SR 工作区

`4-SR` 有五个固定 pane，并会记录后来拆分出的额外 pane。固定目录来自 `storage.json`，额外 pane 的实际目录保存在运行状态中。当前配置按“进入时恢复，显式弹盘时停车”管理：

```text
进入 4-SR：所有已记录的空闲 shell 回到各自 storage 目录
聚焦 Yazi pane：该 pane 首次获得真实 client 焦点后才启动 Yazi；隐藏 pane 不并发启动
切换 session / detach：目录、Yazi、Codex 和后台任务保持原状，不自动停车
C-s U：退出可安全结束的 Yazi/空闲子 shell，所有空闲 SR shell 回到 Home；关闭仍以 storage 为 cwd 的无任务 Kitty 窗口
磁盘未挂载：保持 Home，进入 SR 时在底栏提示，不向不存在的路径执行 cd
磁盘已连接但未挂载：按 C-s I 自动挂载，再切入并恢复
磁盘重新插入：按 C-s I；4-SR 丢失时会按固定映射自动重建
```

| 快捷键 / 命令 | 功能 |
|---|---|
| `C-s U` | 依次停车已登记外接盘的工作区、保存 checkpoint、清理可安全结束的终端占用、检查占用并弹出对应整块物理盘 |
| `C-s I` | 挂载已连接的登记卷，切入 SR，恢复固定及已记录的额外 pane 路径；Yazi 随焦点启动 |
| `storage-eject` | 与 `C-s U` 相同，供普通 Zsh 使用 |
| `storage-restore` | 与 `C-s I` 的恢复逻辑相同，供 tmux 内 Zsh 使用 |

这些操作在 tmux 内只通过底栏 `mbp` 左侧的通知报告结果，不再输出到覆盖整屏的 `run-shell` view。`C-s U` 会依次处理已登记的 `storage`、`Linux`、`兔兔啊`、`U盘` 工作区，并在最后只显示一次汇总；某一卷仍被任务占用时会明确显示 `external eject incomplete · <配置名> not completed`，不会被其他已离线卷的提示覆盖。`usb` 对应 `U盘`。流程通常需要约 10-20 秒。运行期间不要重复按 `U`；重复请求会显示 `operation already running`，不会再启动一份 checkpoint 或弹盘任务。

`U盘` 是 4 GB ExFAT 设备，由 `external-workspaces/usb.json` 中的卷 UUID 识别，不依赖易变的 `disk4` 编号。其 SR pane 路径保存在 `~/.local/state/tmux/usb-workspace.json`；插回同一设备后按 `C-s I` 恢复，不能保证自动重建用户已删除的额外 pane。未登记的其他 U 盘不会被此快捷键自动处理。

2026-09-23 修复：退出旧的 `Yazi -> S shell` 后，`ya emit quit` 可能直接回到另一个 Zsh。清理流程现在等待旧前台 PID 退出，而不是要求命令名必须变成 `yazi`，因此可继续逐层释放目录。若最后仍提示 `QuickLook` 占用，先关闭该卷文件的快速预览再重试；脚本不会自动强杀系统预览服务。本次残留的无可见窗口预览服务经单独确认后清理，随后正常 `diskutil eject` 成功，未强制卸载。

若 storage 卷已经卸载但 USB 硬盘仍连接，`C-s U` 会按卷 UUID 找到父物理盘并再次执行整盘弹出，最终显示 `safe to unplug`。对 macOS 标记为固定介质的 USB 硬盘，成功弹出后硬件仍可能出现在 `diskutil list external physical`；只要 storage 与同盘其他卷都显示 `Mounted: No`，即可安全拔线。

若弹盘因其他进程占用而取消，通知中显示占用进程摘要，完整 `lsof` 结果写入 `~/.local/state/tmux/storage-eject-busy.log`。各阶段耗时与返回码追加到 `~/.local/state/tmux/storage-operations.log`，用于检查“长时间没反应”的具体位置。

正确拔盘流程：

1. 用 `Alt+a` 查看带 `storage` 标记的 Codex；保存工作，并让 Codex、编辑器、下载或计算任务正常结束。
2. 按一次 `C-s U`，等待底栏阶段提示。脚本依次执行“退出可安全结束的 Yazi/空闲子 shell、自动退出已确认完成的 Codex、所有空闲 SR pane 回 Home、生成 `storage-before-eject` checkpoint、关闭仍占用 storage 的无任务 Kitty 窗口及无终端孤儿只读扫描、整盘 `lsof` 检查、`diskutil eject`”。
3. 只在看到 `storage ejected` 后拔线。看到 `still busy`、`snapshot failed` 或 `eject cancelled` 时不要强拔。

不需要杀掉 `4-SR`，保留停车后的 session 才能最快恢复。storage 配置已启用完成态
Codex 自动收尾：仅当 pane 的前台进程确为 `codex`，并连续两次显示 `Ask Codex to do
anything`、且其后没有 `Working`/`esc to interrupt` 时，`C-s U` 才会向该前台进程组发送
`SIGINT` 并继续停车。正在运行、刚开始新任务、状态无法确认或前台并非 Codex 的 pane
仍会拒绝弹出；这类情况先记录 thread ID，等待任务结束后重按 `C-s U`。

重新插入后按 `C-s I`。若卷已连接但处于未挂载状态，配置会按 UUID 找到设备并挂载到 `/Volumes/storage`，然后切到 `4-SR` 并恢复路径；如果 session 已因中断消失，会先重建 `云雷达 / 云雾课题 / AOSL / ERA5` 四个 window 和五个 pane。设备未连接时只给出离线提示，不创建假的目录。

安全边界：

- 直接运行的 Yazi 仅在核实 pane 前台进程确实为 `yazi` 后发送 `TERM`；不再注入 `Esc`/`Q`，避免 Yazi 恰好退出时控制字符泄漏到 Zsh。Yazi 打开的子 shell 只有在确认它处于前台、无子进程且空闲时才会先 `exit`；多层旧 `Yazi -> S shell` 会逐层收起。
- 空闲 shell 才会自动 `cd`。已验证完成提示的 Codex 会自动退出；其余 Codex、编辑器、下载或计算任务会报告 `still busy`，不会终止任务，也不会伪报已经停车。
- 被中断的工具请求偶尔会留下无 TTY、父进程已退出的 `zsh -c find ... | head ...` 只读扫描。`C-s U` 会只在完整进程组仅含 shell、`find`、`head`，且不含 `-delete`、`-exec` 等危险参数时自动结束它；任何带终端、Python/Node/Codex、未知命令或可能写入的扫描仍保留并拒绝弹盘。
- 独立 Kitty 窗口不属于 tmux pane。若其子树仅包含 shell、Yazi、tmux client，或本地 `iap` 客户端，`C-s U` 会关闭该窗口以释放外接盘；IAP 的远端 tmux 会话不会被删除。窗口内存在 Codex、Python、Node、编辑器或未知进程时，脚本会保留窗口并取消弹盘。
- 自动切换 session 的 hook 始终返回成功，不再在顶部显示 `external_workspace.py switch "" returned 1`。进入离线或 busy 的 SR 时只在底栏提示；需要主动弹盘时，`C-s U` 会在底栏报告具体 busy pane。
- 五个目标目录以 `external-workspaces/storage.json` 为准，不再让陈旧运行状态覆盖配置；发送给 shell 的 `cd` 也带目录存在判断，即使命令因 TUI 退出而延迟执行，也不会对已卸载路径报错。
- 配置外拆分出的 pane 会按 `window:pane-index` 保存路径及 Yazi 恢复标记；插盘后同一 pane 仍会回到原目录。
- session 切换和 client detach 永远不停车，避免打断后台 Codex，也避免反复向 Yazi pane 注入 `cd`。因此拔盘必须显式使用 `C-s U`，不能把“已离开 SR”当成“可以拔盘”。
- Yazi 启动时会查询终端能力。恢复阶段只启动真实 client 当前可见的 Yazi pane，其他 pane 等获得焦点后再启动，避免 WezTerm 的 DA/DSR 响应混入另一个 shell。
- `C-s U` 在 SR 释放后、弹盘前强制生成一份路径已回到 Home 的 checkpoint；保存或校验失败会取消弹出。弹盘目标通过 storage 卷 UUID 解析为父物理盘，避免只卸载单个分区而遗漏同盘卷。
- 从停车到 `diskutil eject` 的完整流程使用互斥锁；重复按 `U`、同时执行 `storage-restore`，或弹盘期间触发 SR 自动 hook，都不会启动冲突操作。
- checkpoint 成功后还会用 `lsof` 检查整块盘。Finder、百度网盘或其他应用仍在使用硬盘时会取消弹出；底栏显示占用进程摘要，完整结果保存在 `~/.local/state/tmux/storage-eject-busy.log`。
- `lsof` 最多等待 12 秒，`diskutil eject` 最多等待 45 秒。超时或无法可靠完成占用检查时会取消弹出并明确报错，不会把检查失败当成“无人占用”。

固定路径映射保存在 `external-workspaces/storage.json`，额外 pane 路径和运行状态保存在 `~/.local/state/tmux/storage-workspace.json`。状态文件独立于 Resurrect 快照，因此即使快照记录的是停车后的 Home，重新进入 `4-SR` 仍会恢复正确的硬盘路径。

Resurrect 原版会用全宽 `display-message` 反复显示 `Restoring...`，遮住底栏中的 session/window。当前配置由 `resurrect_status_activity.sh` 接管进度显示：只在 `mbp` 左侧显示紧凑状态，任务结束后立即消失；真正的错误仍使用醒目的 tmux message。

Codex 恢复保存完整 thread ID，并用 `command codex --yolo resume <thread-id>` 绕过 shell alias，避免 `--yolo` 被重复添加。自定义前台进程策略会穿过 Yazi 和嵌套 shell，避免把正在运行的 Codex 错记为 `yazi`。

`iap` 现在连接到 IAP 登录节点上的远端 `iap` tmux session：

```bash
iap
```

SSH 每 10 秒发送一次应用层心跳，连续两次无响应后断开；任何非主动停止的 SSH 退出都会在 3 秒后重连并 attach 原远端 session，不再只处理退出码 `255`。`iap` 支持最多 20 个并行实例：第一个使用远端 session `iap`，后续依次使用 `iap-2`、`iap-3`。每个实例有独立锁、远端 tmux session、尺寸和重连循环，因此可以多开，但不会让不同大小的窗口争抢同一个远端 client。

login02 使用 tmux 1.8，它会把不存在的 session 名按前缀匹配。例如只存在 `iap-2` 时，普通的 `has-session -t iap` 也会错误成功，随后两个本地实例会一起 attach `iap-2` 并通过 `-d` 每隔几秒互相踢下。当前 wrapper 先用 session 列表做完整名称匹配，确保 `iap`、`iap-2` 分别真实存在，再执行 attach。若终端反复显示 `[detached]`、SSH `exit 0`，优先检查远端同名 session；真正的网络中断通常是 SSH `255`、`Broken pipe` 或 keepalive timeout。

本地 pane 顶部会分别显示 `iap`、`iap-2` 等标签；`C-s t` 优先切换当前 IAP pane 对应的远端状态栏。关闭本地 pane 会停止该实例的重连并释放槽位；远端 session 保持 detached，下一次取得同一槽位后继续 attach。若父终端异常退出，wrapper 也会自行清理，不会遗留后台 SSH。

连接不再启用 X11 forwarding，因此不会出现 `xauth key data not generated`；远端配置命令也全部静默执行。IAP 上的长期计算仍应在计算节点、调度系统或远端 tmux 中运行，不能在登录节点直接跑作业。

远端 tmux 1.8 已启用 `mode-mouse` 和 `100000` 行历史。鼠标滚轮会进入内层 copy mode 并查看历史；按 `q` 返回当前输出。若不使用鼠标，也可按远端前缀 `Ctrl+b`，再按 `[` 进入 copy mode。

远端 tmux 的默认状态栏已隐藏，不再显示 `[iap] 0:bash*`、主机名、时间和日期。本地 pane 顶部显示 `iap · 当前目录`；需要查看远端窗口时，按本地前缀 `C-s`，再按 `t`，可立即显示/隐藏仅含窗口名的精简状态栏。这个操作由本地直接向已连接的 IAP pane 发送命令，不需要输入远端的 `Ctrl+b` 前缀，也不会额外建立 SSH 连接。

颜色能力按终端层级声明：WezTerm 使用 `xterm-256color`，本地 tmux pane 使用 `tmux-256color`，IAP SSH client 使用 `xterm-256color`，login02/login03 的远端 tmux pane 使用 `screen-256color`。远端是 tmux 1.8，不能可靠传递 RGB；wrapper 与共享 `.bashrc.minkerui` 会在内层 tmux 中移除 `COLORTERM=truecolor`，并把历史 pane 的 `TERM=screen` 升级为 `screen-256color`。LazyVim 使用带 cterm 定义的 `habamax`。所有层仍会清除 `NO_COLOR`，所以远端保留 256 色，而不是黑白。本地 tmux 继续使用 truecolor，并在 client attach 时更新 `TERM`、`TERM_PROGRAM`；后两项是本地 Yazi 在 tmux 中识别 WezTerm `Iip` 图像后端所必需的。

若 Yazi、Lazygit 等多个 TUI 同时近乎黑白，使用下面的值排查，优先检查环境而不是主题：

```bash
printf 'TERM=%s COLORTERM=%s NO_COLOR=%s\n' \
  "$TERM" "${COLORTERM:-unset}" "${NO_COLOR-unset}"
tput colors
```

本地 pane 应显示 `tmux-256color / truecolor / unset / 256`；login03 应显示 `screen-256color / unset / unset / 256`。关闭再打开 WezTerm 通常只是重新 attach 仍在后台运行的 tmux server，不会重建 server、pane、shell 或其中的 Yazi。可用下面的命令核对存活时间：

```bash
tmux display-message -p 'server=#{pid} pane=#{pane_pid}'
ps -p "$(tmux display-message -p '#{pid}')" -o lstart=,command=
```

旧 shell 已继承的环境不能通过 `tmux source-file` 反向修改。当前 zsh 启动配置会主动移除 `NO_COLOR`；对仍在运行的旧空闲 shell，退出当前 TUI 后执行 `source ~/.config/zsh/aliases.zsh` 再启动 Yazi/Lazygit，或直接新建 window。若 Yazi 的 PDF/图片层越过 pane，可用 `yazi --debug` 检查 `Brand.from_env=WezTerm` 和 `Adapter.matches=Iip`，重开 Yazi 后按 `C-s R` 强制整屏重绘。

## 启动时报 `no current session`

`~/.tmux.conf:<行号>: no current session` 表示配置在没有当前 session 的 tmux server 中执行了一个需要 session 目标的命令。先按报错行号检查，不要直接删除 tmux socket，也不要用 `kill-server` 规避。

本机曾由下面的错误选项作用域触发：

```tmux
# 错误：repeat-time 不是 server option
set -s repeat-time 350

# 正确：设置所有 session 的全局默认值
set -g repeat-time 350
```

当前配置已经修正。即使 server 尚无 session，整份配置也能通过检查。若以后修改配置后再次出现类似错误：

```bash
# 查看报错行及上下文
nl -ba ~/.tmux.conf | sed -n '8,20p'

# tmux 仍可进入时，修正后重新加载并检查
tmux source-file ~/.tmux.conf
tmux source-file -n ~/.tmux.conf
```

如果错误导致完全进不了 tmux，先绕过配置建立一个救援 session：

```bash
tmux -f /dev/null new-session -d -s rescue
tmux source-file ~/.tmux.conf
tmux attach -t rescue
```

`-f /dev/null` 只在启动新 server 时跳过有问题的配置，不会删除 Resurrect 快照。进入后先确认 server 是否只有这个新鲜 pane；只有没有需要保留的运行任务时，才使用 `C-s P` 恢复快照。已有多个活跃 pane 时不要重复恢复，否则会产生重复 session 和 Codex 进程。

## tmux server 停止后恢复历史 session

先区分两种情况：client 断开但 server 仍在时，只需 `tmux attach`；`tmux list-sessions` 显示 `no server running` 时，才需要 Resurrect。冷恢复步骤：

```bash
tmux
# 进入新鲜的单 pane 后按 C-s P
```

当前配置也会在新 server 的第一个真实 client attach 后自动恢复最近快照。恢复期间会暂停 session 自动重编号，把新鲜的 `1-0` 临时改回 Resurrect 需要的 `0`；恢复结束后自动恢复编号 hook，因此 `1-IAP`、`2-Config`、`3-T_WORK`、`4-SR` 不会在创建途中被改乱。

Resurrect 能恢复 session/window/pane、布局、工作目录、保存的 pane scrollback，以及白名单中的 Codex、Yazi、lazygit 和 IAP 命令。它不能恢复进程的内存状态；Codex 依靠 thread ID 重新 `resume`。若同一个 thread 正在 Codex App 中运行，CLI pane 会看到 `already has an active writer` 并回到 shell，这是写入保护，不是历史丢失；结束当前任务后在该 pane 重新执行对应的 `codex resume <thread-id>` 即可。

检查最近快照：

```bash
readlink ~/.local/share/tmux/resurrect/last
python3 ~/.config/tmux/scripts/tmux_snapshot.py list --limit 10
```

不要为了恢复删除 `/private/tmp/tmux-*` socket，也不要先运行 `tmux kill-server`。`C-s P` 只应在新鲜单 pane 中执行一次；若已有重要任务，先保存当前 checkpoint，再决定是否合并恢复。

## Dotfiles 结构

```text
dotfiles/
└── tmux/
    ├── .stow-local-ignore
    ├── .tmux.conf
    ├── Codex_resume_tmux.md
    └── .config/tmux/
        ├── external-workspaces/
        │   └── storage.json
        ├── scripts/
        │   ├── codex_dashboard.py
        │   ├── copy_to_clipboard.sh
        │   ├── external_workspace.py
        │   ├── iap_remote_status.sh
        │   ├── iap_remote_tmux.sh
        │   ├── install_persistence_plugins.sh
        │   ├── new_session.sh
        │   ├── open_codex_dashboard.sh
        │   ├── paste_from_clipboard.sh
        │   ├── resurrect_foreground_process.sh
        │   ├── resurrect_session_hooks.sh
        │   ├── resurrect_status_activity.sh
        │   ├── restore_once_attached.sh
        │   ├── tmux_notice.py
        │   ├── tmux_snapshot.py
        │   ├── tmux_which_key.py
        │   └── session_manager.py
        └── tmux-status/
            └── left.sh
```

激活方式：

```bash
cd /Users/xiaoxiaotu/dotfiles
stow -t /Users/xiaoxiaotu tmux
~/.config/tmux/scripts/install_persistence_plugins.sh
tmux source-file ~/.tmux.conf
```

插件采用官方手动安装方式，位于 `~/.config/tmux/plugins/`，不提交进 dotfiles。安装脚本会为 Codex 恢复策略和紧凑恢复状态建立受管链接；升级后也会重新应用。首次安装执行上面的脚本；升级时执行：

```bash
~/.config/tmux/scripts/install_persistence_plugins.sh --update
```

自动快照保存在 `~/.local/share/tmux/resurrect/`，版本化 checkpoint 保存在其 `checkpoints/` 子目录。`Codex_resume_tmux.md` 留在仓库的 `tmux/` 目录，并由 `.stow-local-ignore` 阻止链接到家目录根部。

本次替换前的冲突文件保存在：

```text
/Users/xiaoxiaotu/dotfiles/.tmp/tmux-base-backup-20260811-205829/
```

## 第二阶段建议

### terminal-notifier

值得安装，但应在实现 Codex 完成/等待输入通知时一起安装和验证：

```bash
brew install terminal-notifier
```

通知应带 session/window/pane 标识，并允许点击后回到对应 WezTerm 窗口；只弹“任务完成”价值不大。

### Codex 用量

不要安装旧的 `@ccusage/codex` / `ccusage-codex`。该包已经废弃，官方项目已统一为 `ccusage`：

```bash
npm install -g ccusage
ccusage codex daily
```

若以后放进状态栏，应使用 30-60 秒缓存，不能跟随 tmux 状态刷新频繁扫描 Codex 日志。

### 暂不加入

- 完整 agent-tracker：规模过大，且包含 Claude/opencode 假设。
- 第二行 AI 状态栏：先确认通知和多 Codex pane 工作流，再决定是否值得占用屏幕。

## 当前验收重点

请在不同 session 中实测：

```text
Ctrl+1
Ctrl+2
Ctrl+3
Ctrl+4
```

然后创建两个 pane，测试：

```text
Alt+n/e/u/i
Alt+N/E/U/I
Alt+f（按两次）
```

如果这些正常，第一阶段即可视为稳定基线；第二阶段再加入纯 Codex 通知和用量模块。

## Shell 不断出现鼠标坐标乱码

如果移动鼠标时不断出现 `35;50;20M` 等字符，可能是全屏程序退出后，
面板仍保留鼠标上报模式，tmux 因而把鼠标事件转给了已经回到提示符的 shell。
这不是 LaTeX 文件内容损坏，也不需要关闭 tmux 全局鼠标功能。

`zsh/.config/zsh/aliases.zsh` 现在通过 `precmd` 在交互式 tmux shell
显示提示符前关闭残留的鼠标、焦点上报及备用屏幕模式；前台程序运行期间不执行。
新 shell 自动加载。已经打开的旧 shell 需在空闲提示符执行
`source ~/.config/zsh/aliases.zsh` 才会加载新保护。
加载后，若 shell 输入行被污染，按 `Ctrl+C` 取消输入并触发提示符清理，
不要按 Enter 执行乱码；不要在仍运行任务的面板盲目按 Ctrl+C。

2026-10-04 实测 `1-IAP:latex` 的 `%10` 只有 zsh，却保留鼠标上报和备用屏幕；
已定向清理并加载保护。两个相邻 Yazi 未被中止。具体哪个程序留下模式尚无日志
证据，不能仅凭此现象认定是快照恢复或 Yazi 导致。

## Storage 已进入目录但无法读取

如果 `pwd` 显示硬盘目录，而 `ls` 返回 `Operation not permitted`，
不能按路径显示判断恢复成功。先在系统设置的“隐私与安全性 → 文件与文件夹”
检查终端的“可移除的宗卷”权限，再确认 tmux 服务进程实际能读取磁盘。
旧 tmux 服务的权限归属可能与当前连接它的终端不同；仅切换客户端不保证权限改变。
不要为此关闭仍承载 Codex 等任务的 tmux 服务。

`Ctrl+s I` 的 storage 恢复入口现在先由 tmux 服务运行磁盘目录读取检查。
读取被拒绝时会返回失败，提示检查 macOS 终端权限，详细错误写入
`~/.local/state/tmux/storage-operations.log`；检查通过才继续切换和恢复。
“完全磁盘访问权限”覆盖范围比可移除宗卷更大，须用户确认后再调整，
调整后仍应在原面板执行 `ls` 实测；不能仅凭开关状态宣称问题已解决。

## 命令执行后看不到输出

先按 `Ctrl+q` 尝试解除软件流控暂停；再按 `Ctrl+s`、`Shift+r`（大写 R）
整屏重绘。`C-s R` 已从只重绘状态栏的 `refresh-client -S` 改为
`refresh-client`。Zsh 提示符清理也会设置 `stty -ixon -ixoff`，避免发送到
shell 的 Ctrl+s 暂停输出。新 shell 自动生效；旧 shell 可在空闲时执行
`source ~/.config/zsh/aliases.zsh` 加载。

2026-10-11 已在当时空闲的 shell 应用关闭流控，并验证模拟终端收到 Ctrl+s
后仍能输出。由于未捕获用户报告的异常现场，这属于已确认配置问题的修正，
尚不能断定所有无输出现象都由流控引起。若再次发生，保留现场并记录 window/pane，
对比 `tmux capture-pane` 与屏幕：缓冲有输出而屏幕无输出时再排查客户端渲染。
