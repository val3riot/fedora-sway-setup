"""Read-only NetworkManager D-Bus status through libnm; no nmcli polling."""
import json
import gi

gi.require_version('NM', '1.0')
from gi.repository import GLib, GObject, NM  # noqa: E402


class Network:
    def __init__(self):
        self.client = NM.Client.new(None)
        self.connections = []
        self.pending = False
        self.previous = None
        self.client.connect('notify', self.schedule)
        self.schedule()

    def schedule(self, *_):
        if not self.pending:
            self.pending = True
            GLib.idle_add(self.update)

    def watch(self, obj):
        if obj is not None:
            self.connections.append((obj, obj.connect('notify', self.schedule)))

    def update(self):
        self.pending = False
        for obj, handler in self.connections:
            GObject.Object.disconnect(obj, handler)
        self.connections.clear()
        interfaces = []
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
            if kind == NM.DeviceType.WIFI:
                ap = device.get_active_access_point()
                self.watch(ap)
                raw = ap.get_ssid() if ap else None
                if raw:
                    ssid = bytes(raw.get_data()).decode('utf-8', errors='replace')
            interfaces.append(dict(type='Wi-Fi' if kind == NM.DeviceType.WIFI else 'Ethernet',
                                   interface=device.get_iface(), connected=active,
                                   state='Connessa' if active else 'Disconnessa',
                                   ipv4=addresses, ssid=ssid))
        connected = any(i['connected'] for i in interfaces)
        result = dict(connected=connected, interfaces=interfaces,
                      state=('Connessa' if connected else 'Disconnessa')
                      if self.client.get_nm_running() else 'NetworkManager non disponibile')
        payload = json.dumps(result)
        if payload != self.previous:
            print(payload, flush=True)
            self.previous = payload
        return GLib.SOURCE_REMOVE


if __name__ == '__main__':
    try:
        service = Network()
        GLib.MainLoop().run()
    except (GLib.Error, BrokenPipeError):
        pass
