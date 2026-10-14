#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把《工期评估-按功能点-给PM》转成电子表格：生成 Flat ODS，再由 soffice 转 xlsx。"""
from html import escape

# 每个工作表: (名称, 表头, 行数据)
CONCL_HEAD = ["项", "内容"]
CONCL_ROWS = [
    ["读法说明", "本文只算服务端：3 名后端承担的业务模块 + 后台模块、含 20% 测试；项目总排期（含 M0 选型、App 端开发、上架收尾）以《排期与里程碑计划-给PM》为准"],
    ["总工期", "业务模块 + 后台模块全部功能点，三人并行、人均每周 3 天投入、含 20% 测试，服务端线收口约 6 个月"],
    ["一期 MVP", "一期服务端功能点约 4~4.5 个月完成（整个项目的一期 5.5~6 个月还包含 M0、App 端、上架收尾）"],
    ["二期", "二期功能点集中在第 5~6 个月收尾"],
    ["并行说明", "各功能点工期相加不等于总工期：三人分工并行，总工期按最长的单线（后端 A 约 6 个月）计"],
    ["外部环节", "后端 C 净开发约 5 个月；运营商接口、支付资质等按以往经验需 1~3 个月，与开发并行；到位晚于并行窗口时联调窗口相应推迟"],
    ["待确认", "无新增，直接按此排期"],
    ["前提", "团队 3 人（后端 A/B/C），人均每周 3 天投入；投入升档或降档，全部数字重排"],
    ["测试", "20% 测试为正式工序：覆盖资金链路、跑腿状态机、碎银账本全量回归，由开发承担（无独立测试编制）"],
    ["后台页面", "统一由后端 B 实现（Vue + Element，初稿借助辅助工具生成），审核工作台等复杂交互页由前端在 S3 冲刺内进场约 2 周完成"],
    ["产能状态", "按人均每周 3 天，6 个月窗口产能与全部功能点工作量刚好持平；外部环节延期、需求新增、返工都会直接推迟总工期；新增需求建议进二期清单"],
]

BIZ_HEAD = ["业务模块", "功能点", "期", "服务端负责", "服务端工期", "量级"]
BIZ_ROWS = [
    ["账号", "注册/登录/找回、微信+Apple 登录、学号认证", "★", "后端 B", "约 5 周", "中"],
    ["首页", "身份/网络状态卡、校园卡卡片、金刚区、Banner、信息流", "★", "后端 B + C", "约 2~3 周（运营商数据部分随后端 C 对接线）", "低"],
    ["碎银", "余额卡、兑换商城、明细流水、任务中心、看广告赚碎银", "★", "后端 A + B", "约 6 周", "高"],
    ["发布", "发闲置（9 图+视频）、社区内容、作品、跑腿发布", "★", "后端 A + C", "约 3~4 周（机审接入随后端 C 三方线）", "中"],
    ["校友圈", "9 分类信息流、多级评论、点赞/收藏/@、表白墙、关注 Tab", "★", "后端 A + C", "约 4 周", "中"],
    ["跑腿", "抢单列表、双角色操作页、七态状态机、投诉", "★", "后端 A + B", "约 6 周", "高"],
    ["花名册", "流量排行榜、榜一封面（换背景/涂鸦/历史归档）", "☆", "后端 A", "约 2 周", "低"],
    ["校园网办理", "套餐展示、办理/充值", "★展示，☆深联调", "后端 C", "约 5 周（外部接口到位后联调）", "中"],
    ["消息", "四分类列表、未读红点、14 类推送接收", "★", "后端 C", "约 3 周", "低"],
    ["订单", "四类订单列表（双层筛选）、评价、物流三选一、地址簿", "★", "后端 A + B", "约 5 周", "中"],
    ["我的", "个人资料、收入余额/提现、身份认证、投诉、设置", "★", "后端 A + B + C", "约 3 周（提现通道随后端 C 资金线）", "中"],
    ["二手", "发布/浏览/聊天协商/举报", "★", "后端 A + B", "约 2~3 周", "低"],
]

