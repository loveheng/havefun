---
dev-loop: devlog
format: v1
epic: misc
total-merged: 0
last-merge: none
---

# misc · 过程日志（追加区，≥5 条归并进 memory.md）

## 2026-10-13

- dev-init 裁剪版接入：文档协作项目，跳过代码向步骤（workflow 命令实测 / 脚本池 / 副作用白名单），理由见 memory.md。

## 2026-10-14

- 评估「文档工程还缺什么」：结构无缺；识别出 ① 内容卡在 PM 批注（D1~D8）② 过程记忆断点缺失过期 ③ 旧工期值残留（5.5~6 / 8~9 个月，10-14 方案 A 调整未同步 TSV 与机械汇总）。
- 用户拍板写作对象扩到协调人员 → 新增协调域 docs/coord/：协调事项清单-给协调人.md（四要素 + 时间门槛 + 已定事项）+ 对接函-校园网校园卡.md（底稿，三方清单承诺的欠账交付物）；域表/README/协调域纪律三处登记。
- 修旧值：TSV 已知值同步 6.5~7 / 9~10；重生成 PM结论汇总-原始.md；给PM 版生成日期与源标注刷新。
- 修 pm-conclusions.sh：-o 生成时小节内指向源目录同目录的裸 .md 链接改写为输出目录相对路径（防搬目录断链）；首版有 ERE 括号未转义 bug（sed 永不命中），xtrace 定位后修复。
- 全链自检绿：docs-lint / doc-refs / docs-word-scan / derived-check / docs-key-facts（110 处命中、0 条 0 命中）。
