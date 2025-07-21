import os
import json
import logging
from typing import List, Dict, Optional, Any, Union
from pathlib import Path

from llama_index.core.memory import Memory
from llama_index.core.llms import ChatMessage, MessageRole
from llama_index.core import Settings

# 设置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ChatMemoryManager:
    """管理每个对话的记忆功能"""
    
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
        # 使用新版API创建记忆实例
        try:
            # 尝试使用新版API
            memory = Memory.from_defaults(
                session_id=chat_id,
                token_limit=token_limit,
                chat_history_token_ratio=0.7,
                token_flush_size=1000,
                insert_method="system"  # 将记忆插入系统消息
            )
            logger.info(f"使用新版API创建记忆实例成功，chat_id: {chat_id}")
            return memory
        except Exception as e:
            logger.error(f"使用新版API创建记忆实例失败: {e}")
            logger.info("尝试使用兼容模式创建记忆实例...")
            
            # 兼容模式：创建基本的Memory对象
            memory = Memory.from_defaults(
                session_id=chat_id,
                token_limit=token_limit,
                insert_method="system"
            )
            logger.info(f"使用兼容模式创建记忆实例成功，chat_id: {chat_id}")
            return memory
    
    def save_memory(self, chat_id: str, messages: List[Dict[str, Any]]) -> bool:
        """保存对话记忆
        
        Args:
            chat_id: 对话ID
            messages: 消息列表
            
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
            
            # 将消息转换为ChatMessage对象
            chat_messages = []
            # 提取所有提到的人名
            mentioned_people = set()
            
            for msg in messages:
                role = MessageRole.USER if msg.get("role") == "user" else MessageRole.ASSISTANT
                # 提取metadata中的人名
                if msg.get("metadata") and msg.get("metadata").get("mentioned_people"):
                    for person in msg.get("metadata").get("mentioned_people"):
                        mentioned_people.add(person)
                
                # 处理内容，提取可能的人名引用
                content = msg.get("content", "")
                
                chat_messages.append(ChatMessage(
                    role=role,
                    content=content
                ))
            
            # 创建记忆实例 - 注意：不再使用内部属性
            memory = self.create_memory_instance(chat_id)
            
            # 将消息添加到记忆中
            for msg in chat_messages:
                memory.put(msg)
            
            # 提取人名相关事实 - 直接创建事实列表，不依赖内部实现
            people_facts = []
            if mentioned_people:
                for person in mentioned_people:
                    people_facts.append(f"对话中提到了人物: {person}")
            
            # 保存记忆状态
            memory_file = os.path.join(self.storage_dir, f"{chat_id}.json")
            
            # 不再尝试访问内部_memory_blocks属性
            # 直接使用提取的事实
            all_facts = people_facts
            
            # 检查文件路径是否有效
            logger.info(f"准备保存记忆到文件: {memory_file}")
            
            # 检查目录权限
            try:
                # 确保目录存在且可写
                os.makedirs(os.path.dirname(memory_file), exist_ok=True)
                
                # 尝试创建一个临时文件测试写入权限
                test_file = os.path.join(os.path.dirname(memory_file), ".test_write")
                with open(test_file, "w") as f:
                    f.write("test")
                os.remove(test_file)
                logger.info(f"目录权限检查通过: {os.path.dirname(memory_file)}")
            except Exception as e:
                logger.error(f"目录权限检查失败: {e}")
                
            # 准备要保存的数据
            memory_data = {
                "chat_id": chat_id,
                "messages": [{
                    "role": msg.get("role"),
                    "content": msg.get("content"),
                    "metadata": msg.get("metadata", {})
                } for msg in messages],  # 保存原始消息，包括metadata
                "facts": all_facts,
                "mentioned_people": list(mentioned_people)  # 添加特别跟踪的人名列表
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
                
            logger.info(f"成功保存对话 {chat_id} 的记忆，包含 {len(messages)} 条消息, {len(all_facts)} 条事实")
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
            
            # 添加静态事实块 - 直接从文件中读取事实，而不是依赖内部结构
            facts_content = ""
            if "facts" in memory_data and memory_data["facts"]:
                facts_content += "\n".join([f"- {fact}" for fact in memory_data["facts"]])
                logger.info(f"加载了 {len(memory_data['facts'])} 条事实")
            
            # 特别处理人名记忆
            if "mentioned_people" in memory_data and memory_data["mentioned_people"]:
                if facts_content:
                    facts_content += "\n\n"
                facts_content += "重要人物:\n" + "\n".join([f"- {person}" for person in memory_data["mentioned_people"]])
                logger.info(f"加载了 {len(memory_data['mentioned_people'])} 个人物")
            
            # 如果有事实内容，使用系统消息添加到记忆中
            if facts_content:
                system_message = ChatMessage(
                    role=MessageRole.SYSTEM,
                    content=f"从之前的对话中提取的事实和信息:\n{facts_content}"
                )
                memory.put(system_message)
                logger.info(f"为对话 {chat_id} 添加了系统消息，包含事实和人物信息")
            
            # 加载消息
            messages = []
            for msg in memory_data.get("messages", []):
                role = MessageRole.USER if msg.get("role") == "user" else MessageRole.ASSISTANT
                messages.append(ChatMessage(
                    role=role,
                    content=msg.get("content", "")
                ))
            
            # 将消息添加到记忆中
            msg_count = 0
            for msg in messages:
                memory.put(msg)
                msg_count += 1
                
            logger.info(f"成功加载对话 {chat_id} 的记忆，共 {msg_count} 条消息")
            return memory
        except Exception as e:
            logger.error(f"加载记忆失败: {e}")
            import traceback
            logger.error(f"详细错误: {traceback.format_exc()}")
            return None
    
    def get_memory_content(self, chat_id: str) -> Dict[str, Any]:
        """获取对话记忆内容
        
        Args:
            chat_id: 对话ID
            
        Returns:
            Dict[str, Any]: 记忆内容，包括消息和提取的事实
        """
        memory_file = os.path.join(self.storage_dir, f"{chat_id}.json")
        
        if not os.path.exists(memory_file):
            logger.info(f"对话 {chat_id} 的记忆不存在")
            return {"chat_id": chat_id, "messages": [], "facts": []}
            
        try:
            # 加载记忆数据
            with open(memory_file, "r", encoding="utf-8") as f:
                memory_data = json.load(f)
            
            return memory_data
        except Exception as e:
            logger.error(f"获取记忆内容失败: {e}")
            return {"chat_id": chat_id, "messages": [], "facts": []}
            
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