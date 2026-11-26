# Tahow boot login

Tahow's greeter runs in Cage and hands authentication and session creation to greetd. It starts Hyprland using the authenticated user's configuration. Ryoku integration is optional.

Install greetd with its distribution PAM policy and the `agreety` fallback, Cage, Quickshell with Qt Wayland and Qt Quick Controls, Hyprland, and Bun. The installer expects a dedicated `greeter` account and a systemd machine that boots into `graphical.target`. For a distribution that names the account differently, run `sudo "$(command -v bun)" tools/install-tahow-login.ts --install ACCOUNT` from the checkout.

```sh
./install.sh --login-screen
```

This selects greetd through systemd's `display-manager.service` alias and adds a Tahow override for greetd. It leaves the existing greetd configuration available for restoration and applies the change at the next boot. The greeter uses VT1. If the graphical process reports a startup failure, the launcher falls back to `agreety` on that VT.

To restore the previous selection, run the following from the checkout and reboot. You can also do this from a text console, for example with Ctrl + Alt + F2.

```sh
./install.sh --restore-login
```

The greeter uses its own background. SDDM-specific wallpaper settings still apply when using the legacy SDDM theme. Tahow's session lock has its own configuration and keyboard shortcut.

Run `bun test tests/greetd-login.test.ts` for simulated authentication over a temporary Unix socket and tests of the systemd selection and restoration with temporary files.
