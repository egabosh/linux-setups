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
dd if=/dev/zero of=/dev/sda bs=1M count=1
dd if=/dev/zero of=/dev/sdb bs=1M count=1
```
Maybe a reboot here is better to get easily rid of opened devices
## partitions withparted
```
# /dev/sda
parted -s /dev/sda mklabel gpt
parted -s /dev/sda mkpart primary fat32 1MiB 513MiB
parted -s /dev/sda set 1 esp on
parted -s /dev/sda mkpart primary ext4 513MiB 1537MiB
parted -s /dev/sda mkpart primary 1537MiB 100%
parted -s /dev/sda set 3 lvm on

# /dev/sdb
parted -s /dev/sdb mklabel gpt
parted -s /dev/sdb mkpart primary 1MiB 100%
parted -s /dev/sdb set 1 lvm on

# reload of kernel partitiontable
partprobe /dev/sda
partprobe /dev/sdb
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
