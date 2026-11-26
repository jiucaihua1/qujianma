# 发版规范与防踩坑规则 (Release Rules)

为防止出现「云端打包失败」「APK 签名不一致无法覆盖安装」「版本号冲突」等问题，每次正式发版必须严格遵守以下规则：

## 1. 签名一致性强约束（核心）
- **统一签名指纹（SHA-256）**：`214fa2e2d37351fa0129b119bf9ca1251d9cae6df6ce63cd13e1632c636a1e3f`
- **本地打包**：使用 `scripts/dev.ps1` 自动指向的本地密钥库（`E:\Vibe_AI\xiaohe_jizhang\.android\debug.keystore`）。
- **云端打包**：GitHub Actions 必须从 Secret `ANDROID_DEBUG_KEYSTORE_BASE64` 还原到 `android/app/ci-signing.keystore`，由 `android/app/build.gradle.kts` 显式引用。
- **自动拦截**：`.github/workflows/release.yml` 在发布 Release 前会调用 `apksigner verify --print-certs` 强制比对 SHA-256，若不一致直接终止发版，绝不发布错误签名的 APK。
- **安全红线**：`*.keystore` 与 `*.jks` 已加入 `.gitignore`，严禁将密钥文件直接提交到代码仓库。

## 2. 版本号与 Tag 规范
- 每次发版必须**严格递增** `pubspec.yaml` 中的 `version`（例如 `0.1.1+2` → `0.1.2+3`），`versionCode`（`+` 号后数字）必须严格大于上一版。
- Git Tag 必须与 `pubspec.yaml` 的语义化版本完全一致，格式为 `vX.Y.Z`（例如 `v0.1.2`）。
- **禁止复写已发布的旧 Tag**：发现问题需要重发时，一律递增小版本号发新 Tag（如 `v0.1.2`），避免 CDN/浏览器缓存旧 APK 或 Release 附件未覆盖。

## 3. CI 构建环境锁定
- `.github/workflows/release.yml` 中锁定与本地一致的 **Flutter 版本（`3.47.2`）** 与 **JDK 版本（`21`）**，防止上游 Flutter 自动升级触发 Gradle 依赖校验中断发版。

## 4. 发版前必检清单
1. 更新 `CHANGELOG.md`，将 `## [Unreleased]` 下的改动归档到新版本号。
2. 更新 `pubspec.yaml` 的 `version`。
3. 本地执行 `scripts/dev.ps1 -Action analyze` 与 `scripts/dev.ps1 -Action test`，确保 0 警告、全部测试通过。
4. 提交代码并推送 `main` 分支，再推送新 Tag `vX.Y.Z` 触发 GitHub Actions。
5. 等 Actions 全部变绿（含 SHA-256 签名校验通过）后，在手机「设置 → 检查应用更新」验证覆盖安装。
