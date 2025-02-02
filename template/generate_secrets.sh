#!/run/current-system/sw/bin/bash

mkdir secrets && cd secrets

echo "Generating Rook Passphrase..."
nix run nixpkgs#openssl -- rand -hex 64 > root_passphrase

echo "Generating Data Passphrase..."
nix run nixpkgs#openssl -- rand -hex 64 > data_passphrase

echo "Generating HostID..."
uuidgen | head -c 8 > hostid

echo "Generating SSH Private and Public Keys..."
ssh-keygen -t ed25519 -N "" -f ssh_skarabox && chmod 600 ssh_skarabox

echo "Generating Age Key..."
nix run nixpkgs#ssh-to-age -- -private-key -i ./ssh_skarabox -o ./age_skarabox.sops

echo "Generating Public Age Key..."
nix run nixpkgs#ssh-to-age -- -i ./ssh_skarabox.pub -o ./age_skarabox.sops.pub