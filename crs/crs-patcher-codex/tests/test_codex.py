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


def test_run_invokes_codex_exec_with_correct_flags(monkeypatch, tmp_path: Path) -> None:
    source_dir = tmp_path / "src"
    source_dir.mkdir()
    pov_dir = tmp_path / "povs"
    pov_dir.mkdir()
    (pov_dir / "pov_0.blob").write_bytes(b"pov")
    bug_dir = tmp_path / "bugs"
    bug_dir.mkdir()
    diff_dir = tmp_path / "diffs"
    diff_dir.mkdir()
    seed_dir = tmp_path / "seeds"
    seed_dir.mkdir()
    patches_dir = tmp_path / "patches"
    patches_dir.mkdir()
    work_dir = tmp_path / "work"
    work_dir.mkdir()

    monkeypatch.setattr(
        codex,
        "_load_prompt_templates",
        lambda: {
            "agents_md": "{workflow_section}\n{pov_section}\n{bug_candidate_section}\n{seed_section}\n{pre_submit_section}\n{diff_section}",
            "workflow_pov": "workflow",
            "workflow_static": "workflow",
            "pov_present": "{pov_list}",
            "bug_candidates_present": "{bug_candidate_list}",
            "diff_present": "{diff_list}",
            "seed_present": "{seed_list}",
            "pre_submit": "{pov_line}{diff_line}",
        },
    )
    monkeypatch.setattr(codex, "AGENT_TIMEOUT", 0)
    monkeypatch.setattr(codex, "_snapshot_patch_state", lambda patches_dir: {})
    monkeypatch.setattr(codex, "_changed_patches", lambda before, patches_dir: [])
    monkeypatch.setattr(
        codex.subprocess,
        "run",
        lambda *args, **kwargs: type("R", (), {"returncode": 0, "stderr": b""})(),
    )

    popen_calls: list[list[str]] = []

    class FakePopen:
        def __init__(self, cmd, **kwargs):
            popen_calls.append(list(cmd))
            self.returncode = 0
            self.pid = 12345

        def wait(self, timeout=None):
            return 0

        def poll(self):
            return 0

    monkeypatch.setattr(codex.subprocess, "Popen", FakePopen)

    result = codex.run(
        source_dir,
        pov_dir,
        bug_dir,
        diff_dir,
        seed_dir,
        "fuzz_parse_buffer_section",
        patches_dir,
        work_dir,
    )

    assert result is False
    assert len(popen_calls) == 1
    cmd = popen_calls[0]
    assert cmd[0] == "codex"
    assert "exec" in cmd
    assert "--dangerously-bypass-approvals-and-sandbox" in cmd
    assert "--model" in cmd
    assert "--skip-git-repo-check" in cmd
