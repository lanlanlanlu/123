# server/test_rerank.py
# Cohere重排序测试脚本

import requests
import json
import time

# 测试混合检索+重排序
BASE_URL = "http://localhost:8000/api/chat"  # 假设服务运行在8000端口

def test_rerank():
    """
    测试混合检索+Cohere重排序，包括不同语言支持
    """
    # 测试查询列表 - 包含中文和英文查询
    test_queries = [
        # 中文查询
        {"text": "我在北京做了哪些事?", "lang": "中文查询"},
        # 英文查询
        {"text": "What have I done in Beijing?", "lang": "英文查询"}
    ]
    
    # 循环测试每个查询
    for query_info in test_queries:
        query = query_info["text"]
        lang_type = query_info["lang"]
        
        print(f"\n{'='*80}")
        print(f"测试{lang_type}: '{query}'")
        print(f"{'='*80}")
        
        # 测试配置
        test_configs = [
            # 混合检索+英文重排序
            {
                "name": "混合检索+英文重排序",
                "params": {"query": query, "use_rerank": True, "rerank_language": "english"}
            },
            # 混合检索+多语言重排序
            {
                "name": "混合检索+多语言重排序",
                "params": {"query": query, "use_rerank": True, "rerank_language": "multilingual"}
            }
        ]
        
        for config in test_configs:
            print(f"\n--- {config['name']} ---")
            
            # 记录请求时间
            start_time = time.time()
            
            try:
                response = requests.post(BASE_URL, json=config["params"])
                
                # 计算响应时间
                response_time = time.time() - start_time
                
                if response.status_code == 200:
                    result = response.json()
                    answer = result.get("response", "")
                    error = result.get("error", None)
                    
                    # 打印结果摘要
                    print(f"状态码: {response.status_code}, 响应时间: {response_time:.2f}秒")
                    if error:
                        print(f"错误信息: {error}")
                    # 打印前200个字符作为预览
                    print(f"回答预览: {answer[:200]}..." if len(answer) > 200 else answer)
                else:
                    print(f"请求失败: 状态码 {response.status_code}")
                    print(response.text)
            
            except Exception as e:
                print(f"请求错误: {str(e)}")
    
    print("\n测试完成!")

if __name__ == "__main__":
    print("开始混合检索+Cohere重排序测试...")
    test_rerank() 