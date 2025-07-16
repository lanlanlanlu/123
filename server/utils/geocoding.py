#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
地理编码工具模块 - 使用Google Maps API
"""

import os
import json
import time
from typing import Dict, List, Optional, Any, Tuple
import googlemaps
from dotenv import load_dotenv
from functools import lru_cache

# 加载环境变量
load_dotenv()

# 获取Google Maps API密钥
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
if not GOOGLE_MAPS_API_KEY:
    print("警告: GOOGLE_MAPS_API_KEY 环境变量未设置，地理编码功能将不可用")

# 初始化Google Maps客户端
try:
    gmaps = googlemaps.Client(key=GOOGLE_MAPS_API_KEY) if GOOGLE_MAPS_API_KEY else None
except Exception as e:
    print(f"初始化Google Maps客户端失败: {e}")
    gmaps = None

# 缓存文件路径
GEOCODE_CACHE_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "storage", "geocode_cache.json")

# 加载缓存
geocode_cache = {}
try:
    if os.path.exists(GEOCODE_CACHE_FILE):
        with open(GEOCODE_CACHE_FILE, 'r', encoding='utf-8') as f:
            geocode_cache = json.load(f)
        print(f"已加载地理编码缓存，共 {len(geocode_cache)} 条记录")
except Exception as e:
    print(f"加载地理编码缓存失败: {e}")

def save_cache():
    """保存地理编码缓存到文件"""
    try:
        os.makedirs(os.path.dirname(GEOCODE_CACHE_FILE), exist_ok=True)
        with open(GEOCODE_CACHE_FILE, 'w', encoding='utf-8') as f:
            json.dump(geocode_cache, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"保存地理编码缓存失败: {e}")

@lru_cache(maxsize=100)
def geocode_location(location_name: str) -> Optional[Dict[str, Any]]:
    """
    使用Google Maps API将地点名称转换为标准形式，并获取其层级关系
    
    Args:
        location_name: 地点名称，如"北京"、"香港"等
        
    Returns:
        包含标准化地点信息的字典，如果地理编码失败则返回None
    """
    if not location_name or not gmaps:
        return None
    
    # 检查缓存
    if location_name in geocode_cache:
        print(f"使用缓存的地理编码结果: {location_name}")
        return geocode_cache[location_name]
    
    try:
        # 调用Google Maps API进行地理编码
        results = gmaps.geocode(location_name, language="zh-CN")
        
        if not results:
            print(f"未找到地点: {location_name}")
            geocode_cache[location_name] = None
            save_cache()
            return None
        
        # 获取第一个结果
        result = results[0]
        
        # 提取地址组件
        address_components = result['address_components']
        
        # 初始化地点信息
        location_info = {
            "formatted_address": result['formatted_address'],
            "location": {
                "lat": result['geometry']['location']['lat'],
                "lng": result['geometry']['location']['lng']
            },
            "place_id": result['place_id'],
            "types": result['types'],
            "components": {}
        }
        
        # 提取地址组件
        for component in address_components:
            for type in component['types']:
                location_info['components'][type] = component['long_name']
                # 也存储短名称
                location_info['components'][f"{type}_short"] = component['short_name']
        
        # 生成地点的变体和层级关系
        location_variants = []
        location_hierarchy = []
        
        # 添加原始名称
        location_variants.append(location_name)
        
        # 添加标准化的地址
        if 'locality' in location_info['components']:
            city = location_info['components']['locality']
            location_variants.append(city)
            # 添加带"市"和不带"市"的变体
            if city.endswith("市"):
                location_variants.append(city[:-1])
            else:
                location_variants.append(f"{city}市")
        
        # 添加行政区划层级
        for key in ['country', 'administrative_area_level_1', 'locality', 'sublocality_level_1']:
            if key in location_info['components']:
                location_hierarchy.append(location_info['components'][key])
        
        # 添加变体和层级关系到结果中
        location_info['variants'] = list(set(location_variants))
        location_info['hierarchy'] = location_hierarchy
        
        # 缓存结果
        geocode_cache[location_name] = location_info
        save_cache()
        
        print(f"成功地理编码: {location_name} -> {location_info['formatted_address']}")
        return location_info
    
    except Exception as e:
        print(f"地理编码失败: {location_name}, 错误: {e}")
        # 缓存失败结果，避免重复请求
        geocode_cache[location_name] = None
        save_cache()
        return None

def extract_locations_from_text(text: str, llm=None) -> List[str]:
    """
    从文本中提取地点名称
    
    Args:
        text: 输入文本
        llm: 可选的LLM模型，用于更智能地提取地点
        
    Returns:
        地点名称列表
    """
    if llm:
        # 使用LLM提取地点
        try:
            prompt = f"""
            从以下文本中提取所有地点名称（城市、国家、地区等）：
            
            {text}
            
            只返回地点名称列表，用逗号分隔。如果没有找到地点，返回空列表[]。
            """
            
            response = llm.complete(prompt)
            response_text = response.text
            
            # 处理LLM返回的文本
            if "[]" in response_text or "没有找到" in response_text:
                return []
            
            # 分割并清理地点名称
            locations = []
            for loc in response_text.replace("，", ",").split(","):
                loc = loc.strip()
                if loc and len(loc) > 1:  # 避免单个字符
                    locations.append(loc)
            
            return locations
        except Exception as e:
            print(f"使用LLM提取地点失败: {e}")
            # 回退到正则表达式方法
    
    # 使用简单的正则表达式提取地点
    import re
    location_patterns = [
        r'在([\w\u4e00-\u9fa5]{1,10})',
        r'到([\w\u4e00-\u9fa5]{1,10})',
        r'去([\w\u4e00-\u9fa5]{1,10})',
        r'从([\w\u4e00-\u9fa5]{1,10})',
        r'at\s+([\w\s]{1,15})',
        r'in\s+([\w\s]{1,15})',
        r'from\s+([\w\s]{1,15})',
        r'to\s+([\w\s]{1,15})'
    ]
    
    locations = []
    for pattern in location_patterns:
        matches = re.finditer(pattern, text, re.IGNORECASE)
        for match in matches:
            location = match.group(1).strip()
            if location and len(location) > 1:  # 避免单个字符
                locations.append(location)
    
    return list(set(locations))

def enhance_location_metadata(locations: List[str]) -> Dict[str, Any]:
    """
    增强地点元数据，添加变体和层级关系
    
    Args:
        locations: 地点名称列表
        
    Returns:
        增强后的地点元数据
    """
    enhanced_data = {
        "original": locations,
        "variants": [],
        "hierarchy": []
    }
    
    for location in locations:
        # 添加原始地点
        if location not in enhanced_data["variants"]:
            enhanced_data["variants"].append(location)
        
        # 使用地理编码API增强
        geo_info = geocode_location(location)
        if geo_info:
            # 添加地点变体
            for variant in geo_info["variants"]:
                if variant not in enhanced_data["variants"]:
                    enhanced_data["variants"].append(variant)
            
            # 添加层级关系
            for level in geo_info["hierarchy"]:
                if level not in enhanced_data["hierarchy"]:
                    enhanced_data["hierarchy"].append(level)
    
    return enhanced_data

def build_location_filters(enhanced_locations: Dict[str, Any], use_hierarchy: bool = True) -> List[Dict[str, Any]]:
    """
    构建地点过滤器
    
    Args:
        enhanced_locations: 增强后的地点元数据
        use_hierarchy: 是否使用层级关系进行匹配
        
    Returns:
        过滤器列表
    """
    from llama_index.core.vector_stores import FilterOperator, MetadataFilter
    
    filters = []
    
    # 添加所有变体的过滤器
    for variant in enhanced_locations["variants"]:
        filters.append({
            "key": "locations",
            "operator": FilterOperator.CONTAINS,
            "value": variant
        })
    
    # 如果启用层级关系，添加层级过滤器
    if use_hierarchy and enhanced_locations["hierarchy"]:
        for level in enhanced_locations["hierarchy"]:
            filters.append({
                "key": "locations",
                "operator": FilterOperator.CONTAINS,
                "value": level
            })
    
    return filters

# 在模块加载时自动创建缓存目录
if not os.path.exists(os.path.dirname(GEOCODE_CACHE_FILE)):
    try:
        os.makedirs(os.path.dirname(GEOCODE_CACHE_FILE), exist_ok=True)
    except Exception as e:
        print(f"创建缓存目录失败: {e}") 