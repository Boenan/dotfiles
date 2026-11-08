#!/usr/bin/python3
# =============================================================================
# Gruber Darker GTK bar popup with four pages: network, calendar, power and
# Bluetooth.
# - One window holds all pages, so only one page can be visible.
# - Stays in the background with its window ready, so the popup opens at once.
# - Reads NetworkManager's list on a timer and keeps the 5 strongest networks.
#   The connected network always stays in the list.
# - SIGUSR1, SIGUSR2, SIGHUP and SIGWINCH toggle the network, calendar, power
#   and Bluetooth pages (see network_popup_toggle.sh).
# - Escape or a click outside the card closes the popup.
# =============================================================================

import os
import re
import signal
import sys
from itertools import zip_longest

import gi

# GtkCalendar takes the first weekday from the locale; en_GB starts on Monday
os.environ["LC_TIME"] = "en_GB.UTF-8"

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, Gio, GLib, Gtk, GtkLayerShell, Pango

MAX_NETWORKS = 5
MAX_DEVICES = 6
REFRESH_SECONDS = 15
RESCAN_WAIT_SECONDS = 3
CSS_PATH = os.path.expanduser("~/.config/waybar/network_popup.css")

IC_LOCK = ""
IC_CHECK = ""
IC_SCAN = ""
IC_COG = ""

POWER_ACTIONS = (
    ("\uf023", "Lock", ["swaylock", "-f", "-c", "000000"]),
    ("\uf08b", "Logout", ["swaymsg", "exit"]),
    ("\uf186", "Suspend", ["systemctl", "suspend"]),
    ("\uf2dc", "Hibernate", ["systemctl", "hibernate"]),
    ("\uf021", "Reboot", ["systemctl", "reboot"]),
    ("\uf011", "Shutdown", ["systemctl", "poweroff"]),
)


def run(argv, done=None):
    """Run a command without blocking the UI; call done(ok, stdout)."""
    flags = Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE
    try:
        proc = Gio.Subprocess.new(argv, flags)
    except GLib.Error:
        if done:
            done(False, "")
        return

    def finished(proc, result):
        try:
            _, out, _ = proc.communicate_utf8_finish(result)
        except GLib.Error:
            out = ""
        if done:
            done(proc.get_successful(), out or "")

    proc.communicate_utf8_async(None, None, finished)


def notify(title, body="", app="Wi-Fi"):
    run(["notify-send", "-a", app, title, body])


def split_terse(line):
    """Split one line of `nmcli -t` output, which escapes ':' and '\\'."""
    return [re.sub(r"\\(.)", r"\1", f) for f in re.split(r"(?<!\\):", line)]


def strongest_networks(output):
    """Return the strongest networks, with the connected network first."""
    best = {}
    for line in output.splitlines():
        fields = split_terse(line)
        if len(fields) != 4 or not fields[3]:
            continue  # malformed line or hidden SSID
        in_use, level, security, ssid = fields
        net = {
            "ssid": ssid,
            "signal": int(level or 0),
            "secure": security not in ("", "--"),
            "active": in_use == "*",
        }
        old = best.get(ssid)
        if old is None or net["active"] or (net["signal"] > old["signal"] and not old["active"]):
            best[ssid] = net
    ordered = sorted(best.values(), key=lambda n: (n["active"], n["signal"]), reverse=True)
    return ordered[:MAX_NETWORKS]


