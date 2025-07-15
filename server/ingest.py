# server/ingest.py

import os
import sqlite3
import json
from dotenv import load_dotenv
from datetime import datetime  # 添加 datetime 导入

# 导入工具类
from utils.date_utils import convert_timestamp_to_date_str

# 我们只从核心包导入，不再需要任何深层次的、容易变动的导入
from llama_index.core import (
    VectorStoreIndex,
    Document,
    StorageContext,
    Settings
)
from llama_index.core.node_parser import SentenceSplitter 

from llama_index.embeddings.google_genai import GoogleGenAIEmbedding
from llama_index.llms.google_genai import GoogleGenAI

import dateparser
import re

# --- 配置 ---
PERSIST_DIR = "./storage"
# 【保持不变】数据库路径
DB_PATH = "D:\\am4yne\\Documents\\record.sqlite" 

# --- 切分参数配置 ---
CHUNK_SIZE = 384
CHUNK_OVERLAP = 50

# --- 辅助函数 ---

# 删除之前的 convert_timestamp_to_date_str 函数，改为导入

def convert_delta_to_plain_text(delta_json_string: str) -> str:
    # 这个函数保持不变
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
    return "".join(text_parts).strip()

def extract_mentioned_dates(text: str) -> list[str]:
    """
    【新增】从文本中提取所有被提及的日期，并标准化格式。
    """
    # 使用正则表达式寻找可能的日期字符串，提高dateparser效率
    # 这个正则表达式可以根据你的笔记习惯进行调整
    date_patterns = re.findall(
        r'\d{4}[-年/\.]\d{1,2}[-月/\.]\d{1,2}日?|'  # 匹配 YYYY-MM-DD, YYYY年M月D日
        r'\d{1,2}月\d{1,2}日?|'                 # 匹配 M月D日
        r'昨天|今天|明天|后天|下周\w*|上周\w*', # 匹配相对日期
        text
    )
    
    standardized_dates = set()
    for date_str in date_patterns:
        # dateparser 会智能地将 "明天", "去年7月1日" 等转换为标准日期对象
        parsed_date = dateparser.parse(date_str, languages=['zh', 'en'])
        if parsed_date:
            standardized_dates.add(parsed_date.strftime('%Y-%m-%d'))
            
    return list(standardized_dates)


def process_concatenated_field(field_value: str | int | None) -> list[str]:
    """
    一个健壮的函数，专门用来处理 GROUP_CONCAT 返回的字段。
    无论输入是字符串、整数还是None，都能安全地返回一个字符串列表。
    """
    if field_value is None:
        return []
    
    value_str = str(field_value)
    
    if not value_str:
        return []
        
    return value_str.split(',')


def load_notes_from_db() -> list[Document]:
    """
    【重大改造】从数据库加载笔记，并通过JOIN一次性获取所有关联的标签和地点。
    """
    if not DB_PATH or "在这里粘贴" in DB_PATH:
        raise ValueError("错误: DB_PATH 未设置！")
    print(f"正在尝试连接数据库: {DB_PATH}")
    try:
        conn = sqlite3.connect(DB_PATH)
        # 使用字典作为行工厂，方便按列名取值
        conn.row_factory = sqlite3.Row 
        cursor = conn.cursor()

        # SQL查询，使用LEFT JOIN来连接notes, note_tags, tags, note_locations
        # 使用 GROUP_CONCAT 将多个标签和地点合并成一个字符串，方便处理
        query = """
        SELECT
            n.id,
            n.title,
            n.content,
            n.created_at,
            GROUP_CONCAT(DISTINCT t.name) as tags,
            GROUP_CONCAT(DISTINCT nl.location) as locations
        FROM
            notes n
        LEFT JOIN
            note_tags nt ON n.id = nt.note_id
        LEFT JOIN
            tags t ON nt.tag_id = t.id
        LEFT JOIN
            note_locations nl ON n.id = nl.note_id
        WHERE
            n.is_deleted = 0
        GROUP BY
            n.id
        """
        cursor.execute(query)
        notes_raw = cursor.fetchall()
        conn.close()
        
        print(f"成功从数据库查询到 {len(notes_raw)} 条笔记及其元数据。")
        documents = []
        for note_row in notes_raw:
            # 将数据库行转换为字典
            note_dict = dict(note_row)

            # **调用已定义的函数**
            tags_list = process_concatenated_field(note_dict['tags'])
            locations_list = process_concatenated_field(note_dict['locations'])
                    
            plain_text_content = convert_delta_to_plain_text(note_dict['content'])
            
            # 组合标题和内容，让AI知道它们的上下文关系
            text_for_embedding = f"笔记标题: {note_dict['title']}\n\n{plain_text_content}"
            # 3. 提取内容中提及的日期
            mentioned_dates_list = extract_mentioned_dates(plain_text_content)

            # 处理创建时间，正确转换 Unix 时间戳
            creation_date = convert_timestamp_to_date_str(note_dict['created_at'])

            doc = Document(
                text=text_for_embedding,
                metadata={
                    "note_id": str(note_dict['id']), # 确保为字符串
                    "title": note_dict['title'],
                    "creation_date": creation_date, # 使用新的转换函数处理时间戳
                    "tags": tags_list,
                    "locations": locations_list,
                    "mentioned_dates": mentioned_dates_list,
                }
            )
            documents.append(doc)
            
        print(f"成功将 {len(documents)} 条笔记转换为包含丰富元数据的可处理文档。")
        return documents
    except Exception as e:
        print(f"从数据库加载笔记时发生错误: {e}")
        return []

def configure_ai_settings():
    # 这个函数保持不变
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
    
    print("AI 设置配置完成。")

def main():
    # main 函数的其余部分保持不变
    print("开始执行数据摄取流程...")
    configure_ai_settings()

    if os.path.exists(PERSIST_DIR):
        print(f"'{PERSIST_DIR}' 目录已存在。将删除旧索引。")
        import shutil
        shutil.rmtree(PERSIST_DIR)

    documents = load_notes_from_db()
    if not documents:
        print("未能从数据库加载任何可处理的文本笔记。程序终止。")
        return

    node_parser = SentenceSplitter(chunk_size=CHUNK_SIZE, chunk_overlap=CHUNK_OVERLAP)
    
    print(f"开始使用 chunk_size={CHUNK_SIZE} 为 {len(documents)} 个文档创建向量索引...")

    nodes = node_parser.get_nodes_from_documents(documents)
    # 显式使用embed_model创建索引
    index = VectorStoreIndex(nodes, embed_model=Settings.embed_model)

    print(f"正在将索引保存到 '{PERSIST_DIR}'...")
    index.storage_context.persist(persist_dir=PERSIST_DIR)
    print("索引创建并保存成功！")

if __name__ == "__main__":
    main()