#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
测试混合搜索功能
"""

import requests
import json
import sys

BASE_URL = "http://localhost:8000/api/chat"

def test_hybrid_search(query):
    """测试混合搜索功能"""
    print(f"\n{'='*80}")
    print(f"测试混合搜索，查询: '{query}'")
    print(f"{'='*80}")
    
    payload = {
        "query": query
    }
    
    try:
        response = requests.post(BASE_URL, json=payload, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✓ 成功!")
            print(f"回复: {result['response']}")
            return True
        else:
            print(f"✗ 失败! 状态码: {response.status_code}")
            print(f"错误: {response.text}")
            return False
    except Exception as e:
        print(f"✗ 请求异常: {str(e)}")
        return False

if __name__ == "__main__":
    # 默认查询
    query = "总结一下我在北京都干了什么"
    
    # 如果提供了命令行参数，则使用它作为查询
    if len(sys.argv) > 1:
        query = sys.argv[1]
    
    # 测试混合搜索
    success = test_hybrid_search(query)
    
    # 打印摘要
    print("\n" + "="*40)
    print("测试结果摘要:")
    print(f"- 混合搜索: {'成功' if success else '失败'}") 