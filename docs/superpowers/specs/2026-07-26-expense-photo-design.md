# TravelSpendPlus 单笔支出加照片 —— 设计方案

日期：2026-07-26
状态：设计已获用户确认（Telegram 逐条问答确认），待写实施计划
仓库：`TravelSpendPlus`

## 一、背景与动机

用户 2026-07-25 晚间通过 Telegram 提出两个后续需求，这份文档覆盖第二个：
"现在就来解决那个每一次的支出那儿是否允许加一个图片，每一个 expense 上都可以有这样一个选择"，并明确要求"对这些 photo 进行大小的限制"。（第一个需求——My Trips 页面显示行程照片——核实后发现在当前已装的 v1.0.0+9 里已经实现，见 `trip_list_screen.dart` 的 `_TripPhotoThumbnail`，无需额外工作。）

用户已确认的两点范围边界（Telegram 逐条问答）：
1. 每笔支出**最多 1 张**照片，不支持多张。
2. 大小限制沿用 [[project_travelspendplus_photo_feature_2026-07-25]] 里 trip 照片已经验证过的方案：长边压到 640px、JPEG 质量 80。

## 二、技术方案：完全复用 trip 照片的既有模式

不做新的方案对比——这个功能在架构上和已经上线的"行程头像"（`TripPhotoStore`，2026-07-25 随 v1.0.0+7 上线）几乎一样，唯一区别是主体从 trip 换成 expense。直接复制同一套模式，具体理由：

- **存储方式不进数据库列**：跟 `TripPhotoStore` 一样，文件本身的存在与否就是"有没有照片"的状态，不需要 Drift schema 迁移，风险和复杂度都最低。
- **压缩参数、只从相册选**：跟 trip 照片完全一致（`_maxDimension = 640`、`_jpegQuality = 80`、`ImagePicker().pickImage(source: ImageSource.gallery)`），用户也已经明确认可这个尺度。
- **UI 交互模式**：`CreateTripScreen._buildPhotoPicker()` 那一套（圆形头像 + 角上的删除按钮，`_pickedPhotoPath`/`_removeExistingPhoto` 状态机）直接搬到 `AddExpenseScreen`。

## 三、代码改动

### 新增：`app/lib/services/expense_photo_store.dart`

`TripPhotoStore` 的逐行复制，把 `tripId` 改成 `expenseId`，存储目录从 `trip_photos/` 换成 `expense_photos/`，文件名 `<expenseId>.jpg`。同样提供 `hasPhoto`/`photoFile`/`saveFromPath`/`delete`/`readBase64`/`writeBase64`/`resetForTesting`。

### `app/lib/ui/add_expense_screen.dart`

- 加 `pickImage` 注入参数（跟 `CreateTripScreen` 一样，测试用假实现替换真实相册选择器）。
- 加 `_pickedPhotoPath`/`_removeExistingPhoto`/`_existingPhotoFile` 三个状态字段和对应的 `_pickPhoto`/`_clearPhoto`/`_loadExistingPhoto`/`_buildPhotoPicker`，直接照抄 `CreateTripScreen` 的实现。
- `initState`：编辑模式下调用 `_loadExistingPhoto(existing.id)`。
- `_save()`：`expense.id`（新建时 `Uuid().v4()`，编辑时沿用 `existing.id`）在构造 `Expense` 对象那一刻就已确定，早于 `addExpense`/`updateExpense` 调用。跟 `CreateTripScreen._save()` 一样，在 `addExpense`/`updateExpense` 调用**之后**，按 `_pickedPhotoPath`/`_removeExistingPhoto` 决定调用 `ExpensePhotoStore.saveFromPath(expense.id, ...)`/`ExpensePhotoStore.delete(expense.id)`——新建和编辑两条路径都要处理，不是只有编辑模式才需要。

### `app/lib/ui/trip_detail_screen.dart` —— 支出列表行

支出列表的每一行（`ListTile` 或等效结构）如果这笔支出存了照片，在行首加一个小缩略图（复用 `trip_list_screen.dart` 的 `_TripPhotoThumbnail` 思路，新建一个参数化的等效 widget，`FutureBuilder<bool>` 查 `ExpensePhotoStore.hasPhoto(expense.id)`，没有照片时渲染 `SizedBox.shrink()`，不占位置）。不做"点击放大看大图"这类额外功能——点这一行本来就会打开编辑页，编辑页顶部就能看到完整头像大小的照片，够用了。

### 清理逻辑（这次顺带修的两个真实缺口）

