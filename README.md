kali-linux-recipes (tweaked to work on ARM)
==================

A work around for the Live Build Config tool breaking the grub menu option when creating a Live Boot image ISO's on ARM devies. Working off of @g0tmi1k's example scripts for customizing the Live Build Config environment, here are a collection of tweaks that leverage the 'kali-config/common/includes.installer/kali-finish-install' hook script (instead of 'kali-config/variant-...' folders) to customize the Kali environment and build a "Full Install" ISO image. These scripts will run as expected on both ARM and non-ARM architectures successfully implementing desired customizations over the less reliable variant folder method.

An issue has been raised by the Kali Linux team on the Live Build bug tracker to address the flaw in the Live Build utility when running on ARM devices, so this work around will hopefully not be needed for long.
