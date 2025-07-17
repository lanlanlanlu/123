# 属性图谱RAG功能指南

本文档详细介绍了属性图谱RAG（Retrieval Augmented Generation）功能的实现和使用方法。

## 功能概述

属性图谱RAG将传统的向量检索和BM25检索与图谱检索相结合，利用实体间的关系增强检索能力，为用户提供更精准的问答体验。

主要特性：

1. **属性图谱存储**：使用Neo4j存储笔记间的复杂关系网络
2. **实体关系提取**：自动从笔记中提取实体（地点、人物、概念等）及其关系
3. **多模态检索**：综合使用向量、关键词和图谱检索
4. **查询意图理解**：分析用户查询，自动选择最佳检索策略
5. **重排序机制**：使用Cohere Rerank优化检索结果排序

## 技术架构

![架构图](https://mermaid.ink/img/pako:eNqFksFugzAMhl_FyhkkeYCeKq3aobR0Yk5ieSPUCrAoMaBQpiHevUDKetqOpnPy-_v9Yh-FVSWKTDinWlOaywC22ynI5UAdqK2FDRjUCiPXwLmB-UK18R7cWdihbkFNUWD3VrXhzo6qbgEHAZ8ZVY3-F-XUO-djLP4GtYD7Q-rygupDDX19SF2vwDGPFMfoNDElnzKDYaPOxnMvuL3q1eiAFQJ1ls5OoV_8DGR4DvnQRhSZp46rg9rKTCpIMy9a4GOZkBJm7mpfBBQAgUWRmgNYO7tX7rMoWP9hyomuj-J6HRhDnTZ92ibk0VQV9BiCXQLeGyn3WPPDB4g3XfKKutXmF5V6kmw?type=png)

## 安装与部署

### 环境要求
- Python 3.8+
- Neo4j 5.x
- Docker 和 Docker Compose (可选)

### 本地安装

1. 安装Neo4j数据库，创建一个新数据库并设置密码
2. 在server目录下创建`.env`文件，填入必要的环境变量：
```
GOOGLE_API_KEY=your_google_api_key
GOOGLE_MAPS_API_KEY=your_maps_api_key
COHERE_API_KEY=your_cohere_api_key
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=your_password
```

3. 安装依赖：
```bash
pip install -r requirements.txt
```

### Docker部署

使用Docker Compose快速部署整个应用：

```bash
docker-compose up -d
```

## 使用方法

### 构建图谱索引

首次使用需要构建图谱索引：

```bash
python ingest.py
```

此命令会从数据库读取笔记，提取实体关系，并同时构建向量索引和图谱索引。

### 启动服务

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### API接口

通过以下API进行图谱增强查询：

```
POST /api/chat
{
  "query": "我在北京做了什么事情？",
  "use_graph": true
}
```

参数说明：
- `query`: 用户查询 (必需)
- `use_graph`: 是否使用图谱检索 (可选，默认为根据查询意图自动判断)
- `use_rerank`: 是否使用重排序 (可选，默认为true)
- `rerank_language`: 重排序语言模型 (可选，默认为auto)

### 查看图谱统计

```
GET /api/graph/stats
```

返回当前图谱中的节点和关系数量统计。

## 查询示例

以下是一些利用图谱增强的示例查询：

1. **实体关系查询**:
   - "张三和李四之间的关系是什么？"
   - "我在北京认识了哪些人？"

2. **时空关联查询**:
   - "我去年在上海做了什么？"
   - "哪些笔记提到了我在北京的经历？"

3. **概念关联查询**:
   - "与机器学习相关的笔记有哪些？"
   - "关于图数据库的笔记中提到了哪些技术？"

## 性能优化

1. **批处理实体提取**：减少LLM API调用，优化成本
2. **图谱缓存**：提高图谱查询性能
3. **增量更新**：只处理新增或修改的笔记
4. **查询意图分析**：根据查询类型智能选择检索策略

## 常见问题

### 无法连接到Neo4j

检查NEO4J_URI、NEO4J_USER和NEO4J_PASSWORD环境变量是否正确设置。

### 实体提取效果不理想

可以通过调整实体提取提示词或使用更专业的实体识别模型来改进。

### 图谱查询速度慢

考虑添加Neo4j索引、优化图谱结构或减少图谱复杂度。

## 维护与扩展

### 添加新实体类型

1. 在`entity_extractor.py`中扩展实体提取逻辑
2. 在`graph_builder.py`中添加新的节点创建和关系建立代码
3. 在`main.py`中更新查询处理逻辑

### 自定义关系类型

修改`graph_builder.py`中的`add_note`方法，增加新的关系处理逻辑。

### 图谱可视化

使用Neo4j Browser (http://localhost:7474) 可视化和探索图谱结构。 