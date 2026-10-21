# 构建与验证

## 环境

使用 Godot 4.7.2 标准版、匹配的 Windows x86_64 导出模板，以及 Python 3.10 或以上版本。重新生成媒体和地形表时需要 `requirements-dev.txt` 中的依赖。

```powershell
python -m pip install -r requirements-dev.txt
python tools/build_public.py import --engine "你的 Godot 可执行文件路径"
```

`--engine` 也可以通过 `GODOT_BIN` 环境变量指定。构建工具使用项目相对路径；日志和构建临时文件写入本项目的 `reports` 与 `.runtime`。

## 运行和导出

日常开发可以直接用 Godot 导入并运行 `project.godot`。源码包含当前烘焙世界，普通修改界面和玩法代码无需重新烘焙几何。

更改建筑或地形生成代码后，使用有图形输出的 Mobile/Vulkan 后端重新烘焙。无头烘焙不能代替此步骤。

```powershell
python tools/build_public.py bake --engine "你的 Godot 可执行文件路径"
python tools/build_public.py check --engine "你的 Godot 可执行文件路径"
python tools/build_public.py smoke --engine "你的 Godot 可执行文件路径"
python tools/build_public.py restore --engine "你的 Godot 可执行文件路径"
python tools/build_public.py export --engine "你的 Godot 可执行文件路径" --templates-dir "匹配的 Windows 模板目录"
python tools/build_public.py audit
python tools/build_public.py package
```

`--templates-dir` 目录应包含 `windows_release_x86_64.exe`，可同时包含 debug 模板。工具把模板放入隔离的构建用户目录，不修改正常游戏存档。

导出目录为 `builds/windows`，压缩包和 SHA-256 校验文件在 `dist`。使用 Godot 编辑器导出时，请先安装标准模板，再选择 `Windows Public` 预设。

## 重新生成资源

```powershell
python tools/build_public.py demo
python tools/make_terrain_field_lut110.py --size 4096
```

地形表生成器先写入 `.runtime/terrain_field110_4096.rg16f`。确认生成结果后，将它复制为 `assets/materials/terrain_field110.bin`，更新公开资源清单，再重新烘焙。当前随源码保留的 64 MiB 地形表可以直接使用。

媒体生成器使用代码绘制几何海景，结合项目原创器乐生成演示短片，没有使用真人图片或声音。重新生成媒体后应执行导入、烘焙和公开资源检查。

## 发布更新

先完成源码和独立包检查，再提交变更、创建新版本标签，并把 `dist` 中的 Windows 压缩包和校验文件上传到同一版本的 GitHub Release。发布前运行 `audit`，检查本次提交和压缩包清单。个人库、存档、原始媒体和历史构建保持在 Git 排除规则内。
