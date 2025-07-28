#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
提取数据库中的日期并展示如何处理Unix时间戳
"""

import sqlite3
from datetime import datetime
import pandas as pd
import os

# 导入自定义工具类
from utils.date_utils import (
    convert_timestamp_to_date_str,
    convert_timestamp_to_date_only,
    convert_timestamps_pandas
)

# 数据库路径 - 尝试几种可能的路径
DB_PATHS = [
    "D:\\am4yne\\Documents\\record.sqlite",  # 原始路径
    "./data/record.sqlite",  # 服务器路径
]

def find_database():
    """尝试查找数据库文件"""
    for path in DB_PATHS:
        if os.path.exists(path):
            print(f"找到数据库: {path}")
            return path
            
    # 如果找不到，尝试在当前目录搜索 .db 和 .sqlite 文件
    current_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(current_dir)
    
    print(f"在 {current_dir} 和父目录中搜索数据库文件...")
    for dir_path in [current_dir, parent_dir]:
        for file in os.listdir(dir_path):
            if file.endswith('.db') or file.endswith('.sqlite'):
                db_path = os.path.join(dir_path, file)
                print(f"找到可能的数据库: {db_path}")
                return db_path
                
    raise FileNotFoundError("找不到数据库文件，请手动指定正确的路径")

# 删除原来的 convert_timestamp_to_date_str 函数，改为导入

def extract_dates():
    """从数据库中提取日期并打印"""
    try:
        # 查找数据库
        DB_PATH = find_database()
        
        # 连接数据库
        print(f"正在连接数据库: {DB_PATH}")
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row  # 使用字典作为行工厂
        cursor = conn.cursor()
        
        # 检查数据库结构
        print("检查数据库表结构...")
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [table[0] for table in cursor.fetchall()]
        print(f"发现表: {', '.join(tables)}")
        
        # 确认 notes 表存在
        if 'notes' not in tables:
            print("警告: 未找到 notes 表! 可用的表: ", tables)
            # 尝试查找其他包含 note 或类似的表
            potential_notes_tables = [t for t in tables if 'note' in t.lower()]
            if potential_notes_tables:
                notes_table = potential_notes_tables[0]
                print(f"尝试使用替代表: {notes_table}")
            else:
                raise ValueError("没有找到可用的笔记表")
        else:
            notes_table = 'notes'
            
        # 检查列名
        cursor.execute(f"PRAGMA table_info({notes_table})")
        columns = [col[1] for col in cursor.fetchall()]
        print(f"表 {notes_table} 的列: {', '.join(columns)}")
        
        # 确定时间列
        created_col = next((col for col in columns if 'creat' in col.lower() and ('time' in col.lower() or 'at' in col.lower())), None)
        updated_col = next((col for col in columns if 'updat' in col.lower() and ('time' in col.lower() or 'at' in col.lower())), None)
        
        if not created_col or not updated_col:
            print(f"警告: 未找到明确的创建/更新时间列! 假设使用 'created_at' 和 'updated_at'")
            created_col = 'created_at'
            updated_col = 'updated_at'
        
        # 执行查询，获取笔记及其时间
        print("正在执行查询...")
        query = f"""
        SELECT id, title, {created_col}, {updated_col} 
        FROM {notes_table} 
        LIMIT 10
        """
        print(f"执行: {query}")
        cursor.execute(query)
        
        notes = cursor.fetchall()
        print(f"获取到 {len(notes)} 条笔记")
        
        # 处理并显示日期
        print("\n===== 笔记时间戳和日期转换 =====")
        print("{:<5} {:<20} {:<15} {:<25} {:<15} {:<25}".format(
            "ID", "标题", "创建时间戳", "创建日期", "更新时间戳", "更新日期"))
        print("-" * 105)
        
        for note in notes:
            created_ts = note[created_col]
            updated_ts = note[updated_col]
            
            # 转换时间戳为可读日期
            created_date = convert_timestamp_to_date_str(created_ts)
            updated_date = convert_timestamp_to_date_str(updated_ts)
            
            print("{:<5} {:<20} {:<15} {:<25} {:<15} {:<25}".format(
                note['id'], 
                str(note['title'])[:18] + '..' if note['title'] and len(str(note['title'])) > 20 else str(note['title']),
                created_ts,
                created_date,
                updated_ts,
                updated_date
            ))
            
        print("\n===== 仅日期格式（不含时间）=====")
        for note in notes[:3]:  # 只显示前3条记录
            created_ts = note[created_col]
            updated_ts = note[updated_col]
            
            # 转换为仅日期格式
            created_date = convert_timestamp_to_date_only(created_ts)
            updated_date = convert_timestamp_to_date_only(updated_ts)
            
            print(f"笔记 ID: {note['id']}, 标题: {note['title']}")
            print(f"  创建日期: {created_date}")
            print(f"  更新日期: {updated_date}")
            
        print("\n===== 使用pandas处理时间戳 =====")
        # 使用pandas处理时间戳
        df = pd.DataFrame([dict(note) for note in notes])
        
        if created_col in df.columns and len(df) > 0:
            # 转换时间戳列为datetime
            try:
                # 使用工具类中的pandas批量转换函数
                timestamps_list = df[created_col].tolist()
                df['created_date'] = convert_timestamps_pandas(timestamps_list)
                df['updated_date'] = convert_timestamps_pandas(df[updated_col].tolist())
                
                # 显示结果
                print(df[['id', 'title', created_col, 'created_date', updated_col, 'updated_date']].head())
                print("\npandas to_datetime 成功将时间戳转换为日期时间。")
            except Exception as e:
                print(f"pandas转换时间戳时出错: {e}")
        else:
            print("没有发现时间戳列或数据为空")
            
        conn.close()
        print("\n处理完成。")
        
    except Exception as e:
        print(f"发生错误: {e}")

if __name__ == "__main__":
    extract_dates()
