import os
import json
import logging
import time
from typing import List, Dict, Optional, Any, Union
from pathlib import Path

# 导入更多记忆类型
from llama_index.core.memory import (
    Memory, 
    ChatMemoryBuffer,
    ChatSummaryMemoryBuffer
)
from llama_index.core.llms import ChatMessage, MessageRole
from llama_index.core import Settings

# 设置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ChatMemoryManager:
    """管理每个对话的记忆功能，使用LlamaIndex的内置记忆管理"""
    
    def __init__(self, storage_dir: str = "./storage/memories"):
        """初始化聊天记忆管理器
        
        Args:
            storage_dir: 存储记忆文件的目录
        """
        self.storage_dir = storage_dir
        Path(storage_dir).mkdir(parents=True, exist_ok=True)
        logger.info(f"记忆管理器初始化完成，存储目录: {storage_dir}")
        
    def create_memory_instance(self, chat_id: str, token_limit: int = 4000) -> Memory:
        """为特定对话创建记忆实例
        
        Args:
            chat_id: 对话ID
            token_limit: 记忆的标记数限制
            
        Returns:
            Memory: 记忆实例
        """
        try:
            # 使用ChatSummaryMemoryBuffer - 会自动摘要长对话
            memory = ChatSummaryMemoryBuffer.from_defaults(
                token_limit=token_limit,
                llm=Settings.llm  # 使用全局设置的LLM创建摘要
                # 移除不支持的memory_key参数
            )
            logger.info(f"使用ChatSummaryMemoryBuffer创建记忆实例成功，chat_id: {chat_id}")
            return memory
        except Exception as e:
            logger.error(f"使用ChatSummaryMemoryBuffer创建记忆实例失败: {e}")
            logger.info("尝试使用基础记忆模式创建实例...")
            
            # 退回到基本的ChatMemoryBuffer
            try:
                memory = ChatMemoryBuffer.from_defaults(
                    token_limit=token_limit
                    # 移除不支持的memory_key参数
                )
                logger.info(f"使用ChatMemoryBuffer创建记忆实例成功，chat_id: {chat_id}")
                return memory
            except Exception as e2:
                logger.error(f"使用ChatMemoryBuffer创建记忆实例失败: {e2}")
                
                # 最后的回退方案：使用标准Memory
                memory = Memory.from_defaults(
                    session_id=chat_id,  # 这里保留session_id参数，因为标准Memory支持
                    token_limit=token_limit
                )
                logger.info(f"使用标准Memory创建记忆实例成功，chat_id: {chat_id}")
                return memory
    
    def save_memory(self, chat_id: str, messages: List[Union[Dict[str, Any], ChatMessage]]) -> bool:
        """保存对话记忆
        
        Args:
            chat_id: 对话ID
            messages: 消息列表，可以是Dict或ChatMessage对象
            
        Returns:
            bool: 是否成功保存
        """
        try:
            # 检查chat_id是否有效
            if not chat_id or not chat_id.strip():
                logger.error("保存记忆失败: chat_id为空")
                return False
                
            logger.info(f"开始保存记忆，chat_id: {chat_id}, 消息数: {len(messages)}")
            
            # 检查存储目录是否存在
            memory_dir = Path(self.storage_dir)
            if not memory_dir.exists():
                logger.info(f"存储目录不存在，正在创建: {memory_dir}")
                memory_dir.mkdir(parents=True, exist_ok=True)
            
            # 将消息转换为ChatMessage对象，处理不同的输入类型
            chat_messages = []
            for msg in messages:
                if isinstance(msg, ChatMessage):
                    # 如果已经是ChatMessage对象，直接使用
                    chat_messages.append(msg)
                else:
                    # 如果是字典格式，转换为ChatMessage对象
                    role = MessageRole.USER if msg.get("role") == "user" else MessageRole.ASSISTANT
                    content = msg.get("content", "")
                    chat_messages.append(ChatMessage(role=role, content=content))
            
            # 创建记忆实例
            memory = self.create_memory_instance(chat_id)
            
            # 将消息添加到记忆中
            for msg in chat_messages:
                memory.put(msg)
            
            # 保存记忆状态到文件
            memory_file = os.path.join(self.storage_dir, f"{chat_id}.json")
            
            # 获取记忆中的消息
            memory_messages = memory.get_all()
            
            # 准备要保存的数据
            memory_data = {
                "chat_id": chat_id,
                "messages": [{
                    "role": msg.role.value,  # 使用枚举的值
                    "content": msg.content
                } for msg in memory_messages],
                "last_updated": int(time.time())  # 使用导入的time模块
            }
            
            # 将数据转换为JSON字符串
            json_data = json.dumps(memory_data, ensure_ascii=False, indent=2)
            logger.info(f"JSON数据准备完成，大小: {len(json_data)} 字节")
            
            # 使用临时文件写入，然后重命名，避免写入中断导致文件损坏
            temp_file = f"{memory_file}.tmp"
            with open(temp_file, "w", encoding="utf-8") as f:
                f.write(json_data)
                f.flush()  # 确保数据写入磁盘
                os.fsync(f.fileno())  # 强制操作系统刷新文件系统缓冲区
            
            # 重命名临时文件为最终文件
            os.replace(temp_file, memory_file)
            
            # 验证文件是否成功创建
            if os.path.exists(memory_file):
                file_size = os.path.getsize(memory_file)
                logger.info(f"文件成功创建: {memory_file}, 大小: {file_size} 字节")
            else:
                logger.error(f"文件创建失败: {memory_file}")
                
            logger.info(f"成功保存对话 {chat_id} 的记忆，包含 {len(memory_messages)} 条消息")
            return True
        except Exception as e:
            logger.error(f"保存记忆失败: {e}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            return False
    
    def load_memory(self, chat_id: str) -> Optional[Memory]:
        """加载对话记忆
        
        Args:
            chat_id: 对话ID
            
        Returns:
            Optional[Memory]: 记忆实例，如果不存在则返回None
        """
        # 检查chat_id是否有效
        if not chat_id or not chat_id.strip():
            logger.error("加载记忆失败: chat_id为空")
            return None
            
        memory_file = os.path.join(self.storage_dir, f"{chat_id}.json")
        
        logger.info(f"尝试加载记忆，chat_id: {chat_id}, 文件路径: {memory_file}")
        
        if not os.path.exists(memory_file):
            logger.info(f"对话 {chat_id} 的记忆文件不存在: {memory_file}")
            return None
            
        try:
            # 加载记忆数据
            logger.info(f"开始读取记忆文件: {memory_file}")
            with open(memory_file, "r", encoding="utf-8") as f:
                memory_data = json.load(f)
            
            logger.info(f"成功读取记忆文件，内容大小: {len(str(memory_data))}字节")
            
            # 创建记忆实例
            memory = self.create_memory_instance(chat_id)
            
            # 加载消息
            messages = []
            for msg in memory_data.get("messages", []):
                # 转换角色字符串为MessageRole
                role_str = msg.get("role", "")
                if role_str.lower() == "user":
                    role = MessageRole.USER
                elif role_str.lower() == "assistant":
                    role = MessageRole.ASSISTANT
                elif role_str.lower() == "system":
                    role = MessageRole.SYSTEM
                else:
                    role = MessageRole.USER  # 默认为用户
                
                messages.append(ChatMessage(
                    role=role,
                    content=msg.get("content", "")
                ))
            
            # 将消息添加到记忆中
            msg_count = 0
            for msg in messages:
                memory.put(msg)
                msg_count += 1
            
            # 添加一个系统消息，明确总结之前的对话内容，使LLM能够正确理解上下文
            if msg_count > 0:
                self._add_context_summary(memory, messages)
                
            logger.info(f"成功加载对话 {chat_id} 的记忆，共 {msg_count} 条消息")
            return memory
        except Exception as e:
            logger.error(f"加载记忆失败: {e}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            return None
    
    def _add_context_summary(self, memory: Memory, messages: List[ChatMessage]) -> None:
        """添加上下文总结作为系统消息
        
        这个函数为Memory添加一个系统消息，明确总结之前的对话内容，
        使LLM能够更好地理解代词指代和上下文
        
        Args:
            memory: 记忆实例
            messages: 历史消息列表
        """
        try:
            # 只处理有实际对话的情况
            if len(messages) < 2:
                logger.info("消息太少，不需要添加上下文总结")
                return
            
            # 构建对话摘要
            context_pairs = []
            for i in range(0, len(messages) - 1, 2):
                if i + 1 < len(messages):
                    user_msg = messages[i].content if messages[i].role == MessageRole.USER else "?"
                    assistant_msg = messages[i+1].content if i+1 < len(messages) and messages[i+1].role == MessageRole.ASSISTANT else "?"
                    # 截断过长的消息内容
                    user_msg = user_msg[:100] + "..." if len(user_msg) > 100 else user_msg
                    assistant_msg = assistant_msg[:150] + "..." if len(assistant_msg) > 150 else assistant_msg
                    context_pairs.append(f"用户问：\"{user_msg}\"，您回答：\"{assistant_msg}\"")
            
            # 提取最近一次用户的问题中可能提及的实体和主题
            last_user_msg = next((msg.content for msg in reversed(messages) if msg.role == MessageRole.USER), "")
            
            # 构建系统消息
            system_message = f"""以下是之前的对话内容摘要，请在回答新问题时考虑这些上下文:
{chr(10).join(context_pairs)}

重要提示：用户在之前的对话中可能提到了特定的实体、人物或概念。
如果用户使用代词（如"它"、"他"、"这个"等），很可能是指代之前提到过的实体。
特别注意处理代词指代问题，确保理解用户真正询问的对象。

当前对话主题: {last_user_msg}
"""
            
            # 添加系统消息到记忆
            memory.put(ChatMessage(role=MessageRole.SYSTEM, content=system_message))
            logger.info("成功添加上下文总结到记忆")
            
        except Exception as e:
            logger.error(f"添加上下文总结失败: {e}")
    
    def get_memory_content(self, chat_id: str) -> Dict[str, Any]:
        """获取对话记忆内容
        
        Args:
            chat_id: 对话ID
            
        Returns:
            Dict[str, Any]: 记忆内容，包括消息
        """
        memory_file = os.path.join(self.storage_dir, f"{chat_id}.json")
        
        if not os.path.exists(memory_file):
            logger.info(f"对话 {chat_id} 的记忆不存在")
            return {"chat_id": chat_id, "messages": []}
            
        try:
            # 加载记忆数据
            with open(memory_file, "r", encoding="utf-8") as f:
                memory_data = json.load(f)
            
            return memory_data
        except Exception as e:
            logger.error(f"获取记忆内容失败: {e}")
            return {"chat_id": chat_id, "messages": []}
    
    def get_conversation_summary(self, chat_id: str) -> str:
        """获取对话的摘要
        
        Args:
            chat_id: 对话ID
            
        Returns:
            str: 对话摘要
        """
        memory_content = self.get_memory_content(chat_id)
        messages = memory_content.get("messages", [])
        
        if not messages:
            return "没有找到相关对话记录。"
        
        # 构建摘要
        summary_parts = []
        for i, msg in enumerate(messages):
            role = msg.get("role", "").lower()
            content = msg.get("content", "")
            
            if role == "user":
                prefix = "用户问："
            elif role == "assistant":
                prefix = "AI回答："
            else:
                prefix = "系统："
                
            # 截断过长的内容
            if len(content) > 100:
                content = content[:100] + "..."
                
            summary_parts.append(f"{prefix} {content}")
            
        return "\n".join(summary_parts)
    
    def rewrite_query(self, chat_id: str, query: str) -> str:
        """基于历史对话重写用户查询，以解决代词指代问题
        
        这是实现"查询重写式RAG"(Query-Rewriting RAG)的核心方法。
        它在检索前使用对话记忆和LLM将模糊的查询(如使用代词"它"的问题)
        重写为明确的、独立的问题，从而大大提高检索准确性。
        
        Args:
            chat_id: 对话ID
            query: 原始用户查询，可能含有代词指代
            
        Returns:
            str: 重写后的明确查询
        """
        # 如果查询本身已经很明确，不需要重写
        if len(query.strip()) > 30 and not any(word in query.lower() for word in ['它', '他', '她', '这个', '那个']):
            logger.info(f"查询已经足够明确，无需重写: {query}")
            return query
            
        try:
            # 获取对话记忆
            memory_content = self.get_memory_content(chat_id)
            messages = memory_content.get("messages", [])
            
            # 如果没有历史记录，无法重写查询
            if not messages or len(messages) < 2:
                logger.info("没有足够的对话历史来重写查询")
                return query
                
            # 构建对话历史上下文，选取最近的4轮对话(最多8条消息)
            recent_messages = messages[-8:]
            history_text = []
            
            for msg in recent_messages:
                role = "用户" if msg.get("role") == "user" else "助手"
                content = msg.get("content", "")
                history_text.append(f"{role}: {content}")
                
            history = "\n".join(history_text)
            
            # 构建查询重写提示词
            rewrite_prompt = f"""请根据以下对话历史，将用户最新的可能含有代词(如"它"、"他"、"这个"等)的问题重写为一个完整、明确、独立的问题。
这个重写后的问题应该是一个陌生人也能立即理解的清晰查询。

对话历史:
{history}

用户最新问题: {query}

重写后的完整明确问题(只输出重写后的问题,不要任何解释):"""
            
            # 调用LLM进行查询重写
            logger.info(f"开始重写查询: {query}")
            llm = Settings.llm
            
            if not llm:
                logger.error("无法获取LLM实例进行查询重写")
                return query
                
            response = llm.complete(rewrite_prompt)
            rewritten_query = response.text.strip()
            
            # 确保重写的查询有意义
            if len(rewritten_query) < 5 or rewritten_query == query:
                logger.info(f"重写结果无效或与原查询相同: {rewritten_query}")
                return query
                
            logger.info(f"查询重写成功。原始查询: '{query}' -> 重写后: '{rewritten_query}'")
            return rewritten_query
            
        except Exception as e:
            logger.error(f"查询重写失败: {e}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            return query  # 出错时返回原始查询
            
    def delete_memory(self, chat_id: str) -> bool:
        """删除对话记忆
        
        Args:
            chat_id: 对话ID
            
        Returns:
            bool: 是否成功删除
        """
        memory_file = os.path.join(self.storage_dir, f"{chat_id}.json")
        
        if not os.path.exists(memory_file):
            logger.info(f"对话 {chat_id} 的记忆不存在，无需删除")
            return True
            
        try:
            os.remove(memory_file)
            logger.info(f"成功删除对话 {chat_id} 的记忆")
            return True
        except Exception as e:
            logger.error(f"删除记忆失败: {e}")
            return False
    
    def list_memories(self) -> List[str]:
        """列出所有记忆的对话ID
        
        Returns:
            List[str]: 对话ID列表
        """
        try:
            memory_files = [f.stem for f in Path(self.storage_dir).glob("*.json")]
            return memory_files
        except Exception as e:
            logger.error(f"列出记忆失败: {e}")
            return [] 