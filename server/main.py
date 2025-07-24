# server/main.py

import os
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import re
import json
import time  # 添加time模块导入
from datetime import datetime  # 添加datetime导入
from typing import List, Dict, Any, Optional
import tenacity  # 添加tenacity模块用于重试功能

# 导入工具类
from utils.date_utils import convert_timestamp_to_date_str
# 导入地理编码工具
from utils.geocoding import extract_locations_from_text, enhance_location_metadata, build_location_filters
# 导入图谱相关工具
from utils.entity_extractor import extract_entities_from_query
from utils.graph_builder import PropertyGraphBuilder
from utils.chat_memory import ChatMemoryManager

# 导入从ingest.py中的转换函数
def convert_delta_to_plain_text(delta_json_string: str) -> str:
    """
    将Quill编辑器的Delta JSON格式转换为纯文本
    """
    if not delta_json_string or delta_json_string.strip() == '[]':
        return ""
    try:
        # 尝试直接解析JSON
        ops = json.loads(delta_json_string)
        if not isinstance(ops, list): return ""
    except json.JSONDecodeError:
        # 如果直接解析失败，说明它可能是一个纯文本字符串
        return delta_json_string.strip()
        
    text_parts = []
    for op in ops:
        if isinstance(op, dict) and 'insert' in op:
            if isinstance(op['insert'], str):
                text_parts.append(op['insert'])
            # 也可以处理图片等其他嵌入类型，但这里我们只关心文本
    
    result = "".join(text_parts).strip()
    return result

# 导入更完整的LlamaIndex组件
from llama_index.core import (
    StorageContext,
    load_index_from_storage,
    Settings,
    PromptTemplate,
    KnowledgeGraphIndex,
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

# 引入Cohere Rerank
import cohere
from llama_index.postprocessor.cohere_rerank import CohereRerank

# 引入图存储和知识图谱索引
from llama_index.graph_stores.neo4j import Neo4jGraphStore
from llama_index.core.query_engine.retriever_query_engine import RetrieverQueryEngine
# 显式导入ChatMessage用于记忆功能
from llama_index.core.llms import MessageRole, ChatMessage

# --- 配置与初始化 ---
PERSIST_DIR = "./storage"
load_dotenv()
api_key = os.getenv("GOOGLE_API_KEY")
if not api_key:
    raise ValueError("GOOGLE_API_KEY 环境变量未设置！")

# 获取Cohere API密钥
cohere_api_key = os.getenv("COHERE_API_KEY")
if not cohere_api_key:
    print("警告: COHERE_API_KEY 环境变量未设置，Cohere Rerank功能将不可用")

# 获取Neo4j连接信息
NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "password")

# 定义Gemini模型列表（从最优先到最不优先）
GEMINI_MODELS = [
    "gemini-2.5-flash",  # 首选模型
    "gemini-2.5-pro",    # 备用模型1
    "gemini-2.0-flash",    # 备用模型2
]

# 定义重试装饰器
retry_on_model_overload = tenacity.retry(
    reraise=True,
    stop=tenacity.stop_after_attempt(3),  # 最多重试3次
    wait=tenacity.wait_exponential(multiplier=1, min=1, max=10),  # 指数退避
    retry=tenacity.retry_if_exception_message(match="model is overloaded")  # 仅在模型过载时重试
)

# 初始化LLM模型(带重试)
@retry_on_model_overload
def initialize_llm():
    """初始化LLM模型，带有重试逻辑"""
    for model_name in GEMINI_MODELS:
        try:
            print(f"尝试初始化模型: {model_name}")
            return GoogleGenAI(
                model=model_name,
                api_key=api_key,
                temperature=0.7,
                retry_on_failure=True,  # 开启内部重试逻辑
                max_retries=2  # 设置最大重试次数
            )
        except Exception as e:
            print(f"初始化 {model_name} 失败: {e}")
            continue
    
    # 如果所有模型都失败
    raise ValueError("所有Gemini模型初始化失败")

# 初始化嵌入模型
@retry_on_model_overload
def initialize_embed_model():
    """初始化嵌入模型，带有重试逻辑"""
    return GoogleGenAIEmbedding(
        model_name="text-embedding-004",
        embed_batch_size=100,
        api_key=api_key,
    )

# 初始化记忆管理器（在其他初始化代码后面）
try:
    # 使用绝对路径初始化记忆管理器
    import os
    memory_storage_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "storage", "memories")
    # 确保目录存在
    os.makedirs(memory_storage_path, exist_ok=True)
    memory_manager = ChatMemoryManager(storage_dir=memory_storage_path)
    print(f"记忆管理器初始化成功，存储路径: {memory_storage_path}")
except Exception as e:
    print(f"记忆管理器初始化失败: {e}")
    memory_manager = None

# 初始化模型
try:
    llm = initialize_llm()
    embed_model = initialize_embed_model()
    
    # 设置全局默认模型
    Settings.llm = llm
    Settings.embed_model = embed_model
    
    print(f"AI 模型初始化成功，使用模型: {llm.model}")
except Exception as e:
    print(f"初始化AI模型失败: {e}")
    raise

app = FastAPI()
# 将索引加载到全局
index = None
# 全局图索引
kg_index = None

# --- 提示词模板 ---
QA_TEMPLATE_STR = (
    "我们有一些上下文信息如下。\n"
    "---------------------\n"
    "{context_str}\n"
    "---------------------\n"
    "你是一个专业的个人笔记助手。请只根据上面提供的上下文信息，来回答这个问题。\n"
    "如果上下文信息与问题无关，请回答“根据您的笔记内容，我无法回答这个问题。”\n"
    "如果用户要求按照特定方式组织回答（如分点、总结等），请务必按照要求组织你的回答。\n"
    "问题: {query_str}\n"
)

# --- 实体提取与过滤器构建 ---

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
        
    # 为人物添加过滤器
    if entities.get("people"):
        for person in entities["people"]:
            all_filters.append(
                MetadataFilter(key="people", operator=FilterOperator.CONTAINS, value=person)
            )
    
    # 为概念添加过滤器
    if entities.get("concepts"):
        for concept in entities["concepts"]:
            all_filters.append(
                MetadataFilter(key="concepts", operator=FilterOperator.CONTAINS, value=concept)
            )
    
    if not all_filters:
        return None

    # 返回最终的过滤器组合，使用OR关系连接所有过滤器
    # 这样可以避免嵌套的MetadataFilters结构
    return MetadataFilters(filters=all_filters, condition=FilterCondition.OR)


# --- 应用生命周期事件 ---
@app.on_event("startup")
def startup_event():
    """在应用启动时执行，加载索引和图谱索引。"""
    global index, kg_index
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
        
        # 加载Neo4j图谱索引
        try:
            print("\n【Neo4j】正在连接Neo4j图谱数据库...")
            print(f"【Neo4j】连接信息: URI={NEO4J_URI}, USER={NEO4J_USER}")
            # 创建Neo4j图谱存储
            graph_store = None
            try:
                # 尝试连接Neo4j
                print("【Neo4j】尝试创建Neo4jGraphStore...")
                graph_store = Neo4jGraphStore(
                    username=NEO4J_USER,
                    password=NEO4J_PASSWORD,
                    url=NEO4J_URI
                )
                print("【Neo4j】Neo4jGraphStore创建成功")
                
                # 测试连接
                try:
                    # 使用简单查询测试Neo4j连接
                    print("【Neo4j】测试数据库连接...")
                    from neo4j import GraphDatabase
                    driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
                    with driver.session() as session:
                        print("【Neo4j】执行测试查询: RETURN 1 as test")
                        result = session.run("RETURN 1 as test")
                        test_value = result.single()
                        print(f"【Neo4j】测试查询结果: {test_value}")
                    driver.close()
                    print("【Neo4j】连接测试成功 ✓")
                except Exception as e:
                    print(f"【Neo4j错误】连接测试失败: {e}")
                    raise
            
                # 创建图谱索引
                print("【Neo4j】创建KnowledgeGraphIndex...")
                kg_index = KnowledgeGraphIndex.from_documents(
                    [],  # 不需要文档，数据已在Neo4j中
                    graph_store=graph_store,
                    include_embeddings=True,
                    max_triplets_per_chunk=10,
                )
                print("【Neo4j】Neo4j图谱索引加载成功! ✓")
                
                # 测试图谱查询
                try:
                    print("【Neo4j】测试图谱查询...")
                    test_retriever = kg_index.as_retriever(include_text=True)
                    print("【Neo4j】图谱检索器创建成功")
                    print("【Neo4j】图谱功能已完全准备就绪 ✓")
                except Exception as query_error:
                    print(f"【Neo4j警告】图谱检索器创建失败，但索引已加载: {query_error}")
            except Exception as e:
                print(f"使用Neo4j图谱存储创建索引失败: {e}")
                print("尝试不使用APOC创建图谱索引...")
                
                # 尝试不使用APOC创建图谱索引
                try:
                    from llama_index.core.graph_stores import SimpleGraphStore
                    
                    # 使用简单图谱存储作为回退
                    simple_graph_store = SimpleGraphStore()
                    kg_index = KnowledgeGraphIndex.from_documents(
                        [],
                        graph_store=simple_graph_store,
                        include_embeddings=True,
                    )
                    print("使用SimpleGraphStore创建图谱索引成功！")
                except Exception as simple_e:
                    print(f"使用SimpleGraphStore创建图谱索引也失败: {simple_e}")
                    kg_index = None
        except Exception as e:
            print(f"加载Neo4j图谱索引失败: {e}")
            kg_index = None
    except Exception as e:
        print(f"加载索引时发生错误: {e}")
        index = None

# 修改聊天请求模型，支持引用对象
class ChatReference(BaseModel):
    id: str  # 引用ID
    title: str  # 引用标题/名称
    type: str  # 引用类型: note, tag, location
    content: Optional[str] = None  # 引用内容 

# 修改ChatRequest模型，增加chat_id字段
class ChatRequest(BaseModel):
    query: str
    references: List[ChatReference] = []
    use_rerank: bool = True       # 是否在检索后使用重排序
    rerank_language: str = "auto"  # 重排序语言: auto, english, multilingual
    use_graph: bool = None        # 是否使用图检索，None表示自动决定
    
    # 使用Field指定别名，将前端的chatId映射到后端的chat_id
    chat_id: str = Field(default="", alias="chatId")  # 聊天ID，用于记忆功能
    
    # 添加模型字段，用于指定使用的模型
    model: Optional[str] = None
    
    class Config:
        populate_by_name = True  # 允许通过别名填充字段

# --- API 端点 ---
# 添加几个记忆管理的API端点
@app.post("/api/memory/save")
async def save_memory(chat_id: str, messages: List[Dict[str, Any]]):
    """保存对话记忆"""
    if not memory_manager:
        raise HTTPException(status_code=503, detail="记忆管理服务不可用")
    
    success = memory_manager.save_memory(chat_id, messages)
    if success:
        return {"status": "success", "message": f"成功保存对话 {chat_id} 的记忆"}
    else:
        raise HTTPException(status_code=500, detail="保存记忆失败")

@app.get("/api/memory/{chat_id}")
async def get_memory(chat_id: str):
    """获取对话记忆"""
    if not memory_manager:
        raise HTTPException(status_code=503, detail="记忆管理服务不可用")
    
    memory_content = memory_manager.get_memory_content(chat_id)
    return memory_content

@app.delete("/api/memory/{chat_id}")
async def delete_memory(chat_id: str):
    """删除对话记忆"""
    if not memory_manager:
        raise HTTPException(status_code=503, detail="记忆管理服务不可用")
    
    success = memory_manager.delete_memory(chat_id)
    if success:
        return {"status": "success", "message": f"成功删除对话 {chat_id} 的记忆"}
    else:
        raise HTTPException(status_code=500, detail="删除记忆失败")

@app.get("/api/memories")
async def list_memories():
    """列出所有记忆的对话ID"""
    if not memory_manager:
        raise HTTPException(status_code=503, detail="记忆管理服务不可用")
    
    memories = memory_manager.list_memories()
    return {"memories": memories}

