"""Run with an administration-capable GitHub CLI identity to enforce the policy."""
import json
import subprocess

REPOSITORY = "nu4ddi4/side-scroller-game"
POLICY = {
    "required_status_checks": {
        "strict": True,
        "contexts": ["Branch policy", "Test & export Windows", "Windows launch"],
    },
    "enforce_admins": True,
    "required_pull_request_reviews": {
        "dismiss_stale_reviews": True,
        "require_code_owner_reviews": False,
        "required_approving_review_count": 0,
    },
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
