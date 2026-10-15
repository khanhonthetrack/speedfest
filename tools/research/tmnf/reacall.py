"""Send one tool call to rea_bridge.  usage: reacall.py SOCKET TOOL 'JSON_ARGS'   (TOOL=@list -> tools/list)"""
import json, socket, sys
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sys.argv[1])
if sys.argv[2] == '@list':
    req = {'method': 'tools/list', 'params': {}}
else:
    req = {'tool': sys.argv[2], 'args': json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}}
s.sendall((json.dumps(req) + '\n').encode())
buf = b''
while not buf.endswith(b'\n'):
    chunk = s.recv(1 << 20)
    if not chunk:
        break
    buf += chunk
sys.stdout.write(buf.decode())
