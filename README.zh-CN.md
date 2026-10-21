# codex-delegate

**Claude 指挥，Codex 干活。** 一个 Claude Code skill，适合 Claude 额度紧张时使用：
Claude 负责架构、设计、写任务书、验收和关键判断，把最耗 token 的部分（写代码、重构、写测试、
反复构建和跑测试）交给本机的 [Codex CLI](https://github.com/openai/codex)。

[English](README.md)

## 为什么

一次编码会话里，大部分 token 都花在读文件、改代码、根据构建和测试失败反复修改上；真正需要判断的部分
（做什么、怎么做、结果对不对）用量小得多。这个 skill 按这条线分工：

| Claude（token 紧张） | Codex CLI（用它自己的额度） |
|---|---|
| 架构、设计、取舍 | 实现、重构 |
| 写精确的任务书 | 写测试、跑构建和测试 |
| 只读 ≤ 25 行的报告 | 写报告 |
| 在沙盒外复核、提交 | 从不 commit |

一两行的小改动仍由 Claude 直接改，写任务书反而更费。

## 工作流程

```
 你 ──► Claude：方案 + 任务书 ──► run-codex.sh（后台）──► codex exec（workspace-write 沙盒）
                                                          │ 改代码、跑测试
 Claude ◄── 完成通知 ◄── 最后一条消息 + 报告 + git status
   └─► 在沙盒外复核构建/测试/启动 ─► 提交，或再写一份简短的修正任务书
```

- 任务书模板依次是：**硬约束**（你的全局禁区、不要 commit、不要改记忆文件）、**已验证事实**
  （避免 Codex 重复探索）、具体要做什么、验证命令、**报告约定**（写在仓库外、限制行数）。
- `run-codex.sh` 在 Claude Code 的 **后台** Bash 任务里前台运行 `codex exec`，结束时 Claude
  会收到通知，不需要轮询。
- Claude 只读结论，检查 `git status` 有没有多余文件，在沙盒外重跑沙盒做不了的事
  （如 `xcodebuild`、启动 GUI App、联网），通过后再提交。

## 前置条件

- [Claude Code](https://docs.claude.com/en/docs/claude-code)（命令行、桌面 App 或 IDE 插件均可）
- 已登录的 Codex CLI：
  ```bash
  npm i -g @openai/codex
  ```
  ```bash
  codex login
  ```
  （也可以 `brew install codex`）
- `git`、`bash`。在 macOS 上测试过；脚本是通用 bash，Linux 上应该也能用。

检查环境（只读，不改任何东西）：
```bash
skills/codex-delegate/scripts/check-setup.sh
```
它还会发现 `codex` 是不是设置了 `CODEX_HOME` 的 shell 函数或 alias（多账号时很常见）。
Claude Code 的非交互 shell 不会加载这类函数，需要给脚本传 `--codex-home`。

## 安装

**作为插件（推荐）**，在 Claude Code 里：
```
/plugin marketplace add LeiZiKang/codex-delegate
/plugin install codex-delegate@codex-delegate
```

**作为普通 skill**，把 skill 目录复制到个人 skills 目录：
```bash
git clone https://github.com/LeiZiKang/codex-delegate
```
```bash
cp -R codex-delegate/skills/codex-delegate ~/.claude/skills/
```
（只给某个项目用就放到 `<项目>/.claude/skills/`。）

## 用法

在 Claude Code 里直接说，例如：

- "Claude 额度不多了，你来规划，让 Codex 写代码。"
- "把设置页交给 Codex 做，你来验收。"
- "这次重构用 codex-delegate。"

Claude 会：
1. 跑环境检查。
2. 按 `templates/brief.md` 写任务书，放在仓库外的笔记目录。
3. 用后台任务运行 `scripts/run-codex.sh --repo … --notes … --brief …`。
4. 完成后读 Codex 的短报告、检查 `git status`、跑真实的构建和测试，通过才提交；不通过就写简短的修正任务书再跑一轮。

### run-codex.sh

```
run-codex.sh --repo DIR --notes DIR --brief FILE [--name TASK]
             [--network] [--codex-home DIR] [--model M] [--stall-minutes N]
             [-- 其他 codex 参数...]
```
在笔记目录写出 `run-<task>.log`、`last-<task>.txt` 和 `<task>.done`（退出码），
然后打印 Codex 的最后一条消息、token 用量和 `git status --short`。

## 实战经验（已写进 skill）

- 不要用 `&` 自行后台化，否则收不到完成通知；用 Claude Code 的 `run_in_background`。
- stdin 管道没关时，`codex exec` 会一直等它（卡在 "Reading additional input from stdin..."，曾有两个并行任务空等 5 小时）。
  一律加 `< /dev/null` 或用 stdin 传任务书；脚本还带了看门狗，卡住会中止并返回 124。
- 并行跑多个任务：每个任务单独起一个后台任务，改的文件互不重叠，构建目录和缓存分开。
- Codex 的 `workspace-write` 沙盒里，SwiftPM 需要 `--disable-sandbox`，并把模块缓存放到项目内；
  `xcodebuild` 包解析、LaunchServices（`open` 报 `-10827`）、私有框架、Apple Events、
  经常还有网络都会失败，这些由 Claude 在沙盒外复核。
- Codex 有时会把报告写进仓库：任务书里写明"绝不写进仓库"，验收时一定看 `git status`。
- UI 验收：让 Codex 自己出预览图（Xcode MCP `xcrun mcpbridge` 或 SwiftUI `ImageRenderer`），
  对照清单自查，只交最终小图和逐条结论。

## 安全

Codex 以 `-s workspace-write` 运行：只能写仓库、笔记目录和临时目录；除非传 `--network`，否则不联网。
skill 不会使用 `--dangerously-bypass-approvals-and-sandbox`。提交前由 Claude 审 diff。

## 许可证

MIT
