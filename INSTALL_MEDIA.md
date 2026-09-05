# Talos installation media

## Pinned image

- Talos: `v1.12.12`
- Platform: `metal-amd64`
- File: `downloads/metal-amd64-v1.12.12.iso`
- Size: approximately 304 MB
- SHA-256: `6f29dcd27458bd766ae0b716e4e16aae5d9d6e1f1b954c54950ce2c5d6b6642c`
- Official URL: <https://github.com/siderolabs/talos/releases/download/v1.12.12/metal-amd64.iso>

The downloaded checksum matches the `metal-amd64.iso` entry in the official
`sha256sum.txt` for the release. The `downloads/` directory is ignored by Git.

This is the standard installer. Disable Secure Boot for the first build. Enabling
Secure Boot later requires the corresponding Secure Boot image and is best treated
as a separate learning exercise.

## JetKVM storage mount

1. Keep JetKVM powered independently from the target NUC if possible, so it remains
   reachable while the NUC is powered off or rebooting.
2. Connect JetKVM HDMI and USB to the target NUC and open the JetKVM interface.
3. Open **Mount Drive** and select **CD/DVD Mode** before mounting the image.
4. Choose **Storage mount**, upload
   `downloads/metal-amd64-v1.12.12.iso`, and mount it.
5. Reboot the NUC and use its one-time UEFI boot menu to select the JetKVM virtual
   CD/DVD device.
6. Wait for the Talos maintenance-mode screen. Merely booting the ISO runs Talos
   from memory; it does not install to the internal SSD until a machine
   configuration is applied.
7. After a successful installation and reboot from the internal SSD, unmount the
   virtual media so the node does not return to the installer.

If storage upload is inconvenient, JetKVM **URL mount** can stream the official URL
above. Storage mount is preferred for repeated installs because the image is local
to JetKVM and can run at its available USB speed.

## Physical USB stick on macOS

### Recommended reusable layout

For these UEFI mini PCs, Talos supports copying the **contents** of its ISO to a
FAT-formatted USB volume whose label begins with `TALOS_`. The USB may therefore
have more than one partition. The proposed layout for the 128 GB stick is:

| Partition | Format | Size | Purpose |
|---|---|---:|---|
| `TALOS_1` | FAT32 | 2 GB | UEFI-bootable Talos installer files |
| `DATA` | exFAT | Remaining space | ISOs, checksums, notes and other portable files |

This is preferable to writing the ISO over the whole device. It leaves most of the
stick useful and follows Talos' UEFI boot method without a third-party bootloader.
Repartitioning still deletes the current NTFS partition and all its files, so copy
anything needed elsewhere first.

Ventoy is another way to create a reusable multiboot USB, and Ventoy lists Talos
among its tested images. It adds another bootloader, however, and Talos documents
that third-party bootloaders are unsupported when an ISO contains an image cache.
Use the direct `TALOS_` FAT32 method for the primary recovery stick.

### Whole-device ISO method

Always identify the external physical device immediately before writing:

```sh
diskutil list external physical
```

At the time this file was written, macOS reported this candidate:

```text
/dev/disk5 (external, physical), 123.0 GB, label "128G Yellow"
```

Device numbers can change after unplugging or rebooting. Confirm the size and label
again; never reuse `/dev/disk5` from this note without checking.

The stick was prepared on 2026-09-05 with this verified layout:

```text
GPT
├── EFI       209.7 MB
├── TALOS_1     2.0 GB  FAT32; extracted Talos v1.12.12 boot files
└── DATA      120.8 GB  exFAT
```

`TALOS_1/EFI/BOOT/BOOTX64.EFI` was verified as an x86-64 EFI application, and
the partition contains `boot/vmlinuz` and `boot/initramfs.xz`.

After confirming the device, unmount it and copy the ISO to the raw disk. Replace
`diskN` with the freshly verified identifier:

```sh
diskutil unmountDisk /dev/diskN
sudo dd if=/Users/danquah/Work/Priv/Talos/rudtal/downloads/metal-amd64-v1.12.12.iso of=/dev/rdiskN bs=4m
sync
diskutil eject /dev/diskN
```

The `dd` command shows little or no output while copying on macOS. Press `Ctrl-T`
to request a progress line without stopping it. Wait for the final byte count and
for `diskutil eject` to succeed before removing the stick.

Writing the image replaces the USB stick's partition table and existing contents.
These commands describe the whole-device alternative; do not use them when making
the recommended `TALOS_1` plus `DATA` layout.

## S03 post-install checkpoint

After the control-plane installation rebooted from `/dev/nvme0n1`, the installer
USB was removed. On 2026-09-05, `diskutil list external physical` returned no
external physical device. Talos reported the internal `nvme0n1` disk and an empty
`sr0` Virtual Media device, so the installer was not available as boot media.

Only after that check, bootstrap the single control-plane etcd cluster once with
the pinned `talosctl`, retrieve the kubeconfig into ignored local state, and
verify the Kubernetes node and system pods. If the bootstrap must be undone,
follow the deliberate Talos reset/rebuild procedure; never rerun bootstrap on
an initialized cluster.