ADMIN_HEAD = ["后台模块", "功能点", "期", "服务端负责", "服务端工期", "量级"]
ADMIN_ROWS = [
    ["内容配置", "Banner/广告位、商城商品、校园通知、跑腿协议", "★", "后端 B", "约 3 周", "中"],
    ["用户管理", "用户列表/封禁、学号认证审核、碎银手动调整", "★", "后端 B", "约 2~3 周", "低"],
    ["审核工作台", "机审结果流、人审批量处置、敏感词库、违规阶梯", "★", "后端 B + C", "约 6 周（含机审对接约 3 周）", "高"],
    ["跑腿管理", "任务监控/异常处理、投诉处理、提现审核", "★", "后端 B", "约 2 周", "低"],
    ["权限审计", "RBAC 三角色、敏感操作审计日志", "★", "后端 B", "约 3 周", "中"],
    ["财务对账", "日账单比对、退款管理、异常账务工单", "★基础", "后端 C + B", "约 3 周", "中"],
    ["套餐管理/配置中心", "套餐档位、FAQ、系统参数", "★", "后端 B", "约 2 周", "低"],
    ["风控", "碎银经济数值配置、黑名单、冻结/解冻", "☆", "后端 B", "约 2~3 周", "低"],
    ["数据报表", "碎银发行-消耗周报、DAU/留存、核心漏斗", "☆", "后端 C + B", "约 3 周", "低"],
]

SHEETS = [
    ("结论与前提", CONCL_HEAD, CONCL_ROWS),
    ("业务模块功能点", BIZ_HEAD, BIZ_ROWS),
    ("后台模块功能点", ADMIN_HEAD, ADMIN_ROWS),
]

def cell(v, style=None):
    attr = ' table:style-name="%s"' % style if style else ""
    return '<table:table-cell office:value-type="string"%s><text:p>%s</text:p></table:table-cell>' % (
        attr, escape(str(v)),
    )


def cells(vals, style=None):
    return "<table:table-row>" + "".join(cell(v, style) for v in vals) + "</table:table-row>"

cols = lambda n: "".join(
    f'<table:table-column table:style-name="co{min(i,5)}" '
    f'table:default-cell-style-name="ce1"/>' for i in range(n)
)

tables = "".join(
    f'<table:table table:name="{escape(name)}">{cols(len(head))}'
    + cells(head, "ce2")
    + "".join(cells(r) for r in rows)
    + "</table:table>"
    for name, head, rows in SHEETS
)

fods = f'''<?xml version="1.0" encoding="UTF-8"?>
<office:document
 xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
 xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
 xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
 xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
 xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
 office:version="1.2" office:mimetype="application/vnd.oasis.opendocument.spreadsheet">
<office:automatic-styles>
 <style:style style:name="co0" style:family="table-column"><style:table-column-properties style:column-width="3cm"/></style:style>
 <style:style style:name="co1" style:family="table-column"><style:table-column-properties style:column-width="6cm"/></style:style>
 <style:style style:name="co2" style:family="table-column"><style:table-column-properties style:column-width="9cm"/></style:style>
 <style:style style:name="co3" style:family="table-column"><style:table-column-properties style:column-width="5cm"/></style:style>
 <style:style style:name="co4" style:family="table-column"><style:table-column-properties style:column-width="4cm"/></style:style>
 <style:style style:name="co5" style:family="table-column"><style:table-column-properties style:column-width="2.5cm"/></style:style>
 <style:style style:name="ce1" style:family="table-cell"><style:text-properties fo:font-size="11pt"/></style:style>
 <style:style style:name="ce2" style:family="table-cell" style:parent-style-name="ce1"><style:text-properties fo:font-weight="bold"/></style:style>
</office:automatic-styles>
<office:body><office:spreadsheet>{tables}</office:spreadsheet></office:body>
</office:document>'''

out = "docs/PM/工期评估-按功能点-给PM.fods"
with open(out, "w", encoding="utf-8") as f:
    f.write(fods)
print("written:", out)
