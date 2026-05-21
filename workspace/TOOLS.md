# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

## API Key Management

### Change API Key (Interactive Flow)

User triggers: `/changekey` or "ganti api key"

Flow:
1. Ask provider: OpenRouter or NVIDIA (use inline buttons)
2. User sends new API key
3. Apply via `gateway config.patch` with `{"env": {"OPENROUTER_API_KEY": "..."}}` or `{"env": {"NVIDIA_API_KEY": "..."}}`
4. Confirm & restart gateway

### Check Key Status

User triggers: `/keys` or "cek api key"

Flow:
1. Run `gateway config.get` → check `env.OPENROUTER_API_KEY` and `env.NVIDIA_API_KEY`
2. Show status: ✅ set or ❌ not set (don't show actual key value)

---

Add whatever helps you do your job. This is your cheat sheet.

## Related

- [Agent workspace](/concepts/agent-workspace)
