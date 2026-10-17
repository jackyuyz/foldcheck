# Spec 阶段核对（2026-10-17）

基线 `6f31983`；本轮直接在 main 补齐不依赖真机及上架配置的缺口。实现与验收分开记录，完整阶段表见 `docs/foldcheck-spec.md` §10。

## 本轮补齐

| 阶段 | 已实现 | 验证依据与边界 |
| --- | --- | --- |
| M6 | StoreKit 异步操作 15 秒测试时限；批准、拒绝、购买、退款、恢复；停止测试 Store 的交易监听、重置 SKTestSession；批准后清除 pending 状态；防止重复同时购买 | `StorePurchaseTests` 六项本地测试实际通过，不再因商品缺失而 skip。在干净模拟器中复现了误走 Sandbox 登录后的超时；增加显式本地 Test Plan 后六项再次通过，并增强 unit-test host 启动防护；最终代码在独立 iPhone 17 / iOS 27.0 与 Duo / iOS 27.1 均六项通过。同类无响应现在会明确超时失败；CI 还有整项/整轮时限。正式 Sandbox 不在本轮验收范围 |
| M1 | `.github/workflows/ci.yml`、可复用包测试与模拟器脚本、独立 `HingeInput` 包 | 八包 macOS 测试；App 单测/UI 与 Release 模拟器构建。GitHub 的 `xcode-27` 是预览镜像，可能仍为 27.0；该环境只能验证回退路径，不能代替本机 27.1 RC Duo 路径。CI 不上传 App、无需发行密钥或私有姿态 CLI |
| M2 | 窗口/显示屏坐标对比；非全屏阻挡说明；保留 runner 状态；iPad 兼容窗口提示和显示结果范围备注 | 纯几何测试、DEBUG 注入阻挡、实际 iPad 模拟器范围提示、真实 Duo 内屏两栏和半折叠浅色/深色检查。不能把 iPad 兼容窗口当作整块 iPad 面板 |
| M4 / T5 | Duo inner/outer ultra-wide 枚举、AVKit direction coordinator、预览及采集旋转协调 | API 来自本机 27.1 RC SDK，受 `FOLDCHECK_HINGE_API` 和 `#available` 双重保护。隐藏/暂停镜头为 N/A；真正的采集配置失败为 Fail。模拟器无摄像头，不是实际发现/成像证明 |
| M4 / T5 | 捕获照片自愿附加 | 默认不写图片；选中照片在完成测试时通过既有 1600 px JPEG 存储写入本机并进入 PDF。取消时丢弃内存草稿。图片保存失败写入结果说明；不能据此宣称 PDF 所有图片字节受签名覆盖 |
| M4 / T6 | 独立听筒步骤 | 只把系统 `builtInReceiver` 路由当作听筒；模拟器明确未测试。不可用不会让整项失败；实际可路由时必须由用户确认。恢复扬声器后继续麦克风流程 |
| M2 / M5 | 原审计漏列的触控热图 | 新记录保存初始物理网格的归一化格子及覆盖，纳入签名数据并绘入 PDF；实心/叉号同时区分已触及和未触及。旧记录没有格子数据，保持无热图，不补造位置 |
| §8 测试工具 | `-UITestMode 1 -AutoCompleteTests pass` | 仅 DEBUG、内存历史隔离、明显的示例标记及每项说明，不写真实 Widget 快照。UI 验证全检查到 PDF 的连接；不是硬件检查通过的证据 |

详细执行结果、模拟器环境与剩余限制见 `simulator-gaps-validation.md`。CI 代码存在、本地脚本通过和 GitHub 远端执行通过是三个不同事实。

## 仍需真机、人工或上架配置

- **M0 / M3**：铰链采样精度、频率、量化与阈值；真实触控尺寸和折痕带；内外屏亮度独立恢复；长时间前台统计。
- **M4 / M5**：真实 Duo 镜头可用性与折叠后的方向变化、画面和照片方向；听筒/扬声器/麦克风、Touch ID、邻近/运动/触感/按键、Secure Enclave；摄像头扫码和 Files 导入人测。
- **M6**：正式 Sandbox 购买/恢复/退款/待批准、商品和 Family Sharing、通知实际投递。
- **M7**：AC1 首用 ≤6 分钟人测、AC9 实际代理网络审计、人工 VoiceOver/Reduce Motion、外语母语校对、正式 Release 商店截图。
- **上架**：真实隐私 URL / 支持邮箱、开发团队与发行签名、App Store Connect 商品及隐私申报。中英文上架文案仍是草稿，无商店提交。
- **M8**：真实锁屏隐私、系统 tint、发行 App Group 权限等仍按 `widget-validation.md` 待验收。

没有发现整套 M2、M3、M5、M6 完全未做。六语言 JSON catalogs、TestsKit 纯模型/App SwiftUI runner、Codable `InspectionSession` + SwiftData `StoredSession` 是已明确记录的架构选择。图标继续保留用户选定的绿底勾。
