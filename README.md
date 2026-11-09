# Ori-Smooth-fix

《精灵与森林》的 Windows 流畅度补丁，分别提供终极版（DE）和 2015 普通版安装包。

从 [Releases](https://github.com/FluorescentLava/Ori-Smooth-fix/releases) 下载对应游戏版本，解压后双击 `Install.cmd`，以后照常启动游戏。安装器直接覆盖或修改文件，不创建备份，不做版本或哈希门槛，不修改 Steam 启动参数，也不要求专用启动器。

| 游戏版本 | 下载 | 功能与验证范围 |
| --- | --- | --- |
| 终极版 / Definitive Edition | [DE v4.0.0](https://github.com/FluorescentLava/Ori-Smooth-fix/releases/tag/de-v4.0.0) | 不限帧、镜头和角色显示插值、角色拖尾逐帧更新、拖尾数据提交缓存；已在 DE 实机验证。 |
| 原版 / 2015 original | [Classic v4.0.0](https://github.com/FluorescentLava/Ori-Smooth-fix/releases/tag/classic-v4.0.0) | 不限帧、镜头和角色显示插值、角色拖尾逐帧更新、拖尾数据提交缓存；使用原版程序集和摄像机回调适配。验收记录见 [原版验证记录](classic/Docs/Validation.md)。 |

两个版本分别适用于 Steam AppID **387290** 和 **261570**，安装包不能互换。

DE 和 Classic 区分的是游戏版本，两包提供相同的补丁功能。旧的 Classic v1.0.0 实验包只完成了不限帧适配，已被完整的 Classic v4.0.0 取代。

## 补丁功能

两版将渲染目标从 60 FPS 改为不限帧，保持 60 Hz 物理模拟，在渲染阶段插值镜头和角色显示位置，并让角色残影按显示位置采样、逐帧更新。缓存跳过未变化的 UV、索引和材质提交。Special K 的配置提供四核心报告、Flip Discard 和关闭呈现同步。原版另适配其摄像机消息接口，并修正原生非同步模式遗留的同步状态，避免游戏时间随渲染帧率变化。

一次局部测试中，拖尾网格更新的 CPU 耗时从 21.28 降至 14.23 微秒；整体 FPS 没有测出显著提升。原作约 30 FPS 的身体姿态素材没有生成额外帧。更多测试数据与适用边界见 [DE 验证记录](de/Docs/Validation.md)。

## 源码与构建

- `de/Source`：DE 辅助模块 C# 源码、三个阶段的 IL 补丁脚本、构建入口和 Mono.Cecil。
- `de/Install*.ps1`：一次性 DE 安装器源码。
- `classic/`：2015 原版完整辅助模块、IL 补丁、独立安装器及验证记录。
- `scripts/package.py`：生成两种 Release ZIP，重新计算文件摘要并验证压缩包。

两版构建需要 PowerShell 7、.NET SDK 6 或更新版本、对应游戏的引用 DLL，以及未修改的原始 `Assembly-CSharp.dll`。以 DE 为例：

```powershell
pwsh -File .\de\Source\Build.ps1 -GameDirectory "D:\SteamLibrary\steamapps\common\Ori DE" -OriginalAssembly "D:\Originals\Assembly-CSharp.dll" -OutputDirectory .\de\Payload
python .\scripts\package.py --edition de
```

仓库不提交游戏拥有的 `Assembly-CSharp.dll`。两版预编译安装文件均在 Release 附件中，安装时直接替换对应游戏文件。Classic 使用原版自己的程序集构建。原版构建与验证说明见其目录内 README。

## 许可证与来源

本项目编写的安装器、辅助模块与补丁脚本采用 [GNU GPL v3](LICENSE)。游戏及其原有代码的权利归原权利人。

- [Special K 26.10.10](https://github.com/SpecialKO/SpecialK/releases/tag/SK_26_10_10)，GPL v3；[对应源码](https://github.com/SpecialKO/SpecialK/tree/SK_26_10_10)。
- [Mono.Cecil 0.11.6](https://github.com/jbevain/cecil/tree/0.11.6)，MIT。

各安装包的 `ThirdParty` 目录包含完整许可证与来源说明。