- **`TripRepository.deleteExpense(String expenseId)`**（`trip_repository.dart:185`）：目前只删数据库行，不清理任何文件。加一行 `await ExpensePhotoStore.delete(expenseId);`，跟 `deleteTrip` 里 `TripPhotoStore.delete(tripId)` 放在事务提交之后同样的位置（不是文件系统操作，不必也不应该包进 DB 事务）。
- **`TripRepository.deleteTrip(String tripId)`**（`trip_repository.dart:330`）：目前事务里删 `expenses` 表整批行，但从未清理这些 expense 各自的照片文件——这在 expense 还没有照片这个概念之前是对的，加了之后如果不修就会在删 trip 时留下孤儿照片文件。修法：事务开始前先查一遍这个 trip 下所有 expense 的 id（`getExpenses(tripId)` 或直接 select id 列），事务提交后循环调用 `ExpensePhotoStore.delete(id)`（同样，文件清理不进事务，理由跟 `TripPhotoStore.delete(tripId)` 那行的既有注释一致）。

### 备份格式：`app/lib/domain/backup.dart` + `trip_repository.dart`

- `TripBundle` 新增字段 `final Map<String, String> expensePhotosBase64;`（key 是 expense id，value 是 base64 JPEG），默认 `const {}`。放在 `TripBundle` 而不是 `Expense` domain 类上——跟 trip 头像的 `photoBase64` 字段一样，不让存储细节渗进纯领域模型。
- `tripBundleToJson`：每个 expense 的 json map 里，如果 `bundle.expensePhotosBase64[e.id]` 非空，加一个 `'photo'` key（跟 trip 那层的 `if (bundle.photoBase64 != null) 'photo': ...` 手法一致，只是这次是在 per-expense 的 map 里）。
- `tripBundleFromJson`：解析每个 expense 的 `raw['photo'] as String?`，收集进一个新建的 `Map<String, String>`（跳过 null），随 `TripBundle` 一起返回。
- `kBackupSchemaVersion`：**5 → 6**，文档注释按现有格式补一条"v6 added an optional per-expense `photo`..."说明，旧备份没有这个 key 时每笔 expense 照片默认视为空，不影响导入。
- `TripRepository.exportAllTripsToJson()`：组装每个 trip 的 `expenses` 列表后，再循环调用 `ExpensePhotoStore.readBase64(expense.id)` 填进 `expensePhotosBase64` map 一并传给 `TripBundle`。
- `TripRepository.importAllTripsFromJson()`：每条 `addExpense(expense)` 之后，若 `bundle.expensePhotosBase64[expense.id]` 非空，调用 `ExpensePhotoStore.writeBase64(expense.id, ...)`（对应 trip 层 `if (bundle.photoBase64 != null) await TripPhotoStore.writeBase64(...)` 那几行)。

## 四、不做的范围（明确边界）

- 不支持每笔支出多张照片。
- 不支持点开大图/全屏查看，也不支持相机拍照（只能从相册选，跟 trip 照片一致）。
- 不改 `Expense` 领域类本身、不改 Drift schema/不触发数据库迁移——这条决定了这次改动不属于"数据库迁移"级别的高风险操作，但仍然改了持久化相关的备份格式和文件清理逻辑，验证环节仍按 [[feedback_travelspendplus_release_process]] 的要求，在真机/模拟器上用真实数据跑一遍覆盖安装。

## 五、测试计划

- `test/services/expense_photo_store_test.dart`：直接复制 `trip_photo_store_test.dart`，换成 expenseId。
- `test/domain/backup_test.dart`：加一个用例，验证带 `expensePhotosBase64` 的 `TripBundle` 经过 `tripBundleToJson` → `tripBundleFromJson` 往返后完全还原；再加一个用例验证不带 `photo` key 的旧格式 expense json（v5 及更早）仍能正常解析，`expensePhotosBase64` 里对应条目缺失即可，不报错。
- `test/persistence/trip_repository_test.dart`：`deleteExpense` 删除后确认 `ExpensePhotoStore.hasPhoto(expenseId)` 变 `false`；`deleteTrip` 删除后确认该 trip 下所有 expense 的照片文件也一并清空。
- widget 层：参照 [[project_travelspendplus_photo_feature_2026-07-25]] 记录的 `flutter_tester` 已知限制——凡是会真的解码渲染一张图片文件（`FileImage`）或直接 `await` 真实文件 IO 的 widget test，一律不写或改成不触发这条路径的窄化版本，photo 的选取/保存/渲染这条链路最终仍然靠 Android 模拟器人工验证，不指望 widget test 覆盖。

## 六、发布前验证（对应 CLAUDE.md 的"user data / 持久化改动"分级）

按项目既有的发布纪律（[[feedback_travelspendplus_release_process]]），这次要验证：
1. 装一个真实的历史 release（如当前 v1.0.0+9），建一个真实 trip + 几笔支出（含照片），然后 `adb install -r` 新版本（不卸载），确认旧数据、旧 trip 照片都还在。
2. 新版本里给已有的和新建的支出都加照片，确认保存、编辑替换、删除三条路径都正确；确认列表缩略图正确显示/消失。
3. 走一遍"完整备份导出 → 清空/新设备导入"，确认支出照片也完整回来了（不只是 trip 照片）。
4. 删除单笔带照片的支出、删除整个带照片支出的 trip，各自确认磁盘上对应的照片文件被清理（不强制脚本化检查，`adb shell` 里看一下 app 私有目录下 `expense_photos/` 即可）。
