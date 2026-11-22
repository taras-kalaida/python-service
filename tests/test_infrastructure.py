import subprocess

import pytest
import testinfra


@pytest.fixture(scope="module")
def host():
    return testinfra.get_host("local://")


def docker_exec(*args):
    return subprocess.run(
        ["docker", "exec", "python-service", *args],
        capture_output=True,
        text=True,
        timeout=15,
    )


def test_app_file_exists(host):
    result = docker_exec("test", "-f", "/app/app.py")

    assert result.returncode == 0


def test_python_process_running(host):
    result = docker_exec(
        "python",
        "-c",
        "import os; print(open('/proc/1/cmdline', 'rb').read())",
    )

    assert result.returncode == 0
    assert "python" in result.stdout


def test_port_listening(host):
    result = docker_exec(
        "python",
        "-c",
        "import socket; s = socket.socket(); s.settimeout(5); "
        "s.connect(('127.0.0.1', 8000)); s.close()",
    )

    assert result.returncode == 0


def test_non_root_user(host):
    result = docker_exec("id", "-u")

    assert result.returncode == 0
    assert int(result.stdout.strip()) != 0