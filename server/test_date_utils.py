#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
测试时间戳转换工具类
"""

from utils.date_utils import (
    convert_timestamp_to_date_str,
    convert_timestamp_to_date_only,
    convert_timestamps_pandas
)

def test_basic_conversion():
    """测试基本的时间戳转换功能"""
    test_cases = [
        # Unix时间戳
        (1752444386, "2025-07-13 23:06:26"),
        (1640995200, "2022-01-01 00:00:00"),
        
        # 字符串日期
        ("2025-07-14", "2025-07-14"),
        ("2025-07-14 22:33:26", "2025-07-14"),
        
        # 空值
        (None, ""),
    ]
    
    print("===== 基本时间戳转换测试 =====")
    for value, expected in test_cases:
        result = convert_timestamp_to_date_str(value)
        status = "✓" if expected in result else "✗"
        print(f"{status} 输入: {value}, 结果: {result}, 预期包含: {expected}")
        
def test_date_only_conversion():
    """测试只返回日期部分的功能"""
    test_cases = [
        # Unix时间戳
        (1752444386, "2025-07-13"),
        (1640995200, "2022-01-01"),
        
        # 字符串日期
        ("2025-07-14", "2025-07-14"),
        ("2025-07-14 22:33:26", "2025-07-14"),
        
        # 空值
        (None, ""),
    ]
    
    print("\n===== 仅日期转换测试 =====")
    for value, expected in test_cases:
        result = convert_timestamp_to_date_only(value)
        status = "✓" if result == expected else "✗"
        print(f"{status} 输入: {value}, 结果: {result}, 预期: {expected}")
        
def test_pandas_conversion():
    """测试pandas批量转换功能"""
    import pandas as pd
    
    # 准备测试数据
    timestamps = [1752444386, 1640995200, 1577836800]
    
    # 转换
    print("\n===== Pandas批量转换测试 =====")
    try:
        dates = convert_timestamps_pandas(timestamps)
        
        # 验证结果
        print("\n时间戳转换结果:")
        for i, ts in enumerate(timestamps):
            dt = dates[i]
            dt_str = dt.strftime("%Y-%m-%d %H:%M:%S")
            date_only = dt.strftime("%Y-%m-%d")
            print(f"  时间戳 {ts} -> {dt_str} (日期: {date_only})")
        
        print("\n✓ Pandas转换测试通过!")
    except Exception as e:
        print(f"\n✗ Pandas转换测试失败: {e}")

def main():
    """运行所有测试"""
    test_basic_conversion()
    test_date_only_conversion()
    test_pandas_conversion()
    
    print("\n所有测试完成！")
    
if __name__ == "__main__":
    main() 