import os
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from llama_index.core import (
    StorageContext,
    load_index_from_storage,
    Settings,
)
# 从 gemini 导入
from llama_index.embeddings.gemini import GeminiEmbedding
from llama_index.llms.gemini import Gemini

# --- 配置与初始化 ---
PERSIST_DIR = "./storage"

# 加载环境变量并配置AI模型
load_dotenv()
api_key = os.getenv("GOOGLE_API_KEY")
if not api_key:
    raise ValueError("GOOGLE_API_KEY 环境变量未设置！请检查你的 .env 文件。")

# 使用 Gemini 类
Settings.llm = Gemini(api_key=api_key, model_name="models/gemini-1.5-flash")
# 使用 GeminiEmbedding 类
Settings.embed_model = GeminiEmbedding(api_key=api_key, model_name="models/text-embedding-004")

# 创建FastAPI应用
app = FastAPI()

# 全局变量，用于存储查询引擎
query_engine = None

# --- 应用生命周期事件 ---
@app.on_event("startup")
def startup_event():
    """在应用启动时执行，加载索引并准备查询引擎。"""
    global query_engine
    
    print("应用启动中...")
    
    if not os.path.exists(PERSIST_DIR):
        raise RuntimeError(
            f"索引存储目录 '{PERSIST_DIR}' 不存在。请确保你已经成功运行了 'ingest.py'。"
        )
        
    try:
        print("正在从本地存储加载索引...")
        storage_context = StorageContext.from_defaults(persist_dir=PERSIST_DIR)
        index = load_index_from_storage(storage_context)
        
        query_engine = index.as_query_engine(streaming=True)
        print("索引加载成功，查询引擎已准备就绪！")
    except Exception as e:
        print(f"加载索引时发生错误: {e}")
        query_engine = None


# --- API 请求体模型 ---
class ChatRequest(BaseModel):
    query: str

# --- API 端点 ---
@app.post("/api/chat")
async def handle_chat_request(request: ChatRequest):
    """处理聊天请求，返回AI生成的答案。"""
    if query_engine is None:
        raise HTTPException(status_code=503, detail="服务不可用：查询引擎尚未初始化。")
    
    if not request.query:
        raise HTTPException(status_code=400, detail="查询内容不能为空。")

    print(f"收到查询: {request.query}")
    
    streaming_response = query_engine.query(request.query)
    
    full_response_text = ""
    for text in streaming_response.response_gen:
         full_response_text += text
    
    print(f"生成的回答: {full_response_text}")
    return {"response": full_response_text}

@app.get("/")
def health_check():
    """健康检查端点，用于确认服务是否正在运行。"""
    return {"status": "ok", "message": "AI 聊天服务正在运行。"}