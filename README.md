# nixos-bootstrap

A small **public** NixOS config that gets a fresh machine installed, on the
network and reachable with your keyboard layout and SSH key. It does not
contain the real configuration: after the first boot you sign in to GitHub and
pull your **private** config, then switch to it.

Two machine types are covered:

| Flake output | Machine | Install path |
|---|---|---|
| `bootstrap` | ordinary x86_64 UEFI PC or laptop | `nixos-install --flake` straight from this repo |
| `bootstrap-asahi` | Apple Silicon Mac running Asahi (aarch64) | stock Asahi install first, then `adopt-config` (see below for why) |

What is in here: a user with an SSH public key (key-only SSH), the Colemak
keyboard layout (Caps Lock as Ctrl, on the console too), NetworkManager,
`git`, `gh`, and one helper command, `adopt-config`. What must never go in
here: passwords or hashes, tokens, work or employer details, home-network
addresses, credentials files. Keep those in the private repo.

```
flake.nix            outputs: bootstrap, bootstrap-asahi, packages.*.adopt-config
adopt-config.nix     the helper (a shellchecked script)
modules/base.nix     shared: user, SSH key, keyboard, tools
modules/x86_64.nix   x86_64 boot loader + hardware
modules/asahi.nix    Apple Silicon: Asahi module, kernel pin, iwd Wi-Fi, keyboard fix
```

## x86_64

From the NixOS installer, as root, with the network up:

```sh
# 0. the installer starts in QWERTY: switch it to Colemak first, so that the
#    commands and the password below are typed with the same layout the
#    installed system's console will use (Caps is Backspace here, Ctrl later)
loadkeys colemak

# 1. partition and mount the target at /mnt (UEFI: an ESP mounted at /mnt/boot)

# 2. generate the hardware config and make it visible to the flake
nixos-generate-config --root /mnt
mkdir -p /etc/nixos
cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/

# 3. install this config straight from GitHub
nixos-install --flake github:<you>/nixos-bootstrap#bootstrap --impure --no-root-password

# 4. a console password for your user (SSH logins use the key, not a password)
nixos-enter --root /mnt -c 'passwd adam'

reboot
```

`--impure` is needed because the config imports
`/etc/nixos/hardware-configuration.nix` by absolute path, the same way the
private config does, so the private config keeps working after the switch.

Then:

```sh
ssh adam@<ip>
adopt-config <you>/<private-repo> [host]     # host defaults to "server"
```

## Apple Silicon (Asahi)

Follow upstream's guide for everything up to and including `nixos-install`:
<https://github.com/nix-community/nixos-apple-silicon/blob/main/docs/uefi-standalone.md>
(Asahi installer `alx.sh` in macOS, the installer ISO from that project's
releases, the partitioning with `sgdisk`, the stock `configuration.nix`
with `hardware.asahi.enable`, `canTouchEfiVariables = false`, iwd Wi-Fi and
the `hid_apple` keyboard fix). Add a user for yourself in that stock config,
with a password, so you can log in. Do **not** use this flake for the install
itself. Reason: `nixos-install` only copies the kernel from the installer ISO
when the installed nixpkgs matches the ISO's. With a flake pinning its own
nixpkgs, it tries to compile the Asahi kernel inside the installer, which
upstream calls "generally not possible due to memory limitations" and needs
30 GB+ of scratch space.

After the first boot, get on Wi-Fi (`nmtui`, or `iwctl` if you did not enable
NetworkManager) and run the helper straight from this repo, with no bootstrap
installed:

```sh
nix run --extra-experimental-features 'nix-command flakes' \
  github:<you>/nixos-bootstrap#adopt-config -- <you>/<private-repo> [host]   # host defaults to "home"
```

The switch builds the kernel on the installed disk, where there is room. The
`bootstrap-asahi` output pins the kernel to the same nixpkgs revision and
`nixos-apple-silicon` commit as the private config, so the kernel it describes
is identical to the private one and is not built twice. Use
`nixos-rebuild switch --flake github:<you>/nixos-bootstrap#bootstrap-asahi --impure`
only for a machine that already has that kernel, for example to repair a
system that lost its config.

## Things to know before running it

- **Asahi, first switch:** the stock install uses the installer ISO's kernel,
  which is not the pinned one. The first `adopt-config` switch therefore
  compiles the Asahi kernel on the installed disk: plan for 30 GB+ of free
  space and a long build. "Not built twice" only holds between
  `bootstrap-asahi` and the private config.
- **Wi-Fi:** the installer's Wi-Fi settings are not carried over. After the
  first boot use `nmtui` (or plug in ethernet).
- **Repo name:** the private repo is cloned to `~/repos/me/<repo>`. Paths in
  the private config may point at a fixed location, so name the repo to match
  (Adam's is `dotfiles`).
- **SSH after the switch:** this config is key-only. The private config only
  keeps that if it says so itself (Adam's `server` host does; `home` does not,
  and gets password logins back).
- **Git credentials:** the login `adopt-config` sets up lives in your global
  git config. If the private config manages git (home-manager), the switch
  replaces it; set the remote back to SSH afterwards.
- **`--impure` with `nixos-install`:** this is listed in `nixos-install --help`
  on a current NixOS, but has not been run on an installer ISO.

## adopt-config

`adopt-config OWNER/REPO [HOST]` signs in with `gh auth login --web` (it prints
a code and a URL to open on any other device, so it works on a headless
machine), sets git to use that login, clones the private repo to
`~/repos/me/<repo>` (or fast-forwards it if it is already there), and runs `sudo nixos-rebuild switch --flake .#<host>
--impure`. HOST defaults to `server` on x86_64 and `home` on aarch64.

The clone uses HTTPS. If your private repo's remote is normally SSH, switch it
afterwards with `git remote set-url origin git@github.com:<you>/<repo>.git`.

The private config must list the same SSH public key (authorized keys are
managed declaratively, so a switch to a config without it removes key
logins), and should import the same hardware-configuration.nix path.

## Limits and what has not been tested

- Only evaluated, never run: the install steps, `adopt-config`'s GitHub login
  and clone, and the `bootstrap`/`bootstrap-asahi` systems themselves. On an
  aarch64 machine the x86_64 system cannot be built; the aarch64 one was only
  evaluated, not built.
- Verified: both systems evaluate; `adopt-config` builds and passes
  shellcheck; the Asahi kernel derivation is identical to the private
  config's.
- The Asahi steps are upstream's, summarised, and may change: read their
  guide for the current version.
