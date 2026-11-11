# Apple Silicon Mac running Asahi Linux (aarch64). The Asahi installer (alx.sh)
# and the nixos-apple-silicon installer ISO are prerequisites; see README.md.
# Imports the hardware-configuration.nix from /etc/nixos, so build with --impure
# (that also lets the module find the peripheral firmware under /boot/vendorfw).
{ inputs, config, lib, ... }:
{
  imports = [
    /etc/nixos/hardware-configuration.nix
    inputs.nixos-apple-silicon.nixosModules.apple-silicon-support
  ];

  hardware.asahi.enable = true;

  # Same kernel pin as the private config (nixpkgs-kernel is the same nixpkgs
  # revision), so switching to it reuses this kernel instead of rebuilding it.
  # The kernel is never in a binary cache and compiling it needs 30 GB+ of
  # scratch space: not possible inside the installer, which is why README.md
  # installs Asahi with the stock config first.
  boot.kernelPackages = lib.mkForce (
    (import inputs.nixpkgs-kernel {
      system = "aarch64-linux";
      overlays = [ config.hardware.asahi.overlay ];
    }).linux-asahi.override { _kernelPatches = config.boot.kernelPatches; }
  );

  nixpkgs.hostPlatform = "aarch64-linux";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  # U-Boot has no writable EFI variables: this MUST be false or the bootloader
  # install fails.
  boot.loader.efi.canTouchEfiVariables = false;

  # Apple keyboards report an ISO layout that swaps ` and <; this undoes it.
  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0
  '';

  networking.hostName = "nixos-bootstrap";
  # Wi-Fi is the only link. iwd, because the Broadcom chips need WPA3, which
  # wpa_supplicant does not support here (the NetworkManager module enables
  # iwd itself when this is set).
  networking.networkmanager.wifi.backend = "iwd";
}
