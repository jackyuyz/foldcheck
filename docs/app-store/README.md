# FoldCheck 上架文案草案

编写日期：2026-10-16。依据当前代码（功能基线 `3d3b37b`，设计记录归档 `f240279`），不把规格中的计划项当作已实现功能。当前 App 图标保持原样。

## 文件与使用范围

| 范围 | 文件 | 用途 |
|---|---|---|
| 公开文案 | [public/en-US.md](public/en-US.md) | 英文名称、副标题、简介、完整描述、关键词和更新说明 |
| 公开文案 | [public/zh-Hans.md](public/zh-Hans.md) | 简体中文对应文案 |
| 审核专用 | [review/en-US.md](review/en-US.md) | 英文 App Review Notes，包含付费路径、权限及验证边界 |
| 审核专用 | [review/zh-Hans.md](review/zh-Hans.md) | 中文审核备注，供选择使用或内部核对 |
| 内部依据 | [internal/feature-evidence.md](internal/feature-evidence.md) | 每类功能对应的实现文件及不能扩大解释的边界 |
| 内部待办 | [internal/TODO.md](internal/TODO.md) | 所有“待确认 / TBC”项目，不属于公开文案或审核备注 |
| 内部校验 | [internal/validation.md](internal/validation.md) | 字段长度、UTF-8 字节数及检查范围 |

仅复制目标字段下的 `text` 代码块内容，不复制标题、说明或内部待办。审核备注不是公开描述；英文和中文是同一审核字段的替代版本，不要直接拼接。

“简介”对应 Promotional Text；另提供 Subtitle，避免与商店副标题混淆。公开描述明确标注免费与付费范围，不写死价格，也不承诺订阅以外的未配置权益。

公开文件各提供两个更新说明字段：`whats-new-initial` 是首发候选；`whats-new-update` 只描述本仓库已完成的 M7 与触控旋转改动。**待确认 / TBC-02：是否已有线上版本及其功能基线。** 不能把本地里程碑当作已发布版本；确认后只选一个字段，并删去线上基线已经包含的更新项。

## 字段限制与来源

按 2026-10-16 查阅的 Apple 文档校验：名称及副标题各不超过 30 字符；简介不超过 170 字符；描述及更新说明各不超过 4000 字符；关键词不超过 100 字节；审核备注不超过 4000 字节。中文关键词和备注按 UTF-8 字节数检查。文案中的段落换行计入长度。

- [App information：名称及副标题](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Platform version information：简介、描述、关键词、更新说明及审核备注](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)

正式商店名称可用性、版本归属、实际价格、联系信息、上架地区和硬件验证仍为待确认项，详见内部待办。公开文案不使用虚构的联系方式、固定金额、审核结果或未验证的检测准确率。

## 本次交付边界

只新增 `docs/app-store/` 文档；不修改 App、图标、工程配置或内购配置。新增上架文案不做 Git commit / push，不上传构建，不写入 App Store Connect，不提交审核。此前已有的图标探索记录另行归档并推送到 `main`，未替换 App 当前图标。
