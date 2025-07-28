@echo off
echo 正在检查依赖项...
pip install -r requirements.txt

echo 设置环境变量...
set DB_PATH=./data/record.sqlite
set NEO4J_URI=bolt://localhost:7687
set NEO4J_USER=neo4j
set NEO4J_PASSWORD=password

echo 正在启动混合搜索服务器...
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
pause 