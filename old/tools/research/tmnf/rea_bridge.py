"""Keep one `rea --mcp` stdio server (and its Ghidra session) alive; accept tool calls on a Unix socket.
usage: python3 -I rea_bridge.py SOCKET_PATH LOGFILE"""
import json, os, socket, subprocess, sys, threading, itertools

sock_path, log_path = sys.argv[1], sys.argv[2]
log = open(log_path, 'a', buffering=1)
proc = subprocess.Popen(['rea', '--mcp'], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                        stderr=open(log_path + '.stderr', 'ab'), bufsize=0)
ids = itertools.count(1)
pending = {}
plock = threading.Lock()
wlock = threading.Lock()

def send(msg):
    data = (json.dumps(msg) + '\n').encode()
    with wlock:
        proc.stdin.write(data)
        proc.stdin.flush()

def reader():
    for raw in proc.stdout:
        try:
            msg = json.loads(raw)
        except Exception:
            log.write('NONJSON ' + raw.decode(errors='replace')[:300] + '\n')
            continue
        if 'method' in msg and 'id' in msg:  # server -> client request
            m = msg['method']
            result = {'roots': []} if m == 'roots/list' else {}
            send({'jsonrpc': '2.0', 'id': msg['id'], 'result': result})
            continue
        if 'method' in msg:  # notification
            log.write('NOTE ' + json.dumps(msg)[:500] + '\n')
            continue
        with plock:
            ev = pending.get(msg.get('id'))
        if ev:
            ev[1] = msg
            ev[0].set()
    log.write('SERVER EXITED\n')

threading.Thread(target=reader, daemon=True).start()

def call(method, params, timeout=None):
    i = next(ids)
    ev = [threading.Event(), None]
    with plock:
        pending[i] = ev
    send({'jsonrpc': '2.0', 'id': i, 'method': method, 'params': params})
    ev[0].wait(timeout)
    with plock:
        pending.pop(i, None)
    return ev[1]

init = call('initialize', {'protocolVersion': '2025-06-18', 'capabilities': {},
                           'clientInfo': {'name': 'speedfest-bridge', 'version': '1'}}, 120)
log.write('INIT ' + json.dumps(init)[:800] + '\n')
send({'jsonrpc': '2.0', 'method': 'notifications/initialized'})

if os.path.exists(sock_path):
    os.unlink(sock_path)
srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(sock_path)
os.chmod(sock_path, 0o600)
srv.listen(8)
log.write('READY\n')

def handle(conn):
    with conn:
        buf = b''
        while not buf.endswith(b'\n'):
            chunk = conn.recv(65536)
            if not chunk:
                break
            buf += chunk
        req = json.loads(buf)
        if req.get('method'):
            resp = call(req['method'], req.get('params', {}))
        else:
            resp = call('tools/call', {'name': req['tool'], 'arguments': req.get('args', {})})
        conn.sendall((json.dumps(resp) + '\n').encode())

while True:
    c, _ = srv.accept()
    threading.Thread(target=handle, args=(c,), daemon=True).start()
