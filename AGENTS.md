# Project instructions

For player-facing wording, apply the user-level `plain-product-copy` skill (`~/.agents/skills/plain-product-copy/SKILL.md`) when available. Keep only necessary functional labels. Do not disclose hidden mechanics, design intent, hints, or the absence of hints. Do not add a replacement slogan when deleting explanatory text. Keep design details in developer documentation.

Follow the branch flow in docs/DEVELOPMENT.md: feature/*, fix/*, or chore/* into beta. Whenever the version increases, publish Windows installer/portable releases automatically after checks: beta uses vX.Y.Z-beta prereleases and main uses vX.Y.Z stable releases. Never replace an already published version.
