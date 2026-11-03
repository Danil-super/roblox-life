#!/usr/bin/env python3
"""Fit native Vinegar Studio windows to changed monitors and hide known empty helpers."""
import re
import argparse
import ctypes as C
import ctypes.util
import json
import os
from pathlib import Path
import subprocess
import time


ROOT = Path(__file__).resolve().parents[1]


def desktop_id(title: str) -> str | None:
    match = re.fullmatch(
        r"([0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12})"
        r" - (?:Рабочий стол Wine|Wine desktop)", title,
    )
    return match.group(1) if match else None


def fit_geometry(monitor, frame):
    x, y, width, height = monitor
    left, right, top, bottom = frame
    if min(frame) < 0:
        raise ValueError("Negative frame extent")
    width -= left + right + 16
    height -= top + bottom + 16
    if width < 320 or height < 240:
        raise ValueError("Monitor cannot fit a 320x240 Wine desktop")
    return x + left + 8, y + top + 8, width, height


def monitor_for_window(monitors, window):
    if not monitors:
        raise ValueError("No active monitors")
    x, y, width, height = window
    center_x, center_y = x + width / 2, y + height / 2

    def score(monitor):
        mx, my, mw, mh = monitor
        overlap = max(0, min(x + width, mx + mw) - max(x, mx)) * max(
            0, min(y + height, my + mh) - max(y, my),
        )
        distance = (center_x - mx - mw / 2) ** 2 + (center_y - my - mh / 2) ** 2
        return overlap, -distance

    return max(monitors, key=score)


class Monitor(C.Structure):
    _fields_ = [("name", C.c_ulong), ("primary", C.c_int), ("automatic", C.c_int),
                ("noutput", C.c_int), ("x", C.c_int), ("y", C.c_int),
                ("width", C.c_int), ("height", C.c_int), ("mwidth", C.c_int),
                ("mheight", C.c_int), ("outputs", C.POINTER(C.c_ulong))]


