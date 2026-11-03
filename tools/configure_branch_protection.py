"""Run with an administration-capable GitHub CLI identity to allow direct development while blocking force pushes and deletion."""
import json
import subprocess

REPOSITORY = "nu4ddi4/OneMoreTry"
POLICY = {
    # Main accepts direct commits. Publishing is gated by the complete CI run.
    "required_status_checks": None,
    "enforce_admins": True,
    "required_pull_request_reviews": None,
    "restrictions": None,
    "required_linear_history": False,
    "allow_force_pushes": False,
    "allow_deletions": False,
    "required_conversation_resolution": True,
}

for branch in ("beta", "main"):
    subprocess.run(
        ["gh", "api", "--method", "PUT", f"repos/{REPOSITORY}/branches/{branch}/protection", "--input", "-", "--silent"],
        input=json.dumps(POLICY), text=True, check=True,
    )
    print(f"Protected {branch}")
