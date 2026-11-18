from pathlib import Path
import subprocess
import os
import tempfile

with tempfile.TemporaryDirectory(prefix="ada-diary-test-") as directory:
    os.mkfifo(Path(directory) / "2024-02-27.diary")
    subprocess.run([str(Path("bin/storage_tests").resolve()), directory], check=True, timeout=5)