class X11:
    def __init__(self):
        self.lib = C.CDLL(ctypes.util.find_library("X11"))
        self.randr = C.CDLL(ctypes.util.find_library("Xrandr"))
        signatures = [
            ("XOpenDisplay", [C.c_char_p], C.c_void_p),
            ("XDefaultRootWindow", [C.c_void_p], C.c_ulong),
            ("XInternAtom", [C.c_void_p, C.c_char_p, C.c_int], C.c_ulong),
            ("XFree", [C.c_void_p], C.c_int),
            ("XSync", [C.c_void_p, C.c_int], C.c_int),
            ("XGetWindowProperty", [C.c_void_p, C.c_ulong, C.c_ulong, C.c_long, C.c_long,
                C.c_int, C.c_ulong, C.POINTER(C.c_ulong), C.POINTER(C.c_int),
                C.POINTER(C.c_ulong), C.POINTER(C.c_ulong), C.POINTER(C.c_void_p)], C.c_int),
            ("XGetGeometry", [C.c_void_p, C.c_ulong, C.POINTER(C.c_ulong), C.POINTER(C.c_int),
                C.POINTER(C.c_int), C.POINTER(C.c_uint), C.POINTER(C.c_uint),
                C.POINTER(C.c_uint), C.POINTER(C.c_uint)], C.c_int),
            ("XTranslateCoordinates", [C.c_void_p, C.c_ulong, C.c_ulong, C.c_int, C.c_int,
                C.POINTER(C.c_int), C.POINTER(C.c_int), C.POINTER(C.c_ulong)], C.c_int),
            ("XQueryTree", [C.c_void_p, C.c_ulong, C.POINTER(C.c_ulong), C.POINTER(C.c_ulong),
                C.POINTER(C.POINTER(C.c_ulong)), C.POINTER(C.c_uint)], C.c_int),
        ]
        for name, args, result in signatures:
            function = getattr(self.lib, name)
            function.argtypes, function.restype = args, result
        self.display = self.lib.XOpenDisplay(None)
        if not self.display:
            raise RuntimeError("XWayland display is not available")
        self.root = self.lib.XDefaultRootWindow(self.display)
        self.randr.XRRGetMonitors.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.POINTER(C.c_int)]
        self.randr.XRRGetMonitors.restype = C.POINTER(Monitor)
        self.randr.XRRFreeMonitors.argtypes = [C.POINTER(Monitor)]
        # A window may close between two queries. Treat BadWindow as a vanished candidate.
        self.error_handler = C.CFUNCTYPE(C.c_int, C.c_void_p, C.c_void_p)(lambda _d, _e: 0)
        self.lib.XSetErrorHandler.argtypes = [type(self.error_handler)]
        self.lib.XSetErrorHandler(self.error_handler)

    def property(self, window, name):
        atom = self.lib.XInternAtom(self.display, name.encode(), 0)
        actual, format_, count, remaining, data = C.c_ulong(), C.c_int(), C.c_ulong(), C.c_ulong(), C.c_void_p()
        status = self.lib.XGetWindowProperty(self.display, window, atom, 0, 4096, 0, 0,
            C.byref(actual), C.byref(format_), C.byref(count), C.byref(remaining), C.byref(data))
        if status or not data.value:
            return ()
        try:
            if format_.value == 32:
                return tuple(C.cast(data, C.POINTER(C.c_ulong))[i] for i in range(count.value))
            if format_.value == 8:
                return C.string_at(data, count.value)
            return ()
        finally:
            self.lib.XFree(data)

    def children(self, window):
        root, parent, children, count = C.c_ulong(), C.c_ulong(), C.POINTER(C.c_ulong)(), C.c_uint()
        if not self.lib.XQueryTree(self.display, window, C.byref(root), C.byref(parent), C.byref(children), C.byref(count)):
            return ()
        try:
            return tuple(children[i] for i in range(count.value))
        finally:
            if children:
                self.lib.XFree(children)

    def geometry(self, window):
        root, x, y, width, height, border, depth = C.c_ulong(), C.c_int(), C.c_int(), C.c_uint(), C.c_uint(), C.c_uint(), C.c_uint()
        if not self.lib.XGetGeometry(self.display, window, C.byref(root), C.byref(x), C.byref(y),
                C.byref(width), C.byref(height), C.byref(border), C.byref(depth)):
            raise RuntimeError("Window closed")
        child = C.c_ulong()
        self.lib.XTranslateCoordinates(self.display, window, self.root, 0, 0, C.byref(x), C.byref(y), C.byref(child))
        return x.value, y.value, width.value, height.value

    def monitors(self):
        count = C.c_int()
        items = self.randr.XRRGetMonitors(self.display, self.root, 1, C.byref(count))
        try:
            return [(m.x, m.y, m.width, m.height) for m in items[:count.value] if m.width > 0 and m.height > 0]
        finally:
            if items:
                self.randr.XRRFreeMonitors(items)

    def workarea(self, monitor):
        values = self.property(self.root, "_NET_WORKAREA")
        current = self.property(self.root, "_NET_CURRENT_DESKTOP")
        offset = 4 * (current[0] if current else 0)
        values = values[offset:offset + 4]
        if len(values) < 4:
            return monitor
        wx, wy, ww, wh = (C.c_int32(v).value for v in values[:4])
        x, y, width, height = monitor
        left, top = max(x, wx), max(y, wy)
        right, bottom = min(x + width, wx + ww), min(y + height, wy + wh)
        return (left, top, right - left, bottom - top) if right > left and bottom > top else monitor

    def hide(self, window):
        self.lib.XUnmapWindow.argtypes = [C.c_void_p, C.c_ulong]
        self.lib.XUnmapWindow(self.display, window)
        self.lib.XSync(self.display, 0)

    def request_geometry(self, window, geometry):
        # Ask GNOME to resize a managed Wine window, so Wine receives ConfigureNotify.
        class Data(C.Union):
            _fields_ = [("l", C.c_long * 5)]
        class Client(C.Structure):
            _fields_ = [("type", C.c_int), ("serial", C.c_ulong), ("send_event", C.c_int),
                        ("display", C.c_void_p), ("window", C.c_ulong), ("message_type", C.c_ulong),
                        ("format", C.c_int), ("data", Data)]
        class Event(C.Union):
            _fields_ = [("client", Client), ("padding", C.c_long * 24)]
        self.lib.XSendEvent.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_long, C.POINTER(Event)]
        def send(name, values):
            event = Event()
            event.client.type, event.client.display, event.client.window = 33, self.display, window
            event.client.message_type = self.lib.XInternAtom(self.display, name.encode(), 0)
            event.client.format = 32
            for index, value in enumerate(values):
                event.client.data.l[index] = value
            self.lib.XSendEvent(self.display, self.root, 0, (1 << 19) | (1 << 20), C.byref(event))
        # Remove native maximization before applying explicit client geometry.
        send("_NET_WM_STATE", [0, self.lib.XInternAtom(self.display, b"_NET_WM_STATE_MAXIMIZED_VERT", 0),
                              self.lib.XInternAtom(self.display, b"_NET_WM_STATE_MAXIMIZED_HORZ", 0), 2])
        left, _right, top, _bottom = self.property(window, "_NET_FRAME_EXTENTS") or (0, 0, 0, 0)
        x, y, width, height = geometry
        send("_NET_MOVERESIZE_WINDOW", [1 | (15 << 8) | (2 << 12), x - left, y - top, width, height])
        self.lib.XSync(self.display, 0)


