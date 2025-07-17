FROM python:3.10-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 复制项目文件
COPY docker-requirements.txt .
COPY *.py .
COPY utils/ ./utils/
COPY templates/ ./templates/
COPY data/ ./data/
COPY storage/ ./storage/

# 创建必要的目录
RUN mkdir -p storage

# 安装依赖
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r docker-requirements.txt

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV HOST=0.0.0.0
ENV PORT=8000

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"] 