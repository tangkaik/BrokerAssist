#!/bin/bash
set -euo pipefail

# 端到端演示：customer → record → summary → chat → advice

BASE_URL="http://127.0.0.1:8001/api/v1"

echo "1. 创建客户..."
CUSTOMER=$(curl -s -X POST "$BASE_URL/customers" \
  -H "Content-Type: application/json" \
  -d '{"name": "演示客户", "phone": "13800138000"}')

CUSTOMER_ID=$(echo "$CUSTOMER" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['customer_id'])")

if [ -z "$CUSTOMER_ID" ] || [ "$CUSTOMER_ID" = "None" ]; then
    echo "错误：创建客户失败或无法解析 customer_id"
    echo "返回内容: $CUSTOMER"
    exit 1
fi

echo "客户ID: $CUSTOMER_ID"

echo "2. 添加沟通记录..."
curl -s -X POST "$BASE_URL/records" \
  -H "Content-Type: application/json" \
  -d "{\"customer_id\": \"$CUSTOMER_ID\", \"content\": \"客户35岁，想了解重疾险，预算1万以内\", \"type\": \"call\"}" | python3 -m json.tool

echo ""
echo "3. 生成摘要..."
curl -s -X POST "$BASE_URL/customers/$CUSTOMER_ID/summary/generate" | python3 -m json.tool

echo ""
echo "4. Chat 问答..."
curl -s -X POST "$BASE_URL/customers/$CUSTOMER_ID/chat" \
  -H "Content-Type: application/json" \
  -d '{"question": "客户预算多少？"}' | python3 -m json.tool

echo ""
echo "5. 生成建议..."
curl -s -X POST "$BASE_URL/customers/$CUSTOMER_ID/advice/generate" | python3 -m json.tool

echo ""
echo "=== 演示完成 ==="
