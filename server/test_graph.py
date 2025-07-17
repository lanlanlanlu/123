#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
测试属性图谱功能
"""

import os
import sys
import json
from dotenv import load_dotenv

# 确保能够导入server目录中的模块
sys.path.append('.')

# 设置测试环境变量
os.environ["GOOGLE_API_KEY"] = "test_key"
os.environ["GOOGLE_MAPS_API_KEY"] = "test_key"
os.environ["NEO4J_URI"] = "bolt://localhost:7687"
os.environ["NEO4J_USER"] = "neo4j"
os.environ["NEO4J_PASSWORD"] = "password"

# 导入图谱构建器
from utils.graph_builder import PropertyGraphBuilder

def test_graph_connection():
    """测试连接到Neo4j图数据库"""
    print("\n===== 测试图谱数据库连接 =====")
    try:
        graph_builder = PropertyGraphBuilder()
        if graph_builder.connected:
            print("✓ 成功连接到Neo4j图数据库")
            
            # 获取节点和关系统计信息
            node_counts = graph_builder.get_node_count()
            relation_counts = graph_builder.get_relation_count()
            
            print(f"图谱统计信息:")
            print(f"  节点数量: {node_counts}")
            print(f"  关系数量: {relation_counts}")
            
            graph_builder.close()
            return True
        else:
            print("✗ 无法连接到Neo4j图数据库")
            return False
    except Exception as e:
        print(f"✗ 连接Neo4j时发生错误: {e}")
        return False

def test_add_node():
    """测试添加节点和关系"""
    print("\n===== 测试添加节点和关系 =====")
    try:
        graph_builder = PropertyGraphBuilder()
        if not graph_builder.connected:
            print("✗ 无法连接到Neo4j图数据库")
            return False
            
        # 创建测试笔记数据
        note_data = {
            "id": "test_note_001",
            "title": "测试笔记",
            "creation_date": "2023-06-01",
            "created_at": 1685577600  # 2023-06-01的Unix时间戳
        }
        
        # 创建测试实体数据
        entities = {
            "tags": ["测试", "图谱"],
            "locations": ["北京", "上海"],
            "location_hierarchy": ["中国", "北京市", "朝阳区"],
            "mentioned_dates": ["2023-05-01", "2023-06-15"],
            "people": ["张三", "李四"],
            "concepts": ["图数据库", "知识图谱"],
            "organizations": ["示例公司"],
            "relations": [
                {"head": "张三", "relation": "就职于", "tail": "示例公司"},
                {"head": "李四", "relation": "访问", "tail": "北京"}
            ]
        }
        
        # 添加到图谱
        success = graph_builder.add_note(note_data, entities)
        if success:
            print("✓ 成功添加测试笔记及相关实体到图谱")
            
            # 获取节点和关系统计信息
            node_counts = graph_builder.get_node_count()
            relation_counts = graph_builder.get_relation_count()
            
            print(f"添加后图谱统计信息:")
            print(f"  节点数量: {node_counts}")
            print(f"  关系数量: {relation_counts}")
            
            # 查询添加的笔记子图
            subgraph = graph_builder.get_note_subgraph("test_note_001")
            if subgraph:
                print(f"笔记子图:")
                print(f"  笔记ID: {subgraph.get('note_id')}")
                print(f"  笔记标题: {subgraph.get('note_title')}")
                print(f"  关联实体数量: {len(subgraph.get('entities', []))}")
            
            graph_builder.close()
            return True
        else:
            print("✗ 添加测试笔记失败")
            graph_builder.close()
            return False
    except Exception as e:
        print(f"✗ 测试添加节点时发生错误: {e}")
        return False

if __name__ == "__main__":
    print("开始测试属性图谱功能...")
    
    # 加载环境变量
    load_dotenv()
    
    # 测试图谱连接
    connection_success = test_graph_connection()
    
    # 如果连接成功，测试添加节点
    if connection_success:
        test_add_node() 