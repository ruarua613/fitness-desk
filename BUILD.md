# 训练台 · 构建说明

这是一个 **Flutter 原生应用**（Dart + Material 3，无 WebView、无网页套壳）。
代码全部在 `lib/` 下，数据落在本机 SQLite，同步接口已预留（`lib/data/repository.dart` 的 `SyncAdapter`）。

## 一、在一台装了 Flutter 的机器上出 APK

```bash
cd fitness_flutter

# 生成 android/ 目录（已存在就跳过；不会覆盖 lib/ 下的代码）
flutter create --platforms=android --org com.lzheng --project-name fitness_desk .

# 拉依赖
flutter pub get

# 出包
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`
把 APK 传到手机（微信/QQ/数据线都行），允许「未知来源安装」即可装上，装完是独立 App，图标在系统桌面。

调试用：`flutter run`（连着手机或模拟器）。

## 二、用 GitHub Actions 云编译（不用本地装 Flutter）

仓库里已经放好 `.github/workflows/apk.yml`：

1. 把这个目录推成一个 GitHub 仓库；
2. 推到 `main` 分支，Actions 会自动跑；
3. 跑完在 Actions 页面的 Artifacts 里下载 `fitness-desk-apk`。

## 三、目录结构

```
lib/
  main.dart             入口 + 底部五个 Tab 的壳
  theme.dart            Material 3 主题
  scope.dart            仓储 / 设置的注入
  utils.dart            日期、数值格式化
  widgets.dart          卡片、空状态、统计块、迷你折线图
  data/
    models.dart         Plan / Session / SetLog / BodyMetric / Meal …
    db.dart             SQLite 建表（8 张表 + sync_queue）
    repository.dart     数据访问抽象 + SyncAdapter（预留同步）
    local_repository.dart  SQLite 实现，写入时记脏标记
    settings.dart       当前计划、加重单位
  domain/
    catalog.dart        17 个动作库
    templates.dart      3 套模板 → plan-contract JSON
    progression.dart    渐进规则（加重 / 维持 / 校准）
  pages/
    today_page.dart     今日：按周排期找训练日 + 每个动作的本次建议
    workout_page.dart   训练执行：逐组记重量/次数/RPE + 组间歇计时
    plans_page.dart     计划列表 / 详情 / 新建（模板 or 导入 JSON）
    history_page.dart   训练记录 / 动作进展曲线
    body_page.dart      身体数据 + 营养
    me_page.dart        设置、本周复盘、导出导入
```

## 四、签名（可选）

默认 `flutter build apk --release` 用 debug key 签名，能装能跑。
要上架才需要自己的 keystore：在 `android/key.properties` 里配置，
并在 `android/app/build.gradle.kts` 里加 `signingConfigs`。
