# Ori-Smooth-fix · 2015 原版

适用于 Windows Steam《Ori and the Blind Forest》（AppID 261570，32 位）。

## 功能

- 渲染不限帧，关闭垂直同步。
- 镜头和角色显示位置插值，保持 60 Hz 物理模拟。
- 按显示位置采样角色拖尾，逐帧更新网格。
- 缓存未变化的拖尾 UV、索引和材质提交。
- Special K 核心报告与 Flip Discard 呈现配置。

## 安装

1. 关闭游戏并解压安装包。
2. 双击 `Install.cmd`。
3. 从 Steam 或原快捷方式启动游戏。

安装器自动定位游戏目录并替换文件。也可将 `Payload` 文件夹中的内容覆盖到 `ori.exe` 所在目录。安装无需编译环境或额外启动参数；文件覆盖不保留备份。

自动定位失败时，将安装包放在 `ori.exe` 旁运行，或指定游戏目录：

```powershell
Install.cmd -GameDirectory "D:\SteamLibrary\steamapps\common\Ori"
```

补丁运行文件：

```text
dxgi.dll
dxgi.ini
ori_Data/Managed/Assembly-CSharp.dll
ori_Data/Managed/OriMotionSmoothing.dll
```

## 效果与适用范围

补丁改善显示位置和拖尾的更新频率，角色姿态素材保持原有动画帧数。显示插值可能增加约一个物理步的延迟，实际帧率取决于硬件和场景。测试数据见 [验证记录](Docs/Validation.md)。

## 卸载

关闭游戏，移除 `dxgi.dll`、`dxgi.ini` 和 `ori_Data/Managed/OriMotionSmoothing.dll`，通过 Steam 验证游戏文件恢复原程序集。

## 源码与构建

`Source` 包含辅助模块和构建脚本，`Docs` 保存验证数据，`ThirdParty` 包含许可证和来源链接。

构建需要 PowerShell 7、.NET SDK 6 或更新版本、游戏引用 DLL 和未修改的 `Assembly-CSharp.dll`。在安装包根目录执行：

```powershell
pwsh -File .\Source\Build.ps1 -GameDirectory "D:\SteamLibrary\steamapps\common\Ori" -OriginalAssembly "D:\Originals\Assembly-CSharp.dll" -OutputDirectory .\Build\Payload
```
