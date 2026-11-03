#!/usr/bin/env python3
"""Control one local solo test using Roblox's official Studio MCP and test API."""
import argparse
import json
import os
import re
import selectors
import subprocess
import time

from studio_mcp import launch_command


def content(response):
    if "error" in response:
        raise RuntimeError(str(response["error"]))
    result = response.get("result", {})
    value = "\n".join(c["text"] for c in result.get("content", []) if c.get("type") == "text")
    if result.get("isError"):
        raise RuntimeError(value or "Studio tool failed")
    return value


class StudioRpc:
    def __init__(self):
        self.process = subprocess.Popen(launch_command(), stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.process.stdout, selectors.EVENT_READ)
        self.buffer, self.serial = b"", 0
        try:
            self.request("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                                       "clientInfo": {"name": "Roblox Life local test", "version": "1"}})
            self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
            time.sleep(3)
        except Exception:
            self.close()
            raise

    def send(self, message):
        self.process.stdin.write((json.dumps(message) + "\n").encode())
        self.process.stdin.flush()

    def request(self, method, params):
        self.serial += 1
        self.send({"jsonrpc": "2.0", "id": self.serial, "method": method, "params": params})
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                try:
                    value = json.loads(line)
                except ValueError:
                    continue
                if value.get("id") == self.serial:
                    if "error" in value:
                        raise RuntimeError(str(value["error"]))
                    return value
            if self.process.poll() is not None:
                raise RuntimeError("Official Studio MCP exited before replying")
            if self.selector.select(.2):
                chunk = os.read(self.process.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError("Official Studio MCP closed its output")
                self.buffer += chunk
        raise RuntimeError("Official Studio MCP timed out")

    def tool(self, name, args):
        return content(self.request("tools/call", {"name": name, "arguments": args}))

    def close(self):
        self.selector.close()
        try:
            self.process.stdin.close()
        except BrokenPipeError:
            pass
        try:
            self.process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()


START = '''_G.RobloxLifeSoloLaunchError=nil
task.spawn(function()
 local ok,result=pcall(function()
  return game:GetService("StudioTestService"):ExecutePlayModeAsync({source="RobloxLifeDev"})
 end)
 if not ok then _G.RobloxLifeSoloLaunchError=tostring(result) end
end)
return "Solo test requested"'''
STOP = 'game:GetService("StudioTestService"):EndTest("RobloxLifeDev");return "Stop requested"'


def operate(client, action, studio_id=None, timeout=45):
    studios = json.loads(client.tool("list_roblox_studios", {})).get("studios", [])
    selected = [s for s in studios if not studio_id or s["id"] == studio_id]
    if len(selected) != 1 or selected[0]["name"] not in ("NeighborhoodFixer", "roblox-life.rbxlx"):
        raise RuntimeError("Select exactly one Roblox Life Studio with --studio-id; no other project was changed")
    studio = selected[0]["id"]

    def mode():
        text = client.tool("get_studio_state", {"studio_id": studio})
        match = re.search(r"Current Studio Mode: (Edit|Play)\b", text)
        if not match:
            raise RuntimeError("Unknown Studio mode; no successful test is assumed")
        return match[1]

    def execute(code, model):
        return client.tool("execute_luau", {"studio_id": studio, "code": code, "datamodel_type": model})

    current = mode()
    target = "Play" if action == "start" else "Edit"
    if action == "status" or current == target:
        return current
    try:
        execute(START if action == "start" else STOP, "Edit" if action == "start" else "Server")
    except RuntimeError:
        if mode() == target:
            return target
        raise
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        current = mode()
        if current == target:
            return current
        if action == "start" and current == "Edit":
            try:
                failure = execute('return _G.RobloxLifeSoloLaunchError or ""', "Edit")
            except RuntimeError:
                if mode() == target:
                    return target
                raise
            if failure:
                raise RuntimeError(failure)
        time.sleep(.25)
    raise RuntimeError("Studio did not reach the requested mode; no Play verification is claimed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("start", "stop", "status"))
    parser.add_argument("--studio-id")
    args = parser.parse_args()
    client = None
    try:
        client = StudioRpc()
        mode = operate(client, args.action, args.studio_id)
        print(json.dumps({"mode": mode, "action": args.action}))
        return 0
    except (RuntimeError, ValueError, OSError) as error:
        print(f"Studio test: {error}")
        return 1
    finally:
        if client is not None:
            client.close()


if __name__ == "__main__":
    raise SystemExit(main())
