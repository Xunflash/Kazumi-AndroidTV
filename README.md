<div align="center">

  <h1>Kazumi TV</h1>

  <img src="assets/images/logo/logo_rounded.png" width="200" alt="Kazumi TV logo">

  <p>
    <img src="https://img.shields.io/badge/Android_TV-adapted-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android TV adapted">
    <img src="https://img.shields.io/badge/ARM-32%20bit%20%7C%2064%20bit-0091BD?style=for-the-badge&logo=arm&logoColor=white" alt="32-bit and 64-bit ARM">
    <img src="https://img.shields.io/badge/Flutter-03A9F4?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  </p>

  <p>面向 Android TV 和 Google TV 的非官方 Kazumi 适配版，重点改善 32 位电视设备兼容性、遥控器导航、播放器操作与低性能设备体验。</p>
</div>

> [!IMPORTANT]
> 本仓库是 [Kazumi 原项目](https://github.com/Predidit/Kazumi) 的非官方 Android TV 适配分支，并非原项目维护者发布的官方电视版本。遇到本分支特有的问题时，请在 [Xunflash/Kazumi-AndroidTV](https://github.com/Xunflash/Kazumi-AndroidTV/issues) 反馈，不要将其归因于上游项目。

## Android TV 适配

- **32 位 ARM 支持**：Release APK 同时包含 `armeabi-v7a` 和 `arm64-v8a`，覆盖仍在使用 32 位系统的电视与电视盒子。
- **遥控器焦点导航**：补全主页、侧边导航、搜索与设置、详情页操作、悬浮按钮等区域的方向键焦点路径，并增强聚焦状态的可见性。
- **播放器遥控操作**：支持方向键快进/快退及可配置步长；控制栏、顶部操作、选集和播放器功能按钮可通过方向键到达并确认执行。
- **设置与文本输入**：改善播放器键位设置、WebDAV 配置、保存操作和返回键对软键盘的处理。
- **电视性能优化**：针对低性能和低内存设备调整播放缓存、Android 视频渲染策略与部分动画效果。
- **分支更新源**：由本仓库构建的安装包会从 [Xunflash/Kazumi-AndroidTV Releases](https://github.com/Xunflash/Kazumi-AndroidTV/releases) 检查和下载更新。

## AI 辅助说明

本分支的主要 Android TV 适配由 **OpenAI Codex** 辅助完成，包括代码分析、实现、测试补充和构建验证。相关修改经过自动化测试与静态分析，但 AI 辅助和自动化测试不能替代真实电视设备验证。不同厂商遥控器键码、系统输入法、GPU 驱动和解码能力存在差异，发布前及反馈问题时仍应进行实机测试。

## 兼容范围

- 本分支的发布目标是 Android TV / Google TV，重点支持 ARM 32 位和 ARM 64 位设备。
- 手机、桌面和其他平台的代码仍继承自上游，但不是此分支的主要适配与发布目标。
- 原项目的跨平台版本、文档及支持范围请参阅 [Predidit/Kazumi](https://github.com/Predidit/Kazumi)。

## 屏幕截图 

<table>
  <tr>
    <td><img alt="homepage" src="static/screenshot/img_1.png"></td>
    <td><img alt="timetable" src="static/screenshot/img_2.png"></td>
    <td><img alt="details" src="static/screenshot/img_3.png"></td>
  <tr>
  <tr>
    <td><img alt="selection-page" src="static/screenshot/img_4.png"></td>
    <td><img alt="rules-mange" src="static/screenshot/img_5.png"></td>
    <td><img alt="rules-edit" src="static/screenshot/img_6.png"></td>
  <tr>
</table>

## 功能 / 开发计划

以下核心功能继承自 Kazumi 原项目；本分支在此基础上维护 Android TV 适配。

- [x] 规则编辑器
- [x] 番剧目录
- [x] 番剧搜索
- [x] 番剧时间表
- [x] 番剧字幕
- [x] 分集播放
- [x] 视频播放器
- [x] 多视频源支持
- [x] 规则分享
- [x] 硬件加速
- [x] 高刷适配
- [x] 追番列表
- [x] 番剧弹幕
- [x] 在线更新
- [x] 历史记录
- [x] 倍速播放
- [x] 配色方案 
- [x] 跨设备同步
- [x] 无线投屏 (DLNA)
- [x] 外部播放器播放
- [x] 超分辨率
- [x] 一起看
- [x] 番剧下载
- [ ] 番剧更新提醒
- [ ] 还有更多 (/・ω・＼) 

## 下载

通过本仓库的 [Releases](https://github.com/Xunflash/Kazumi-AndroidTV/releases/latest) 页面下载 Android TV APK：

<a href="https://github.com/Xunflash/Kazumi-AndroidTV/releases">
  <img src="static/svg/get_it_on_github.svg" alt="Get it on Github" width="200"/>
</a>

Release APK 同时支持 `armeabi-v7a` 与 `arm64-v8a`。其他平台以及 F-Droid、Flathub、AUR 等发行渠道请使用 [上游项目的官方发布](https://github.com/Predidit/Kazumi/releases/latest)。

> [!NOTE]
> Kazumi TV 无法使用上游项目的 Android 签名证书。首次从上游官方版或本地调试版切换到 Kazumi TV 正式版时，需要先卸载原安装；此后由本仓库同一正式证书签名的 Release 可以直接覆盖升级。卸载前请先备份需要保留的数据。

## 上游同步与自动发布

GitHub Actions 会在本分支 `main` 更新后、每天北京时间 04:23 以及手动触发时检查 [Predidit/Kazumi](https://github.com/Predidit/Kazumi) 的 `main` 分支。同步使用普通 merge commit，不会 reset 或强制推送；发生冲突时不会改动远端，而会保留冲突工件并创建 Issue。

每个尚未发布的 fork 提交都会获得稳定的 TV 版本号。自动流程依次执行测试、静态分析、ARM 32/64 位构建、16 KB 对齐检查和正式签名校验，全部通过后才创建标签与 Release。构建失败或 APK 上传不完整时，后续同步会自动重试。首次启用和签名配置参见 [上游同步与发布配置](.github/UPSTREAM_SYNC.md)。

## 贡献

欢迎向原项目的 [规则仓库](https://github.com/Predidit/KazumiRules) 提交您的自定义规则。您可以自由选择是否在规则中留下您的ID。详细的规则编写教程可以参考 [规则开发文档](https://kazumi.app/docs/rules/develop-rules)。Android TV 适配问题请提交到 [本分支 Issues](https://github.com/Xunflash/Kazumi-AndroidTV/issues)。

## Q&A

<details>
<summary>使用者 Q&A</summary>

#### Q: 为什么少数番剧中有广告？

A: 本项目未插入任何广告。广告来自视频源, 请不要相信广告中的任何内容, 并尽量选择没有广告的视频源观看。

#### Q: 为什么我启用超分辨率功能后播放卡顿？

A: 超分辨率功能对 GPU 性能要求较高, 如果没有在高性能独立显卡上运行 Kazumi, 尽量选择效率档而非质量档。对低分辨率视频源而非高分辨率视频源使用超分也可以降低性能消耗。

#### Q: 为什么播放视频时内存占用较高？

A: 本程序在视频播放时, 会尽可能多地缓存视频到内存, 以提供较好的观看体验。如果您的内存较为紧张, 可以在播放设置选项卡启用低内存模式, 这将限制缓存。

#### Q: 为什么少数番剧无法通过外部播放器观看？

A: 部分视频源的番剧使用了反盗链措施, 这可以被 Kazumi 解决, 但无法被外部播放器解决。

#### Q: 为什么下载的 Linux 版本缺少图标和托盘功能？

A: 使用 .deb 版本进行安装, tar.gz 版本仅为方便二次打包, 这一格式先天缺乏图标和托盘功能支持。

</details>

<details>
<summary>规则编写者 Q&A</summary>

#### Q: 为什么我的自定义规则无法实现检索？

A: 目前我们对 `Xpath` 语法的支持并不完整, 我们目前只支持以 `//` 开头的选择器。建议参照我们给出的示例规则构建自定义规则。

#### Q: 为什么我的自定义规则可以实现检索, 但不能实现观看？

A: 尝试关闭自定义规则的使用内置播放器选项, 这将尝试使用 `webview` 进行播放, 提高兼容性。但在内置播放器可用时, 建议启用内置播放器, 以获得更加流畅并带有弹幕的观看体验。

</details>

<details>
<summary>开发者 Q&A</summary>

#### Q: 我在尝试自行编译该项目, 但编译没有成功。

A: 本项目编译需要良好的网络环境, 除了由 Google 托管的 Flutter 相关依赖外, 本项目同样依赖托管在 MavenCentral/Github/SourceForge 上的资源。如果您位于中国大陆, 可能需要设置恰当的镜像地址。

</details>

## 美术资源

本项目图标来自 [Yuquanaaa](https://www.pixiv.net/users/66219277) 发表在 [Pixiv](https://www.pixiv.net/artworks/116666979) 上的作品。

此图标由其原作者 [Yuquanaaa](https://www.pixiv.net/users/66219277) 拥有版权。我们已获得原作者的授权和许可, 可以在本项目中使用这一图标。这一图标不是自由使用的, 未经原作者明确授权, 任何人不得擅自使用、复制、修改或分发这一图标。

本项目内嵌字体为 [Mi Sans](https://hyperos.mi.com/font/zh/details/sc/) 字体, 由 [Xiaomi](https://www.mi.com/index.html) 开发和拥有版权。

## 免责声明

本项目是 [Kazumi](https://github.com/Predidit/Kazumi) 的修改版本，继续依据仓库内的 [GNU 通用公共许可证第 3 版](LICENSE)（GPL-3.0）授权。原项目及其贡献者的版权与署名予以保留。我们不对其适用性、可靠性或准确性作出任何明示或暗示的保证。在法律允许的最大范围内, 作者和贡献者不承担任何因使用本软件而产生的直接、间接、偶然、特殊或后果性的损害赔偿责任。

使用本项目需遵守所在地法律法规, 不得进行任何侵犯第三方知识产权的行为。因使用本项目而产生的数据和缓存应在24小时内清除, 超出 24 小时的使用需获得相关权利人的授权。

## 隐私政策

我们不收集任何用户数据, 不使用任何遥测组件。

## 代码签名策略
提交者: [贡献者](https://github.com/Predidit/Kazumi/graphs/contributors)
审阅者: [所有者](https://github.com/Predidit)

## 赞助

| ![signpath](https://signpath.org/assets/favicon-50x50.png) | Free code signing on Windows provided by [SignPath.io](https://about.signpath.io/), certficate by [SignPath Foundation](https://signpath.org/) |
|------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| <img src="https://kilo.ai/favicon/favicon.svg" width="50"> | **Automatic PR review provided by [Kilo Code](https://kilo.ai/), sponsored by the [Kilo OSS Program](https://kilo.ai/oss)** |
| <a href="https://m.do.co/c/0062035db3e4"><img src="https://opensource.nyc3.cdn.digitaloceanspaces.com/attribution/assets/SVG/DO_Logo_icon_blue.svg" width="50" height="50"></a> | **Cloud infrastructure is supported by [DigitalOcean](https://m.do.co/c/0062035db3e4)** |

## 致谢

特别感谢 [XpathSelector](https://github.com/simonkimi/xpath_selector) 这个优秀的项目是本项目的基石。

特别感谢 [弹弹play](https://www.dandanplay.com/) 本项目使用了 弹弹play开放平台 以提供弹幕交互。

特别感谢 [Bangumi](https://bangumi.tv/) 本项目使用了 Bangumi 开放 API 以提供番剧元数据。

特别感谢 [Anime4K](https://github.com/bloc97/Anime4K) 本项目使用 Anime4K 进行实时超分。

特别感谢 [SyncPlay](https://github.com/Syncplay/syncplay) 本项目使用 SyncPlay 协议并通过 SyncPlay 公共服务器实现一起看功能。

特别感谢 [所有贡献者](https://github.com/Predidit/Kazumi/graphs/contributors) 本项目因为你们变得更好。

特别感谢 [trace.moe](https://trace.moe) 本项目使用了 trace.moe 提供的图片识别番剧功能。

感谢 [media-kit](https://github.com/media-kit/media-kit) 本项目跨平台媒体播放能力来自 media-kit。

感谢 [avbuild](https://github.com/wang-bin/avbuild) 本项目使用了来自 avbuild 的树外补丁实现非标准视频流播放。

感谢 [hive](https://github.com/isar/hive) 本项目持久化储存能力来自 hive。
