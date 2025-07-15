#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
日期和时间工具类
包含各种时间戳处理和日期格式化功能
"""

from datetime import datetime
import pandas as pd

def convert_timestamp_to_date_str(timestamp_value):
    """
    将各种可能的时间戳格式转换为标准的日期字符串 (YYYY-MM-DD)
    - 如果是整数/浮点数: 视为 Unix 时间戳 (秒)
    - 如果是字符串: 尝试提取日期部分
    
    参数:
        timestamp_value: 时间戳值，可以是整数、浮点数或字符串
        
    返回:
        str: 格式化的日期字符串，如 "2025-07-14" 或 "2025-07-14 22:33:26"
    """
    if timestamp_value is None:
        return ""
        
    # 处理整数类型时间戳 (Unix 时间戳，以秒为单位)
    if isinstance(timestamp_value, (int, float)):
        try:
            dt_object = datetime.fromtimestamp(timestamp_value)
            return dt_object.strftime('%Y-%m-%d %H:%M:%S')
        except (ValueError, OSError, OverflowError):
            # 时间戳无效时的回退处理
            print(f"警告: 无法将时间戳 {timestamp_value} 转换为日期")
            return str(timestamp_value)
            
    # 处理字符串类型
    try:
        # 如果字符串包含空格，通常日期在前面部分
        return str(timestamp_value).split(' ')[0]
    except:
        return str(timestamp_value)

def convert_timestamp_to_date_only(timestamp_value):
    """
    将时间戳转换为纯日期格式 (不含时间)
    
    参数:
        timestamp_value: 时间戳值，可以是整数、浮点数或字符串
        
    返回:
        str: 格式化的日期字符串，如 "2025-07-14"
    """
    full_date = convert_timestamp_to_date_str(timestamp_value)
    if full_date and ' ' in full_date:
        return full_date.split(' ')[0]
    return full_date

def convert_timestamps_pandas(timestamps_list, unit='s'):
    """
    使用pandas批量转换时间戳为日期时间对象
    
    参数:
        timestamps_list: 时间戳列表或Series
        unit: 时间单位，默认's'表示秒，可选值: 's'(秒), 'ms'(毫秒), 'us'(微秒), 'ns'(纳秒)
        
    返回:
        pandas.Series: 包含转换后的日期时间对象
    """
    import pandas as pd
    if not timestamps_list:
        return pd.Series([])
    return pd.to_datetime(timestamps_list, unit=unit)

if __name__ == "__main__":
    # 简单的单元测试
    test_timestamps = [
        1752444386,  # Unix 时间戳 (秒)
        "2025-07-14",  # 已格式化日期
        "2025-07-14 22:33:26",  # 已格式化日期时间
        None  # 空值
    ]
    
    print("单个时间戳转换测试:")
    for ts in test_timestamps:
        result = convert_timestamp_to_date_str(ts)
        print(f"  {ts} -> {result}")
    
    print("\n仅日期转换测试:")
    for ts in test_timestamps:
        result = convert_timestamp_to_date_only(ts)
        print(f"  {ts} -> {result}")
    
    print("\npandas批量转换测试:")
    numeric_timestamps = [t for t in test_timestamps if isinstance(t, (int, float))]
    if numeric_timestamps:
        pd_dates = convert_timestamps_pandas(numeric_timestamps)
        for i, ts in enumerate(numeric_timestamps):
            print(f"  {ts} -> {pd_dates[i]}") 