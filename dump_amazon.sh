# Mac 扒代码命令清单
# 复制到 Mac 终端逐段执行

# ========== 1. 许可证系统 ==========
echo "=== LICENSE SYSTEM ===" > ~/Desktop/amazon_dump.txt

# DER 验证函数完整反汇编
otool -tV ~/Desktop/Payload/Stocks.app/Stocks 2>/dev/null | grep -A200 "_der_decode:" | head -200 >> ~/Desktop/amazon_dump.txt

echo "---DER_SEQ---" >> ~/Desktop/amazon_dump.txt
otool -tV ~/Desktop/Payload/Stocks.app/Stocks 2>/dev/null | grep -A100 "_der_decode_seq:" | head -100 >> ~/Desktop/amazon_dump.txt

echo "---DECOMPRESS---" >> ~/Desktop/amazon_dump.txt
otool -tV ~/Desktop/Payload/Stocks.app/Stocks 2>/dev/null | grep -A200 "_decompress_lzss:" | head -200 >> ~/Desktop/amazon_dump.txt

echo "=== DONE 1 ===" && wc -l ~/Desktop/amazon_dump.txt


# ========== 2. KFD 内核 ==========
echo "=== KFD KERNEL ===" >> ~/Desktop/amazon_dump.txt

otool -tV ~/Desktop/Payload/Stocks.app/Stocks 2>/dev/null | grep -A100 "_xpf_common_init:" | head -100 >> ~/Desktop/amazon_dump.txt
otool -tV ~/Desktop/Payload/Stocks.app/Stocks 2>/dev/null | grep -A100 "_xpf_bad_recovery_init:" | head -100 >> ~/Desktop/amazon_dump.txt
otool -tV ~/Desktop/Payload/Stocks.app/Stocks 2>/dev/null | grep -A100 "_IOSurface_kalloc:" | head -100 >> ~/Desktop/amazon_dump.txt

echo "=== DONE 2 ===" && wc -l ~/Desktop/amazon_dump.txt


# ========== 3. 游戏核心类 ==========
echo "=== OBJC METHODS ===" >> ~/Desktop/amazon_dump.txt

# LoginViewController 方法
otool -ov ~/Desktop/Payload/Stocks.app/Stocks 2>/dev/null | sed -n '/name 0x.*LoginViewController/,/Meta Class/p' >> ~/Desktop/amazon_dump.txt

# HUDMainWindow 方法
otool -ov ~/Desktop/Payload/Stocks.app/Stocks 2>/dev/null | sed -n '/name 0x.*HUDMainWindow/,/Meta Class/p' | head -80 >> ~/Desktop/amazon_dump.txt

# HUDRootViewController 方法
otool -ov ~/Desktop/Payload/Stocks.app/Stocks 2>/dev/null | sed -n '/name 0x.*HUDRootViewController/,/Meta Class/p' | head -100 >> ~/Desktop/amazon_dump.txt

echo "=== DONE 3 ===" && wc -l ~/Desktop/amazon_dump.txt


# ========== 4. 加密字符串 ==========
echo "=== ENCRYPTED STRINGS ===" >> ~/Desktop/amazon_dump.txt

strings ~/Desktop/Payload/Stocks.app/Stocks | grep -E "^[A-Za-z0-9+/]{20,}$" >> ~/Desktop/amazon_dump.txt

echo "=== FINAL ===" && wc -l ~/Desktop/amazon_dump.txt
