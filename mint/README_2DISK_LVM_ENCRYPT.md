# WARNING: All your data will be deleted!!!

# boot from Mint medium

# Shell

## get disks (in thix examle sda and sdb
```
sudo fdisk -l
```
# Delete partition tables and boot sectors of the existing disks
```
sudo dd if=/dev/zero of=/dev/sda bs=1M count=1
sudo dd if=/dev/zero of=/dev/sdb bs=1M count=1
```
Maybe a reboot here is better to get easily rid of opened devices
## partitions withparted
```
# /dev/sda
sudo parted -s /dev/sda mklabel gpt
sudo parted -s /dev/sda mkpart primary fat32 1MiB 513MiB
sudo parted -s /dev/sda set 1 esp on
sudo parted -s /dev/sda mkpart primary ext4 513MiB 1537MiB
sudo parted -s /dev/sda mkpart primary 1537MiB 100%
sudo parted -s /dev/sda set 3 lvm on

# /dev/sdb
sudo parted -s /dev/sdb mklabel gpt
sudo parted -s /dev/sdb mkpart primary 1MiB 100%
sudo parted -s /dev/sdb set 1 lvm on

# reload of kernel partitiontable
sudo partprobe /dev/sda
sudo partprobe /dev/sdb
```

## format EFI
```
sudo mkfs.fat -F32 /dev/sda1
```
## add both drives to one logical drive with LVM
```
sudo pvcreate /dev/sda3
sudo pvcreate /dev/sdb1
sudo vgcreate vg_mint /dev/sda3 /dev/sdb1
sudo lvcreate -l 100%FREE -n lv_root vg_mint
```
# Linux Mint installer
1. Start the Linux Mint installer.
2. Select “Something else” for partitioning.
3. Right click on 2nd `/dev/mapper/vg_mint-lv_root` -> Change -> Use as: "Physical volume for encryption" -> Set PW
4. Right click on 2nd `/dev/mapper/vg_mint-lv_root_crypt` -> Change -> Use as: "Ext4 journaling file system" -> Mount point: `/`
5. /dev/sda1 should already be defined as EFI
6. Right click on `/dev/sda2` -> Change -> Use as: "Ext4 journaling file system" -> Mount point: `/boot` -> check "Format the partition"
7. go on normal installation
8. possibly use "Log in automatically" without "Encrypt my home folder" because the LVM volume underneath is already encrypted and asking for password.
10. reboot

# Lower root reserve
```
sudo tune2fs -m0.1 /dev/mapper/vg_mint-lv_root_crypt
```
