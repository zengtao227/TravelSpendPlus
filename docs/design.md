# TravelSpendPlus 详细方案（第二版，基于 TravelSpend 官方帮助文档的深入研究）

日期：2026-07-17
状态：待用户确认，未开始实施
仓库：`TravelSpendPlus`（GitHub 公开仓库，账号 zengtao227）

## 一、这次研究了什么

上一版方案只是搜了产品介绍页的概括性描述，这次直接查了 TravelSpend 官方帮助中心（help.travel-spend.com）的具体条目、官方博客对分摊功能的图文说明，把几个关键机制的**精确逻辑**（不是"大概是这样"，是官方原话描述的公式和步骤）搞清楚了：

### 1. 预算机制（Travel Budget / Daily Metrics 分类）
- **一趟旅行只有一个总预算**，不是按类别分别设预算（官方明确说这是为了"保持简单"的设计选择）——类别（餐饮/交通/住宿等）只用来做统计可视化，不设单独上限
- **每日剩余预算**是动态算的，公式：
  ```
  今日可用预算 = 当前剩余总预算 ÷ 剩余天数
  ```
  官方举例：10天行程预算€1000，花了6天后剩€800（即已花€200），剩4天 → €200÷4 = 每天€50。这个数字会每天根据实际花销重新计算，用来提醒"照这个速度花下去会不会超支"，而不是死板地用"总预算÷总天数"

### 2. 多币种（Currencies & Conversion Rates 分类）
- 每趟行程可以单独设置"本位币"（home currency），不是整个 App 只有一个全局本位币
- 记账时可选任意币种输入金额，自动折算成本位币显示
- 汇率：默认用联网时获取的实时汇率，离线时用上次缓存的汇率继续换算，不会因为没网就不让记账
- **支持手动改汇率**：如果在机场/路边用现金换汇拿到的实际汇率比市场价差，可以手动输入实际拿到的汇率，而不是强制用官方汇率（这个细节容易漏掉，但对经常用现金的场景很重要）

### 3. 分摊功能（Cost Splitting 分类 + 官方博客图文说明）
完整流程（官方博客里 Alex/Stephanie 那个例子还原）：
1. 一个人建立行程，生成邀请链接，拉朋友加入（"Invites & Shared Trips"）
2. 每笔支出记录时填三样：类别、金额、备注，再加两个分摊专用字段：
   - **"Paid by"**：这笔钱实际是谁垫付的（单选）
   - **"Paid for"**：这笔钱是为哪些人花的（多选，比如4人同行但只有3人叫了车，就只勾3人）
3. App 根据所有笔记录自动算出每个人的净余额（谁该收钱、谁该付钱），不需要人工去凑
4. 结算是**线下**完成的（转账/现金），完成后回 App 里手动标记"已结清"，把余额清零；App 本身不处理实际转账
5. 所有记录留痕，"以后翻账可查"

官方资料里没提到"不均分/自定义比例分摊"这种更复杂的场景（比如某人多付一点这种），大概率是没有这个功能——分摊逻辑就是"付款人 + 平均分给受益人"这么简单，这也符合它"专注旅行记账、故意不做复杂功能"的产品定位。**这块我会先按同款逻辑（简单均分）来做，不做加权分摊，除非你后面觉得需要。**

## 二、TravelSpendPlus 要加的核心功能：计划中 / 已发生

在上面这套机制基础上，给每笔支出加一个状态字段：

| 状态 | 含义 |
|------|------|
| 计划中 (Planned) | 钱还没花，是提前订好/预估的（机票、酒店、预估餐费） |
| 已发生 (Actual) | 已经实际花掉的钱 |

跟 TravelSpend 原有机制结合后的具体影响：

- **预算总览**：总预算里会分别显示"计划中总额"+"已发生总额"，两者加起来跟总预算比，出发前就知道大概花多少
- **每日剩余预算**：默认把"计划中"的钱也算进已用掉的部分（因为这笔钱迟早要花，提前算更保守、更准），但界面上给一个开关"是否把计划中费用计入每日预算"，方便你自己决定看哪种口径
- **一键转换**：到了日期或者真花了之后，点一下把"计划中"转成"已发生"，同时可以顺手把预估金额改成实际金额（预估和实际不一致是常态，不强制两者相等）
- **分摊场景下**：是否把"计划中"的支出算进分摊账本，**做成用户可选**（每笔支出上有个开关，用户自己决定这笔计划中的钱算不算分摊），不做统一的默认规则（用户 2026-07-17 确认）

