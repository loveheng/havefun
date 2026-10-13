---
name: xiaolequ-docs
description: 校乐趣0825（与 PM 协作的产品需求/设计文档项目，无代码）的 docs/ 域落点表、lint 路径与本仓例外。新增/修改/移动/废弃工程文档时先读本表定落点，规范机制一律指针到全局 docs-spec。
---

# 校乐趣0825 · 文档域表（项目数据）

规范机制（frontmatter / 切片命名 / Tombstone / 索引维护 / lint）见全局 skill `docs-spec` §1–§7，本文件只记项目数据，禁止复制规范正文。

## 域目录表

| 域目录 | 用途 | 现有文档 |
|---|---|---|
| `docs/requirements/` | 产品需求域：需求文档的评估、拆解、版本演进 | `requirements/需求文档评估.md`、`requirements/需求覆盖度清单.md`、`requirements/自建服务难度评估.md`、`requirements/数据闭环推演.md`、`requirements/缺失补全方案.md`、`requirements/端与交付物清单.md` |

- 新域按实际出现登记；跨域架构/方案决策类文档落 `docs/decisions/`（按需创建）。
- **面向 PM 的评估/评审类文档**：首节固定 `## 结论（给 PM）`（≤5 行：判断 + 待拍板问题）；细节正文随后，裁剪交付只取该节。结论提炼由 AI 会话完成，不依赖脚本。
- 根目录 `需求文档.md` 为产品需求 1.0 原文（PM 协作对象，暂不迁入 docs/；迁入时按 docs-spec §2 三处同步）。

## lint 脚本路径

- `toolbox run docs-lint`（全局池，本机已装 toolbox）。

## 本仓例外

- 无。
