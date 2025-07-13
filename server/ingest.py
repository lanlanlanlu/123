# server/ingest.py

import os
import sqlite3
import json
from dotenv import load_dotenv
from delta import Delta

from llama_index.core import (
    VectorStoreIndex,
    Document,
    StorageContext,
    Settings,
)
from llama_index.embeddings.gemini import GeminiEmbedding
from llama_index.llms.gemini import Gemini

# --- 配置 ---
PERSIST_DIR = "./storage"
DB_PATH = "D:\\am4yne\\Documents\\record.sqlite"

def convert_delta_to_plain_text(delta_json_string: str) -> str:
    if not delta_json_string or delta_json_string.strip() == '[]':
        return ""

    try:
        ops = json.loads(delta_json_string)
        delta = Delta(ops)
        text_parts = []
        
        for op in delta:
            if op.type == 'insert':
                # 如果值是字符串，就添加到我们的文本片段列表中
                if isinstance(op.value, str):
                    text_parts.append(op.value)
                # 注意：这里我们忽略了图片等非文本嵌入
                
        # 将所有文本片段合并成一个单一的字符串，并移除首尾的空白
        return "".join(text_parts).strip()

    except (json.JSONDecodeError, Exception) as e:
        print(f"解析 Quill Delta 时发生错误: {e}\n原始数据: {delta_json_string}")
        # 如果解析失败，返回空字符串，避免将错误的 JSON 喂给 AI
        return ""

def load_notes_from_db() -> list[Document]:
    """从 Drift (SQLite) 数据库加载笔记并转换为 LlamaIndex 文档"""
    if not DB_PATH or "在这里粘贴" in DB_PATH:
        raise ValueError("错误: DB_PATH 未设置！请在 ingest.py 文件中设置正确的数据库路径。")
        
    print(f"正在尝试连接数据库: {DB_PATH}")
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT id, title, content, created_at FROM notes WHERE is_deleted = 0")
        notes = cursor.fetchall()
        conn.close()
        
        print(f"成功从数据库查询到 {len(notes)} 条笔记。")
        
        documents = []
        for note in notes:
            note_id, title, quill_content, created_at = note
            
            # 使用我们新的、更强大的解析函数
            plain_text_content = convert_delta_to_plain_text(quill_content)
            
            # 只有当笔记有实际文本内容时，我们才创建文档
            if plain_text_content:
                text_for_embedding = f"笔记标题: {title}\n\n{plain_text_content}"
                
                doc = Document(
                    text=text_for_embedding,
                    metadata={
                        "note_id": note_id,
                        "creation_date": created_at,
                        "title": title,
                        "source": "database"
                    }
                )
                documents.append(doc)
            
        return documents

    except Exception as e:
        print(f"从数据库加载笔记时发生错误: {e}")
        return []

def configure_ai_settings():
    """加载环境变量并配置LlamaIndex的AI模型设置"""
    load_dotenv()
    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("GOOGLE_API_KEY 环境变量未设置！请检查你的 .env 文件。")
    
    Settings.llm = Gemini(api_key=api_key, model_name="models/gemini-1.5-flash")
    Settings.embed_model = GeminiEmbedding(api_key=api_key, model_name="models/text-embedding-004")
    print("AI 设置配置完成。")

def main():
    """主函数，执行数据摄取和索引创建"""
    print("开始执行数据摄取流程...")
    
    configure_ai_settings()

    if os.path.exists(PERSIST_DIR):
        print(f"'{PERSIST_DIR}' 目录已存在。将删除旧索引以反映最新的数据库内容。")
        import shutil
        shutil.rmtree(PERSIST_DIR)

    documents = load_notes_from_db()
    
    if not documents:
        print("未能从数据库加载任何可处理的文本笔记。程序终止。")
        return

    print("正在创建向量索引...")
    index = VectorStoreIndex.from_documents(documents)
    
    print(f"正在将索引保存到 '{PERSIST_DIR}'...")
    index.storage_context.persist(persist_dir=PERSIST_DIR)
    print("索引创建并保存成功！")

if __name__ == "__main__":
    main()