## 二.5、支出分类统计（对齐 TravelSpend 的可视化能力）

- 按类别（餐饮/交通/住宿/...）做实时统计，饼图展示每个类别占比，随记账实时更新（不是每天批量算一次，加一笔就刷新一次）
- 这个是 TravelSpend 本来就有的功能（官方叫 spending insights），照做

## 三、技术栈推荐

你说了安卓先做、以后再出iOS。基于这个前提：

**推荐：Flutter**（单一 Dart 代码库，安卓和 iOS 共用大部分代码）
- 优点：以后出 iOS 版本时，UI/业务逻辑基本不用重写，只需要处理少量 iOS 专属细节（比如 App Store 上架、部分平台专属交互）；本地离线存储（sqlite，用 `drift` 这个包）、多币种计算、图表可视化这些 TravelSpend 需要的能力 Flutter 生态都成熟
- 对比"先做安卓原生（Kotlin）"：原生开发流畅度/生态确实更好，但你明确说了以后要出 iOS，原生安卓的代码到时候等于要用 Swift 重新写一遍 UI 和业务逻辑，等于做两次；这跟你"先做安卓、以后改 iOS"的计划矛盾，所以不推荐
- 对比 React Native：也能一套代码两端，但状态管理/原生模块生态没有 Flutter 稳定，尤其你们这种要精细控制本地数据库+图表的场景，Flutter 通常问题更少

如果你对 Kotlin/Swift/Dart 某一个已经比较熟，也可以告诉我，会影响你自己后续维护代码的难度，这个我可以再调整建议。

## 四、初步数据模型（草案，供讨论，不是最终版）

```
Trip（行程）
  - name, start_date, end_date
  - home_currency（本位币，行程级别）
  - total_budget（总预算，单一数值，不分类别）
  - participants（成员列表，含邀请链接）

Expense（支出）
  - trip_id
  - category（餐饮/交通/住宿/... 可自定义）
  - amount, currency, custom_exchange_rate（可选，覆盖默认汇率）
  - description, photo（可选）
  - date（可以是过去的实际日期，也可以是未来计划日期）
  - status: planned | actual
  - include_in_split（bool，仅 status=planned 时有意义，用户自己勾选这笔计划中的钱要不要算进分摊账本；status=actual 时恒为 true）
  - paid_by（单个 participant）
  - paid_for（participant 列表，默认全员）

Settlement（结算记录）
  - trip_id, from_participant, to_participant, amount, settled_at
```

## 五、确认状态（2026-07-17 已由用户确认，方案定稿）

1. ~~"计划中"的支出要不要算进分摊账本~~ → 用户自选（每笔支出一个开关），已加进数据模型
2. ~~技术栈~~ → Flutter，已确认
3. ~~分类统计~~ → 需要饼图，实时更新，已加进方案（第二.5节）
4. 下一步：建仓库 + 写实施计划（本文档），计划经用户 review 后再开始写代码

## 参考来源

- [TravelSpend Help Center](https://help.travel-spend.com/)
- [每日剩余预算怎么算](https://help.travel-spend.com/daily-metrics/nsEZBhRKe4aEiaHGB4fnwF/how-does-the-remaining-daily-budget-work/uT5EPNGKPV3AFsgGuuKQGq)
- [能不能给每个类别单独设预算](https://help.travel-spend.com/travel-budget/3shM3rgJUHqqd4VcV38Vqt/can-i-set-separate-budgets-for-individual-categories/3R7SjaJVz7GMguyAeTMKCN)
- [分摊功能官方图文说明](https://travel-spend.com/blog/organize-group-bills-split-costs-with-travelspend/)
- [货币与汇率帮助分类](https://help.travel-spend.com/currencies--conversion-rates/tRj7gE8u4nhvErytPouJdg)
