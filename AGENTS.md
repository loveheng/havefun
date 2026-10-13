# AGENTS.md（校乐趣0825 · 文档协作项目）

> 项目性质：与项目经理协作的产品需求/设计文档项目，无代码。文档规范归 `.agents/skills/xiaolequ-docs/SKILL.md` + 全局 `docs-spec`；过程记忆归 `context/`。

## 会话初始化（新窗口开场执行一次）

- 开场含「继续/开工/初始化」或首次指令时：跑 `toolbox run panel`（无 toolbox 或无 panel 工具时跳过）→ 读 `context/CURRENT` → 绑定 epic 的 `memory.md` 断点 → 输出会话绑定卡（域/状态）→ 按断点开工或等指令。
- CURRENT 缺失/none → 列 `context/epics/` 候选请用户选，严禁自选开工；无 context/ → 提示走 dev-init 接入；命令速查 `~/.agents/COMMANDS.md`（存在时）。
- 文档改动收尾：跑 `toolbox run docs-lint`，并确认实质修改刷新了 frontmatter `updated`。
