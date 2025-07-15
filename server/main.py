# server/main.py

import os
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import re
from datetime import datetime  # 添加datetime导入

# 导入工具类
from utils.date_utils import convert_timestamp_to_date_str

# 我们只从核心包导入
from llama_index.core import (
    StorageContext,
    load_index_from_storage,
    Settings,
    PromptTemplate,
)
# 【新增】引入元数据过滤器
from llama_index.core.vector_stores import MetadataFilters, ExactMatchFilter

from llama_index.embeddings.google_genai import GoogleGenAIEmbedding
from llama_index.llms.google_genai import GoogleGenAI

# 【新增】引入dateparser
import dateparser

# --- 配置与初始化 (保持不变) ---
PERSIST_DIR = "./storage"
load_dotenv()
api_key = os.getenv("GOOGLE_API_KEY")
if not api_key:
    raise ValueError("GOOGLE_API_KEY 环境变量未设置！")

llm = GoogleGenAI(
    model="gemini-1.5-flash",
    api_key=api_key,  # uses GOOGLE_API_KEY env var by default
)
embed_model = GoogleGenAIEmbedding(
    model_name="text-embedding-004",
    embed_batch_size=100,
    api_key=api_key,
)

# 设置全局默认模型
Settings.llm = llm
Settings.embed_model = embed_model

app = FastAPI()
# 【修改】我们将把 index 加载到全局，而不是 query_engine
# 因为我们需要根据每个请求动态地创建带有过滤器的 query_engine
index = None

# --- 提示词模板 (保持不变) ---
QA_TEMPLATE_STR = (
    "我们有一些上下文信息如下。\n"
    "---------------------\n"
    "{context_str}\n"
    "---------------------\n"
    "你是一个专业的个人笔记助手。请只根据上面提供的上下文信息，来回答这个问题。如果上下文信息与问题无关，请回答“根据您的笔记内容，我无法回答这个问题。”\n"
    "问题: {query_str}\n"
)

# --- 【新增】实体提取与过滤器构建 ---

def extract_entities_from_query(query: str) -> dict:
    """
    从用户的自然语言查询中提取实体（标签、地点、日期）。
    """
    entities = {
        "tags": [],
        "locations": [],
        "dates": []
    }
    
    # 1. 提取标签 (例如: #工作 or @工作)
    tags = re.findall(r'[@#]([\w\u4e00-\u9fa5]+)', query)
    if tags:
        entities["tags"] = [tag.strip() for tag in tags]

    # 2. 提取地点 (例如: 在上海, from London)
    # 使用正则表达式进行一个简单的提取
    location_matches = re.search(r'(在|位于|去|from\s|at\s)([\w\u4e00-\u9fa5]+)', query, re.IGNORECASE)
    if location_matches:
        entities["locations"].append(location_matches.group(2).strip())

    # 3. 提取日期 (例如: "今天", "7月1日", "last week")
    # 这是一个简化版，真实场景可能需要更复杂的逻辑或LLM
    # 先移除已识别的标签和地点，避免干扰日期解析
    clean_query = re.sub(r'[@#]([\w\u4e00-\u9fa5]+)', '', query)
    
    # 使用 dateparser 解析
    # 注意：dateparser 可能会将 "2025" 这样的年份也解析成一个日期
    # 我们需要一些逻辑来处理这种情况，或者依赖更精确的提取
    parsed_date = dateparser.parse(clean_query, languages=['zh', 'en'])
    if parsed_date:
        entities["dates"].append(parsed_date.strftime('%Y-%m-%d'))
        
    return entities