def signal_bars(level):
    filled = min(4, 1 + level // 25)
    return "▂▄▆█"[:filled] + f"<span alpha='30%'>{'▂▄▆█'[filled:]}</span>"


def parse_devices(output):
    """Return {mac: name} from `bluetoothctl devices` output."""
    devices = {}
    for line in output.splitlines():
        match = re.match(r"Device (\S+) (.*)", line)
        if match:
            devices[match[1]] = match[2]
    return devices


class NetworkPopup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="local.waybar.NetworkPopup")
        self.radio = None
        self.known = set()
        self.networks = None
        self.bt_view = None
        self.bt_devices = []
        self.bt_busy = False
        self.pending_ssid = None
        self.page = "network"

    def do_startup(self):
        Gtk.Application.do_startup(self)
        self.hold()
        self.load_css()
        self.build_window()
        for signum, page in (
            (signal.SIGUSR1, "network"),
            (signal.SIGUSR2, "calendar"),
            (signal.SIGHUP, "power"),
            (signal.SIGWINCH, "bluetooth"),
        ):
            GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signum, self.on_toggle, page)
        GLib.timeout_add_seconds(REFRESH_SECONDS, self.on_timer)
        self.refresh()
        self.refresh_bluetooth()
        if "--show" in sys.argv:
            self.open_page("network")
        elif "--show-calendar" in sys.argv:
            self.open_page("calendar")
        elif "--show-power" in sys.argv:
            self.open_page("power")
        elif "--show-bluetooth" in sys.argv:
            self.open_page("bluetooth")

    def do_activate(self):
        pass  # a second start only reaches this instance, and then it exits

    def load_css(self):
        provider = Gtk.CssProvider()
        provider.load_from_path(CSS_PATH)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER
        )

    def build_window(self):
        win = self.window = Gtk.ApplicationWindow(application=self)
        win.set_visual(win.get_screen().get_rgba_visual())
        win.set_app_paintable(True)
        GtkLayerShell.init_for_window(win)
        GtkLayerShell.set_namespace(win, "network-popup")
        GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        # Fill the output under the bar, so a click outside the card reaches us
        for edge in (
            GtkLayerShell.Edge.TOP,
            GtkLayerShell.Edge.BOTTOM,
            GtkLayerShell.Edge.LEFT,
            GtkLayerShell.Edge.RIGHT,
        ):
            GtkLayerShell.set_anchor(win, edge, True)
        win.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        win.connect("button-press-event", self.on_window_click)
        win.connect("key-press-event", self.on_key)

        card = self.card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        card.get_style_context().add_class("card")
        card.set_halign(Gtk.Align.END)
        card.set_valign(Gtk.Align.START)
        card.set_size_request(340, -1)
        win.add(card)

        self.network_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        card.add(self.network_page)
        self.calendar = Gtk.Calendar()
        card.add(self.calendar)
        power_page = self.build_power_page()
        card.add(power_page)
        bluetooth_page = self.build_bluetooth_page()
        card.add(bluetooth_page)
        self.pages = {
            "network": self.network_page,
            "calendar": self.calendar,
            "power": power_page,
            "bluetooth": bluetooth_page,
        }

        header = Gtk.Box(spacing=8)
        title = Gtk.Label(label="Wi-Fi", xalign=0, hexpand=True)
        title.get_style_context().add_class("title")
        self.switch = Gtk.Switch(valign=Gtk.Align.CENTER)
        self.switch_handler = self.switch.connect("notify::active", self.on_switch)
        header.add(title)
        header.add(self.switch)
        self.network_page.add(header)

        self.rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        # The rows stay alive and only change text. A new row under the pointer
        # has no hover state, so its first click has no effect.
        self.row_widgets = [self.build_row() for _ in range(MAX_NETWORKS)]
        for row in self.row_widgets:
            self.rows.add(row)
        self.empty = Gtk.Label(xalign=0)
        self.empty.get_style_context().add_class("empty")
        self.rows.add(self.empty)
        self.network_page.add(self.rows)

        self.password_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.prompt = Gtk.Label(xalign=0, ellipsize=Pango.EllipsizeMode.END)
        self.prompt.get_style_context().add_class("prompt")
        self.password = Gtk.Entry(visibility=False, placeholder_text="Password")
        self.password.connect("activate", self.on_password)
        self.password_box.add(self.prompt)
        self.password_box.add(self.password)
        self.password_box.set_no_show_all(True)
        self.prompt.show()
        self.password.show()
        self.network_page.add(self.password_box)

        footer = Gtk.Box(spacing=4)
        footer.get_style_context().add_class("footer")
        rescan = Gtk.Button(label=f"{IC_SCAN}  Rescan", hexpand=True)
        rescan.connect("clicked", lambda _: self.rescan())
        editor = Gtk.Button(label=f"{IC_COG}  Advanced", hexpand=True)
        editor.connect("clicked", self.on_editor)
        footer.add(rescan)
        footer.add(editor)
        self.network_page.add(footer)
        card.show_all()
        for row in self.row_widgets + self.device_rows:
            row.hide()

    def build_power_page(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        title = Gtk.Label(label="Power", xalign=0)
        title.get_style_context().add_class("title")
        title.get_style_context().add_class("page-title")
        page.add(title)
        for icon, name, argv in POWER_ACTIONS:
            button = Gtk.Button()
            button.get_style_context().add_class("action")
            button.add(Gtk.Label(label=f"{icon}   {name}", xalign=0))
            button.connect("clicked", self.on_power, argv)
            page.add(button)
        return page

    def build_bluetooth_page(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        header = Gtk.Box(spacing=8)
        title = Gtk.Label(label="Bluetooth", xalign=0, hexpand=True)
        title.get_style_context().add_class("title")
        self.bt_switch = Gtk.Switch(valign=Gtk.Align.CENTER)
        self.bt_handler = self.bt_switch.connect("notify::active", self.on_bt_switch)
        header.add(title)
        header.add(self.bt_switch)
        page.add(header)

        rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        self.device_rows = [self.build_device_row() for _ in range(MAX_DEVICES)]
        for row in self.device_rows:
            rows.add(row)
        self.bt_empty = Gtk.Label(xalign=0)
        self.bt_empty.get_style_context().add_class("empty")
        rows.add(self.bt_empty)
        page.add(rows)

        footer = Gtk.Box(spacing=4)
        footer.get_style_context().add_class("footer")
        manager = Gtk.Button(label=f"{IC_COG}  Advanced", hexpand=True)
        manager.connect("clicked", self.on_bt_manager)
        footer.add(manager)
        page.add(footer)
        return page

    def build_device_row(self):
        button = Gtk.Button()
        button.get_style_context().add_class("network")
        button.connect("clicked", self.on_device)
        button.device = None

        box = Gtk.Box(spacing=8)
        button.name = Gtk.Label(xalign=0, hexpand=True, ellipsize=Pango.EllipsizeMode.END)
        button.check = Gtk.Label(label=IC_CHECK)
        button.status = Gtk.Label(xalign=1)
        for widget in (button.name, button.check, button.status):
            box.add(widget)
        button.add(box)
        return button

    # ---- Data --------------------------------------------------------------
    def refresh(self):
        run(["nmcli", "-t", "-f", "WIFI", "radio"], self.on_radio)

    def on_radio(self, _ok, out):
        self.radio = out.strip() == "enabled"
        run(["nmcli", "-t", "-f", "NAME", "connection", "show"], self.on_known)

    def on_known(self, _ok, out):
        self.known = {split_terse(line)[0] for line in out.splitlines()}
        if not self.radio:
            self.render([])
            return
        # "--rescan no" reads NetworkManager's list and never waits for a scan
        fields = "IN-USE,SIGNAL,SECURITY,SSID"
        run(
            ["nmcli", "-t", "-f", fields, "device", "wifi", "list", "--rescan", "no"],
            lambda _ok, out: self.render(strongest_networks(out)),
        )

    def refresh_bluetooth(self):
        run(["bluetoothctl", "show"], self.on_bt_show)

    def on_bt_show(self, _ok, out):
        powered = "Powered: yes" in out

        def on_paired(_ok, out):
            paired = parse_devices(out)

            def on_connected(_ok, out):
                connected = parse_devices(out)
                devices = [
                    {"mac": mac, "name": name, "connected": mac in connected}
                    for mac, name in paired.items()
                ]
                devices.sort(key=lambda d: (not d["connected"], d["name"].lower()))
                self.bt_devices = devices[:MAX_DEVICES]
                if not self.bt_busy:
                    self.render_bluetooth(powered, self.bt_devices if powered else [])

            run(["bluetoothctl", "devices", "Connected"], on_connected)

        run(["bluetoothctl", "devices", "Paired"], on_paired)

    def rescan(self):
        run(["nmcli", "device", "wifi", "rescan"])
        GLib.timeout_add_seconds(RESCAN_WAIT_SECONDS, self.on_rescan_done)

    def on_rescan_done(self):
        self.refresh()
        return GLib.SOURCE_REMOVE

    def on_timer(self):
        self.refresh()
        self.refresh_bluetooth()
        return GLib.SOURCE_CONTINUE

    # ---- Rendering ---------------------------------------------------------
    def render(self, networks):
        self.switch.handler_block(self.switch_handler)
        self.switch.set_active(bool(self.radio))
        self.switch.set_state(bool(self.radio))
        self.switch.handler_unblock(self.switch_handler)
        # Do not replace rows that are the same or that the user reads for a password
        if networks == self.networks or self.pending_ssid:
            return
        self.networks = networks
        for row, net in zip_longest(self.row_widgets, networks):
            if net:
                self.update_row(row, net)
            else:
                row.hide()
        self.empty.set_text("No networks found" if self.radio else "Wi-Fi is off")
        self.empty.set_visible(not networks)

    def build_row(self):
        button = Gtk.Button()
        button.get_style_context().add_class("network")
        button.connect("clicked", self.on_network)
        button.net = None

        box = Gtk.Box(spacing=8)
        button.name = Gtk.Label(xalign=0, hexpand=True, ellipsize=Pango.EllipsizeMode.END)
        button.check = Gtk.Label(label=IC_CHECK)
        button.lock = Gtk.Label(label=IC_LOCK)
        button.bars = Gtk.Label()
        button.percent = Gtk.Label(xalign=1, width_chars=4)
        for widget in (button.name, button.check, button.lock, button.bars, button.percent):
            box.add(widget)
        button.add(box)
        return button

    def update_row(self, row, net):
        row.net = net
        row.name.set_text(net["ssid"])
        row.check.set_visible(net["active"])
        row.lock.set_visible(net["secure"])
        row.bars.set_markup(signal_bars(net["signal"]))
        row.percent.set_text(f"{net['signal']}%")
        style = row.get_style_context()
        if net["active"]:
            style.add_class("active")
        else:
            style.remove_class("active")
        row.show()

    def render_bluetooth(self, powered, devices):
        self.bt_switch.handler_block(self.bt_handler)
        self.bt_switch.set_active(powered)
        self.bt_switch.set_state(powered)
        self.bt_switch.handler_unblock(self.bt_handler)
        if (powered, devices) == self.bt_view:
            return
        self.bt_view = (powered, devices)
        for row, device in zip_longest(self.device_rows, devices):
            if device:
                self.update_device_row(row, device)
            else:
                row.hide()
        self.bt_empty.set_text("No paired devices" if powered else "Bluetooth is off")
        self.bt_empty.set_visible(not devices)

    def update_device_row(self, row, device):
        row.device = device
        row.name.set_text(device["name"])
        row.check.set_visible(device["connected"])
        row.status.set_text("Connected" if device["connected"] else "Paired")
        style = row.get_style_context()
        if device["connected"]:
            style.add_class("active")
        else:
            style.remove_class("active")
        row.show()

    # ---- Popup state -------------------------------------------------------
    def reset_password(self):
        self.pending_ssid = None
        self.password.set_text("")
        self.password_box.hide()
        self.rows.show()

    def open_page(self, page):
        self.page = page
        self.reset_password()
        for name, widget in self.pages.items():
            widget.set_visible(name == page)
        if page == "calendar":
            today = GLib.DateTime.new_now_local()
            self.calendar.select_month(today.get_month() - 1, today.get_year())
            self.calendar.select_day(today.get_day_of_month())
        self.window.show()
        if page == "network":
            self.refresh()
            self.rescan()
        elif page == "bluetooth":
            self.refresh_bluetooth()

    def close_popup(self):
        self.reset_password()
        self.window.hide()
        # Start each open with new surfaces, so that pointer state from earlier
        # opens cannot go stale in this long-running process
        self.window.unrealize()

    def on_toggle(self, page):
        if self.window.get_visible() and self.page == page:
            self.close_popup()
        else:
            self.open_page(page)
        return GLib.SOURCE_CONTINUE

    # ---- Events ------------------------------------------------------------
    def on_window_click(self, _win, event):
        x, y = self.card.translate_coordinates(self.window, 0, 0)
        alloc = self.card.get_allocation()
        if not (x <= event.x < x + alloc.width and y <= event.y < y + alloc.height):
            self.close_popup()
        return False

    def on_key(self, _win, event):
        if event.keyval == Gdk.KEY_Escape:
            self.close_popup()
            return True
        return False

    def on_switch(self, switch, _param):
        state = "on" if switch.get_active() else "off"
        self.networks = None
        run(["nmcli", "radio", "wifi", state], lambda *_: self.refresh())

    def on_power(self, _button, argv):
        self.close_popup()
        run(argv)

    def on_bt_switch(self, switch, _param):
        powered = switch.get_active()
        # Draw the expected result now, because the command can take seconds
        devices = [dict(d, connected=False) for d in self.bt_devices] if powered else []
        self.render_bluetooth(powered, devices)
        self.bt_busy = True

        def done(*_):
            self.bt_busy = False
            self.refresh_bluetooth()

        run(["bluetoothctl", "power", "on" if powered else "off"], done)

    def on_bt_manager(self, _button):
        self.close_popup()
        run(["blueman-manager"])

    def on_device(self, button):
        device = button.device
        self.close_popup()
        action = "disconnect" if device["connected"] else "connect"
        want = "no" if device["connected"] else "yes"

        def on_info(_ok, out):
            ok = f"Connected: {want}" in out
            done = "Disconnected" if device["connected"] else "Connected"
            notify(done if ok else f"Failed to {action}", device["name"], "Bluetooth")
            self.refresh_bluetooth()

        run(
            ["bluetoothctl", action, device["mac"]],
            lambda *_: run(["bluetoothctl", "info", device["mac"]], on_info),
        )

    def on_editor(self, _button):
        self.close_popup()
        run(["nm-connection-editor"])

    def on_network(self, button):
        net = button.net
        ssid = net["ssid"]
        if net["active"]:
            self.close_popup()
        elif ssid in self.known:
            self.close_popup()
            self.connect_network(["nmcli", "connection", "up", "id", ssid], ssid)
        elif net["secure"]:
            self.pending_ssid = ssid
            self.prompt.set_text(f"Password for {ssid}")
            self.rows.hide()
            self.password_box.show()
            self.password.grab_focus()
        else:
            self.close_popup()
            self.connect_network(["nmcli", "device", "wifi", "connect", ssid], ssid)

    def on_password(self, entry):
        ssid, password = self.pending_ssid, entry.get_text()
        if not ssid or not password:
            return
        self.close_popup()
        argv = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
        self.connect_network(argv, ssid)

    def connect_network(self, argv, ssid):
        def done(ok, _out):
            notify("Connected" if ok else "Failed to connect", ssid)
            self.refresh()

        run(argv, done)


if __name__ == "__main__":
    sys.exit(NetworkPopup().run([sys.argv[0]]))
