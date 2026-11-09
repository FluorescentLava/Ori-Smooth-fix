# Ori Classic Smooth fix — experimental

Windows Steam《精灵与森林》2015 普通版，AppID 261570。

**解压 → 双击 `Install.cmd` → 以后照常启动游戏。**

安装器直接修改玩家自己的 `ori_Data/Managed/Assembly-CSharp.dll`，解除渲染目标帧率并关闭引擎垂直同步；复制 Special K 的 32 位本地插件与四核心报告/不限帧配置。不会生成备份，不做版本或哈希门槛，不写 Steam 参数，不需要特殊启动器。普通玩家无需安装 .NET SDK 或编译工具。

这是普通版的**基础解锁实验包**。本机没有普通版游戏文件，因此尚未完成普通版实际运行验收。此包不包含 DE 的预编译游戏程序集，也不宣称包含 DE 版的镜头/角色插值、逐帧拖尾或拖尾上传缓存优化。代码已经通过合成程序集的执行测试；测试范围见 `Docs/Validation.md`。

Special K 的 DXGI 呈现与核心报告配置沿用 DE 配置，普通版的实际加载和性能效果尚未验证；基础帧率/VSync 补丁本身不依赖 Special K 成功加载。

找不到安装目录时，把包内全部内容放到 `ori.exe` 旁再双击 `Install.cmd`，也可执行 `Install.cmd -GameDirectory "D:\SteamLibrary\steamapps\common\Ori"`。

`Source/Patch-Classic.ps1` 是完整补丁源码；`Source/lib/Mono.Cecil.dll` 是兼容 Windows PowerShell 5.1 的安装依赖。普通版未知布局的 `settings.bin` 不会被修改；运行时只在值发生变化时设置引擎帧率和 VSync。

恢复游戏原程序集可使用 Steam 验证游戏文件；插件文件是游戏目录的 `dxgi.dll`、`dxgi.ini`。
