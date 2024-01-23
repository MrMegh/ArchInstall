#!/bin/bash

# Check if iwctl is available
if ! command -v iwctl &> /dev/null; then
    echo "Error: iwctl not found. Please install it before running this script."
    exit 1
fi

# Check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root. Please use sudo."
    exit 1
fi

# Check if a network interface is already connected
connected_interface=$(ip link | grep "state UP" | awk -F: '{print $2}' | tr -d ' ')
if [ -n "$connected_interface" ]; then
    echo "Already connected via $connected_interface."
    exit 0
fi

# Get a list of available Wi-Fi devices
wifi_devices=$(iwctl device list | grep "Device" | awk '{print $2}')

# Check if there are multiple Wi-Fi devices
if [ $(echo "$wifi_devices" | wc -l) -gt 1 ]; then
    echo "Multiple Wi-Fi devices found:"
    awk '{print NR".", $0}' <<< "$wifi_devices"
    
    read -p "Enter the number of the Wi-Fi device to use: " device_number
    selected_device=$(awk -v num="$device_number" 'NR==num {print $2}' <<< "$wifi_devices")
else
    # If only one device is available, select it automatically
    selected_device=$wifi_devices
fi

# Use iwctl to configure Wi-Fi for the selected device
iwctl station "$selected_device" connect

# Prompt user to choose a desktop environment
echo "Choose a desktop environment to install:"
echo "1. KDE Plasma with SDDM"
echo "2. GNOME with GDM"
echo "3. XFCE4 with SDDM"

read -p "Enter the number of your choice: " desktop_choice

case $desktop_choice in
    1)
        desktop_environment="kde-plasma-desktop sddm"
        ;;
    2)
        desktop_environment="gnome gdm"
        ;;
    3)
        desktop_environment="xfce4 sddm"
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Store the selected desktop environment for later use
echo "Selected desktop environment: $desktop_environment" > desktop_environment.txt

# Prompt user for installation password
read -p "Enter the password for the installation: " installation_password

# Ask if the user wants to change the root password
read -p "Do you want to change the root password? (yes/no): " change_root_password

if [ "$change_root_password" == "yes" ]; then
    read -p "Enter the new root password: " root_password
else
    # Use the installation password as the root password
    root_password="$installation_password"
fi

# Store the root password for later use
echo "Root password: $root_password" > root_password.txt

# Prompt user for time zone
timedatectl list-timezones
read -p "Enter your desired time zone: " time_zone

# Store the selected time zone for later use
echo "Time zone: $time_zone" > time_zone.txt

# Prompt user for additional packages
read -p "Enter any additional packages you want to install (space-separated): " additional_packages

# Store the additional packages for later use
echo "Additional packages: $additional_packages" > additional_packages.txt

# Prompt user about swap
read -p "Do you want to include a swap partition? (yes/no, default is yes): " include_swap

# List available disks and their sizes
echo "Available disks:"
lsblk -d -o NAME,SIZE -n

read -p "Enter the disk to install Arch Linux (e.g., sda): " install_disk

# Confirm the selection with the user
read -p "Are you sure you want to install Arch Linux on $install_disk? (yes/no): " confirm_install_disk

if [ "$confirm_install_disk" != "yes" ]; then
    echo "Aborted installation. Exiting."
    exit 1
fi

# Format the selected disk with a simple Btrfs partition scheme
echo "Formatting $install_disk with Btrfs file system..."
umount "/dev/${install_disk}"* 2>/dev/null # Unmount any existing partitions
wipefs --all "/dev/${install_disk}"* 2>/dev/null # Wipe existing filesystem signatures

# Create a single Btrfs partition covering the whole disk
parted -s "/dev/${install_disk}" mklabel gpt
parted -s -a optimal "/dev/${install_disk}" mkpart primary btrfs 0% 100%

# Format the Btrfs partition
mkfs.btrfs "/dev/${install_disk}1"

# Mount the Btrfs partition
mount "/dev/${install_disk}1" /mnt

# If the user chose to include swap, create a swapfile
if [ "$include_swap" == "yes" ]; then
    echo "Creating swapfile..."
    dd if=/dev/zero of=/mnt/swapfile bs=1M count=2048 status=progress
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile
fi

# Continue with the Arch Linux installation process...

echo "Wi-Fi configuration, desktop environment choice, password setup, time zone selection, additional packages selection, disk formatting, and swap setup completed. Continue with the Arch Linux installation."
