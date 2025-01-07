# WARNING: All your data will be deleted!!!

# boot from Mint medium

# Shell

## become root
```
sudo -i
```
## get disks (in thix examle sda and sdb
```
fdisk -l
```
# Delete partition tables and boot sectors of the existing disks
```
dd if=/dev/zero of=/dev/sda bs_1m count=1
dd if=/dev/zero of=/dev/sdb bs_1m count=1
```
## gparted
```
# dev   size  type
- sda1  512M  EFI
- sda2  1G    Linux
- sda3  REST  LVM
```

## format EFI
```
sudo mkfs.fat -F32 /dev/sda1
```
## add both drives to one logical drive with LVM
```
pvcreate /dev/mapper/sda3
pvcreate /dev/mapper/sdb1
vgcreate vg_mint /dev/mapper/sda3 /dev/mapper/sdb1
lvcreate -l 100%FREE -n lv_root vg_mint
```
# Linux Mint installer
1. Start the Linux Mint installer.
2. Select “Something else” for partitioning.
3. Right click on lc_root -> Encrypted volume
4. format new created crypt volume with ext4 and mount /
5. use /dev/sda1 as EFI
6. format /dev/sda2 with ext4 and mount /boot
7. go on normal installation
8. possibly use user autologin and home without encryption because the LVM volume underneath is already encrypted.
9. reboot

# Lower root reserve
```
tune2fs -m0.1 /dev/mapper/vg_mint-lv_root_crypt
```