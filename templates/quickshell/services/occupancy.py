"""Supplement native I3 workspaces with window counts, on IPC events only."""
import json
import os
import socket
import struct


def receive(sock):
    def exact(count):
        result = b''
        while len(result) < count:
            chunk = sock.recv(count - len(result))
            if not chunk:
                raise EOFError
            result += chunk
        return result
    magic, size, kind = struct.unpack('=6sII', exact(14))
    if magic != b'i3-ipc' or size > 32 * 1024 * 1024:
        raise ValueError('Invalid IPC frame')
    return kind, json.loads(exact(size))


def send(sock, kind, value=''):
    payload = value.encode()
    sock.sendall(struct.pack('=6sII', b'i3-ipc', len(payload), kind) + payload)


def counts(tree):
    result = {}
    def has_window(node):
        return bool(node.get('app_id') or node.get('window') or node.get('pid')) or any(
            has_window(child) for child in node.get('nodes', []) + node.get('floating_nodes', []))
    def walk(node):
        children = node.get('nodes', []) + node.get('floating_nodes', [])
        if node.get('type') == 'workspace':
            result[str(node['id'])] = any(has_window(child) for child in children)
        for child in children:
            walk(child)
    walk(tree)
    return result


def fullscreen_outputs(tree):
    result = {}
    def walk(node, output=None):
        if node.get('type') == 'output':
            output = node.get('name')
        if output and node.get('type') in ('con', 'floating_con') and node.get('fullscreen_mode', 0):
            result[output] = True
        for child in node.get('nodes', []) + node.get('floating_nodes', []):
            walk(child, output)
    walk(tree)
    return result


def main():
    path = os.environ.get('SWAYSOCK') or os.environ.get('I3SOCK')
    if not path:
        return
    with socket.socket(socket.AF_UNIX) as events, socket.socket(socket.AF_UNIX) as query:
        events.connect(path)
        query.connect(path)
        send(events, 2, '["window", "workspace"]')
        receive(events)
        previous = None
        while True:
            send(query, 4)
            _, tree = receive(query)
            payload = json.dumps(dict(occupied=counts(tree), fullscreen=fullscreen_outputs(tree)), sort_keys=True)
            if payload != previous:
                print(payload, flush=True)
                previous = payload
            receive(events)


if __name__ == '__main__':
    try:
        main()
    except (OSError, EOFError, ValueError):
        pass
