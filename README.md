# SkaraboxOS

SkaraboxOS is an opinionated and simplified headless NixOS installer.

It provides a flake [template](./template) which combines:
- Creating a bootable ISO, installable on an USB key.
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) to install NixOS headlessly.
- [disko](https://github.com/nix-community/disko) to format the drives using native ZFS encryption with remote unlocking through SSH.
- [sops-nix](https://github.com/Mic92/sops-nix) to handle secrets.
- [deploy-rs](https://github.com/serokell/deploy-rs) to deploy updates.

This repository does not invent any of those wonderful tools.
It merely provides an opinionated way to make them all fit together for a seamless experience.

## Why?

Because the landscape of installing NixOS could be better and this repository is an attempt at that.
By being more opinionated, it allows you to get setup faster.

> [!NOTE]
> The name SkaraboxOS comes from the scarab (the animal), box (for the server) and OS (for Operating System).
Scarab is spelled with a _k_ because it's kool.
A scarab is a _very_ [strong](https://en.wikipedia.org/wiki/Dung_beetle#Ecology_and_behavior) animal representing well what this repository's intention.

## Prerequisites
Just like every project, there will need to be some things you will need to have/know before you can successfully install SkaraboxOS:
1. Nix already installed on a laptop/desktop/server.
2. A computer/server you would like to install SkaraboxOS on.
3. A USB Key  
   - Recommended to be bigger than 16 GB.
4. An Internet Connection.
   - Both devices will need to be networked so you can connect via SSH.


## Hardware Requirements

SkaraboxOS expects a particular hardware layout:

- 1 SSD or NVMe drive for the OS.
- 0 or 2 Hard drives that will store data.
  - Capacity depends on the amount of data that will be stored. They will be formatted in Raid 1 (mirror) so each hard drive should have the same size.
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

> [!WARNING]
> The 1-3 disks will be formatted and completely wiped out of data.

## Installation Process Overview

 
1. Write ISO to USB Key
2. Boot server from USB key 
4. Gather Configuration Requirements
5. Download the Flake Template
6. Perform Configuration Changes
7. Done!

At the end of the process, the server will:
- Have an encrypted ZFS root partition using the NVMe drive, unlockable remotely through SSH.
- Have an encrypted ZFS data mirror on hard drives.
  - If 2 hard drives was chosen.
- Be accessible through SSH for administration and updates.

Services can then be installed by using NixOS options directly or, through [Self Host Blocks](https://github.com/ibizaman/selfhostblocks). Similarly to SkaraboxOS, Self Host Blocks provide an opinionated way to configure services in a seamless way.

> [!CAUTION]
> Proceeding with the following steps WILL ERASE THE CONTENT for the following devices:
> - Data on USB Key.
> - Data on Server hard drives.

## Installation

### 1. Generate ISO

Execute the following command to create the `.iso` file:

```bash
$ nix build github:ibizaman/skarabox#beacon
```

### 2. Write ISO to USB Key

1. Run USB Imager with the following command:

```bash
$ nix run nixpkgs#usbimager
```
2. Select `./result/iso/beacon.iso` file in row 1 (`...`).
3. Select USB key in row 3.

> [!IMPORTANT]
> Executing the next command will erase the USB Key!

4. Click write (arrow down) in row 2.

### 3. Boot server from USB key

With the server off; plug the USB stick in the server, hit the start button, and change the boot order (selecting USB Key as primary).

On first boot up, you will be logged in automatically with user `nixos`.

> [!NOTE]
> We have not installed SkaraboxOS on the system yet, we only just booted into a Live Environment.

### 4. Gather Configuration Requirements

We will need the note the following pieces of information:
 - IP Address
 - Disk Layout
 
Upon bootup, instructions will be at the top of the screen.

> [!NOTE]
> If there are no instructions, simply reboot the system.

### 5. Download Flake Template

Create a directory and download the template.

```bash
$ mkdir myskarabox
$ cd myskarabox
$ nix flake init --template github:ibizaman/skarabox
```

### 6. Perform Configuration Changes

Open the new `flake.nix` file and generate whatever it needs.
Also, open the other files and see how to generate them too.
All the instructions are included.

Note the `root_passphrase` file will contain a passphrase that will need to be provided every time the server boots up.

3. Run the following command replacing `<ip>` with the IP address you got in the previous step.

```bash
$ nix run github:nix-community/nixos-anywhere -- \
  --flake '.#skarabox' \
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

## Post Installation Checklist

These items act as a checklist that you should go through to make sure your installation is robust.
How to proceed with each item is highly dependent on which hardware you have so it is hard for Skarabox to give a detailed explanation here.
If you have any question, don't hesitate to open a [GitHub issue](https://github.com/ibizaman/skarabox/issues/new).

### Secrets with SOPS

To setup secrets with SOPS, you must retrieve the box's host key with:

```bash
$ ssh-keyscan -p 22 -t ed25519 -4 <ip>
<ip> ssh-ed25519 AAAAC3NzaC1lXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Then transform it to an `age` key with:

```bash
$ nix shell nixpkgs#ssh-to-age --command sh -c "echo ssh-ed25519 AAAAC3NzaC1lXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX | ssh-to-age"
age10gclXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Finally, allow that key to decrypt the secrets file:

```bash
SOPS_AGE_KEY_FILE=sops.key \
  nix run --impure nixpkgs#sops -- --config .sops.yaml -r -i \
  --add-age "age10gclXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" \
  secrets.yaml
```

### Domain Name

Get your external IP Address by connecting to your home network and going to [https://api.ipify.org/](https://api.ipify.org/).

- Buy a cheap domain name.
  I recommend [https://porkbun.com/](https://porkbun.com/) because I use it and know it works but others work too.
- Configure the domain's DNS entries to have:
  - A record: Your domain name to your external IP Address.
  - A record: `*` (yes, a literal "asterisk") to your external IP Address.

To check if this setup works, you will first need to go through the step below too.

### Router Configuration

These items should happen on your router.
Usually, connecting to it is done by entering one of the following IP addresses in your browser: `192.168.1.1` or `192.168.1.254`.

- Reduce the DHCP pool to the bounds .100 to .200, inclusive.
  This way, you are left with some space to statically allocate some IPs.
- Statically assign the IP address of the server.
- Enable port redirection for ports to the server IP:
  - 80 to 80.
  - 443 to 443.
  - A random port to 22 to be able to SSH into your server from abroad.
  - A random port to 2222 to be able to start the server from abroad.

To check if this setup works,
you can connect to another network (like using the tethered connection from your phone or connecting to another WiFi network)
and then SSH into your server like above,
but instead of using the IP address, use the domain name:

```bash
$ ssh -p 22 skarabox@<domainname> -o IdentitiesOnly=yes -i ssh_skarabox
```

### Add Services

I do recommend using the sibling project [Self Host Blocks](https://github.com/ibizaman/selfhostblocks) to setup services like Vaultwarden, Nextcloud and others.

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