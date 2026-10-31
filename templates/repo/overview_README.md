# 总览区（docs/overview/）

> 本目录只由项目总览写。所有 agent 开工前先读本文件和 `auto_runs.md`。

## 项目

<一段话：研究问题、目标、截止时间>

## 执行 agent 的工作规则

1. **优先级**：用户当前指令 > 本区最新的决策记录 > 本区任务单 > 交接文档 > 其他历史文档。同一主题以日期最新的为准。
2. 只改自己负责的目录（见下表）；`docs/overview/` 只读。有异议写进自己的报告或给总览的消息。
3. 每次运行开始读 `reports/<自己>/STATE.md`，结束前更新它；当天日志写 `reports/<自己>/YYYY-MM-DD.md`。
4. 给总览的消息：`reports/<自己>/messages/YYYY-MM-DD_<自己>_to_overview_NN.md`；发出后不改。
5. 需要用户的事写进自己 STATE.md 的"需要用户的事"；不写 `reports/需要你处理.md`。
6. 先预注册、后看数据；看完结果不调宽判定线；负结果照实保留。预算按任务单单列，超出先报总览。
7. 红线：<密钥只放环境变量；研究数据不删除；公开仓库不放未发表路线；……>

## agent 配置

| agent | 运行方式 | 负责 | 可以改的目录 |
|---|---|---|---|
| 总览 | 交互 + 定时巡检 | 路线、决策 | `docs/overview/`、`reports/需要你处理.md`、`reports/reviews/`、`reports/worklists/` |
| <L1> | 云端定时 | <...> | <...>、`reports/L1/` |

## 当前有效指令（最新在上）

| 日期 | 文件 | 对象 | 要点 |
|---|---|---|---|
| YYYY-MM-DD | [decisions/YYYY-MM-DD_project_start.md](decisions/YYYY-MM-DD_project_start.md) | 全部 | **最新**。项目启动、agent 配置 |
