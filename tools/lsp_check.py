"""Ask a Godot language server for the analyzer warnings and errors of GDScript files.

Usage: python tools/lsp_check.py <port> <file> [<file> ...]
Paths are relative to the working directory (the project root). Prints one line per diagnostic,
`path:line: severity: (CODE): message`, then a summary line. Exits 1 when any file has a
diagnostic or did not get a reply, 0 otherwise. tools/lsp_check.sh starts the server this talks to.
"""
import json
import os
import socket
import sys
import time
from urllib.parse import unquote

ROOT = os.getcwd()
SEVERITY = {1: 'error', 2: 'warning', 3: 'info', 4: 'hint'}
WAIT_PER_FILE = 0.6   # seconds to collect the server's reply after opening a file


def file_uri(path: str) -> str:
  return 'file:///' + os.path.abspath(os.path.join(ROOT, path)).replace('\\', '/')


def same_file_key(uri: str) -> str:
  # The server sends URIs percent-encoded and with its own drive-letter case.
  return unquote(uri).lower().replace('file:///', '').replace('file://', '')


class Client:
  def __init__(self, port: int) -> None:
    self.sock = socket.create_connection(('127.0.0.1', port))
    self.sock.settimeout(0.2)
    self.buf = b''
    self.next_id = 1

  def send(self, method: str, params: dict, is_request: bool = False) -> None:
    msg = {'jsonrpc': '2.0', 'method': method, 'params': params}
    if is_request:
      msg['id'] = self.next_id
      self.next_id += 1
    body = json.dumps(msg).encode('utf-8')
    self.sock.sendall(b'Content-Length: %d\r\n\r\n' % len(body) + body)

  def read(self, wait: float) -> list:
    out = []
    end = time.time() + wait
    while time.time() < end:
      try:
        chunk = self.sock.recv(65536)
        if not chunk:
          break
        self.buf += chunk
      except socket.timeout:
        pass
      while True:
        head_end = self.buf.find(b'\r\n\r\n')
        if head_end < 0:
          break
        length = 0
        for line in self.buf[:head_end].split(b'\r\n'):
          if line.lower().startswith(b'content-length:'):
            length = int(line.split(b':')[1])
        if len(self.buf) < head_end + 4 + length:
          break
        out.append(json.loads(self.buf[head_end + 4:head_end + 4 + length]))
        self.buf = self.buf[head_end + 4 + length:]
    return out


def main() -> int:
  port = int(sys.argv[1])
  files = sys.argv[2:]
  client = Client(port)
  client.send('initialize', {
    'processId': os.getpid(),
    'rootPath': ROOT.replace(os.sep, '/'),
    'rootUri': file_uri('.'),
    'capabilities': {'textDocument': {'publishDiagnostics': {}}},
  }, True)
  client.read(2.0)
  client.send('initialized', {})
  client.read(0.5)

  diags = {}

  def collect(messages: list) -> None:
    for m in messages:
      if m.get('method') == 'textDocument/publishDiagnostics':
        diags[same_file_key(m['params']['uri'])] = m['params']['diagnostics']

  for path in files:
    with open(os.path.join(ROOT, path), encoding='utf-8') as f:
      text = f.read()
    client.send('textDocument/didOpen', {'textDocument': {
      'uri': file_uri(path), 'languageId': 'gdscript', 'version': 1, 'text': text}})
    collect(client.read(WAIT_PER_FILE))
    client.send('textDocument/didClose', {'textDocument': {'uri': file_uri(path)}})
  collect(client.read(1.5))

  count = 0
  missing = []
  for path in files:
    key = same_file_key(file_uri(path))
    if key not in diags:
      missing.append(path)
      continue
    for d in diags[key]:
      count += 1
      print('%s:%d: %s: %s' % (path, d['range']['start']['line'] + 1,
          SEVERITY.get(d.get('severity'), '?'), d['message']))
  for path in missing:
    print('%s: no reply from the language server' % path)
  print('checked %d files, %d replied, %d diagnostics' % (len(files), len(files) - len(missing), count))
  return 1 if count or missing else 0


if __name__ == '__main__':
  sys.exit(main())
