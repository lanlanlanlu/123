#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
测试不同搜索模式的脚本
"""

import requests
import json
import time

BASE_URL = "http://localhost:8000/api/chat"

def test_search_modes(query):
    """测试三种不同的搜索模式并比较结果"""
    print(f"\n{'='*80}")
    print(f"查询: '{query}'")
    print(f"{'='*80}")
    
    results = {}
    
    for mode in ["default", "bm25", "hybrid"]:
        print(f"\n测试 {mode} 模式...")
        
        payload = {
            "query": query,
            "search_mode": mode
        }
        
        start_time = time.time()
        response = requests.post(BASE_URL, json=payload)
        end_time = time.time()
        
        if response.status_code == 200:
            result = response.json()
            elapsed = end_time - start_time
            
            results[mode] = {
                "response": result["response"],
                "time": elapsed
            }
            
            print(f"✓ 成功! 耗时: {elapsed:.2f}秒")
            print(f"回复: {result['response'][:100]}...")  # 只打印前100个字符
        else:
            print(f"✗ 失败! 状态码: {response.status_code}")
            print(f"错误: {response.text}")
            results[mode] = {"error": response.text}
    
    return results

if __name__ == "__main__":
    # 测试查询列表
    test_queries = [
        "什么是向量数据库?",
        "llama index的主要功能是什么",
        "混合搜索有什么优势"
    ]
    
    for query in test_queries:
        result = test_search_modes(query)
        # 可以在这里添加结果比较逻辑
        print("\n") 