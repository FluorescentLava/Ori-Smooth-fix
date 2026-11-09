# 终极版验证记录

适用游戏为 Steam AppID 387290，Unity 5.3.2f1，Windows 32 位。

## 运行测试

游戏在无图形启动参数时使用 DX11 和多线程渲染（threaded=1），辅助模块正常加载。测试覆盖角色拖尾采样、完整网格更新、暂停恢复和瞬移。

拖尾提交缓存的数据核对包含 160 次连续场景采样和 128 次交错采样。局部 CPU 网格更新时间为未缓存 21.28 微秒、缓存 14.23 微秒；对应整体帧率为 441.72 和 440.42 FPS。这组数据支持局部提交开销减少，未显示整体 FPS 收益。

## 程序集与安装器

补丁修改 10 个方法并增加两个私有缓存字段。源码构建的主程序集与运行文件逐字节一致，辅助模块的 16 个方法 IL 和字段一致，编译元数据允许差异。

Windows PowerShell 5.1 的隔离安装测试覆盖文件替换、重复安装、含空格路径和 Steam 库定位。安装器保留 Steam 配置和存档，settings.bin 仅修改 VSync 字节。运行模块不包含自动读档、自动移动、存档重定向或性能探针。

逐项结果见本目录 JSON：

- [程序集比较](patch-verification.json)
- [拖尾测试](trail-test-results.json)
- [缓存测试](cache-test-results.json)与[缓存回归测试](cache-regression-results.json)
- [安装器测试](installer-test-results.json)
- [无启动参数运行测试](no-launch-arguments-test.json)
- [构建验证](package-verification.json)

## 适用范围

测试覆盖局部场景，未遍历全地图、全部技能或全部硬件。角色姿态素材保持原有动画帧数，显示插值可能增加最多一个物理步（约16.7 ms）的延迟。实际帧率、温度和风扇噪声受硬件及场景影响，四核心报告配置未证明对所有电脑最优。
