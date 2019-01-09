#!/bin/sh
GPU=41:00
videobusid="0000:${GPU}.0"
videoid="10de 1b06"
audiobusid="0000:${GPU}.1"
audioid="10de 10ef"
USB=42:00.3
USBBUS="0000:${USB}"
USBID="1022 145c"
USB2=08:00.3
USB2BUS="0000:${USB2}"
USB2ID="1022 145c"
OBAUDIO=09:00.3
OBAUDIOBUS="0000:${OBAUDIO}"
OBAUDIOID="1022 1457"
WIN10="-drive file=w10.qcow2,media=disk,format=qcow2,if=virtio,cache=writeback,l2-cache-size=39321600"

## Remove the framebuffer and console
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

# Unload the Kernel Modules that use the GPU
modprobe -r nvidia_drm
modprobe -r nvidia_modeset
modprobe -r nvidia
modprobe -r snd_hda_intel

# Load the kernel module
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio-pci

## Detach the GPU
echo $videoid > /sys/bus/pci/drivers/vfio-pci/new_id
echo $videobusid > /sys/bus/pci/devices/$videobusid/driver/unbind
echo $videobusid > /sys/bus/pci/drivers/vfio-pci/bind
echo $videoid > /sys/bus/pci/drivers/vfio-pci/remove_id

echo $audioid > /sys/bus/pci/drivers/vfio-pci/new_id
echo $audiobusid > /sys/bus/pci/devices/$audiobusid/driver/unbind
echo $audiobusid > /sys/bus/pci/drivers/vfio-pci/bind
echo $audioid > /sys/bus/pci/drivers/vfio-pci/remove_id

## Detach the USB controllers
echo $USBID > /sys/bus/pci/drivers/vfio-pci/new_id
echo $USBBUS > /sys/bus/pci/devices/$USBBUS/driver/unbind
echo $USBBUS > /sys/bus/pci/drivers/vfio-pci/bind
echo $USBID > /sys/bus/pci/drivers/vfio-pci/remove_id

echo $USB2ID > /sys/bus/pci/drivers/vfio-pci/new_id
echo $USB2BUS > /sys/bus/pci/devices/$USB2BUS/driver/unbind
echo $USB2BUS > /sys/bus/pci/drivers/vfio-pci/bind
echo $USB2ID > /sys/bus/pci/drivers/vfio-pci/remove_id

## Detach onboard audio
echo "1022 1455" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "0000:09:00.0" > /sys/bus/pci/drivers/vfio-pci/bind
echo "1022 1455" > /sys/bus/pci/drivers/vfio-pci/remove_id

echo ${OBAUDIOID} > /sys/bus/pci/drivers/vfio-pci/new_id
echo ${OBAUDIOBUS} > /sys/bus/pci/devices/${OBAUDIOBUS}/driver/unbind
echo ${OBAUDIOBUS} > /sys/bus/pci/drivers/vfio-pci/bind
echo ${OBAUDIOID} > /sys/bus/pci/drivers/vfio-pci/remove_id

# echo 1 > /sys/module/kvm/parameters/ignore_msrs
qemu-system-x86_64 -enable-kvm \
		   -cpu host,kvm=off,hv_relaxed,hv_spinlocks=0x1fff,hv_time,hv_vapic,hv_vendor_id=0xDEADBEEFFF \
		   -m 24G \
		   -smp cores=8 \
		   -nographic -vga none -parallel none -serial none \
		   -rtc base=localtime \
		   -drive if=pflash,format=raw,readonly,file=OVMF_CODE.fd \
		   -drive if=pflash,format=raw,file=OVMF_VARS.fd \
		   -device vfio-pci,host=${GPU}.0,multifunction=on,x-vga=on,romfile=/home/csegale/VM/vc_roms/patched/1080ti_armored_patched.rom \
		   -device vfio-pci,host=${GPU}.1 \
		   -device vfio-pci,host=${USB} \
		   -device vfio-pci,host=${USB2} \
		   -device vfio-pci,host=${OBAUDIO} \
		   ${WIN10} 2> qemu_errors.txt &
wait
sleep 1

## Unbind USB controller from VFIO
echo $USBBUS > /sys/bus/pci/devices/$USBBUS/driver/unbind

## Reload USB Kernel Module

echo $USBBUS > /sys/bus/pci/drivers/xhci_hcd/bind
echo $USB2BUS > /sys/bus/pci/drivers/xhci_hcd/bind

## Unbind GPU from vfio
echo -n "${videobusid}" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "${audiobusid}" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "${videoid}" > /sys/bus/pci/drivers/vfio-pci/remove_id
echo -n "${audioid}" > /sys/bus/pci/drivers/vfio-pci/remove_id

## Unbind onboard audio from VFIO
echo -n "0000:09:00.0" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "1022 1455" > /sys/bus/pci/drivers/vfio-pci/remove_id

echo -n "${OBAUDIOBUS}" > /sys/bus/pci/drivers/vfio-pci/unbind
echo -n "${OBAUDIOID}" > /sys/bus/pci/drivers/vfio-pci/remove_id

## Unload vfio modules
modprobe -r vfio
modprobe -r vfio_iommu_type1
modprobe -r vfio-pci
sleep 1

## Load nvidia modules
modprobe  nvidia_drm
modprobe  nvidia_modeset
modprobe  nvidia
modprobe  snd_hda_intel
sleep 1

## Rebind GPU
echo -n "${videobusid}" > /sys/bus/pci/drivers/nvidia/bind
echo -n "${audiobusid}" > /sys/bus/pci/drivers/snd_hda_intel/bind

sleep 1
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind
