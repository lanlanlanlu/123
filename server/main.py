# server/main.py

import os
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import re
import json
import time  # 添加time模块导入
from datetime import datetime  # 添加datetime导入
from typing import List, Dict, Any, Optional

# 导入工具类
from utils.date_utils import convert_timestamp_to_date_str
# 导入地理编码工具
from utils.geocoding import extract_locations_from_text, enhance_location_metadata, build_location_filters
# 导入图谱相关工具
from utils.entity_extractor import extract_entities_from_query
from utils.graph_builder import PropertyGraphBuilder

# 我们只从核心包导入
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
                    from llama_index.graph_stores.simple import SimpleGraphStore
                    
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

class ChatRequest(BaseModel):
    query: str
    use_rerank: bool = True       # 是否在检索后使用重排序
    rerank_language: str = "auto"  # 重排序语言: auto, english, multilingual
    use_graph: bool = None        # 是否使用图检索，None表示自动决定

# --- API 端点 ---
@app.post("/api/chat")
async def handle_chat_request(request: ChatRequest):
    """
    处理聊天请求，使用混合搜索模式并支持重排序和图检索:
    - use_rerank: 是否对检索结果进行重排序
    - rerank_language: 重排序使用的语言模型，可选 auto, english, multilingual
    - use_graph: 是否使用图检索，可选true, false, null(自动决定)
    """
    if index is None:
        raise HTTPException(status_code=503, detail="服务不可用：索引未初始化。")
    if not request.query:
        raise HTTPException(status_code=400, detail="查询不能为空。")

    print(f"\n{'='*50}\n收到原始查询: {request.query}")

    
    # 2. 从查询中提取实体
    entities = extract_entities_from_query(request.query, llm=Settings.llm)
    print(f"提取到的实体: {entities}")

    # 3. 根据实体构建元数据过滤器
    metadata_filters = build_metadata_filters(entities)
    
    # 4. 创建检索引擎
    qa_template = PromptTemplate(QA_TEMPLATE_STR)
    
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
    # 为了让AI更好地理解，我们可以把标签和地点从问题中移除
    clean_query = re.sub(r'[@#]([\w\u4e00-\u9fa5]+)', '', request.query).strip()
    if not clean_query:  # 如果清理后问题为空，就用原始问题
        clean_query = request.query

    print(f"发送给AI的清理后查询: {clean_query}")
    
    try:
        # 添加异常处理，确保任何查询错误都能被正确处理
        print(f"\n【执行查询】开始执行查询...")
        start_time = time.time()
        response = query_engine.query(clean_query)
        query_time = time.time() - start_time
        print(f"【执行查询】查询完成，耗时: {query_time:.2f}秒")
        
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
        return {"response": full_response_text}
        
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