from pathlib import Path
import fcntl
import os
import pty
import re
import select
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time

ROOT = Path(__file__).resolve().parents[1]
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07]*(?:\x07|\x1b\\)")


class Session:
    def __init__(self, directory, rows=30, columns=110):
        self.master, slave = pty.openpty()
        self.slave = slave
        self.resize(rows, columns, notify=False)
        self.original_mode = termios.tcgetattr(slave)
        output = os.open(os.ttyname(slave), os.O_WRONLY)
        self.process = subprocess.Popen(
            [str(ROOT / "bin/diary"), "--data-dir", directory],
            stdin=slave, stdout=output, stderr=output,
            env={**os.environ, "TERM": "xterm-256color", "COLORTERM": "truecolor"},
            start_new_session=True,
        )
        os.close(output)
        self.output = ""
        self.read(0.7)

    def resize(self, rows, columns, notify=True):
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))
        if notify:
            os.kill(self.process.pid, signal.SIGWINCH)
            self.read(0.3)

    def read(self, seconds=0.2):
        chunks = []
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            ready, _, _ = select.select([self.master], [], [], max(0, deadline - time.monotonic()))
            if not ready:
                break
            chunks.append(os.read(self.master, 65536))
        text = ANSI.sub("", b"".join(chunks).decode("utf-8", errors="replace"))
        self.output += text
        return text

    def send(self, text):
        os.write(self.master, text.encode("utf-8"))
        return self.read()

    def expect(self, text):
        if text not in self.output:
            raise AssertionError(f"Expected {text!r}; recent output: {self.output[-1500:]!r}")

    def close(self):
        try:
            if sys.exc_info()[0] is not None:
                self.process.kill()
                self.process.wait()
                return
            self.process.wait(timeout=3)
            assert termios.tcgetattr(self.slave) == self.original_mode, "Terminal mode was not restored"
            assert self.process.returncode == 0, self.output[-1500:]
        finally:
            if self.process.poll() is None:
                self.process.kill()
                self.process.wait()
            os.close(self.master)
            os.close(self.slave)


help_result = subprocess.run([str(ROOT / "bin/diary"), "--help"], capture_output=True, text=True, timeout=3, check=True)
assert "Usage: diary" in help_result.stdout
invalid_result = subprocess.run([str(ROOT / "bin/diary"), "--unknown"], capture_output=True, text=True, timeout=3)
assert invalid_result.returncode != 0

with tempfile.TemporaryDirectory(prefix="ada-diary-tui-") as directory:
    app = Session(directory)
    try:
        app.expect("ADA DIARY")
        app.send("n")
        app.expect("NEW ENTRY")
        app.send("\x13")
        app.expect("Enter a nonblank title")
        assert not list(Path(directory).glob("*.diary"))
        app.send("한글 제목\t첫 번째 줄\r두 번째 줄")
        app.send("\x1b[3~\x1b[1;5C")
        app.send("\x13")
        app.expect("Entry saved")
        files = list(Path(directory).glob("*.diary"))
        assert len(files) == 1
        saved = files[0].read_text()
        assert saved == "ADA-DIARY-1\n한글 제목\n첫 번째 줄\n두 번째 줄", saved
        app.send("q")
    finally:
        app.close()
    app = Session(directory)
    try:
        app.resize(12, 40)
        app.send("dy")
        assert files[0].exists(), "Small-screen commands deleted entry"
        app.resize(30, 110)
        app.send("e")
        app.expect("EDIT ENTRY")
        app.resize(12, 40)
        app.send("invisible\x13\x1by")
        assert files[0].read_text() == saved, "Small-screen input changed entry"
        app.resize(30, 110)
        app.send("\x05!")
        app.send("\x13")
        assert "한글 제목!" in files[0].read_text()
        app.send("e")
        app.send("x\x1b")
        app.expect("Discard changes?")
        app.send("n")
        app.send("\x1b")
        app.send("y")
        assert "한글 제목!" in files[0].read_text()
        app.send("d")
        app.expect("Delete this entry?")
        app.send("n")
        assert files[0].exists()
        app.send("\x1b[D")
        app.send("\x1b[C")
        app.send("d")
        app.send("y")
        assert not files[0].exists()
        app.resize(12, 40)
        app.expect("Resize terminal")
        app.resize(30, 110)
        app.send("q")
    finally:
        app.close()
    assert not (Path(directory) / ".lock").exists()
print("PASS TUI calendar, Unicode CRUD, restart, confirmations and resize")
