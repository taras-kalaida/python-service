import pytest
import testinfra


@pytest.fixture(scope="module")
def host():
    return testinfra.get_host("docker://python-service")


def test_app_file_exists(host):
    app_file = host.file("/app/app.py")

    assert app_file.exists
    assert app_file.is_file


def test_python_process_running(host):
    processes = host.process.filter(comm="python")

    assert len(processes) > 0


def test_port_listening(host):
    socket = host.socket("tcp://0.0.0.0:8000")

    assert socket.is_listening


def test_non_root_user(host):
    user = host.user("appuser")

    assert user.exists
    assert user.uid != 0

    result = host.run("id -u")

    assert result.rc == 0
    assert int(result.stdout.strip()) != 0