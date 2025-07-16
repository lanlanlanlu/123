# server/test_hybrid_search.py
# 混合搜索测试脚本

import requests
import json
import time

# 测试不同搜索模式的查询结果对比
BASE_URL = "http://localhost:8000/api/chat"  # 假设服务运行在8000端口

def test_search_modes():
    """
    测试三种不同的搜索模式：
    1. 默认向量搜索 (default)
    2. BM25搜索 (bm25)
    3. 混合搜索 (hybrid)
    """
    # 测试查询列表
    test_queries = [
        "什么是强化学习与人类反馈?",
        "Llama 2模型的参数量有多大?",
        "介绍一下Llama 2的安全措施",
        "Llama 2和其他开源模型相比有什么优势?"
    ]
    
    # 循环测试每个查询
    for query in test_queries:
        print(f"\n{'='*80}")
        print(f"测试查询: '{query}'")
        print(f"{'='*80}")
        
        # 测试每种搜索模式
        for mode in ["default", "bm25", "hybrid"]:
            print(f"\n--- 搜索模式: {mode} ---")
            
            # 构建请求
            payload = {
                "query": query,
                "search_mode": mode
            }
            
            # 记录请求时间
            start_time = time.time()
            
            try:
                response = requests.post(BASE_URL, json=payload)
                
                # 计算响应时间
                response_time = time.time() - start_time
                
                if response.status_code == 200:
                    result = response.json()
                    answer = result.get("response", "")
                    
                    # 打印结果摘要
                    print(f"状态码: {response.status_code}, 响应时间: {response_time:.2f}秒")
                    # 打印前200个字符作为预览
                    print(f"回答预览: {answer[:200]}..." if len(answer) > 200 else answer)
                else:
                    print(f"请求失败: 状态码 {response.status_code}")
                    print(response.text)
            
            except Exception as e:
                print(f"请求错误: {str(e)}")
    
    print("\n测试完成!")

if __name__ == "__main__":
    print("开始混合搜索功能测试...")
    test_search_modes() 