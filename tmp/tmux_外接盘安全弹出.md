# Tmux 外接盘安全弹出

## 2026-10-09：storage 安全退出成功

storage 已安全退出，可以拔线。tmux 快照和工作路径已保存，重新插入后按 `Ctrl+s I` 恢复。

## 2026-10-07：磁盘权限已修复并实测恢复

现在恢复正常了。已开启你授权的 WezTerm 完全磁盘访问权限，并在原来报错的 AOSL 面板执行 `ls`，文件已正常列出。

`Ctrl+s I` 也已修正：会检查实际磁盘读取权限，失败时明确提示原因。现有 tmux 会话和 Codex 任务保留。

## 2026-10-07：恢复失败原因更新

已确认 tmux 实际读取 `storage` 时被系统拒绝：`Operation not permitted`。上一轮只验证路径，恢复成功的判断不完整。

已修正 `Ctrl+s I`：现在先检查 tmux 服务能否读取磁盘，失败会明确提示并记录原因。测试通过。

界面中 WezTerm、Kitty 的“可移除宗卷”权限均开启，“完全磁盘访问权限”关闭。已停在权限页面，等待用户确认是否扩大 WezTerm 权限后再测试；当前尚未恢复目录读取。

## 2026-10-07：已执行 storage 工作区恢复

已恢复并切换到 `4-SR → AOSL`，现存的硬盘工作目录可访问。
“雾微物理课题”第二面板原路径不存在，仍停在 Home；未擅自改目录。
没有重启 tmux、推出硬盘或修改 Kitty。

## 2026-10-07：storage 与 SR 状态检查

storage 已正常挂载在 `/Volumes/storage`，SR 会话存在，多数面板已进入硬盘目录，Yazi 能显示文件。
发现“雾微物理课题”第二面板保存的 `/Volumes/storage/WORK/SR_论文修改/05_论文稿件/最终稿` 已不存在，所以该面板停在 Home。
待确认用户说的“打不开”是 Ctrl+s I 恢复失败，还是 Ctrl+s U 推出失败，以及对应窗口或报错。未卸载磁盘、终止进程或修改 Kitty 配置。

## 2026-10-04：确认 storage 已退出

已确认 **storage 已退出，可以拔线**。SR 路径已保存，重新插入后可按 `C-s I` 恢复。

## 2026-09-28：storage 已成功弹出

**storage 已安全弹出，可以拔线。** 已释放 Yazi／子 shell 占用并保存恢复快照；同盘各卷均已卸载，未强制卸载。

## 2026-09-27：storage 已成功弹出

**storage 已安全弹出，可以拔线；Linux 未动。**

这次是 `AOSL.2` 的多层 Yazi／子 shell 超过单次清理限制。已逐层释放占用、保存恢复快照，并确认 `storage` 和同盘 `backup` 均已卸载。本次未修改清理上限，也未强制卸载。

## 2026-09-23：U盘已成功弹出

**U 盘已安全弹出，可以拔出。**

原因有三处：快捷键原来未登记这块 U 盘、嵌套 Yazi 未完全退出、Quick Look 残留 PDF 占用。

已补齐登记、修复 Yazi 清理并释放预览占用。下次用 `Ctrl+s U` 弹出，插回后用 `Ctrl+s I` 恢复已记录目录。若仍有 Quick Look 占用，需先关闭对应预览；不会强制卸载。

## 2026-09-18：本次弹出成功

storage 开始时已挂载在 `/Volumes/storage`，`lsof` 未发现任何占用进程。执行与 `C-s U`
完全相同的后端流程后返回 `external eject complete · storage, linux, tutu` 与
`eject_result=0`，挂载点已消失。现在可以安全拔出。

## 2026-09-16：本次快捷键失败已修复并实测

本次 `C-s U` 已自动关闭完成态 `AOSL.1` Codex，但最后仍被一个无终端、父进程已退出的
`zsh -c find ... | head ...` 孤儿扫描占用。该扫描来自中断后的工具检索，不属于 tmux 或
Kitty pane，因此原有 `lsof` 只会取消弹出。

现已在 `lsof` 前加入严格白名单清理：仅清理完整进程组只含 shell、`find`、`head`，无
TTY，shell 父进程已退出，并且没有 `-delete`、`-exec`、`-ok` 等写入/执行参数的只读扫描。
实际重新执行弹盘后已自动关闭该扫描，`lsof` 为空、`diskutil eject` 成功，storage 挂载点
已消失。之后同类残留直接按一次 `C-s U` 即可处理。

