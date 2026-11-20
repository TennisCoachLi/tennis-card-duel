#!/usr/bin/env bash
# 在局域网里起一个测试服务，手机可直接访问
#
#   bash serve.sh          # 起服务并打印手机可用的地址
#   bash serve.sh stop     # 停掉
#
# 注意：Mac 同时接了网线(en0)和 WiFi(en1) 且在同一网段时，
# 路由表会把同网段流量导向 en0，手机的包进来后回程走不通。
# 所以服务只绑定 WiFi 的 IP —— 这是唯一手机能访问到的地址。

set -e
cd "$(dirname "$0")"

PORT="${PORT:-8000}"

# 找 WiFi 网卡的 IP
WIFI_IF=""
for i in en1 en2 en0; do
  if networksetup -listallhardwareports 2>/dev/null | grep -A2 "Hardware Port: Wi-Fi" | grep -q "Device: $i"; then
    WIFI_IF="$i"; break
  fi
done
if [ -z "$WIFI_IF" ]; then
  WIFI_IF="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
fi
IP="$(ipconfig getifaddr "$WIFI_IF" 2>/dev/null)"

if [ "$1" = "stop" ]; then
  pkill -f "http.server $PORT" 2>/dev/null || true
  pkill -f "dns-sd -R cardduel" 2>/dev/null || true
  echo "已停止"
  exit 0
fi

if [ -z "$IP" ]; then
  echo "找不到 WiFi IP" >&2
  exit 1
fi

# 停掉旧的
pkill -f "http.server $PORT" 2>/dev/null || true
sleep 1

# 只绑定 WiFi IP —— 保证回程走 WiFi
nohup python3 -m http.server "$PORT" --bind "$IP" >/dev/null 2>&1 </dev/null &
sleep 1.5

# 广播 mDNS，手机可以用主机名访问
nohup dns-sd -R "cardduel" _http._tcp local "$PORT" >/dev/null 2>&1 </dev/null &

echo "服务已启动 (iface: $WIFI_IF)"
echo
echo "  手机用这个地址 (同一个路由器):"
echo "    http://$IP:$PORT/"
echo
echo "  手机预览对照页 (三种 iPhone 宽度):"
echo "    http://$IP:$PORT/preview.html"
echo
echo "  主机名方式 (部分手机/浏览器支持):"
echo "    http://$(hostname -s).local:$PORT/"
echo
echo "  停止: bash serve.sh stop"
