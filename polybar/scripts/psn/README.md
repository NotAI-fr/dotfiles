# Optional PlayStation friend module

This module uses the unofficial `PSNAWP` Python library. Credentials and presence caches are deliberately ignored by Git.

## Setup

```bash
cd ~/.config/polybar/scripts/psn
python -m venv venv
venv/bin/pip install psnawp
cp npsso.example npsso
chmod 600 npsso
```

Replace the placeholder inside `npsso` with your own NPSSO code, then test:

```bash
./psn-friends test-auth
./psn-friends refresh-friends
```

Never commit these paths:

```text
npsso
venv/
cache/
```
