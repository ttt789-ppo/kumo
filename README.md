# Kumo

给 AdGuard Home 做的 Android 管理客户端，界面按 BakaSU / KernelSU 那套「大标题 + 圆角卡片 + 低饱和青灰」风格写。

现有第三方客户端（com.jgeek00.adguard_home_manager）在 AdGuard Home 1.0.0 上会出现「无法加载过滤器」，Kumo 全部请求走 Basic Auth，不依赖会话 Cookie，不会出现登进去了但某个页面 401 的情况。

## 功能

| 页面 | 内容 |
|---|---|
| 主页 | 保护开关、今日查询数、拦截数、拦截率、查询趋势图、DNS 端口、上游 DNS、安全浏览开关 |
| 日志 | 最近 200 条查询，支持搜索、只看被拦截、下拉刷新 |
| 过滤器 | 订阅列表（规则数 / 更新时间 / 逐个开关）、一键更新全部、添加订阅、编辑自定义规则 |
| 客户端 | 已配置客户端 + 自动发现设备，显示标识与屏蔽状态 |
| 设置 | DNS 配置摘要（上游、Bootstrap、缓存、AAAA）、DNS 重写增删、断开连接 |

## 编译

### 方式一：GitHub Actions（推荐）

仓库已带 `.github/workflows/build.yml`，推到 GitHub 后在 **Actions** 里跑 `Build Kumo APK`，
构建完成后在运行记录的 **Artifacts** 下载 `kumo-apk`，里面就是 `kumo-<run>.apk`。

首次推送会自动触发，也可以手动 `Run workflow`。

### 方式二：本地

```bash
flutter pub get
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

需要 Flutter 3.24+ 与 JDK 17。仓库里没有 `gradle-wrapper.jar`，本地首次构建前先执行一次：

```bash
flutter create --platforms=android --project-name kumo --org com.kumo /tmp/tpl
cp /tmp/tpl/android/gradlew android/ && chmod +x android/gradlew
cp /tmp/tpl/android/gradle/wrapper/gradle-wrapper.jar android/gradle/wrapper/
```

### 方式三：手机上用 AndroidIDE

把仓库导入 AndroidIDE，直接点 Build，等价于方式二。

## 使用

1. 打开 App，填 AdGuard Home 的**管理面板**地址（默认 `http://127.0.0.1:3000`）、端口、用户名、密码
2. 点「测试连接」，能读到版本号就说明通了
3. 保存并连接，之后每次打开直接进主页

AdGuard Home 的密码在 `AdGuardHome.yaml` 的 `users` 段，是 bcrypt 哈希，忘了就重置：

```bash
sed -i '/^users:/,/^auth_attempts:/{/password:/!b};' AdGuardHome.yaml
```

## 说明

- 只用 `http` / `shared_preferences` 两个依赖，没有原生插件，构建轻
- 密码明文存在 `SharedPreferences`，需要更高安全性可替换成 `flutter_secure_storage`
- 允许明文 HTTP（`network_security_config.xml`），因为 ADH 常部署在局域网 http
- 未配置签名，release 用 debug key 签名，方便直接安装

## License

MIT
