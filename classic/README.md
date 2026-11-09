# Ori Smooth fix — 2015 原版

适用于 Windows Steam《Ori and the Blind Forest》2015 原版（AppID 261570）。

**解压 → 双击 `Install.cmd` → 以后照常启动游戏。**

`classic` 和 `de` 区分的是游戏版本，两者均提供完整的流畅度修复功能。本包已取代旧的 `classic-v1.0.0-experimental` 基础解锁包。

- 解除渲染帧率上限，运行时关闭引擎 VSync。
- 镜头和角色视觉位置按渲染帧插值。
- 使用原生非同步时序，保留 60 Hz 物理步长。
- 角色拖尾在插值后的视觉位置生成，每个渲染帧更新完整拖尾网格。
- 缓存未变化的拖尾网格拓扑、UV 和材质提交，减少重复上传。
- 附带 Special K 的 32 位本地插件与不限帧配置。

安装器直接覆盖四个运行文件，不生成备份、不做版本或哈希检查、不写 Steam 参数，不需要专用启动器、.NET SDK 或编译工具。也可以把 `Payload` **里面**的内容直接覆盖到 `ori.exe` 所在目录。下次正常启动即生效。

自动定位失败时，把安装包放在 `ori.exe` 旁边后运行 `Install.cmd`，也可执行：

```powershell
Install.cmd -GameDirectory "D:\SteamLibrary\steamapps\common\Ori"
```

安装后的文件：

```text
Ori/
  dxgi.dll
  dxgi.ini
  ori_Data/Managed/
    Assembly-CSharp.dll
    OriMotionSmoothing.dll
```

游戏目录内的 `ori_Data` 是原版目录；DE 使用 `oriDE_Data`。两个游戏的程序集不可交叉替换。

渲染不限帧会增加负载；实际帧率取决于硬件、场景和温度。位置插值和拖尾按渲染帧更新，原游戏逐帧制作的角色动画素材仍使用原来的动画帧数。

验证记录见 `Docs/Validation.md`。本包基于实际原版程序集构建；发行包包含预编译文件，源码仓库提供可复现的补丁构建脚本。开发者使用 PowerShell 7 和 .NET SDK 构建：

```powershell
pwsh -File Source/Build.ps1 -GameDirectory "D:\SteamLibrary\steamapps\common\Ori" -OriginalAssembly "D:\Original\Assembly-CSharp.dll" -OutputDirectory "D:\Build\Ori-Classic"
```

`OriginalAssembly` 必须指向未修改的原版程序集；省略时使用游戏当前的程序集。构建与测试脚本只面向开发者，普通玩家直接安装发行包即可。

卸载时关闭游戏，删除游戏目录的 `dxgi.dll`、`dxgi.ini` 和 `ori_Data/Managed/OriMotionSmoothing.dll`，再用 Steam 验证游戏文件恢复原版程序集。
