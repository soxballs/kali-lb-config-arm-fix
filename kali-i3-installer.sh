#!/usr/bin/env bash
## Create a Kali rolling i3 full installer image, using kali-finish-install hook to drive 
## non-metapackage package installs and the i3 Display Environment.
## Updated: 2024-12-20
## Author: soxballs
## Based on: Kali build script examples by g0tmi1k - https://gitlab.com/kalilinux/recipes/live-build-config-examples.git
## as well as various content from arszilla (https://gitlab.com/Arszilla/kali-i3.git) and
## Kali Team Live Build guides (https://www.kali.org/docs/development/live-build-a-custom-kali-iso).
#
## Example:
##   $ curl "https://raw.githubusercontent.com/soxballs/lb-config-arm-tweaks/refs/heads/main/kali-i3-installer.sh" | sh
#

## Exit on issue
set -e

## Make sure we have programs needed
sudo apt-get update
sudo apt-get install -yqq git live-build simple-cdd cdebootstrap curl

## Get base-image build-script
if [ -e "/opt/kali-builder/" ]; then
  sudo rm -rf /opt/kali-builder/
fi
sudo git clone https://gitlab.com/kalilinux/build-scripts/live-build-config.git /opt/kali-builder/
cd /opt/kali-builder/

##
## Generate required files
##

## Select package options for installer
sudo mkdir kali-config/installer-i3
cat <<'EOF' | sudo tee kali-config/installer-i3/packages >/dev/null
## Desktop environment packages
kali-desktop-headless

## Metapackages
kali-linux-firmware
kali-linux-core
kali-tools-top10
kali-linux-default
EOF

## Update the default variant to i3
cd kali-config
sudo unlink variant-default
sudo ln -s variant-i3 variant-default
cd ..

## Select packages for image (Chroot)
cat <<'EOF' | sudo tee kali-config/variant-i3/package-lists/kali.list.chroot >/dev/null
## Desktop environment packages
# i3 gets installed through the kali-finish-install hook sine it doesn't show up 
# as a Display package option during the install.

## Metapackages
kali-linux-core
kali-linux-firmware
kali-linux-default
kali-tools-top10
EOF

## Modify stock kali-finish-install script
cat <<'EOF' | sudo tee kali-config/common/includes.installer/kali-finish-install >/dev/null
#!/bin/sh

# The reference version of this script is maintained in
# ./live-build-config/kali-config/common/includes.installer/kali-finish-install
#
# It is used in multiple places to finish configuring the target system
# and build.sh copies it where required (in the simple-cdd configuration
# and in the live-build configuration).

configure_sources_list() {
    if grep -q '^deb ' /etc/apt/sources.list; then
	echo "INFO: sources.list is configured, everything is fine"
	return
    fi

    echo "INFO: sources.list is empty, setting up a default one for Kali"

    cat >/etc/apt/sources.list <<END
# See https://www.kali.org/docs/general-use/kali-linux-sources-list-repositories/
deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware

# Additional line for source packages
# deb-src http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware
END
    apt-get update
}

get_user_list() {
    for user in $(cd /home && ls); do
	if ! getent passwd "$user" >/dev/null; then
	    echo "WARNING: user '$user' is invalid but /home/$user exists" >&2
	    continue
	fi
	echo "$user"
    done
    echo "root"
}

configure_zsh() {
    if grep -q 'nozsh' /proc/cmdline; then
	echo "INFO: user opted out of zsh by default"
	return
    fi
    if [ ! -x /usr/bin/zsh ]; then
	echo "INFO: /usr/bin/zsh is not available"
	return
    fi
    for user in $(get_user_list); do
	echo "INFO: changing default shell of user '$user' to zsh"
	chsh --shell /usr/bin/zsh $user
    done
}

configure_usergroups() {
    # Ensure those groups exist
    addgroup --system kaboxer || true
    addgroup --system wireshark || true

    # adm - read access to log files
    # dialout - for serial access
    # kaboxer - for kaboxer
    # vboxsf - shared folders for virtualbox guest
    # wireshark - capture sessions in wireshark
    kali_groups="adm dialout kaboxer vboxsf wireshark"

    for user in $(get_user_list | grep -xv root); do
	echo "INFO: adding user '$user' to groups '$kali_groups'"
	for grp in $kali_groups; do
	    getent group $grp >/dev/null || continue
	    usermod -a -G $grp $user
	done
    done
}

configure_i3() {
  # Install i3 here since it doesn't work in packages file
  apt install kali-desktop-i3 i3-dotfiles -y

  # Copy i3 dotfiles to /etc/skel/ for installer
  rsync -a /usr/share/i3-dotfiles/etc/skel/ /etc/skel/

  # Copy i3 dotfiles to /root/ for installer
  rsync -a /usr/share/i3-dotfiles/etc/skel/ /root/
}

configure_sources_list
configure_zsh
configure_usergroups
configure_i3
EOF
sudo chmod +x kali-config/common/includes.installer/kali-finish-install

## Local mirror
#echo "http://192.168.1.123/kali" | sudo tee .mirror >/dev/null

## Build image
sudo ./build.sh \
  --debug \
  --variant i3 \
  --installer

## Output
ls -lh ./images/*.iso

## Done
echo "[i] Done"
exit 0