# 修改聊天API，支持记忆功能
@app.post("/api/chat")
async def handle_chat_request(request: ChatRequest):
    """
    处理聊天请求，使用混合搜索模式并支持重排序、图检索和记忆功能:
    - references: 引用列表，包含笔记、标签和地点的引用
    - use_rerank: 是否对检索结果进行重排序
    - rerank_language: 重排序语言: auto, english, multilingual
    - use_graph: 是否使用图检索，可选true, false, null(自动决定)
    - chat_id: 聊天ID，用于记忆功能
    - model: 指定使用的模型名称
    """
    # 添加详细的请求调试信息
    print(f"\n【请求调试】原始请求数据: {request}")
    print(f"【请求调试】chat_id值: '{request.chat_id}'")
    print(f"【请求调试】请求模型字段: {request.__fields__.keys()}")
    
    # 检测模型切换测试请求
    is_model_switch_test = False
    if request.query.startswith("模型切换测试") or request.query == "模型切换测试 - 请忽略":
        is_model_switch_test = True
        print(f"【检测】这是模型切换测试请求")
    
    # 处理客户端指定的模型参数
    requested_model = getattr(request, "model", None)
    if requested_model and requested_model in GEMINI_MODELS:
        print(f"【模型】客户端请求使用模型: {requested_model}")
    else:
        requested_model = GEMINI_MODELS[0]  # 使用默认模型
        print(f"【模型】未指定有效模型，使用默认模型: {requested_model}")
    
    # 记录使用的当前模型
    current_model = getattr(Settings.llm, "model", GEMINI_MODELS[0])
    used_model = current_model
    
    if requested_model != current_model:
        print(f"\n{'='*50}")
        print(f"【模型切换】从 {current_model} 切换到 {requested_model}")
        print(f"{'='*50}\n")
        try:
            # 临时切换LLM模型
            original_llm = Settings.llm
            Settings.llm = GoogleGenAI(
                model=requested_model,
                api_key=api_key,
                temperature=0.7,
                retry_on_failure=True
            )
            used_model = requested_model
            print(f"【模型切换】成功切换到 {requested_model} ✓")
        except Exception as e:
            print(f"【模型切换】切换到 {requested_model} 失败: {e}")
            print(f"【模型切换】继续使用当前模型: {current_model}")
    else:
        print(f"【模型】当前使用: {current_model}")
    
    # 如果是模型切换测试请求，直接返回结果
    if is_model_switch_test:
        print(f"\n{'='*50}")
        print(f"【模型切换测试】完成模型切换，当前使用: {used_model}")
        print(f"{'='*50}\n")
        return {
            "response": f"模型已切换为: {used_model}",
            "model": used_model
        }
    
    if index is None:
        raise HTTPException(status_code=503, detail="服务不可用：索引未初始化。")
    if not request.query:
        raise HTTPException(status_code=400, detail="查询不能为空。")

    print(f"\n{'='*50}\n收到原始查询: {request.query}")
    print(f"聊天ID: {request.chat_id}")
    
    # 加载记忆（如果有chat_id）
    memory = None
    if memory_manager and request.chat_id:
        memory = memory_manager.load_memory(request.chat_id)
        if memory:
            print(f"成功加载对话 {request.chat_id} 的记忆")
    
    # ======= 查询重写阶段 =======
    # 如果有chat_id和记忆管理器，执行查询重写以解决代词指代问题
    original_query = request.query
    rewritten_query = original_query
    
    if memory_manager and request.chat_id:
        try:
            # 使用查询重写方法获取明确的查询
            rewritten_query = memory_manager.rewrite_query(request.chat_id, original_query)
            if rewritten_query != original_query:
                print(f"【查询重写】原始查询: '{original_query}' -> 重写后: '{rewritten_query}'")
        except Exception as e:
            print(f"【查询重写】失败: {e}，将使用原始查询继续")
    
    # 处理引用内容
    user_specified_context = ""
    
    # 2. 从查询中提取实体 (添加错误处理和重试)
    try:
        # 使用重写后的查询进行实体提取
        entities = extract_entities_from_query(rewritten_query, llm=Settings.llm)
        print(f"从查询中提取到的实体: {entities}")
    except Exception as e:
        print(f"实体提取失败: {e}")
        # 如果提取实体失败，使用空实体字典继续
        entities = {}
    
    # 处理引用对象，将标签和地点直接添加到实体中，笔记添加到上下文
    if request.references:
        for ref in request.references:
            ref_type = ref.type.lower()
            
            if ref_type == "note":
                # 笔记内容仍然添加到上下文
                if ref.content:
                    content = convert_delta_to_plain_text(ref.content)
                    user_specified_context += f"【笔记: {ref.title}】\n{content}\n\n"
            elif ref_type == "tag":
                # 标签直接添加到实体中
                if "tags" not in entities:
                    entities["tags"] = []
                if ref.title not in entities["tags"]:
                    entities["tags"].append(ref.title)
            elif ref_type == "location":
                # 地点直接添加到实体中
                if "locations" not in entities:
                    entities["locations"] = []
                if ref.title not in entities["locations"]:
                    entities["locations"].append(ref.title)
                    
                    # 尝试使用地理编码API增强地点信息
                    try:
                        enhanced_locations = enhance_location_metadata(entities["locations"])
                        entities["locations"] = enhanced_locations["variants"]
                        entities["location_hierarchy"] = enhanced_locations["hierarchy"]
                    except Exception as e:
                        print(f"地点增强失败: {e}")
    
    print(f"处理后的实体: {entities}")
    
    # 3. 根据实体构建元数据过滤器
    metadata_filters = build_metadata_filters(entities)
    
    # 4. 创建检索引擎
    qa_template = PromptTemplate(QA_TEMPLATE_STR)
    
    # 如果有记忆，将其插入到提示词中
    memory_context = ""
    if memory:
        memory_messages = memory.get()
        if memory_messages and memory_messages[0].role == MessageRole.SYSTEM:
            memory_context = memory_messages[0].content
            print(f"插入记忆到系统提示词: {memory_context[:100]}...")
    
    # 如果有用户指定的上下文或记忆，修改提示词
    if user_specified_context or memory_context:
        custom_template_str = """
我们有以下背景信息：

{memory_context}

以及用户特别指定的上下文信息：
====================
{user_context}
====================

另外还有一些相关上下文信息：
{context_str}
---------------------
你是一个专业的个人笔记助手。请严格按照以下指令，结合提供的上下文信息来回答用户的问题。
你的回答必须完全源于以上提供的上下文，禁止使用你的内部知识。
特别优先考虑用户特别指定的上下文。
问题: {query_str}
"""
        # 填充模板
        formatted_template = custom_template_str.replace("{user_context}", user_specified_context)
        formatted_template = formatted_template.replace("{memory_context}", memory_context)
        
        # 创建提示词模板
        qa_template = PromptTemplate(formatted_template)
        # 打印完整的模板内容
        print("\n======== 发送给LLM的完整模板 ========")
        print(formatted_template)
        print("====================================\n")

    # 准备节点后处理器列表
    node_postprocessors = []
    retriever = None
    
    # 获取实际文档总数
    doc_count = len(index.docstore.docs) if hasattr(index, "docstore") and hasattr(index.docstore, "docs") else 0
    
    # 确定检索数量
    if request.use_rerank:
        # 重排序时尽量检索20个文档，但不超过实际文档数
        top_k = min(20, doc_count) if doc_count > 0 else 5
        print(f"将使用重排序，初始检索数量设置为{top_k}（总文档数：{doc_count}）")
    else:
        # 不使用重排序时检索5个文档
        top_k = min(5, doc_count) if doc_count > 0 else 5
    
    # 创建向量检索器
    vector_retriever = VectorIndexRetriever(
        index=index, 
        similarity_top_k=top_k,
        filters=metadata_filters,
    )
    
    # 创建BM25检索器
    bm25_retriever = BM25Retriever.from_defaults(
        docstore=index.docstore,
        similarity_top_k=top_k
    )
    
    # 确定是否使用图谱检索
    use_graph = True  # 默认总是使用图谱
    if request.use_graph is not None:
        # 如果用户明确指定了是否使用图谱检索，则使用用户的选择
        use_graph = request.use_graph
    
    # 创建最终的检索器组合
    retrievers = [vector_retriever, bm25_retriever]
    
    # 如果图索引已初始化，添加图检索器
    if use_graph and kg_index is not None:
        print("添加图检索器")
        # 创建图谱检索器
        try:
            print(f"【Neo4j】正在创建图谱检索器，连接到 {NEO4J_URI}")
            graph_retriever = kg_index.as_retriever(
                include_text=True,
                similarity_top_k=top_k,
            )
            print(f"【Neo4j】图谱检索器创建成功!")
            # 将图检索器添加到检索器列表
            retrievers.append(graph_retriever)
        except Exception as e:
            print(f"【Neo4j错误】创建图谱检索器失败: {e}")
    elif use_graph and kg_index is None:
        print(f"【Neo4j警告】图谱索引未初始化，无法使用图谱检索")
    
    # 创建融合检索器
    print(f"【检索】创建融合检索器，包含 {len(retrievers)} 个检索器")
    retriever = QueryFusionRetriever(
        retrievers=retrievers,
        similarity_top_k=top_k,
        num_queries=1,
    )
    
    # 如果启用了重排序，添加重排序处理器
    if request.use_rerank and cohere_api_key:
        # 根据语言选择适当的模型
        model = "rerank-english-v3.0"  # 默认英文模型
        
        # 多语言模型处理
        if request.rerank_language == "multilingual":
            model = "rerank-multilingual-v3.0"  # 多语言模型
            print(f"使用Cohere多语言重排序器 (模型: {model})")
        elif request.rerank_language == "english":
            print(f"使用Cohere英文重排序器 (模型: {model})")
        else:  # auto
            # 自动检测查询语言
            has_chinese = any('\u4e00' <= char <= '\u9fff' for char in request.query)
            if has_chinese:
                # 对于中文查询使用多语言模型
                model = "rerank-multilingual-v3.0"
                print(f"检测到中文查询，使用Cohere多语言重排序器 (模型: {model})")
            else:
                print(f"使用Cohere英文重排序器 (模型: {model})")
                
        # 创建Cohere重排序器
        reranker = CohereRerank(
            api_key=cohere_api_key,
            model=model,
            top_n=5  # 重排序后保留的文档数量
        )
        node_postprocessors.append(reranker)
    elif request.use_rerank and not cohere_api_key:
        print("警告：Cohere API密钥未设置，跳过重排序")
    
    # 创建查询引擎，加入后处理器
    query_engine = RetrieverQueryEngine.from_args(
        retriever=retriever,
        text_qa_template=qa_template,
        node_postprocessors=node_postprocessors,
        llm=Settings.llm,
        streaming=False  # 明确指定不使用流式响应
    )

    # 4. 使用查询引擎进行查询
    # 使用重写后的查询进行搜索，但仍保留原始查询文本供LLM了解用户真实问题
    clean_query = re.sub(r'[@#]([\w\u4e00-\u9fa5]+)', '', rewritten_query).strip()
    if not clean_query:  # 如果清理后问题为空，就用重写后的原始问题
        clean_query = rewritten_query

    print(f"发送给AI的清理后查询: {clean_query}")
    
    try:
        # 添加异常处理，确保任何查询错误都能被正确处理
        print(f"\n【执行查询】开始执行查询...")
        start_time = time.time()
        
        # 添加重试逻辑
        retry_count = 0
        max_retries = 3
        
        while retry_count <= max_retries:
            try:
                response = query_engine.query(clean_query)
                query_time = time.time() - start_time
                print(f"【执行查询】查询完成，耗时: {query_time:.2f}秒")
                break  # 成功获取响应，退出循环
            except Exception as e:
                error_msg = str(e).lower()
                retry_count += 1
                
                # 检查是否是Google API过载错误
                if "model is overloaded" in error_msg and retry_count <= max_retries:
                    wait_time = 2 ** retry_count  # 指数退避: 2, 4, 8秒
                    print(f"【API过载】Google API暂时过载，等待{wait_time}秒后重试 ({retry_count}/{max_retries})...")
                    time.sleep(wait_time)
                    continue
                    
                # 如果是最后一次重试仍失败，或者是其他类型的错误，则抛出异常
                if retry_count > max_retries or "model is overloaded" not in error_msg:
                    raise
        
        # 如果所有重试都失败，就报错
        if retry_count > max_retries:
            raise Exception("尝试多次后仍无法获取响应，Google API可能持续过载")
        
        # 获取并打印实际发送给LLM的完整提示词
        try:
            if hasattr(response, '_source_nodes') and hasattr(response, '_template'):
                print("\n======== LLM收到的实际提示词(含上下文) ========")
                # 提取所有节点内容
                contexts = [node.get_content() for node in response._source_nodes]
                context_str = "\n---\n".join(contexts)
                
                # 替换模板中的占位符
                actual_prompt = response._template.format(
                    context_str=context_str,
                    query_str=clean_query
                )
                print(actual_prompt)
                print("=================================================\n")
        except Exception as e:
            print(f"无法打印完整提示词: {e}")
        
        # 打印检索到的上下文
        print(f"\n--- 检索到的上下文 ({len(response.source_nodes)} 条) ---")
        if not response.source_nodes:
            print("【警告】未能检索到任何相关上下文。")
        else:
            # 统计不同检索器的结果
            retriever_stats = {}
            for i, node in enumerate(response.source_nodes):
                source_type = node.metadata.get("_node_type", "unknown")
                if source_type not in retriever_stats:
                    retriever_stats[source_type] = 0
                retriever_stats[source_type] += 1
                
                print(f"【上下文 {i+1}】 (相似度: {node.score:.4f}, 来源: {source_type})")
                print(f"来源笔记ID: {node.metadata.get('note_id', 'N/A')}, 标题: {node.metadata.get('title', 'N/A')}")
                
                # 检查是否来自图谱
                if "kg" in source_type.lower() or "graph" in source_type.lower():
                    print(f"【Neo4j】此结果来自图谱检索 ✓")
                    
                print(f"元数据: {node.metadata}")  # 打印所有元数据以供调试
                print(f"内容片段:\n---\n{node.get_content()}\n---")
            
            # 打印检索统计信息
            print("\n【检索统计】")
            for source_type, count in retriever_stats.items():
                print(f"- {source_type}: {count}条结果")
        print(f"{'='*50}\n")
        
        # 获取响应文本
        full_response_text = response.response
        print(f"生成的回答: {full_response_text}")
        
        # 打印使用的模型信息
        print(f"\n{'='*50}")
        print(f"【响应完成】使用模型: {used_model}")
        print(f"{'='*50}\n")
        
        # 7. 保存记忆（如果启用）
        if memory_manager and request.chat_id and request.chat_id.strip():
            try:
                # 处理记忆保存
                ai_message = ChatMessage(content=full_response_text, role=MessageRole.ASSISTANT)
                human_message = ChatMessage(content=request.query, role=MessageRole.USER)
                
                # 如果memory为None（可能是因为之前没有记忆），则创建一个新的memory对象
                if memory is None:
                    print(f"为chat_id {request.chat_id}创建新的记忆实例")
                    memory = memory_manager.create_memory_instance(request.chat_id)
                
                # 逆序添加消息，确保最新的在前面
                memory.put(ai_message)
                memory.put(human_message)
                
                # 保存更新后的记忆
                messages_to_save = memory.get_all()
                result = memory_manager.save_memory(request.chat_id, messages_to_save)
                print(f"记忆保存结果: {'成功' if result else '失败'}")
            except Exception as memory_error:
                print(f"保存记忆时出错: {memory_error}")
                import traceback
                print(f"详细错误: {traceback.format_exc()}")

        # 返回格式化的响应对象
        return {
            "response": full_response_text, 
            "model": used_model  # 添加使用的模型信息
        }
        
    except ValueError as e:
        # 捕获值错误，如文档数量不足的错误
        print(f"查询引擎错误: {str(e)}")
        error_message = "抱歉，处理您的查询时出现了技术问题。"
        if "larger than the number of available scores" in str(e):
            error_message = "抱歉，数据库中的文档数量不足以执行当前的检索操作。请稍后再试或使用标准向量搜索模式。"
        return {"response": error_message, "error": str(e)}
    except Exception as e:
        # 捕获所有其他异常
        error_str = str(e)
        print(f"未预期的错误: {error_str}")
        
        # 处理Google API过载错误
        if "model is overloaded" in error_str.lower():
            print("Google API过载，尝试切换到备用Gemini模型...")
            
            # 尝试使用不同的Gemini模型
            current_model = getattr(Settings.llm, "model", GEMINI_MODELS[0])
            
            # 找到当前模型在列表中的位置
            try:
                current_index = GEMINI_MODELS.index(current_model)
            except ValueError:
                current_index = -1  # 如果当前模型不在列表中
            
            # 尝试列表中的下一个模型
            for i in range(current_index + 1, len(GEMINI_MODELS)):
                fallback_model = GEMINI_MODELS[i]
                try:
                    print(f"尝试切换到备用模型: {fallback_model}")
                    # 临时切换LLM模型
                    original_llm = Settings.llm
                    Settings.llm = GoogleGenAI(
                        model=fallback_model,
                        api_key=api_key,
                        temperature=0.7
                    )
                    
                    # 创建新的查询引擎
                    fallback_query_engine = RetrieverQueryEngine.from_args(
                        retriever=retriever,
                        text_qa_template=qa_template,
                        node_postprocessors=node_postprocessors,
                        llm=Settings.llm,
                        streaming=False
                    )
                    
                    # 尝试使用备用模型进行查询
                    print(f"使用{fallback_model}模型重试查询...")
                    response = fallback_query_engine.query(clean_query)
                    print(f"成功使用{fallback_model}模型回退")
                    
                    # 恢复原始LLM
                    Settings.llm = original_llm
                    
                    return {"response": str(response.response), "note": f"使用了备用模型{fallback_model}进行回答"}
                except Exception as fallback_error:
                    print(f"{fallback_model}模型回退也失败: {str(fallback_error)}")
                    # 恢复原始LLM
                    Settings.llm = original_llm
                    continue
            
            return {"response": "抱歉，AI服务器目前负载较高，请稍后再试。", "error": error_str}
        
        # 处理Cohere API特定错误
        if "model " in error_str and "not found" in error_str or "cohere" in error_str.lower():
            # Cohere模型相关错误，回退到不使用重排序
            print("Cohere API错误，回退到不使用重排序")
            # 创建不使用重排序的查询引擎
            fallback_query_engine = RetrieverQueryEngine.from_args(
                retriever=retriever,
                text_qa_template=qa_template,
                node_postprocessors=[], # 不使用后处理器
                llm=Settings.llm,
                streaming=False
            )
            try:
                # 尝试使用回退查询引擎
                response = fallback_query_engine.query(clean_query)
                print("成功使用回退查询引擎（无重排序）")
                return {"response": str(response.response)}
            except Exception as fallback_error:
                print(f"回退查询也失败: {str(fallback_error)}")
        
        return {"response": f"抱歉，处理您的查询时出现了问题。请稍后再试。", "error": error_str}

