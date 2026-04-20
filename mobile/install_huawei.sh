#!/bin/bash
# 华为鸿蒙设备一键安装脚本
# 通过华为分享/网络传输，无需 ADB

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"

echo -e "${YELLOW}═══════════════════════════════${NC}"
echo -e "${YELLOW}  保险助手 - 华为设备安装${NC}"
echo -e "${YELLOW}═══════════════════════════════${NC}"

# Build
echo -e "\n📦 构建 APK..."
flutter build apk --debug

if [ $? -ne 0 ]; then
    echo "❌ 构建失败"
    exit 1
fi

# 获取本机 IP，提示用户用华为分享
IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)

echo -e "\n${GREEN}✅ 构建成功！${NC}"
echo -e "\n文件位置: ${YELLOW}$APK_PATH${NC}"
echo -e "文件大小: $(du -h $APK_PATH | cut -f1)"

echo -e "\n${YELLOW}═══════════════════════════════${NC}"
echo -e "${YELLOW}请选择安装方式：${NC}"
echo -e "\n1️⃣  华为分享（最快）"
echo -e "   手机打开 华为分享 → 电脑文件管理器访问手机"
echo -e "   把 APK 拖到手机任意文件夹，手机上点击安装"

echo -e "\n2️⃣  局域网 HTTP 下载"
echo -e "   电脑 IP: ${GREEN}http://$IP:8080/app-debug.apk${NC}"
echo -e "   手机浏览器访问以上地址直接下载"

echo -e "\n3️⃣  微信/QQ 文件传输"
echo -e "   APK 已准备，手动发送到文件传输助手"
echo -e "${YELLOW}═══════════════════════════════${NC}"

# 提供 HTTP 下载方式（可选）
read -p "\n是否开启 HTTP 下载服务? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n🌐 启动 HTTP 服务..."
    echo -e "手机浏览器访问: ${GREEN}http://$IP:8080/app-debug.apk${NC}"
    echo -e "按 Ctrl+C 停止服务\n"
    
    cd build/app/outputs/flutter-apk
    python3 -m http.server 8080
fi
