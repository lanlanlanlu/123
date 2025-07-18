#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
实体关系提取工具
用于从文本中提取实体和关系，构建属性图谱所需的数据
"""

import json
import re
from typing import Dict, List, Any, Optional, Union

# 导入现有工具类
from utils.geocoding import extract_locations_from_text, enhance_location_metadata

def extract_entities_from_text(text: str, llm=None) -> Dict[str, Any]:
    """
    从文本中提取多种实体和关系
    
    
    参数:
        text: 输入文本
        llm: 可选的LLM模型，用于提取实体和关系
        
    返回:
        包含实体和关系的字典
    """
    # 默认结果结构
    result = {
        "locations": [],
        "people": [],
        "organizations": [],
        "concepts": [],
        "relations": []
    }
    
    # 尝试使用LLM进行全面提取
    if llm:
        try:
            prompt = f"""
            你是一个提取Graph RAG的实体和关系信息专家，从以下文本中提取实体和关系信息，以JSON格式返回：
            
            {text}
            
            请提取以下类型的实体：
            1. 地点：如城市、国家、地区、景点等地理位置
            2. 人物：任何人名、职位后的人名等
            3. 组织：如公司、学校、机构等
            4. 概念：如技术、理论、方法、产品等
            
            并识别实体间的关系，如"工作于"、"位于"、"研发"、"使用"等。
            
            返回格式 (严格按照以下JSON格式返回，不要添加任何其他内容):
            {{
              "locations": ["地点1", "地点2"],
              "people": ["人名1", "人名2"],
              "organizations": ["组织1", "组织2"],
              "concepts": ["概念1", "概念2"],
              "relations": [
                {{"head": "实体1", "relation": "关系类型", "tail": "实体2"}}
              ]
            }}
            """
            
            response = llm.complete(prompt)
            response_text = response.text.strip()
            
            # 清理LLM响应，移除可能的前缀和后缀
            json_str = response_text
            # 移除可能的Markdown代码块标记
            if "```json" in json_str:
                json_str = json_str.split("```json", 1)[1]
            if "```" in json_str:
                json_str = json_str.split("```", 1)[0]
            
            # 尝试找到JSON的开始和结束
            start_idx = json_str.find('{')
            end_idx = json_str.rfind('}')
            if start_idx >= 0 and end_idx > start_idx:
                json_str = json_str[start_idx:end_idx+1]
                
            try:
                extracted = json.loads(json_str)
                # 验证结果格式
                if isinstance(extracted, dict):
                    # 合并结果，确保结构一致
                    for key in result.keys():
                        if key in extracted and isinstance(extracted[key], list):
                            result[key] = extracted[key]
                    print(f"LLM实体提取成功: 找到 {sum(len(result[k]) for k in result if isinstance(result[k], list))} 个实体")
                    return result
            except json.JSONDecodeError as e:
                print(f"无法解析LLM响应: {e}")
                print(f"原始响应: {response_text[:100]}...")
                print(f"处理后的JSON字符串: {json_str[:100]}...")
        except Exception as e:
            print(f"LLM实体提取失败: {e}")
    
    
    return result

def extract_entities_from_query(query: str, llm=None) -> Dict[str, Any]:
    """
    从查询中提取可能的实体，用于查询理解
    这个函数可以重用现有的提取逻辑，但更专注于从查询中提取
    
    参数:
        query: 用户查询
        llm: LLM模型
        
    返回:
        实体字典
    """
    entities = {
        "tags": [],
        "locations": [],
        "dates": [],
        "people": [],
        "concepts": []
    }
    
    # 1. 提取标签 (例如: #工作 or @工作)
    tags = re.findall(r'[@#]([\w\u4e00-\u9fa5]+)', query)
    if tags:
        entities["tags"] = [tag.strip() for tag in tags]
    
    # 2. 识别工作日相关词汇
    workday_patterns = {
        "周一": "Monday",
        "周二": "Tuesday",
        "周三": "Wednesday", 
        "周四": "Thursday",
        "周五": "Friday",
        "工作日": "Weekday",
        "工作": "Work"
    }
    
    # 检查是否有工作日相关词汇
    for day_zh, day_en in workday_patterns.items():
        if day_zh in query:
            if "tags" not in entities:
                entities["tags"] = []
            # 添加为标签
            if day_zh not in entities["tags"]:
                entities["tags"].append(day_zh)
            # 也可以添加英文版本作为概念
            if "concepts" not in entities:
                entities["concepts"] = []
            if day_en not in entities["concepts"]:
                entities["concepts"].append(day_en)
    
    # 3. 使用LLM进行全面实体提取
    extracted = extract_entities_from_text(query, llm=llm)
    
    # 4. 合并提取结果
    if extracted:
        # 地点需要特殊处理，使用地理编码API增强
        if extracted.get("locations"):
            try:
                # 使用地理编码API增强地点信息
                enhanced_locations = enhance_location_metadata(extracted["locations"])
                entities["locations"] = enhanced_locations["variants"]
                entities["location_hierarchy"] = enhanced_locations["hierarchy"]
            except Exception as e:
                print(f"增强地点信息失败: {e}")
                entities["locations"] = extracted["locations"]
        
        # 合并其他实体
        for key in ["people", "organizations", "concepts"]:
            if extracted.get(key):
                if key not in entities:
                    entities[key] = []
                entities[key].extend([item for item in extracted[key] if item not in entities[key]])
    
    # 5. 增强日期提取 - 特别是工作日相关
    if "工作日" in query or any(day in query for day in ["周一", "周二", "周三", "周四", "周五"]):
        # 如果提到工作日但没有具体日期，添加一个通用的工作日标记
        if "dates" not in entities or not entities["dates"]:
            entities["dates"] = ["weekday"]
    
    print(f"提取到的实体: {entities}")
    return entities

def batch_extract_entities(texts: List[str], llm=None, batch_size=2) -> List[Dict[str, Any]]:
    """
    批量处理多个文本的实体提取，减少LLM API调用次数
    
    参数:
        texts: 文本列表
        llm: LLM模型
        batch_size: 批处理大小，默认为2（降低了默认值以提高稳定性）
        
    返回:
        提取结果列表
    """
    results = []
    
    
    # 批处理
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i+batch_size]
        
        # 构造批处理提示
        batch_texts = []
        for j, text in enumerate(batch):
            # 截取文本以避免过长
            short_text = text[:1000] + "..." if len(text) > 1000 else text
            batch_texts.append(f"文本[{j+1}]：\n{short_text}\n---")
        
        prompt = f"""
        你是一个提取Graph RAG的实体和关系信息专家，分析以下{len(batch)}段文本，提取每段文本中的实体和关系。
        
        {"".join(batch_texts)}
        
        仅返回以下格式的JSON数组，不要添加任何其他解释或注释：
        [
          {{
            "doc_id": 1,
            "entities": {{
              "locations": ["地点1", "地点2"],
              "people": ["人名1", "人名2"],
              "organizations": ["组织1", "组织2"],
              "concepts": ["概念1", "概念2"]
            }},
            "relations": [
              {{"head": "实体1", "relation": "关系类型", "tail": "实体2"}}
            ]
          }},
          // 对每个文本重复上述结构
        ]
        """
        
        try:
            print(f"批量处理 {len(batch)} 个文本，范围: {i+1}-{i+len(batch)}/{len(texts)}")
            response = llm.complete(prompt)
            response_text = response.text.strip()
            
            # 清理LLM响应文本，提取JSON部分
            json_str = response_text
            
            # 移除可能的Markdown代码块标记
            if "```json" in json_str:
                json_str = json_str.split("```json", 1)[1]
            elif "```" in json_str:
                json_str = json_str.split("```", 1)[1]
            
            if "```" in json_str:
                json_str = json_str.split("```", 1)[0]
            
            # 寻找JSON数组的起始和结束位置
            start_idx = json_str.find('[')
            end_idx = json_str.rfind(']')
            
            if start_idx >= 0 and end_idx > start_idx:
                json_str = json_str[start_idx:end_idx+1]
                try:
                    batch_results = json.loads(json_str)
                    print(f"成功解析批量结果，包含 {len(batch_results)} 条记录")
                    
                    # 处理批处理结果
                    for j in range(len(batch)):
                        if j < len(batch_results):
                            doc_result = batch_results[j]
                            # 格式化结果以匹配单个文档的格式
                            entity_result = doc_result.get("entities", {})
                            entity_result["relations"] = doc_result.get("relations", [])
                            results.append(entity_result)
                        else:
                            # 如果LLM未返回足够的结果，使用回退方法
                            print(f"LLM未返回文本[{j+1}]的结果")
                except json.JSONDecodeError as e:
                    print(f"JSON解析错误: {e}")
                    print(f"处理后的JSON字符串: {json_str[:100]}...")
            else:
                print(f"无法在响应中找到有效的JSON数组")
                    
        except Exception as e:
            print(f"批量提取实体失败: {e}")
    
    print(f"总共处理了 {len(texts)} 个文本，提取了 {len(results)} 个结果")
    return results 