@app.get("/")
def health_check():
    return {"status": "ok", "message": "AI 聊天服务正在运行。"}

@app.get("/api/graph/stats")
async def get_graph_stats():
    """获取图谱统计信息"""
    try:
        graph_builder = PropertyGraphBuilder()
        if not graph_builder.connected:
            return {"error": "无法连接到图数据库"}
        
        node_counts = graph_builder.get_node_count()
        relation_counts = graph_builder.get_relation_count()
        graph_builder.close()
        
        return {
            "node_counts": node_counts,
            "relation_counts": relation_counts,
            "total_nodes": sum(node_counts.values()) if node_counts else 0,
            "total_relations": sum(relation_counts.values()) if relation_counts else 0
        }
    except Exception as e:
        return {"error": str(e)}

@app.get("/api/graph/status")
async def get_graph_status():
    """获取Neo4j连接状态和详细信息"""
    try:
        print("\n【Neo4j】正在检查Neo4j连接状态...")
        result = {
            "connected": False,
            "uri": NEO4J_URI,
            "user": NEO4J_USER,
            "kg_index_loaded": kg_index is not None,
            "details": {},
            "error": None
        }
        
        # 测试直接连接
        try:
            from neo4j import GraphDatabase
            print(f"【Neo4j】尝试直接连接到 {NEO4J_URI}...")
            driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
            with driver.session() as session:
                # 测试基本连接
                print("【Neo4j】执行基本测试查询...")
                test_result = session.run("RETURN 1 as test").single()
                result["connected"] = True
                result["details"]["basic_connection"] = "成功"
                
                # 测试APOC
                print("【Neo4j】测试APOC插件...")
                try:
                    apoc_result = session.run("CALL apoc.help('meta')").values()
                    result["details"]["apoc_plugin"] = "已安装"
                except Exception as apoc_error:
                    result["details"]["apoc_plugin"] = f"未安装或无法访问: {str(apoc_error)}"
                
                # 获取数据库版本
                try:
                    version_result = session.run("CALL dbms.components() YIELD name, versions RETURN name, versions").single()
                    if version_result:
                        result["details"]["version"] = f"{version_result['name']} {version_result['versions'][0]}"
                except:
                    result["details"]["version"] = "无法获取"
                
                # 获取节点和关系统计
                graph_builder = PropertyGraphBuilder()
                if graph_builder.connected:
                    result["details"]["node_counts"] = graph_builder.get_node_count()
                    result["details"]["relation_counts"] = graph_builder.get_relation_count()
                    graph_builder.close()
            
            driver.close()
            print("【Neo4j】连接测试完成 ✓")
            
        except Exception as e:
            result["error"] = str(e)
            print(f"【Neo4j错误】连接测试失败: {e}")
        
        return result
    except Exception as e:
        return {"connected": False, "error": str(e)}