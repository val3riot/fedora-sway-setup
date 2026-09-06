"""Minimal virtual keyboard for isolated test compositors only (no global input)."""
import array
import ctypes
import os
import socket
import struct
import time


class Keyboard:
    def __init__(self, runtime, display):
        assert 'desktop-tools-' in str(runtime), 'Only the private test compositor accepts input'
        self.socket = socket.socket(socket.AF_UNIX)
        self.socket.connect(str(runtime / display))
        self.socket.settimeout(3)
        self.send(1, 1, struct.pack('I', 2))  # get_registry
        self.send(1, 0, struct.pack('I', 3))  # sync
        data = b''; globals_ = {}; done = False
        while not done:
            data += self.socket.recv(65536)
            while len(data) >= 8:
                obj, word = struct.unpack('II', data[:8]); size, opcode = word >> 16, word & 65535
                if len(data) < size: break
                body, data = data[8:size], data[size:]
                if obj == 3: done = True
                if obj == 2 and opcode == 0:
                    name, length = struct.unpack('II', body[:8])
                    interface = body[8:8+length-1].decode()
                    globals_[interface] = name
        for interface, identity in [('wl_seat', 4), ('zwp_virtual_keyboard_manager_v1', 5)]:
            value = interface.encode() + b'\0'
            string = struct.pack('I', len(value)) + value + b'\0' * (-len(value) % 4)
            self.send(2, 0, struct.pack('I', globals_[interface]) + string + struct.pack('II', 1, identity))
        self.send(5, 0, struct.pack('II', 4, 6))
        self.pointer_manager = globals_['zwlr_virtual_pointer_manager_v1']
        self.pointer_ready = False
        xkb = ctypes.CDLL('libxkbcommon.so.0')
        xkb.xkb_context_new.argtypes = [ctypes.c_int]; xkb.xkb_context_new.restype = ctypes.c_void_p
        xkb.xkb_keymap_new_from_names.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int]; xkb.xkb_keymap_new_from_names.restype = ctypes.c_void_p
        xkb.xkb_keymap_get_as_string.argtypes = [ctypes.c_void_p, ctypes.c_int]; xkb.xkb_keymap_get_as_string.restype = ctypes.c_void_p
        context = xkb.xkb_context_new(0); keymap = xkb.xkb_keymap_new_from_names(context, None, 0)
        pointer = xkb.xkb_keymap_get_as_string(keymap, 1)
        text = ctypes.string_at(pointer) + b'\0'
        libc = ctypes.CDLL(None); libc.free.argtypes = [ctypes.c_void_p]; libc.free(pointer)
        xkb.xkb_keymap_unref.argtypes = [ctypes.c_void_p]; xkb.xkb_keymap_unref(keymap)
        xkb.xkb_context_unref.argtypes = [ctypes.c_void_p]; xkb.xkb_context_unref(context)
        fd = os.memfd_create('test-keymap'); os.write(fd, text)
        message = struct.pack('II', 6, 16 << 16) + struct.pack('II', 1, len(text))
        self.socket.sendmsg([message], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array('i', [fd]))])
        os.close(fd); time.sleep(.1)

    def send(self, obj, opcode, body):
        self.socket.sendall(struct.pack('II', obj, ((len(body)+8) << 16) | opcode) + body)

    def key(self, code):
        for state in (1, 0):
            self.send(6, 1, struct.pack('III', int(time.monotonic()*1000) & 0xffffffff, code, state))
        time.sleep(.12)

    def pointer(self, x=None, y=None, pressed=None):
        if not self.pointer_ready:
            interface = b'zwlr_virtual_pointer_manager_v1\0'
            body = struct.pack('II', self.pointer_manager, len(interface)) + interface + b'\0' * (-len(interface) % 4) + struct.pack('II', 1, 7)
            self.send(2, 0, body)
            self.send(7, 0, struct.pack('II', 4, 8))
            self.pointer_ready = True
            time.sleep(.15)
        now = int(time.monotonic()*1000) & 0xffffffff
        if x is not None: self.send(8, 1, struct.pack('IIIII', now, x, y, 2560, 720))
        if pressed is not None: self.send(8, 2, struct.pack('III', now, 272, int(pressed)))
        self.send(8, 4, b'')
        time.sleep(.12)

    def close(self):
        self.socket.close()
