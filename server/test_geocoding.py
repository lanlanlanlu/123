#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
测试地理编码功能
"""

import os
import json
from dotenv import load_dotenv
from utils.geocoding import geocode_location, extract_locations_from_text, enhance_location_metadata
from llama_index.llms.google_genai import GoogleGenAI

# 加载环境变量
load_dotenv()

# 初始化LLM
api_key = os.getenv("GOOGLE_API_KEY")
if not api_key:
    raise ValueError("GOOGLE_API_KEY 环境变量未设置！")

llm = GoogleGenAI(
    model="gemini-1.5-flash",
    api_key=api_key,
)

def test_geocode_location():
    """测试地理编码功能"""
    print("\n===== 测试地理编码功能 =====")
    
    # 测试地点列表
    test_locations = [
        "北京",
        "香港",
        "上海",
        "深圳",
        "广州",
        "纽约",
        "东京",
        "伦敦",
        "巴黎",
        "悉尼"
    ]
    
    for location in test_locations:
        print(f"\n正在地理编码: {location}")
        result = geocode_location(location)
        
        if result:
            print(f"  标准地址: {result['formatted_address']}")
            print(f"  地点变体: {result['variants']}")
            print(f"  层级关系: {result['hierarchy']}")
            print(f"  坐标: {result['location']['lat']}, {result['location']['lng']}")
        else:
            print(f"  地理编码失败")

def test_extract_locations():
    """测试从文本中提取地点"""
    print("\n===== 测试从文本中提取地点 =====")
    
    # 测试查询列表
    test_queries = [
        "我去北京吃了烤鸭",
        "总结一下我在香港的经历",
        "上海的外滩风景怎么样",
        "去年在东京的旅行笔记",
        "纽约时代广场的照片在哪里"
    ]
    
    for query in test_queries:
        print(f"\n查询: '{query}'")
        
        # 使用正则表达式提取
        regex_locations = extract_locations_from_text(query)
        print(f"  正则表达式提取的地点: {regex_locations}")
        
        # 使用LLM提取
        llm_locations = extract_locations_from_text(query, llm=llm)
        print(f"  LLM提取的地点: {llm_locations}")
        
        # 使用地理编码API增强
        if llm_locations:
            enhanced = enhance_location_metadata(llm_locations)
            print(f"  增强后的地点: {enhanced['variants']}")
            print(f"  地点层级关系: {enhanced['hierarchy']}")

def test_specific_case():
    """测试特定案例：香港与香港市的匹配"""
    print("\n===== 测试特定案例：香港与香港市的匹配 =====")
    
    # 地理编码"香港"
    hong_kong = geocode_location("香港")
    if hong_kong:
        print(f"香港的标准地址: {hong_kong['formatted_address']}")
        print(f"香港的变体: {hong_kong['variants']}")
        
        # 检查"香港市"是否在变体中
        if "香港市" in hong_kong['variants']:
            print("✓ '香港市'在'香港'的变体中，可以匹配")
        else:
            print("✗ '香港市'不在'香港'的变体中")
            # 手动添加变体
            print("手动添加'香港市'作为'香港'的变体")
            hong_kong['variants'].append("香港市")
    
    # 测试查询"我去香港市吃了美食"
    query = "我去香港市吃了美食"
    print(f"\n测试查询: '{query}'")
    
    # 提取地点
    locations = extract_locations_from_text(query, llm=llm)
    print(f"提取到的地点: {locations}")
    
    # 增强地点信息
    enhanced = enhance_location_metadata(locations)
    print(f"增强后的地点: {enhanced['variants']}")
    print(f"地点层级关系: {enhanced['hierarchy']}")
    
    # 检查是否能匹配"香港"
    if "香港" in enhanced['variants']:
        print("✓ 可以匹配到'香港'")
    else:
        print("✗ 无法匹配到'香港'")

if __name__ == "__main__":
    # 测试地理编码功能
    test_geocode_location()
    
    # 测试从文本中提取地点
    test_extract_locations()
    
    # 测试特定案例
    test_specific_case() 