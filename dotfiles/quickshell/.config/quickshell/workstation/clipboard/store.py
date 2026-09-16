#!/usr/bin/env python3
"""Session-only text history. Clipboard data stays in memory and private pipes."""
import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading

LIMIT = 65536


class History:
    def __init__(self):
        self.items = []
        self.serial = 0

    def add(self, text, state='data'):
        if state != 'data' or not isinstance(text, str) or not text.strip() or '\x00' in text or len(text.encode('utf-8')) > LIMIT:
            return False
        self.items = [item for item in self.items if item['text'] != text]
        self.serial += 1
        self.items.insert(0, {'id': self.serial, 'text': text})
        self.items = self.items[:100]
        while sum(len(item['text'].encode('utf-8')) for item in self.items) > 2 * 1024 * 1024:
            self.items.pop()
        return True

    def rows(self, query=''):
        return [{'id': item['id'], 'name': ' '.join(item['text'].split())[:200], 'icon': ''}
                for item in self.items if query.casefold() in item['text'].casefold()]

    def get(self, identity):
        return next((item['text'] for item in self.items if item['id'] == identity), None)


def capture():
    # wl-clipboard 2.2.1 marks x-kde-passwordManagerHint as sensitive.
    if os.environ.get('CLIPBOARD_STATE', 'data') != 'data':
        return
    data = sys.stdin.buffer.read(LIMIT + 1)
    if len(data) <= LIMIT:
        try:
            text = data.decode('utf-8')
        except UnicodeDecodeError:
            return
        print(json.dumps({'text': text}), flush=True)


def serve():
    history = History()
    events = queue.Queue(maxsize=200)
    def read(stream, kind):
        for line in stream:
            events.put((kind, line))
        events.put((kind, None))
    def send(data):
        print(json.dumps(data), flush=True)
    watcher = subprocess.Popen(['wl-paste', '--type', 'text', '--watch', '/usr/bin/python3', str(Path(__file__).resolve()), 'capture'],
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    threading.Thread(target=read, args=(watcher.stdout, 'capture'), daemon=True).start()
    threading.Thread(target=read, args=(sys.stdin, 'command'), daemon=True).start()
    try:
        while True:
            kind, line = events.get()
            if line is None:
                if kind == 'command': break
                send({'error': 'Clipboard Wayland non disponibile.'})
                continue
            try:
                data = json.loads(line)
                if kind == 'capture':
                    if history.add(data.get('text')): send({'changed': True})
                elif data.get('op') == 'list':
                    send({'rows': history.rows(str(data.get('query', ''))), 'query': data.get('query', '')})
                elif data.get('op') == 'clear':
                    history.items.clear(); send({'changed': True})
                elif data.get('op') == 'copy':
                    text = history.get(data.get('id'))
                    if text is not None:
                        subprocess.run(['wl-copy', '--type', 'text/plain;charset=utf-8'], input=text.encode('utf-8'),
                                       stderr=subprocess.DEVNULL, timeout=3, check=True)
            except (ValueError, TypeError, subprocess.SubprocessError, OSError):
                send({'error': 'Operazione clipboard non riuscita.'})
    finally:
        watcher.terminate()
        watcher.wait(timeout=3)


if __name__ == '__main__':
    try:
        capture() if sys.argv[1:] == ['capture'] else serve()
    except (OSError, BrokenPipeError):
        sys.exit(1)
