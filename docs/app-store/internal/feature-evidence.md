# 内部功能依据 / Feature evidence

仅内部使用，不复制到公开描述或审核备注。核对日期：2026-10-16；功能代码基线 `3d3b37b`，当前 HEAD `f240279` 只归档设计记录。实现存在不等于所有真实硬件、正式商店配置或发行环境已验证。

| 文案事实 | 实现依据 | 使用边界 |
|---|---|---|
| 完整检查、快速触控/屏幕/铰链检查及跳过 | [HomeView](../../../App/Home/HomeView.swift)、[InspectionFlowView](../../../App/Inspection/InspectionFlowView.swift) | 不承诺固定完成时间；没有实测六分钟以内的用户数据 |
| 检测与当次屏幕结果免费 | [InspectionSummaryView](../../../App/Summary/InspectionSummaryView.swift)、[HomeView](../../../App/Home/HomeView.swift) | 生成报告、历史查看等另有内购；不写“全部功能免费” |
| 触控网格、密集折痕带、多点触控 | [TouchGridTestView](../../../App/Tests/TouchGrid/TouchGridTestView.swift)、[TouchGridSession](../../../Packages/TestsKit/Sources/TestsKit/TouchGridSession.swift) | 普通手机没有折痕带；不等同于全机自动故障诊断 |
| 旋转保留同一份物理网格、总格数和覆盖 | [TouchGridProjection](../../../Packages/TestsKit/Sources/TestsKit/TouchGridProjection.swift)、[TouchGridTestView](../../../App/Tests/TouchGrid/TouchGridTestView.swift) | 90°/180°使用坐标转换，不重新分格；内外屏是独立表面，切换时确认并开始独立网格 |
| 逐格点按、视觉协助跳过、大字体/减少动态效果处理 | [TouchGridTestView](../../../App/Tests/TouchGrid/TouchGridTestView.swift)、[InspectionFlowView](../../../App/Inspection/InspectionFlowView.swift)、[InspectionPanels](../../../App/Design/InspectionPanels.swift) | 不据此宣称完整 VoiceOver 认证或所有无障碍项目已人工验证 |
| 纯色显示、用户标记屏幕问题 | [PixelTestView](../../../App/Tests/Pixels/PixelTestView.swift) | 不是自动发现全部坏点、烧屏或修复屏幕 |
| 折痕可见度评分与可选导入照片 | [CreaseTestView](../../../App/Tests/Crease/CreaseTestView.swift) | 主观评分；照片由其他设备拍摄后主动导入；不测物理深度 |
| 铰链开合、五秒保持、连续性/一致性 | [HingeSweepTestView](../../../App/Tests/HingeSweep/HingeSweepTestView.swift)、[HingeAnalysis](../../../Packages/HingeAnalysis/Sources) | 不是绝对角度精度、寿命预测或故障原因认证；手动输入有标记 |
| 摄像头预览及曝光/清晰度数据 | [CameraTestView](../../../App/Tests/Hardware/CameraTestView.swift) | 动态发现可用镜头；包含用户目视确认；不保证每个型号的每颗镜头都可用 |
| 声音、录音回放、运动/距离感应/触感及按键 | [AudioTestView](../../../App/Tests/Hardware/AudioTestView.swift)、[SensorsTestView](../../../App/Tests/Hardware/SensorsTestView.swift)、[ButtonsTestView](../../../App/Tests/Hardware/ButtonsTestView.swift) | 部分需听觉/触觉/手动确认；音量键通过系统音量变化观察，其他按键是手动清单 |
| 仅在支持 Touch ID 的设备进行对应检查 | [TouchIDTestView](../../../App/Tests/Hardware/TouchIDTestView.swift) | 不宣称 Face ID 检测、取得生物特征数据或修复认证硬件 |
| 一次性非消耗型 Reports 解锁及恢复购买 | [Store](../../../Packages/Store/Sources/Store/Store.swift)、[Entitlements](../../../Packages/Store/Sources/Store/Entitlements.swift)、[PaywallView](../../../App/Paywall/PaywallView.swift) | 商品 ID 已实现；正式商品配置、价格、地区、Family Sharing 待确认；不复制本地 StoreKit 示例价格 |
| 本地历史查看与两次检查对比 | [HistoryView](../../../App/History/HistoryView.swift)、[CompareView](../../../App/History/CompareView.swift)、[InspectionSummaryView](../../../App/Summary/InspectionSummaryView.swift) | 历史访问和对比受内购限制；完整检查自动保存，快速检查由用户保存；不能承诺云同步或跨设备迁移 |
| 每月本地提醒 | [MonthlyReminder](../../../App/Settings/MonthlyReminder.swift)、[SettingsView](../../../App/Settings/SettingsView.swift) | 需解锁及通知授权；本地安排每月 10:00，日期上限 28 日；不承诺通知必达 |
| 前台观察的折叠次数和显示状态时长 | [FoldCounterModel](../../../App/FoldCounter/FoldCounterModel.swift)、[FoldStatsView](../../../App/FoldCounter/FoldStatsView.swift) | 统计页受内购限制；不是后台监测、系统累计值或设备终身折叠次数 |
| PDF 导出、用户分享、备注/曲线/附件与二维码 | [ReportPreviewView](../../../App/Report/ReportPreviewView.swift)、[ReportPDFRenderer](../../../App/Report/ReportPDFRenderer.swift) | 报告内容取决于完成的项目及用户提供的附件；不承诺触控热力图、保险认可、维修凭证效力或可信时间戳 |
| 免费导入 PDF 验证或扫码验证 | [VerifyView](../../../App/Verify/VerifyView.swift)、[ReportVerifier](../../../Packages/ReportKit/Sources/ReportKit/ReportVerifier.swift) | PDF 验嵌入的已签名数据；QR 仅验摘要签名；不验所有可见页面、设备身份、检测真实性或设备时钟 |
| 安全签名及开发回退标记 | [ReportSigning](../../../App/Report/ReportSigning.swift)、[SecureEnclaveReportSigner](../../../Packages/ReportKit/Sources/ReportKit/SecureEnclaveReportSigner.swift) | 不能宣称所有环境均使用 Secure Enclave；缺少时使用明确标记的开发签名 |
| 本地存储、无需 App 账号、无广告/分析 SDK | [FoldCheckApp](../../../App/FoldCheckApp.swift)、[PrivacyInfo](../../../App/Resources/PrivacyInfo.xcprivacy)、[project.yml](../../../project.yml) | 用户主动分享与 Apple StoreKit 服务另行说明；隐私清单不自动证明正式商店问卷或所有网络行为已审核 |
| 六种界面语言，报告跟随界面或固定英语 | [AppLanguage](../../../Packages/FoldL10n/Sources/FoldL10n/AppLanguage.swift)、[AppSettings](../../../App/Localization/AppSettings.swift) | 不声称任意组合的独立报告语言选择器；系统权限弹窗跟随设备语言 |
| 非铰链机型的适用检查及系统可用性限制 | [FoldCheckApp](../../../App/FoldCheckApp.swift)、[project.yml](../../../project.yml)、[InspectionPlan](../../../Packages/TestsKit/Sources/TestsKit/InspectionPlan.swift) | 工程最低 iOS 17；Duo 铰链桥按 iOS 27.1 限制。正式支持清单及真实硬件结果待确认，公开文案不写“支持全部 iPhone” |

已存在的验证记录见 [M7 validation](../../review/m7-validation.md)。其中模拟器测试、软件生成报告和示例截图不能替代真实设备、人工无障碍或 App Store Sandbox 的验收。此前已完成的图标探索未被选为新图标，因此更新说明不宣传新图标或已采用原生 Liquid Glass 图标。
