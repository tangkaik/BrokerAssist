#!/bin/bash
# 一键构建并安装 APK 到手机

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}═══════════════════════════════${NC}"
echo -e "${YELLOW}  保险助手 - 一键构建安装${NC}"
echo -e "${YELLOW}═══════════════════════════════${NC}"

# 检查设备
if ! adb devices | grep -q "device$"; then
    echo -e "${RED}❌ 未检测到手机，请连接 USB 或开启无线调试${NC}"
    echo "提示: adb connect <手机IP>:5555"
    exit 1
fi

# Build
echo -e "\n${YELLOW}📦 正在构建 APK...${NC}"
flutter build apk --debug

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 构建失败${NC}"
    exit 1
fi

# 安装
echo -e "\n${YELLOW}📱 正在安装到手机...${NC}"
adb install -r build/app/outputs/flutter-apk/app-debug.apk

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 安装失败${NC}"
    exit 1
fi

# 启动
echo -e "\n${YELLOW}🚀 正在启动 App...${NC}"
adb shell am start -n com.example.broker_assist/.MainActivity

echo -e "\n${GREEN}✅ 完成！${NC}"
