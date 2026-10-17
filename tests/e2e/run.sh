#!/bin/sh
# 偽のサーバーを立てて、実際の HTTP 通信でクライアントを動かす（dolphin が PATH にあること）
cd "$(dirname "$0")" || exit 1
PORT=${1:-18765}
dolphin mock_server.dol "$PORT" > /dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 2
dolphin client.dol "$PORT"
