# 取件码（Qujianma）

一款 **纯本地离线、零联网权限、隐私友好** 的 Android 快递「身份码直达 & 取件码聚合」应用（基于 Flutter + Kotlin 原生能力构建）。

> 仓库地址：https://github.com/jiucaihua1/qujianma

---

## 核心特性

### 1. 身份码极简首页（单手一键亮码）
- **主入口直达**：大号按钮一键拉起 **淘宝 / 菜鸟身份码**、**拼多多身份码**。
- **多平台待取件 / 订单直达**：支持 **淘宝待取件、拼多多待取件、菜鸟待取件、京东、抖音、快手、得物**，支持在设置页自由排序、显隐与自定义 URL Scheme。
- **默认启动页可选**：可自由设定打开 App 时默认进入「身份码」还是「取件一览」。

### 2. 取件一览（按驿站自动归类）
- **同驿站智能合并**：自动清洗冗长省市区前缀、括号备注与重复后缀，将不同平台略有差异的同一驿站合并到同一卡片下，到达一个驿站一次拿完。
- **全字段可编辑 & 物品大图标分类**：支持修改取件码、驿站名、快递单号、来源标签、物品备注，内置 8 种简洁大图标分类（服饰、零食、日用、数码、美妆、生鲜、图书、其他）。
- **类 QQ / 菜鸟安全左滑核销**：左滑拉出「编辑 / 已取件」按钮，防止误滑删除；核销后自动进入历史记录，支持撤销、恢复与按天数自动清理。

### 3. 多渠道本地离线收码
- **跳转 App 自动收码（推荐）**：选择目标应用（菜鸟、淘宝、拼多多、京东、抖音、快手、得物、短信）跳转后，顶部显示无需悬浮窗权限的轻量胶囊（`TYPE_ACCESSIBILITY_OVERLAY`），自动扫描当前页面并支持「入库并返回 / 入库继续 / 手动 OCR 截屏」。
- **控制中心磁贴一键识码**：下拉系统控制中心点击「识取件码」磁贴，自动收起面板 → **无障碍控件树优先识别** → **内存截屏 + 本地 Google ML Kit 中文 OCR 保底**（不写入系统相册，识别完立即释放内存）→ 去重入库并发送系统通知。
- **Shizuku 无障碍自动保活**：可选接入 Shizuku，系统杀掉无障碍服务进程时自动强拉起恢复，无需反复进系统设置重开。
- **倒查系统短信（1 / 3 / 7 / 15 天）**：按需本地扫描最近 N 天收件箱中的快递通知短信，支持递管家/京东派（如 `02A006`）、菜鸟、丰巢、兔喜、近邻宝、速递易、熊猫快收、小邮局等 30+ 驿站体系，自动过滤银行验证码与已签收通知。
- **剪贴板自动检测 & 截图本地 OCR & 粘贴批量解析**：切回 App 自动提示剪贴板取件码，也支持从相册选图离线 OCR 或手动录入。

---

## 隐私与权限说明

本应用 **不声明 `INTERNET` 联网权限**，不要求登录任何电商账号，所有识别、解析与数据库存储均在手机本地完成：

| 权限 | 是否必需 | 唯一用途 |
| :--- | :--- | :--- |
| 通知权限（`POST_NOTIFICATIONS`） | 可选 | 控制中心磁贴一键识码后展示入库结果通知 |
| 无障碍服务（`AccessibilityService`） | 可选 | 仅在点击控制中心磁贴或发起「跳转自动收码」限时会话时读取当前页面控件或内存截屏，平时零后台监听 |
| 读取短信（`READ_SMS`） | 可选 | 仅在用户主动点击「倒查系统短信」时本地扫描最近 N 天快递通知 |
| Shizuku 授权 | 可选 | 防止系统杀后台导致无障碍失效，按需自动恢复 |

---

## 技术栈与目录结构

- **前端框架**：Flutter（Material 3）+ `ChangeNotifier`
- **本地存储**：SQLite（`sqflite` 与原生 `SQLiteOpenHelper` 共享 `qujianma.db`，开启 WAL + `busy_timeout`）+ `SharedPreferences`
- **离线 OCR**：Google ML Kit 中文识别（`com.google.mlkit:text-recognition-chinese`）
- **原生增强**：Android `TileService`、`AccessibilityService`（控件树 DFS + `takeScreenshot`）、`Shizuku` AIDL UserService、`Telephony.Sms.Inbox`

```text
qujianma/
├── lib/
│   ├── main.dart                      # 应用入口、生命周期刷新与剪贴板检测
│   ├── models/                        # PickupItem、ItemCategory、IdentityShortcut、AppSettings
│   ├── pages/                         # 身份码首页、取件一览页、设置页
│   ├── services/                      # AppState、DatabaseService、PickupParser、OcrService、QuickTileService、SchemeLauncher
│   └── widgets/                       # 录入/编辑/跳转收码/短信倒查弹窗
├── android/app/src/main/
│   ├── aidl/com/qujianma/qujianma/    # Shizuku 保活 AIDL 接口
│   └── kotlin/com/qujianma/qujianma/  # MainActivity、TileService、AccessibilityService、悬浮胶囊、原生解析器、短信倒查、Shizuku 保活
├── test/                              # 解析器与页面单元测试
└── scripts/dev.ps1                    # Windows 本地开发 / 测试 / 构建封装脚本
```

---

## 本地开发与构建

### 环境要求
- Flutter SDK（Dart `^3.13.2`）
- Android SDK（Android 11+ / API 30+ 完整支持一键截屏识码）
- JDK 17+

### 常用命令

```bash
# 安装依赖
flutter pub get

# 静态代码检查
flutter analyze

# 运行单元测试
flutter test

# 编译 Release APK（推荐真机安装，AOT 编译更流畅）
flutter build apk --release
```

Windows 环境也可直接使用项目自带的 `scripts/dev.ps1`：

```powershell
pwsh -ExecutionPolicy Bypass -File .\scripts\dev.ps1 -Action analyze
pwsh -ExecutionPolicy Bypass -File .\scripts\dev.ps1 -Action test
pwsh -ExecutionPolicy Bypass -File .\scripts\dev.ps1 -Action build -Release
```

---

## 小米 / 澎湃 OS 使用提示

1. **倒查短信读不到快递短信**：进入「应用信息 → 权限管理」，除「读取短信」外，还需将小米单独的 **「通知类短信」** 设为「始终允许」。
2. **侧载安装无法开启无障碍**：进入「应用信息」右上角点击 **「允许受限制的设置」** 后，再回到无障碍页面开启（或直接使用 Shizuku 保活）。
3. **剪贴板自动识别**：在「权限管理」中将 **「读取剪贴板」** 设为「始终允许」。

---

## 后续计划（Roadmap）

- [ ] 可选的系统通知栏监听（`NotificationListenerService`）自动收码
- [ ] 桌面小组件（一键亮码 / 待取件数概览）
- [ ] 自定义驿站别名映射规则
- [ ] 导出 / 备份本地取件记录