## 2026-09-16：完成态 Codex 自动收尾

`C-s U` 不再需要人工请求 Codex 退出才能弹盘。storage 已启用
`close_completed_codex`：仅当前台进程确为 `codex`，并连续两次捕获到
`Ask Codex to do anything` 完成提示、且提示后无工作状态时，才会向该前台进程组发送
`SIGINT`，等待回到 shell 后继续停车和弹盘。

运行中、刚开始新任务、状态无法确定或非 Codex 前台进程一律不会被关闭，仍会保持
`still busy` 并拒绝推出。这样可自动处理此前反复出现的“任务已完成但 Codex CLI 仍持有
storage cwd”情形，同时不牺牲未完成工作的保护。重新插入硬盘后按 `C-s I` 恢复。

## 2026-09-16：本次结果

storage 已成功退出，可以安全拔出。`C-s U` 的绑定和后端脚本均正常触发；它取消弹出是
因为 `4-SR:3.1` 有 Codex 仍以 storage 为当前目录。该 pane 已显示任务完成，确认无
运行中工作后正常中断该 Codex，再执行同一弹盘流程即成功，挂载点已消失。

当 `C-s U` 因 Codex 取消时，这表示保护机制生效，而不是快捷键失效。先在提示的 pane
确认 Codex 已完成并退出；若仍在工作，则不能安全弹出。重新插入硬盘后按 `C-s I` 恢复。

## 当前结论

2026-09-15 已再次确认 storage 真正退出：当前挂载点已不存在，可以安全拔出。
本次最后的占用不是 Kitty 或 Yazi，而是 `AOSL.1` 中一个已经完成、仍停留在 Codex
交互界面的进程；它的当前目录仍位于 storage。确认任务已完成后才结束该 Codex，随后
执行与 `C-s U` 相同的后端流程成功完成停车、checkpoint 和整盘弹出。

```text
external eject complete · storage, linux, tutu
eject_result=0
```

本次失败的直接根因已修复：旧的 Yazi 停止流程会先发送 `Esc`/`Q`。当 Yazi 已经退出，
这些按键会泄漏至 Zsh，形成 `Q[` 前缀，令自动 `cd /Users/xiaoxiaotu` 变成无效命令。
现在仅确认前台 PID 确为 Yazi 后发送 `TERM`，不会向 shell 注入控制字符；多个旧的
`Yazi -> S shell` 层也会逐层退出。

此前的根因是流程只处理 `4-SR` 的 tmux pane，遗漏了不属于 tmux 的 Kitty OS 窗口。已
实现并验证关闭三类无任务 Kitty 会话：

- 直接连接本地 tmux 的 Kitty client；
- Yazi 及其 `S` 打开的空闲 shell；
- Yazi 内启动的本地 IAP 客户端。该客户端关闭后，远端 IAP tmux 会话仍在服务器上。

`C-s U` 只会关闭由 Kitty 承载、且进程树仅含 shell、Yazi、tmux client 或本地 IAP
client 的会话。检测到 Codex、Python、Node、编辑器、下载或未知命令时会保留窗口并
拒绝弹盘，不会为拔盘强杀工作。若提示 Codex 占用，应先在该 pane 确认已出现完成提示，
再退出 Codex 后重按 `C-s U`。

## 下一步

重新插入 storage 后，按 `C-s I`。它会按 UUID 挂载磁盘、切入 `4-SR` 并恢复保存的
目录与延迟启动的 Yazi；独立 Kitty 窗口不会自动重开，避免再次无意占用硬盘。

## 已修复

- `C-s U` / `C-s I` 改为显式 `python3` 启动，避免脚本没有执行位时静默失败。
- 多卷流程只显示一次最终汇总，不再由其他已离线卷覆盖 storage 的失败原因。
- tmux 的预期非零退出码不再显示为顶部 `returned 1` 错误。
- `C-s U` 新增基于 `lsof` 和 Kitty 进程树的独立窗口清理；进程参数出现非 UTF-8 字节时以替换解码继续检查，不再让脚本异常退出。
- Yazi 停止改为 PID 定向 `TERM`，并递归处理多层空闲 `Yazi -> S shell`，不再向 shell 泄漏 `Esc/Q`。
