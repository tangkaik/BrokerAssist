#!/bin/bash
# 超简单：build 完提示文件位置

flutter build apk --debug && \
echo -e "\n✅ 构建成功！" && \
echo -e "📱 文件: build/app/outputs/flutter-apk/app-debug.apk" && \
echo -e "\n👉 请用以下任一方式发送到手机：" && \
echo -e "   1. 微信文件传输助手" && \
echo -e "   2. 华为分享" && \
echo -e "   3. 邮件/QQ 发送给自己\n"

# 自动打开文件夹（Mac）
open build/app/outputs/flutter-apk
