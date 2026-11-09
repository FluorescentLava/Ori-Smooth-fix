# Ori-Smooth-fix

《精灵与森林》的 Windows 流畅度补丁，支持 2015 原版和终极版。

## 下载

从 [Releases](https://github.com/FluorescentLava/Ori-Smooth-fix/releases/latest) 选择与游戏对应的安装包：

| 游戏 | Steam AppID | 安装包 |
| --- | --- | --- |
| Ori and the Blind Forest（2015 原版） | 261570 | [Classic](https://github.com/FluorescentLava/Ori-Smooth-fix/releases/download/v4.0.0/Ori-Smooth-fix-Classic-v4.0.0.zip) |
| Ori and the Blind Forest: Definitive Edition（终极版） | 387290 | [DE](https://github.com/FluorescentLava/Ori-Smooth-fix/releases/download/v4.0.0/Ori-Smooth-fix-DE-v4.0.0.zip) |

## 功能

- 解除渲染帧率上限并关闭垂直同步。
- 按渲染帧插值镜头和角色显示位置，保持 60 Hz 物理模拟。
- 按角色显示位置生成拖尾，逐帧更新拖尾网格。
- 缓存未变化的拖尾 UV、索引和材质数据，减少重复提交。
- 提供 Special K 的核心报告与 Flip Discard 呈现配置。

## 安装

1. 关闭游戏，解压对应安装包。
2. 双击 `Install.cmd`。
3. 从 Steam 或原快捷方式启动游戏。

安装器会定位 Steam 游戏目录并替换补丁文件。也可以将包内 `Payload` 文件夹中的内容覆盖到游戏目录。安装无需编译环境或额外启动参数；文件覆盖不保留备份。

目录定位和卸载方法见 [原版说明](classic/README.md) 或 [终极版说明](de/README.md)。

## 效果与适用范围

补丁改善镜头、角色显示位置和拖尾的更新频率。角色姿态素材保持原有动画帧数。显示插值可能增加约一个物理步的延迟，实际帧率取决于硬件和场景。

测试数据见 [原版验证记录](classic/Docs/Validation.md) 和 [终极版验证记录](de/Docs/Validation.md)。

## 构建

`classic/Source` 和 `de/Source` 包含对应游戏的 C# 辅助模块、IL 补丁及构建脚本；`scripts/package.py` 生成安装包。

构建需要 PowerShell 7、.NET SDK 6 或更新版本、对应游戏的引用 DLL，以及未修改的 `Assembly-CSharp.dll`。在仓库根目录执行：

```powershell
pwsh -File .\classic\Source\Build.ps1 -GameDirectory "D:\SteamLibrary\steamapps\common\Ori" -OriginalAssembly "D:\Originals\Classic\Assembly-CSharp.dll" -OutputDirectory .\classic\Payload
python .\scripts\package.py --edition classic

pwsh -File .\de\Source\Build.ps1 -GameDirectory "D:\SteamLibrary\steamapps\common\Ori DE" -OriginalAssembly "D:\Originals\DE\Assembly-CSharp.dll" -OutputDirectory .\de\Payload
python .\scripts\package.py --edition de
```

预编译运行文件随安装包提供。游戏程序集不存入源码仓库。

## 许可证

项目代码采用 [GNU GPL v3](LICENSE)。游戏及其原有代码的权利归原权利人。

- [Special K 26.10.10](https://github.com/SpecialKO/SpecialK/tree/SK_26_10_10)：GPL v3。
- [Mono.Cecil 0.11.6](https://github.com/jbevain/cecil/tree/0.11.6)：MIT。

安装包的 `ThirdParty` 目录包含许可证和来源链接。
