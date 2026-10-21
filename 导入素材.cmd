@echo off
chcp 65001 >nul
cd /d "%~dp0"
python -X utf8 tools\import_media.py
if errorlevel 1 (
  echo 导入失败。请安装 Python，并运行 python -m pip install -r tools\requirements-import.txt。
) else (
  echo 导入记录：UserMedia\import_report.json。原文件已保留。
)
pause
