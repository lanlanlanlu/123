#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
属性图谱构建工具
用于从笔记内容构建Neo4j属性图谱
"""

import os
from dotenv import load_dotenv
from typing import Dict, List, Any, Optional
from neo4j import GraphDatabase
import json
import time

# 加载环境变量
load_dotenv()

# 获取Neo4j连接信息
NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "password")

class PropertyGraphBuilder:
    """Neo4j属性图谱构建器"""
    
    def __init__(self, uri=NEO4J_URI, user=NEO4J_USER, password=NEO4J_PASSWORD):
        """初始化图谱构建器"""
        self.uri = uri
        self.user = user
        self.password = password
        self.driver = None
        self.connected = False
        self.connect()
        
    def connect(self):
        """连接到Neo4j数据库，增加重试机制"""
        retry_count = 0
        max_retries = 3
        retry_delay = 2  # 秒
        
        while retry_count < max_retries:
            try:
                self.driver = GraphDatabase.driver(self.uri, auth=(self.user, self.password))
                # 测试连接
                with self.driver.session() as session:
                    # 使用简单查询测试连接
                    result = session.run("RETURN 1 as test")
                    result.single()
                    
                    # 测试APOC是否可用
                    try:
                        session.run("CALL apoc.help('meta')")
                        print("APOC插件已成功加载")
                    except Exception as apoc_error:
                        print(f"APOC插件可能未正确加载: {apoc_error}")
                        # 继续执行，不要因为APOC错误而中断连接
                        
                self.connected = True
                print(f"成功连接到Neo4j图数据库: {self.uri}")
                # 初始化图谱模式
                self.init_schema()
                return
            except Exception as e:
                retry_count += 1
                print(f"连接Neo4j失败 (尝试 {retry_count}/{max_retries}): {e}")
                if retry_count < max_retries:
                    print(f"等待 {retry_delay} 秒后重试...")
                    time.sleep(retry_delay)
                    retry_delay *= 2  # 指数退避
                else:
                    print(f"达到最大重试次数，无法连接Neo4j")
                    self.connected = False
            
    def close(self):
        """关闭数据库连接"""
        if self.driver:
            self.driver.close()
            
    def init_schema(self):
        """初始化图谱模式（创建约束和索引）"""
        if not self.connected:
            print("未连接到Neo4j，无法初始化模式")
            return
            
        try:
            with self.driver.session() as session:
                # 创建唯一约束
                session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (n:Note) REQUIRE n.id IS UNIQUE")
                session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (t:Tag) REQUIRE t.name IS UNIQUE")
                session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (l:Location) REQUIRE l.name IS UNIQUE")
                session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (d:Date) REQUIRE d.value IS UNIQUE")
                session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (c:Concept) REQUIRE c.name IS UNIQUE")
                session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (p:Person) REQUIRE p.name IS UNIQUE")
                session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (o:Organization) REQUIRE o.name IS UNIQUE")
                
                # 创建索引
                session.run("CREATE INDEX IF NOT EXISTS FOR (n:Note) ON (n.title)")
                session.run("CREATE INDEX IF NOT EXISTS FOR (n:Note) ON (n.created_at)")
                
                print("Neo4j图谱模式初始化完成")
        except Exception as e:
            print(f"初始化Neo4j模式失败: {e}")
    
    def clear_graph(self):
        """清空图数据库（危险操作！）"""
        if not self.connected:
            return
            
        try:
            with self.driver.session() as session:
                session.run("MATCH (n) DETACH DELETE n")
                print("图数据库已清空")
        except Exception as e:
            print(f"清空图数据库失败: {e}")
    
    def add_note(self, note_data: Dict[str, Any], entities: Dict[str, Any]) -> bool:
        """
        添加笔记节点及其关联的实体节点和关系
        
        参数:
            note_data: 笔记数据，包含id、title、created_at等字段
            entities: 实体数据，包含tags、locations、people、concepts、relations等字段
        
        返回:
            bool: 是否成功添加
        """
        if not self.connected:
            print("未连接到Neo4j，无法添加笔记")
            return False
            
        try:
            with self.driver.session() as session:
                # 1. 创建笔记节点
                session.run("""
                    MERGE (n:Note {id: $id})
                    ON CREATE SET 
                        n.title = $title, 
                        n.created_at = $created_at,
                        n.created_at_ts = $created_at_ts
                    ON MATCH SET 
                        n.title = $title
                """, {
                    "id": str(note_data.get("id", "")),
                    "title": note_data.get("title", ""),
                    "created_at": note_data.get("creation_date", ""),
                    "created_at_ts": note_data.get("created_at", 0)
                })
                
                note_id = str(note_data.get("id", ""))
                
                # 2. 处理标签
                for tag in entities.get("tags", []):
                    if tag and len(tag.strip()) > 0:
                        session.run("""
                            MERGE (t:Tag {name: $tag})
                            MERGE (n:Note {id: $note_id})
                            MERGE (n)-[r:HAS_TAG]->(t)
                        """, {"tag": tag.strip(), "note_id": note_id})
                
                # 3. 处理地点
                for location in entities.get("locations", []):
                    if location and len(location.strip()) > 0:
                        session.run("""
                            MERGE (l:Location {name: $location})
                            MERGE (n:Note {id: $note_id})
                            MERGE (n)-[r:MENTIONS_LOCATION]->(l)
                        """, {"location": location.strip(), "note_id": note_id})
                
                # 4. 处理地点层级关系
                location_hierarchy = entities.get("location_hierarchy", [])
                if len(location_hierarchy) >= 2:
                    for i in range(len(location_hierarchy) - 1):
                        parent = location_hierarchy[i].strip()
                        child = location_hierarchy[i+1].strip()
                        if parent and child:
                            session.run("""
                                MERGE (parent:Location {name: $parent})
                                MERGE (child:Location {name: $child})
                                MERGE (child)-[r:IS_PART_OF]->(parent)
                            """, {"parent": parent, "child": child})
                
                # 5. 处理日期
                for date in entities.get("mentioned_dates", []):
                    if date:
                        session.run("""
                            MERGE (d:Date {value: $date})
                            MERGE (n:Note {id: $note_id})
                            MERGE (n)-[r:MENTIONS_DATE]->(d)
                        """, {"date": date, "note_id": note_id})
                
                # 处理创建日期
                created_date = note_data.get("creation_date", "")
                if created_date:
                    # 只取日期部分
                    if " " in created_date:
                        created_date = created_date.split(" ")[0]
                    
                    session.run("""
                        MERGE (d:Date {value: $date})
                        MERGE (n:Note {id: $note_id})
                        MERGE (n)-[r:CREATED_ON]->(d)
                    """, {"date": created_date, "note_id": note_id})
                
                # 6. 处理人物
                for person in entities.get("people", []):
                    if person and len(person.strip()) > 0:
                        session.run("""
                            MERGE (p:Person {name: $person})
                            MERGE (n:Note {id: $note_id})
                            MERGE (n)-[r:MENTIONS_PERSON]->(p)
                        """, {"person": person.strip(), "note_id": note_id})
                
                # 7. 处理概念
                for concept in entities.get("concepts", []):
                    if concept and len(concept.strip()) > 0:
                        session.run("""
                            MERGE (c:Concept {name: $concept})
                            MERGE (n:Note {id: $note_id})
                            MERGE (n)-[r:MENTIONS_CONCEPT]->(c)
                        """, {"concept": concept.strip(), "note_id": note_id})
                
                # 8. 处理组织
                for org in entities.get("organizations", []):
                    if org and len(org.strip()) > 0:
                        session.run("""
                            MERGE (o:Organization {name: $org})
                            MERGE (n:Note {id: $note_id})
                            MERGE (n)-[r:MENTIONS_ORGANIZATION]->(o)
                        """, {"org": org.strip(), "note_id": note_id})
                
                # 9. 处理显式关系
                for relation in entities.get("relations", []):
                    head = relation.get("head", "").strip()
                    rel_type = relation.get("relation", "").strip()
                    tail = relation.get("tail", "").strip()
                    
                    if head and rel_type and tail:
                        # 创建自定义关系（使用标准Cypher而不是apoc）
                        # 清理关系类型，移除特殊字符，只保留字母、数字和下划线
                        rel_type_clean = ''.join(c for c in rel_type if c.isalnum() or c == '_')
                        # 确保不为空，否则使用默认关系类型
                        if not rel_type_clean.strip():
                            rel_type_clean = "RELATES_TO"
                        rel_type_upper = rel_type_clean.upper()
                        session.run(f"""
                            MATCH (a), (b)
                            WHERE a.name = $head AND b.name = $tail
                            CREATE (a)-[r:{rel_type_upper} {{noteId: $note_id}}]->(b)
                            RETURN r
                        """, {"head": head, "tail": tail, "note_id": note_id})
                
                return True
        except Exception as e:
            print(f"添加笔记到图数据库失败: {e}")
            return False
    
    def batch_add_notes(self, notes_data: List[Dict[str, Any]]) -> int:
        """
        批量添加笔记到图数据库
        
        参数:
            notes_data: 笔记数据列表
            
        返回:
            int: 成功添加的笔记数量
        """
        successful_adds = 0
        for note_data in notes_data:
            entities = {
                "tags": note_data.get("metadata", {}).get("tags", []),
                "locations": note_data.get("metadata", {}).get("locations", []),
                "location_hierarchy": note_data.get("metadata", {}).get("location_hierarchy", []),
                "mentioned_dates": note_data.get("metadata", {}).get("mentioned_dates", []),
                "people": note_data.get("metadata", {}).get("people", []),
                "concepts": note_data.get("metadata", {}).get("concepts", []),
                "organizations": note_data.get("metadata", {}).get("organizations", []),
                "relations": note_data.get("metadata", {}).get("relations", [])
            }
            
            # 提取ID和创建时间等基本信息
            note_info = {
                "id": note_data.get("metadata", {}).get("note_id", ""),
                "title": note_data.get("metadata", {}).get("title", ""),
                "creation_date": note_data.get("metadata", {}).get("creation_date", ""),
                "created_at": note_data.get("metadata", {}).get("created_at", 0)
            }
            
            if self.add_note(note_info, entities):
                successful_adds += 1
                
        return successful_adds
        
    def get_node_count(self) -> Dict[str, int]:
        """获取各类型节点的数量"""
        if not self.connected:
            print("【Neo4j错误】未连接到Neo4j，无法获取节点数量")
            return {}
            
        try:
            print("【Neo4j】正在获取节点数量...")
            with self.driver.session() as session:
                result = session.run("""
                    MATCH (n)
                    RETURN labels(n)[0] as label, count(n) as count
                """)
                
                counts = {}
                for record in result:
                    counts[record["label"]] = record["count"]
                
                print(f"【Neo4j】节点统计: {counts}")
                return counts
        except Exception as e:
            print(f"【Neo4j错误】获取节点数量失败: {e}")
            return {}
    
    def get_relation_count(self) -> Dict[str, int]:
        """获取各类型关系的数量"""
        if not self.connected:
            print("【Neo4j错误】未连接到Neo4j，无法获取关系数量")
            return {}
            
        try:
            print("【Neo4j】正在获取关系数量...")
            with self.driver.session() as session:
                result = session.run("""
                    MATCH ()-[r]->()
                    RETURN type(r) as type, count(r) as count
                """)
                
                counts = {}
                for record in result:
                    counts[record["type"]] = record["count"]
                
                print(f"【Neo4j】关系统计: {counts}")
                return counts
        except Exception as e:
            print(f"【Neo4j错误】获取关系数量失败: {e}")
            return {}
        
    def get_note_subgraph(self, note_id: str) -> Dict[str, Any]:
        """获取指定笔记的子图（笔记及其直接关联的实体）"""
        if not self.connected:
            return {}
            
        try:
            with self.driver.session() as session:
                result = session.run("""
                    MATCH (n:Note {id: $note_id})-[r]->(e)
                    RETURN n.title as note_title, type(r) as relation, labels(e)[0] as entity_type, e.name as entity_name
                """, {"note_id": note_id})
                
                subgraph = {
                    "note_id": note_id,
                    "entities": []
                }
                
                for record in result:
                    subgraph["note_title"] = record["note_title"]
                    subgraph["entities"].append({
                        "type": record["entity_type"],
                        "name": record["entity_name"],
                        "relation": record["relation"]
                    })
                    
                return subgraph
        except Exception as e:
            print(f"获取笔记子图失败: {e}")
            return {} 