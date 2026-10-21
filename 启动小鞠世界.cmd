@echo off
chcp 65001 >nul
if exist "%~dp0builds\windows\XiaojuWorld.exe" (
  start "" "%~dp0builds\windows\XiaojuWorld.exe"
) else (
  echo 请先从 GitHub Releases 下载 Windows 试玩包，或用 Godot 打开 project.godot。
  pause
)
