# 普通版验证范围

发布状态：实验包，建议作为 GitHub prerelease 发布。

- Windows PowerShell 5.1 下加载官方 Mono.Cecil 0.11.6 的 .NET Framework 4.0 版本。
- 用自建的 Unity API / GameController 合成程序集验证注入后实际执行结果，不使用或分发来源不明的游戏程序集。
- 覆盖原方法正常返回、分支返回、游戏再次写入帧率/VSync、重复安装、无备份/临时文件、其他代码执行保留等情况。
- 值相同时不重复调用 Unity 设置器。
- 没有普通版实际游戏运行测试，也没有普通版 FPS 数据。
- DE 的运动和拖尾代码依赖 DE 的 PhysicsLimitTest、GameplayCamera、SeinCharacter、UberGhostTrail 等接口，当前普通版包不含这些未验证的接口假设。

原版模组工具可确认原版使用 `ori_Data/Managed/Assembly-CSharp.dll` 的程序集修改模式：[Ori Controller Remap](https://github.com/beatcracker/Ori-Controller-Remap)。

Unity 帧率接口：[Application.targetFrameRate](https://docs.unity3d.com/ScriptReference/Application-targetFrameRate.html)、[QualitySettings.vSyncCount](https://docs.unity3d.com/ScriptReference/QualitySettings-vSyncCount.html)。

安装器里的方法存在性判断是生成有效 IL 所需的结构要求，不要求版本确认，也没有已知哈希白名单。
