#!/usr/bin/env python3
"""Read-only optional hardware checks. Never changes radio or audio state."""
from pathlib import Path
import gi

gi.require_version('NM', '1.0')
from gi.repository import Gio, GLib, NM  # noqa: E402


def main():
    failed = False
    client = NM.Client.new(None)
    if not client.get_nm_running():
        print('FAIL NetworkManager non disponibile')
        failed = True
    wifi = [d for d in client.get_devices() if d.get_device_type() == NM.DeviceType.WIFI and d.is_real()]
    print('OK   Wi-Fi:', str(len(wifi)) + ' dispositivi' if wifi else 'optional absent')
    hardware = list(Path('/sys/class/bluetooth').glob('hci*'))
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        result = bus.call_sync('org.bluez', '/', 'org.freedesktop.DBus.ObjectManager',
                              'GetManagedObjects', None, GLib.VariantType('(a{oa{sa{sv}}})'),
                              Gio.DBusCallFlags.NONE, 3000, None).unpack()[0]
        adapters = [interfaces['org.bluez.Adapter1'] for interfaces in result.values()
                    if 'org.bluez.Adapter1' in interfaces]
        print('OK   Bluetooth:', str(len(adapters)) + ' adapter BlueZ' if adapters else 'optional absent')
        if hardware and not adapters:
            print('FAIL Bluetooth hardware presente ma non esposto da BlueZ')
            failed = True
    except GLib.Error:
        if hardware:
            print('FAIL BlueZ non raggiungibile con hardware Bluetooth presente')
            failed = True
        else:
            print('OK   Bluetooth: optional absent (BlueZ non attivo)')
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
