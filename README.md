# SkaraboxOS

SkaraboxOS is an opinionated and simplified headless NixOS installer.

It provides a flake [template](./template) which combines:
- Creating a bootable ISO, installable on an USB key.
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) to install NixOS headlessly.
- [disko](https://github.com/nix-community/disko) to format the drives.
- [sops-nix](https://github.com/Mic92/sops-nix) to handle secrets.
- [deploy-rs](https://github.com/serokell/deploy-rs) to deploy updates.

This repository does not invent any of those wonderful tools.
It merely provides an opinionated way to make them all fit together for a seamless experience.

## Hardware Requirements

SkaraboxOS expects a particular hardware layout:

- 1 SSD or NVMe drive for the OS.
- 2 Hard drives that will store data.
  Capacity depends on the amount of data that will be stored.
  They will be formatted in Raid 1 (mirror) so each hard drive should have the same size.
<!--
This is for Self Host Blocks.

- 16Gb or more of RAM.
- AMD or Intel CPU with embedded graphics.
  (Personally using AMD Ryzen 5 5600G with great success).
- *Work In Progress* Optional graphics card.
  Only needed for speech to text applications like for Home Assistant.
- Internet access is optional.
  It is only required:
  - for updates;
  - for accessing services from outside the LAN;
  - for federation (to share documents or pictures across the internet).
-->

**WARNING: The 3 disks will be formatted and completely wiped out of data.**

## Installation Process Overview

1. Download the flake template.
2. Generate a ISO and format a USB key.
3. Boot server on USB key and get its IP address.
4. Generate secrets on laptop, update some default values.
5. Run installer from laptop.
6. Done!

At the end of the process, the server will:
- Have an encrypted ZFS root partition using the NVMe drive, unlockable remotely through ssh.
- Have an encrypted ZFS data hard drives.
- Be accessible through ssh for administration and updates.

Services can then be installed by using NixOS options directly or through [Self Host Blocks](https://github.com/ibizaman/selfhostblocks).
The latter, similarly to SkaraboxOS, provides an opinionated way to configure services in a seamless way.

## Caution

Following the steps WILL ERASE THE CONTENT of any disk on that server.

## Installation

1. Boot on the NixOS installer. You just need to boot, no need to install.

   1. First, create the .iso file.

   ```bash
   $ nix build github:ibizaman/skarabox#beacon
   ```

   2. Copy the .iso file to a USB key. This WILL ERASE THE CONTENT of the USB key.

   ```bash
   $ nix run nixpkgs#usbimager
   ```

   - Select `./result/iso/beacon.iso` file in row 1 (`...`).
   - Select USB key in row 3.
   - Click write (arrow down) in row 2.

   3. Plug the USB stick in the server. Choose to boot on it.

   You will be logged in automatically with user `nixos`.

   4. Note down the IP address of the server. For that, follow the steps that appeared when booting
      on the USB stick.

2. Connect to the installer and install

   1. Create a directory and download the template.

   ```bash
   $ mkdir myskarabox
   $ cd myskarabox
   $ nix flake init --template github:ibizaman/skarabox
   ```

   2. Open the new `flake.nix` file and generate whatever it needs.
   Also, open the other files and see how to generate them too.
   All the instructions are included.

   Note the `root_passphrase` file will contain a passphrase that will need to be provided every time the server boots up.

   3. Run the following command replacing `<ip>` with the IP address you got in the previous step.

   ```bash
   $ nix run github:nix-community/nixos-anywhere -- \
     --flake .#skarabox' \
     --ssh-option "IdentitiesOnly=yes" \
     --disk-encryption-keys /tmp/root_passphrase root_passphrase \
     --disk-encryption-keys /tmp/data_passphrase data_passphrase \
     nixos@<ip>
   ```

   You will be prompted for a password, enter "skarabox123" without the double quotes.

   4. The server will reboot into NixOS on its own.

   5. Decrypt the SSD and the Hard Drives.

   Run the following command.

   ```bash
   $ ssh -p 2222 root@<ip> -o IdentitiesOnly=yes -i ssh_skarabox
   ```

   It will prompt you a first time to verify the key fingerprint.

   ```bash
   The authenticity of host '[<ip>]:2222 ([<ip>]:2222)' can't be established.
   ED25519 key fingerprint is SHA256:<redacted>.
   This key is not known by any other names.
   Are you sure you want to continue connecting (yes/no/[fingerprint])?
   ```

   Just enter `"yes"` followed by pressing on the Enter key.
   Next time the server will boot, you will not need to do this step.

   ```bash
   Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
   Warning: Permanently added '[<ip>]:2222' (ED25519) to the list of known hosts.
   ```

   You will be prompted a second time, this time to enter the root passphrase.
   Copy the content of the `root_passphrase` file and paste it and press Enter.
   No `*` will appear upon pasting but just press Enter.

   ```bash
   Enter passphrase for 'root':
   ```

   The connection will disconnect automatically.
   This is normal behavior.

   ```bash
   Connection to <ip> closed.
   ```

   Now, the hard drives are decrypted and the server continues to boot.

   It's a good idea to make sure you can login correctly, at least the first time.
   See next section.

## Normal Operations

   1. Login

   ```bash
   $ ssh -p 22 skarabox@<ip> -o IdentitiesOnly=yes -i ssh_skarabox
   ```

   2. Reboot

   ```bash
   $ ssh -p 22 skarabox@<ip> -o IdentitiesOnly=yes -i ssh_skarabox reboot
   ```

   You will then be required to decrypt the hard drives as explained above.

   3. Deploy an Update

   Modify the `./configuration.nix` file then run:

   ```bash
   nix run nixpkgs#deploy-rs
   ```

   4. Edit secrets

   ```bash
   nix run nixpkgs#sops secrets.yaml
   ```

## Contribute

To start a VM with the beacon, run:

```
nix run .#beacon-test
```

To test the installer, run:

```
nix run github:nix-community/nixos-anywhere -- --flake .#installer --vm-test
```

## Links

- https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/installation-device.nix
- https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/cd-dvd/installation-cd-base.nix
- https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/no-os.md#installing-on-a-machine-with-no-operating-system
