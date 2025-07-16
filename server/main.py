# server/main.py

import os
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import re
import json
from datetime import datetime  # 添加datetime导入

# 导入工具类
from utils.date_utils import convert_timestamp_to_date_str
# 导入地理编码工具
from utils.geocoding import extract_locations_from_text, enhance_location_metadata, build_location_filters

# 我们只从核心包导入
from llama_index.core import (
    StorageContext,
    load_index_from_storage,
    Settings,
    PromptTemplate,
)
# 引入元数据过滤器
from llama_index.core.vector_stores import MetadataFilters, ExactMatchFilter, FilterCondition, FilterOperator, MetadataFilter
# 引入查询引擎
from llama_index.core.query_engine import RetrieverQueryEngine

from llama_index.embeddings.google_genai import GoogleGenAIEmbedding
from llama_index.llms.google_genai import GoogleGenAI

# 引入dateparser
import dateparser

# 引入BM25检索器和混合检索相关组件
from llama_index.retrievers.bm25 import BM25Retriever
from llama_index.core.retrievers import QueryFusionRetriever, VectorIndexRetriever
from llama_index.core.vector_stores.types import VectorStoreQueryMode

# --- 配置与初始化 ---
PERSIST_DIR = "./storage"
load_dotenv()
api_key = os.getenv("GOOGLE_API_KEY")
if not api_key:
    raise ValueError("GOOGLE_API_KEY 环境变量未设置！")

