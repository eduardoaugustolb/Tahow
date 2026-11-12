# Security policy

Tahow is early software. Only the current development branch receives fixes; there is no supported stable release series yet.

For a vulnerability, use GitHub's private vulnerability reporting option on [the repository security page](https://github.com/eduardoaugustolb/Tahow/security). If that option is unavailable, open an issue asking for a private contact channel **without publishing exploit details or secrets**. No response-time guarantee is currently offered.

A useful report includes the affected revision, compositor and Qt/Quickshell versions, prerequisites, impact, and a minimal reproduction using synthetic data. Never include credentials, real authentication input, or an unredacted desktop capture.

## Relevant boundaries

- Hosted locking delegates authentication to qylock/PAM/fingerprint. Standalone locking depends on Wayland session-lock support and the configured PAM service. Tahow does not install system PAM policy.
- Automated checks use simulated authentication. They do not establish that a real session can be locked and unlocked safely on every machine.
- Desktop snapshots can contain private window content. Captures are frozen, exclude Tahow's own surfaces, and are released as surfaces close; they must not be logged, persisted, or transmitted by diagnostic code.
- Compositor and capture-provider behavior varies. Hyprland is runtime-tested; niri remains unvalidated.

Do not add password or keystroke logging, authentication bypasses, or commands that disable a user's existing lock service. Keep security fixes focused and explain how the affected boundary was checked.
