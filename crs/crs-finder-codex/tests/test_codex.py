import os
import stat
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from agents import codex


def test_setup_writes_codex_config_with_litellm(monkeypatch, tmp_path: Path) -> None:
    source_dir = tmp_path / "src"
    source_dir.mkdir()
    home_dir = tmp_path / "home"
    home_dir.mkdir()
    codex_home = tmp_path / "codex-home"
    run_calls: list[list[str]] = []

    class FakeResult:
        returncode = 0
        stdout = "codex 0.144.3"
        stderr = ""

    def fake_run(cmd, **kwargs):
        run_calls.append(list(cmd))
        return FakeResult()

    monkeypatch.setattr(codex.Path, "home", staticmethod(lambda: home_dir))
    monkeypatch.setattr(codex.subprocess, "run", fake_run)
    monkeypatch.setattr(codex, "CODEX_MODEL", "gpt-5.5")
    monkeypatch.setattr(codex, "CODEX_MODEL_REASONING_EFFORT", "xhigh")
    monkeypatch.delenv("OSS_CRS_LLM_API_KEY", raising=False)
    monkeypatch.delenv("IS_SANDBOX", raising=False)
    monkeypatch.delenv("CODEX_HOME", raising=False)

    codex.setup(
        source_dir,
        {
            "llm_api_url": "http://litellm.example/v1",
            "llm_api_key": "test-key",
            "codex_home": str(codex_home),
        },
    )

    config_path = codex_home / "config.toml"
    config_text = config_path.read_text()
    assert 'model = "gpt-5.5"' in config_text
    assert 'model_reasoning_effort = "xhigh"' in config_text
    assert 'model_provider = "oss_crs"' in config_text
    assert 'base_url = "http://litellm.example/v1"' in config_text
    assert 'env_key = "OSS_CRS_LLM_API_KEY"' in config_text
    assert 'wire_api = "responses"' in config_text
    assert stat.S_IMODE(config_path.stat().st_mode) == 0o600
    assert os.environ["OSS_CRS_LLM_API_KEY"] == "test-key"
    assert os.environ["IS_SANDBOX"] == "1"
    assert os.environ["CODEX_HOME"] == str(codex_home)
    assert "AGENTS.md" in (home_dir / ".gitignore").read_text()
    assert any(call[:3] == ["git", "config", "--global"] for call in run_calls)
