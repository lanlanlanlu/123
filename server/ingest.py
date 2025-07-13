import os
from dotenv import load_dotenv
from llama_index.core import (
    VectorStoreIndex,
    SimpleDirectoryReader,
    StorageContext,
    Settings,
)
# 修正: 从 gemini 导入
from llama_index.embeddings.gemini import GeminiEmbedding
from llama_index.llms.gemini import Gemini

# --- 配置 ---
PERSIST_DIR = "./storage"

def configure_ai_settings():
    """加载环境变量并配置LlamaIndex的AI模型设置"""
    load_dotenv()
    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("GOOGLE_API_KEY 环境变量未设置！请检查你的 .env 文件。")
    
    # 修正: 使用 Gemini 类
    Settings.llm = Gemini(api_key=api_key, model_name="models/gemini-1.5-flash")
    # 修正: 使用 GeminiEmbedding 类
    Settings.embed_model = GeminiEmbedding(api_key=api_key, model_name="models/text-embedding-004")
    print("AI 设置配置完成。")

def main():
    """主函数，执行数据摄取和索引创建"""
    print("开始执行数据摄取流程...")
    
    configure_ai_settings()

    if not os.path.exists(PERSIST_DIR):
        print(f"'{PERSIST_DIR}' 目录不存在。开始从头创建索引。")
        
        print("正在从 './data' 目录加载文档...")
        documents = SimpleDirectoryReader("./data").load_data()
        
        if not documents:
            print("警告：在 './data' 目录中没有找到任何文档。")
            return

        print(f"成功加载 {len(documents)} 个文档。")
        
        print("正在创建向量索引...")
        index = VectorStoreIndex.from_documents(documents)
        
        print(f"正在将索引保存到 '{PERSIST_DIR}'...")
        index.storage_context.persist(persist_dir=PERSIST_DIR)
        print("索引创建并保存成功！")
    else:
        print(f"'{PERSIST_DIR}' 目录已存在，跳过索引创建。")
        print("如果需要重新生成索引，请先手动删除 'storage' 文件夹。")

if __name__ == "__main__":
    main()