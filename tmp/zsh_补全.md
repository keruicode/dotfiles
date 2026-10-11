# Zsh 补全

## 2026-09-16：修复 `unzip -x` 的 archive 条目补全

`unzip archive.zip -x <Tab>` 现在会列出该 zip 内可排除的文件路径，包括含空格和嵌套目录
的条目。普通 `unzip` 参数仍使用系统 `_zip` 补全，未改变其他压缩命令行为。

当前已打开的 shell 执行一次：

```zsh
source ~/.config/zsh/aliases.zsh
```

新开终端或 tmux window 会自动加载。命令必须先给出 archive，例如
`unzip archive.zip -x <Tab>`；未给 archive 时无法得知可排除的内部条目，Tab 会改为补全
本地 `.zip` 文件。

验证：临时 zip 的 `alpha.txt` 与 `nested/beta file.txt` 均被补全函数返回；
`zsh -n` 和 `git diff --check` 通过。
