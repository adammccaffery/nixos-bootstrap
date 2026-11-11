# Ordinary x86_64 UEFI PC. Imports the hardware-configuration.nix that
# nixos-generate-config wrote to /etc/nixos, so build with --impure.
{ ... }:
{
  imports = [ /etc/nixos/hardware-configuration.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-bootstrap";
  hardware.enableRedistributableFirmware = true; # Wi-Fi/Bluetooth firmware
}
