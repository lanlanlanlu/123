@echo off
echo 正在检查依赖项...
pip install -r requirements.txt

echo 正在启动混合搜索服务器...
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
pause 