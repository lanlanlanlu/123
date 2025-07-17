@echo off
echo 正在启动混合搜索服务器...

REM 切换到服务器目录
cd %~dp0

REM 使用python -m启动，确保模块路径正确
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000

pause 