llm = GoogleGenAI(
    model="gemini-1.5-flash",
    api_key=api_key,
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
# 将索引加载到全局
index = None

# --- 提示词模板 ---
QA_TEMPLATE_STR = (
    "我们有一些上下文信息如下。\n"
    "---------------------\n"
    "{context_str}\n"
    "---------------------\n"
    "你是一个专业的个人笔记助手。请只根据上面提供的上下文信息，来回答这个问题。"
    "如果上下文信息与问题无关，请回答“根据您的笔记内容，我无法回答这个问题。”\n"
    "如果用户要求按照特定方式组织回答（如分点、总结等），请务必按照要求组织你的回答。\n"
    "问题: {query_str}\n"
)

# --- 实体提取与过滤器构建 ---

def extract_entities_from_query(query: str) -> dict:
    """
    从用户的自然语言查询中提取实体（标签、地点、日期）。
    使用LLM和地理编码API提高提取准确性。
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

    # 2. 使用LLM和地理编码API提取地点
    try:
        # 使用LLM提取地点
        locations = extract_locations_from_text(query, llm=Settings.llm)
        if locations:
            # 使用地理编码API增强地点信息
            enhanced_locations = enhance_location_metadata(locations)
            entities["locations"] = enhanced_locations["variants"]
            entities["location_hierarchy"] = enhanced_locations["hierarchy"]
            print(f"提取到的地点: {locations}")
            print(f"增强后的地点: {entities['locations']}")
            print(f"地点层级关系: {entities['location_hierarchy']}")
    except Exception as e:
        print(f"提取地点时出错: {e}")

    # 3. 提取日期 (例如: "今天", "7月1日", "last week")
    clean_query = re.sub(r'[@#]([\w\u4e00-\u9fa5]+)', '', query)
    
    parsed_date = dateparser.parse(clean_query, languages=['zh', 'en'])
    if parsed_date:
        entities["dates"].append(parsed_date.strftime('%Y-%m-%d'))
        
    return entities

def build_metadata_filters(entities: dict) -> MetadataFilters | None:
    """
    根据提取的实体构建 LlamaIndex 的 MetadataFilters 对象。
    支持地点的变体和层级关系匹配。
    """
    # 所有过滤器列表
    all_filters = []
    
    # 为 "tags" 创建过滤器
    if entities.get("tags"):
        tag_filters = [
            MetadataFilter(key="tags", operator=FilterOperator.CONTAINS, value=t)
            for t in entities["tags"]
        ]
        all_filters.extend(tag_filters)

    # 为 "locations" 创建过滤器，优先使用精确地点匹配
    location_filters = []
    if entities.get("locations"):
        # 添加所有地点变体的过滤器
        for location in entities["locations"]:
            location_filters.append(
                MetadataFilter(key="locations", operator=FilterOperator.CONTAINS, value=location)
            )
    
    # 只有在没有具体地点匹配时才使用层级关系
    if not location_filters and entities.get("location_hierarchy"):
        for level in entities["location_hierarchy"]:
            location_filters.append(
                MetadataFilter(key="location_hierarchy", operator=FilterOperator.CONTAINS, value=level)
            )
    
    if location_filters:
        all_filters.extend(location_filters)

    # 为 "dates" 创建过滤器
    if entities.get("dates"):
        for date in entities["dates"]:
            # 匹配创建日期
            all_filters.append(
                MetadataFilter(key="creation_date", operator=FilterOperator.EQ, value=date)
            )
            # 匹配提及的日期
            all_filters.append(
                MetadataFilter(key="mentioned_dates", operator=FilterOperator.CONTAINS, value=date)
            )
        
    if not all_filters:
        return None

    # 返回最终的过滤器组合，使用OR关系连接所有过滤器
    # 这样可以避免嵌套的MetadataFilters结构
    return MetadataFilters(filters=all_filters, condition=FilterCondition.OR)


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
    处理聊天请求，使用混合搜索（向量+BM25）
    """
    if index is None:
        raise HTTPException(status_code=503, detail="服务不可用：索引未初始化。")
    if not request.query:
        raise HTTPException(status_code=400, detail="查询不能为空。")

    print(f"\n{'='*50}\n收到原始查询: {request.query}")

    # 1. 从查询中提取实体
    entities = extract_entities_from_query(request.query)
    print(f"提取到的实体: {entities}")

    # 2. 根据实体构建元数据过滤器
    metadata_filters = build_metadata_filters(entities)
    
    # 3. 创建混合检索引擎
    qa_template = PromptTemplate(QA_TEMPLATE_STR)
    
    # 混合检索模式：BM25 + 向量检索
    print("使用混合检索模式（Hybrid Search）")
    # 创建向量检索器
    vector_retriever = VectorIndexRetriever(
        index=index, 
        similarity_top_k=5,
        filters=metadata_filters,
    )
    
    # 创建BM25检索器
    bm25_retriever = BM25Retriever.from_defaults(
        docstore=index.docstore,
        similarity_top_k=5
    )
    
    # 创建融合检索器
    retriever = QueryFusionRetriever(
        retrievers=[vector_retriever, bm25_retriever],
        similarity_top_k=3,
        num_queries=1,
    )
    
    # 创建查询引擎
    query_engine = RetrieverQueryEngine.from_args(
        retriever=retriever,
        text_qa_template=qa_template,
        llm=Settings.llm,
        streaming=False  # 明确指定不使用流式响应
    )

    # 4. 使用查询引擎进行查询
    # 为了让AI更好地理解，我们可以把标签和地点从问题中移除
    clean_query = re.sub(r'[@#]([\w\u4e00-\u9fa5]+)', '', request.query).strip()
    if not clean_query:  # 如果清理后问题为空，就用原始问题
        clean_query = request.query

    print(f"发送给AI的清理后查询: {clean_query}")
    response = query_engine.query(clean_query)
    
    # 打印检索到的上下文
    print(f"\n--- 检索到的上下文 ({len(response.source_nodes)} 条) ---")
    if not response.source_nodes:
        print("未能检索到任何相关上下文。")
    else:
        for i, node in enumerate(response.source_nodes):
            print(f"【上下文 {i+1}】 (相似度: {node.score:.4f})")
            print(f"来源笔记ID: {node.metadata.get('note_id', 'N/A')}, 标题: {node.metadata.get('title', 'N/A')}")
            print(f"元数据: {node.metadata}")  # 打印所有元数据以供调试
            print(f"内容片段:\n---\n{node.get_content()}\n---")
    print(f"{'='*50}\n")
    
    # 获取响应文本
    full_response_text = response.response
    print(f"生成的回答: {full_response_text}")
    return {"response": full_response_text}

@app.get("/")
def health_check():
    return {"status": "ok", "message": "AI 聊天服务正在运行。"}