def install_service():
    source = ROOT / "scripts/desktop_window.py"
    path = Path.home() / ".config/systemd/user/roblox-life-desktop.service"
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and str(source) not in path.read_text():
        raise RuntimeError("An unrelated roblox-life-desktop.service already exists")
    path.write_text(
        "[Unit]\nDescription=Fit Vinegar Studio to changing monitor resolution\n"
        "After=graphical-session.target\nPartOf=graphical-session.target\n\n"
        f'[Service]\nExecStart=/usr/bin/python3 "{source}"\n'
        "Environment=PYTHONUNBUFFERED=1\nRestart=on-failure\nRestartSec=3\n\n"
        "[Install]\nWantedBy=graphical-session.target\n"
    )
    variables = [name for name in ("DISPLAY", "XAUTHORITY", "WAYLAND_DISPLAY") if name in os.environ]
    if variables:
        subprocess.run(["systemctl", "--user", "import-environment", *variables], check=True)
    subprocess.run(["systemctl", "--user", "daemon-reload"], check=True)
    subprocess.run(["systemctl", "--user", "enable", "--now", path.name], check=True)
    print("Enabled user service:", path.name)


def is_empty_helper(title, class_name, width, height):
    return (title == b"RobloxStudio" and b"robloxstudiobeta.exe" in class_name.lower()
            and (width, height) == (100, 100))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--size", help="Test Studio window size, e.g. 1280x800 (requires --once)")
    parser.add_argument("--install-service", action="store_true")
    args = parser.parse_args()
    if args.install_service:
        install_service()
        return
    requested = None
    if args.size:
        match = re.fullmatch(r"(\d{3,4})x(\d{3,4})", args.size)
        if not args.once or not match:
            parser.error("Use --once --size WIDTHxHEIGHT")
        requested = tuple(map(int, match.groups()))
        if not (320 <= requested[0] <= 8192 and 240 <= requested[1] <= 8192):
            parser.error("Size must be between 320x240 and 8192x8192")
    x11 = X11()
    signatures = {}
    while True:
        live = set()
        monitors = x11.monitors()
        clients = x11.property(x11.root, "_NET_CLIENT_LIST")
        # Include root children: some helpers get mapped before GNOME lists them.
        for window in set(clients) | set(x11.children(x11.root)):
            class_name = x11.property(window, "WM_CLASS")
            if not isinstance(class_name, bytes) or b"robloxstudiobeta.exe" not in class_name.lower():
                continue
            title = x11.property(window, "_NET_WM_NAME") or x11.property(window, "WM_NAME")
            try:
                geometry = x11.geometry(window)
                if is_empty_helper(title, class_name, *geometry[2:]):
                    x11.hide(window)
                    continue
                if not isinstance(title, bytes) or not (title == b"Roblox Studio" or title.endswith(b" - Roblox Studio")):
                    continue
                if x11.property(window, "WM_TRANSIENT_FOR"):
                    continue
                normal = x11.lib.XInternAtom(x11.display, b"_NET_WM_WINDOW_TYPE_NORMAL", 0)
                types = x11.property(window, "_NET_WM_WINDOW_TYPE")
                if types and normal not in types:
                    continue
                live.add(window)
                area = x11.workarea(monitor_for_window(monitors, geometry))
                frame = x11.property(window, "_NET_FRAME_EXTENTS") or (0, 0, 0, 0)
                signature = (tuple(monitors), area, frame)
                if args.once or signatures.get(window) != signature:
                    target = fit_geometry(area, frame)
                    if requested:
                        target = (*target[:2], *requested)
                    x11.request_geometry(window, target)
                    signatures[window] = signature
                    print(json.dumps({"window": hex(window), "requested": target}), flush=True)
            except (OSError, ValueError, RuntimeError) as error:
                if args.once:
                    raise
                print("Resize pending:", str(error), flush=True)
        signatures = {key: value for key, value in signatures.items() if key in live}
        if args.once:
            if not live:
                raise SystemExit("No native Vinegar Roblox Studio window is open")
            return
        time.sleep(0.2)


if __name__ == "__main__":
    main()