def build_metadata_filters(entities: dict) -> MetadataFilters | None:
    """
    根据提取的实体构建 LlamaIndex 的 MetadataFilters 对象。
    """
    filters_list = []
    
    # 为每个实体类型创建过滤器
    if entities.get("tags"):
        filters_list.extend(
            [ExactMatchFilter(key="tags", value=t) for t in entities["tags"]]
        )
    
    if entities.get("locations"):
        filters_list.extend(
            [ExactMatchFilter(key="locations", value=l) for l in entities["locations"]]
        )

    if entities.get("dates"):
        # 日期可以匹配 creation_date 或 mentioned_dates
        # 注意: LlamaIndex 的过滤器目前对列表中的 'or' 逻辑支持有限
        # 我们这里简化为匹配 creation_date
        filters_list.extend(
            [ExactMatchFilter(key="creation_date", value=d) for d in entities["dates"]]
        )
        
    if not filters_list:
        return None

    # 多个过滤器之间默认是 AND 关系
    return MetadataFilters(filters=filters_list)


# --- 应用生命周期事件 ---
@app.on_event("startup")
def startup_event():
    """在应用启动时执行，只加载索引。"""
    global index
    print("应用启动中...")
    if not os.path.exists(PERSIST_DIR):
        print(f"警告: 索引目录 '{PERSIST_DIR}' 不存在。请先运行 ingest.py。")
        return
    try:
        print("正在从本地存储加载索引...")
        storage_context = StorageContext.from_defaults(persist_dir=PERSIST_DIR)
        # 显式指定嵌入模型
        index = load_index_from_storage(storage_context, embed_model=Settings.embed_model)
        print("索引加载成功！")
    except Exception as e:
        print(f"加载索引时发生错误: {e}")
        index = None

class ChatRequest(BaseModel):
    query: str

# --- API 端点 ---
@app.post("/api/chat")
async def handle_chat_request(request: ChatRequest):
    """
    【重大改造】处理聊天请求，先提取实体并应用过滤器，然后再查询。
    """
    if index is None:
        raise HTTPException(status_code=503, detail="服务不可用：索引未初始化。")
    if not request.query:
        raise HTTPException(status_code=400, detail="查询不能为空。")

    print(f"\n{'='*50}\n收到原始查询: {request.query}")

    # 1. 【新增】从查询中提取实体
    entities = extract_entities_from_query(request.query)
    print(f"提取到的实体: {entities}")

    # 2. 【新增】根据实体构建元数据过滤器
    metadata_filters = build_metadata_filters(entities)
    
    # 3. 【修改】动态创建查询引擎
    qa_template = PromptTemplate(QA_TEMPLATE_STR)
    query_engine = index.as_query_engine(
        streaming=True,
        similarity_top_k=3,
        text_qa_template=qa_template,
        filters=metadata_filters,  # <-- 在这里应用过滤器！
        embed_model=Settings.embed_model,  # 显式指定嵌入模型
        llm=Settings.llm  # 显式指定LLM
    )

    # 4. 使用查询引擎进行查询
    # 为了让AI更好地理解，我们可以把标签和地点从问题中移除
    clean_query = re.sub(r'[@#]([\w\u4e00-\u9fa5]+)', '', request.query).strip()
    if not clean_query: # 如果清理后问题为空，就用原始问题
        clean_query = request.query

    print(f"发送给AI的清理后查询: {clean_query}")
    response = query_engine.query(clean_query)
    
    # ... (后续的调试输出和返回逻辑保持不变) ...
    print(f"\n--- 检索到的上下文 ({len(response.source_nodes)} 条) ---")
    if not response.source_nodes:
        print("未能检索到任何相关上下文。")
    else:
        for i, node in enumerate(response.source_nodes):
            print(f"【上下文 {i+1}】 (相似度: {node.score:.4f})")
            print(f"来源笔记ID: {node.metadata.get('note_id', 'N/A')}, 标题: {node.metadata.get('title', 'N/A')}")
            print(f"元数据: {node.metadata}") # 打印所有元数据以供调试
            print(f"内容片段:\n---\n{node.get_content()}\n---")
    print(f"{'='*50}\n")
    
    full_response_text = "".join([text for text in response.response_gen])
    print(f"生成的回答: {full_response_text}")
    return {"response": full_response_text}

@app.get("/")
def health_check():
    return {"status": "ok", "message": "AI 聊天服务正在运行。"}