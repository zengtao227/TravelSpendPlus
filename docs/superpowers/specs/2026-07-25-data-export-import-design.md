# TravelSpendPlus 数据导出/导入设计方案

日期：2026-07-25
状态：设计已获用户确认（Telegram 逐条问答确认），待写实施计划
仓库：`TravelSpendPlus`

## 一、背景与动机

用户 2026-07-25 提出："我的 app 做出来是为了以后我们使用的，所以把历史数据导出功能做好"——即为将来的换手机/数据安全场景提前准备好备份与恢复能力。这是 [[project_travelspendplus_domain_core_2026-07-23]] / [[project_travelspendplus_ui_plan_b_2026-07-24]] 里早先记录的"下一个后续项目"，现在正式设计。

## 二、范围声明（Telegram 逐条问答确认，2026-07-25）

**这一版做的**：
- 首页：一个"完整备份"入口 → 导出**全部行程**（所有 Trip + 参与人 + 支出 + 汇率表）打包成一个 JSON 文件，用系统分享面板分享出去
- 首页空状态（当前设备上还没有任何行程时）：一个"从备份恢复"入口 → 用文件选择器选一个之前导出的 JSON 文件，原样恢复全部行程
- 行程详情页：一个"导出这个行程"按钮 → 把这一个行程的支出明细导出成 CSV（日期/类别/状态/备注/金额/币种/折合本位币金额），用系统分享面板分享出去，方便导入 Excel/表格软件查看

**明确不做**（用户确认过的范围边界）：
- CSV **不支持导入**——CSV 是给人看的表格，天然会丢失结构化信息（汇率锁定、参与人、跨行程关系），无法无损导回
- 导入**只在设备上零行程时才提供**——已有数据的设备不提供导入入口，不做合并(merge)/覆盖(overwrite)选择这类更复杂的冲突处理，把"换手机"这一个核心场景做扎实，其它场景留到真的有需求时再加
- 不做云端自动备份（不接 Google Drive/iCloud API）——见下方"技术方案对比"

## 三、技术方案对比

考虑过三种做法：

1. **系统分享面板 + 文件选择器（选用）**：导出时用 `share_plus` 库把生成好的文件交给系统分享菜单（用户可选"存文件""发送到 Drive""发给自己"等）；导入时用 `file_picker` 库弹出系统选文件界面。这是 Flutter 生态里做"导出/导入单个文件"最标准的方式，不需要申请存储权限，用户体验和系统原生 App 一致。
2. **直接写入 Downloads 目录**：不需要新依赖，但用户体验差很多——导出后要自己去文件管理器里找文件，换手机场景下还得自己想办法把文件从旧手机弄到新手机（额外步骤，容易出错）。放弃。
3. **接入 Google Drive API 做自动云备份**：类似 WhatsApp 的云备份体验，但要走 OAuth、建 Google Cloud 项目、处理 API 配额——对这个两人使用的私人 App 来说明显过度设计（YAGNI）。放弃。

**新增依赖**：`share_plus`（分享文件）、`file_picker`（选择要导入的文件）、`csv`（正确处理 CSV 里的逗号/引号转义，不手写字符串拼接——备注字段里如果用户本来就写了逗号会出问题）。

## 四、数据格式

### JSON 完整备份

结构化 JSON，包含全部行程及其关联数据。关键设计点：

- **金额按分（minorUnits）存**，不用浮点数字，跟 `Money` 类自身的设计原则一致（避免精度问题）
- **日期存成纯日期字符串**，如 `"2026-01-09"`（不带时间、不带时区）——这个选择直接呼应这次一并修复的 [[project_travelspendplus_ui_plan_b_2026-07-24]] 里记录的时区/DST 日期漂移 bug 的根因：`civil_date.dart` 已经把应用内部的"日期"概念统一成不含时区的公历日期，导出格式延续同样的原则，避免以后又因为时区解析引入新的漂移 bug
- **顶层带 `schemaVersion` 字段**（从 1 开始），为以后格式升级预留兼容识别的空间；`exportedAt` 记录导出时刻（这个字段本身是纯粹的元数据展示用途，不参与任何业务逻辑判断，所以可以用普通 ISO 8601 时间戳）

大致结构（字段名最终以实施时的 Dart 代码为准）：

```json
{
  "schemaVersion": 1,
  "exportedAt": "2026-07-25T12:00:00Z",
  "trips": [
    {
      "id": "...",
      "name": "10月日本行",
      "startDate": "2026-10-05",
      "endDate": "2026-10-12",
      "homeCurrency": "CNY",
      "totalBudgetMinorUnits": 2000000,
      "participants": [{"id": "...", "name": "Me"}],
      "expenses": [
        {
          "id": "...",
          "category": "food",
          "amountMinorUnits": 30000,
          "amountCurrency": "JPY",
          "amountInHomeCurrencyMinorUnits": 1500,
          "description": "...",
          "date": "2026-10-06",
          "status": "actual",
          "includeInSplit": true,
          "paidById": "...",
          "paidForIds": ["..."]
        }
      ],
      "exchangeRates": [{"fromCurrency": "JPY", "rate": 0.05}]
    }
  ]
}
```

### 单行程 CSV 导出

一张表，一行一笔支出：`日期, 类别, 状态, 备注, 金额, 币种, 折合本位币金额`。表头用中/英/德当前界面语言（跟随 `AppLocalizations`，与其它界面文案一致）。

## 五、代码分层

延续现有的 `domain/` 纯逻辑、`persistence/` 数据库、`ui/` 界面三层结构：

- **`app/lib/domain/backup.dart`**（新增）：纯逻辑，负责 `Trip`/`Participant`/`Expense`/`ExchangeRate` 与 JSON 的相互转换，以及 `Expense` 列表到 CSV 行的转换。不涉及文件 IO、不依赖 Flutter，方便单元测试覆盖各种边界情况（空行程、多币种、特殊字符备注等）。
- **复用现有 `TripRepository`** 的方法（`getAllTrips`/`getExpenses`/`getExchangeRates` 取数据，`createTrip`/`addExpense`/`setExchangeRate` 写数据）来在数据库和上面这层纯逻辑之间搬运数据——**不需要改数据库 schema**，不需要新的 Drift 表或迁移。
- **文件 IO 放在 UI 层**（首页、行程详情页的按钮点击处理里）：生成好 JSON/CSV 字符串后写入临时文件（`path_provider` 已经在用了），交给 `share_plus` 分享；导入则用 `file_picker` 选文件、读内容、交给 `domain/backup.dart` 解析、再逐条调用 `TripRepository` 写入数据库。

## 六、错误处理

- **导入文件格式不对/解析失败**：捕获异常，界面上用明确的错误提示（不是静默失败——这次 review 修复的第 5 条问题就是"静默失败让人以为按钮没反应"，同样的原则用在这里）
- **导入文件的 `schemaVersion` 比当前代码认识的更新**：拒绝导入并提示"请升级 App 后再导入"，而不是尝试硬解析导致数据错乱
- **用户在导入过程中途取消文件选择**：什么都不做，回到原来的空状态界面，不报错

## 七、测试计划

- `domain/backup_test.dart`：JSON 往返(round-trip)测试（导出再导入应该完全还原原始数据，包括多币种、多参与人、特殊字符备注、空行程列表等边界情况）；CSV 生成的格式正确性测试（逗号/引号转义）
- UI 层：`file_picker`/`share_plus` 涉及平台原生交互，widget test 里用 mock/fake 替换，验证"选中文件后触发正确的导入调用""导出按钮触发正确的分享调用"这类逻辑，不测试系统分享面板本身的行为（那是操作系统的责任）
