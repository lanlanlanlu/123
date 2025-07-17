@echo off
echo 正在启动Graph RAG服务器...

REM 切换到服务器目录
cd %~dp0
 
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
pause 