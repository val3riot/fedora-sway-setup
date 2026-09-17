"""Event-driven libnm status and explicit commands; credentials never enter this process."""
import json
import os
from pathlib import Path
import shutil
import sys
import time
import gi
from wifi import deduplicate, saved_profile, valid_command

gi.require_version('NM', '1.0')
from gi.repository import Gio, GLib, GObject, NM  # noqa: E402


class Network:
    def __init__(self, client=None):
        self.client = client if client is not None else NM.Client.new(None)
        self.connections = []
        self.pending = False
        self.previous = None
        self.message = ''
        self.busy = False
        self.active = None
        self.operation_timer = 0
        self.generation = 0
        self.last_scan = {}
        self.scan_count = 0
        self.buffer = b''
        self.client.connect('notify', self.schedule)
        self.schedule()

    def schedule(self, *_):
        if not self.pending:
            self.pending = True
            GLib.idle_add(self.update)

    def watch(self, obj, signal='notify'):
        if obj is not None:
            self.connections.append((obj, obj.connect(signal, self.schedule)))

    def wifi_devices(self):
        return [d for d in self.client.get_devices()
                if d.get_device_type() == NM.DeviceType.WIFI and d.is_real()]

    def finish(self, message):
        self.busy = False
        self.active = None
        self.message = message
        self.generation += 1
        if self.operation_timer:
            GLib.source_remove(self.operation_timer)
            self.operation_timer = 0
        self.schedule()

    def expired(self):
        self.operation_timer = 0
        self.finish('Operazione non completata: verificare NetworkManager.')
        return GLib.SOURCE_REMOVE

    def update(self):
        self.pending = False
        for obj, handler in self.connections:
            GObject.Object.disconnect(obj, handler)
        self.connections.clear()
        interfaces, rows = [], []
        wireless = self.wifi_devices()
        for device in self.client.get_devices():
            kind = device.get_device_type()
            if kind not in (NM.DeviceType.ETHERNET, NM.DeviceType.WIFI):
                continue
            self.watch(device)
            active = device.get_state() == NM.DeviceState.ACTIVATED
            config = device.get_ip4_config()
            self.watch(config)
            addresses = [a.get_address() for a in config.get_addresses()] if config else []
            ssid = ''
            if device in wireless:
                self.watch(device, 'access-point-added')
                self.watch(device, 'access-point-removed')
                current = device.get_active_access_point()
                for ap in device.get_access_points():
                    self.watch(ap)
                    raw = ap.get_ssid()
                    data = bytes(raw.get_data()) if raw else b''
                    name = data.decode('utf-8', errors='replace').strip('\x00')
                    flags = ap.get_wpa_flags() | ap.get_rsn_flags()
                    secure = bool(flags or ap.get_flags() & getattr(NM, '80211ApFlags').PRIVACY)
                    security = ('WPA/RSN' if flags else 'WEP') if secure else 'Aperta'
                    is_current = active and ap == current
                    if is_current:
                        ssid = name
                    rows.append(dict(path=ap.get_path(), device=device.get_path(),
                                     ssid=name or 'Rete nascosta', ssidKey=data.hex() if name else '',
                                     hidden=not bool(name), strength=ap.get_strength(),
                                     current=is_current, secure=secure, security=security,
                                     saved=saved_profile(device, ap) is not None))
            state = device.get_state()
            state_text = ('Connessa' if active else 'Connessione fallita' if state == NM.DeviceState.FAILED
                          else 'Connecting…' if NM.DeviceState.PREPARE <= state <= NM.DeviceState.SECONDARIES
                          else 'Disconnessa')
            interfaces.append(dict(type='Wi-Fi' if kind == NM.DeviceType.WIFI else 'Ethernet',
                                   interface=device.get_iface(), connected=active,
                                   state=state_text, ipv4=addresses, ssid=ssid))
        if self.active:
            self.watch(self.active)
            state = self.active.get_state()
            if state == NM.ActiveConnectionState.ACTIVATED:
                self.finish('Connessa')
            elif state == NM.ActiveConnectionState.DEACTIVATED:
                self.finish('Connessione fallita: verificare il profilo nel tool di sistema.')
        if not self.client.get_nm_running() and self.busy:
            self.finish('NetworkManager non disponibile')
        connected = any(i['connected'] for i in interfaces)
        primary = self.client.get_primary_connection()
        primary_type = primary.get_connection_type() if primary else ''
        result = dict(connected=connected, interfaces=interfaces,
                      state=('Connessa' if connected else 'Disconnessa')
                      if self.client.get_nm_running() else 'NetworkManager non disponibile',
                      label='WIFI' if primary_type == '802-11-wireless' else 'ETH' if primary_type == '802-3-ethernet' else 'NET',
                      wifiAvailable=bool(wireless), wifiEnabled=self.client.wireless_get_enabled(),
                      wifiHardwareEnabled=self.client.wireless_hardware_get_enabled(),
                      accessPoints=deduplicate(rows) if self.client.wireless_get_enabled() else [],
                      busy=self.busy, scanning=self.scan_count > 0, message=self.message)
        payload = json.dumps(result)
        if payload != self.previous:
            print(payload, flush=True)
            self.previous = payload
        return GLib.SOURCE_REMOVE

    def configure(self):
        helper = str(Path.home() / '.local/bin/workstation-network')
        if not Path(helper).is_file():
            helper = str(Path.home() / '.local/bin/workstation-system-tool')
            args = [helper, 'network']
        else:
            args = [helper]
        try:
            process = Gio.Subprocess.new(args, Gio.SubprocessFlags.STDOUT_SILENCE | Gio.SubprocessFlags.STDERR_SILENCE)
            def editor_closed(proc, result, *_):
                try:
                    proc.wait_check_finish(result)
                except GLib.Error:
                    self.message = 'TUI di rete terminata con errore.'
                    self.schedule()
            process.wait_check_async(None, editor_closed, None)
            self.message = 'Configura connessioni e parametri nella TUI di rete (nmtui).'
        except GLib.Error:
            self.message = 'Impossibile avviare la TUI NetworkManager (nmtui).'
        self.schedule()

    def command(self, command):
        if not valid_command(command):
            return  # Never echo malformed input or credentials.
        if os.environ.get('WORKSTATION_QUICKSHELL_TEST') == '1':
            return
        if not self.client.get_nm_running() or not self.wifi_devices():
            return
        action = command['action']
        if action == 'configure':
            self.configure()
        elif action == 'toggle' and not self.busy:
            self.busy = True
            self.message = 'Aggiornamento Wi-Fi…'
            self.operation_timer = GLib.timeout_add_seconds(15, self.expired)
            token = self.generation
            def done(client, result, *_):
                if token != self.generation:
                    return
                try:
                    client.dbus_set_property_finish(result)
                    self.finish('')
                except GLib.Error:
                    self.finish('Toggle Wi-Fi fallito: verificare permessi o rfkill.')
            self.client.dbus_set_property('/org/freedesktop/NetworkManager',
                'org.freedesktop.NetworkManager', 'WirelessEnabled',
                GLib.Variant('b', command['enabled']), 10000, None, done, None)
        elif action == 'scan' and self.client.wireless_get_enabled():
            for device in self.wifi_devices():
                path = device.get_path()
                now = time.monotonic()
                if now - self.last_scan.get(path, -100) < 15:
                    self.message = 'Attendere 15 secondi tra scansioni.'
                    continue
                self.last_scan[path] = now
                self.scan_count += 1
                self.message = ''
                def scanned(dev, result, *_):
                    self.scan_count -= 1
                    try:
                        dev.request_scan_finish(result)
                    except GLib.Error:
                        self.message = 'Scansione Wi-Fi fallita.'
                    self.schedule()
                device.request_scan_async(None, scanned, None)
        elif action == 'connect' and not self.busy and self.client.wireless_get_enabled():
            target = next(((d, a) for d in self.wifi_devices() for a in d.get_access_points()
                           if a.get_path() == command['path']), None)
            if not target:
                self.message = 'Rete non più disponibile.'
                self.schedule()
                return
            device, ap = target
            profile = saved_profile(device, ap)
            secure = bool(ap.get_wpa_flags() or ap.get_rsn_flags() or
                          ap.get_flags() & getattr(NM, '80211ApFlags').PRIVACY)
            raw = ap.get_ssid()
            hidden = not raw or not bytes(raw.get_data()).strip(b'\x00')
            if profile is None and (secure or hidden):
                self.configure()
                return
            self.busy = True
            self.message = 'Connecting…'
            self.operation_timer = GLib.timeout_add_seconds(60, self.expired)
            token = self.generation
            def activated(client, result, *_):
                if token != self.generation:
                    return
                try:
                    self.active = (client.activate_connection_finish(result) if profile else
                                   client.add_and_activate_connection_finish(result))
                except GLib.Error:
                    self.finish('Connessione fallita: verificare il profilo nel tool di sistema.')
                self.schedule()
            if profile:
                self.client.activate_connection_async(profile, device, ap.get_path(), None, activated, None)
            else:
                # NM completes an open AP profile; no secret settings are constructed.
                self.client.add_and_activate_connection_async(None, device, ap.get_path(), None, activated, None)
        self.schedule()

    def read_command(self, fd, condition):
        data = os.read(fd, 4096)
        if not data:
            return GLib.SOURCE_REMOVE
        self.buffer += data
        if len(self.buffer) > 8192:
            self.buffer = b''
            return GLib.SOURCE_CONTINUE
        while b'\n' in self.buffer:
            line, self.buffer = self.buffer.split(b'\n', 1)
            try:
                self.command(json.loads(line))
            except (ValueError, TypeError, GLib.Error):
                self.message = 'Operazione NetworkManager non riuscita.'
                self.schedule()
        return GLib.SOURCE_CONTINUE


if __name__ == '__main__':
    try:
        service = Network()
        if '--snapshot' in sys.argv:
            service.update()
        else:
            GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, service.read_command)
            GLib.MainLoop().run()
    except (GLib.Error, BrokenPipeError):
        print(json.dumps(dict(connected=False, state='NetworkManager non disponibile',
                             interfaces=[], wifiAvailable=False, accessPoints=[])), flush=True)
