# 📸 PiCloud Photos: Secure Family iCloud Replacement
### Built for Raspberry Pi 4 / 5 + NVMe SSD with Zero-Trust Tailscale VPN & Automated 2TB Google Drive Offsite Backup

Replace costly iCloud and Google Photos subscriptions with an automated, ultra-fast self-hosted photo engine running on your **Raspberry Pi** and an **NVMe SSD**, backed by **client-side AES-256 encrypted 2TB offsite disaster recovery**.

---

## 🔒 Zero-Trust Security Architecture

When hosting family memories, **privacy and reliability are paramount**. PiCloud Photos uses a multi-layered security design with zero open router ports:

```text
       [ iPhone / Android (Family Members) ]
                         │
      (End-to-End Encrypted WireGuard Mesh via Tailscale)
                         │  (NO ROUTER PORT FORWARDING!)
                         ▼
        [ immich_tailscale Container Sidecar ]
                         │  (network_mode: "service:tailscale")
                         ▼
   [ immich_server + PostgreSQL (pgvecto-rs) + Redis ]
                         │
        [ High-Speed Local NVMe Storage (/mnt/nvme) ]
                         │
                         ▼ (Nightly at 3:00 AM via cron)
        [ Client-Side AES-256 Encrypted Sync (rclone) ]
                         │
                         ▼
        [ Your 2TB Google Drive (Gemini Advanced Plan) ]
        (100% Zero-Knowledge: Google cannot scan or view your photos!)
```

---

## ⚡ Recommended Hardware BOM

* **SBC**: Raspberry Pi 5 (4GB or 8GB) or Raspberry Pi 4 Model B (4GB or 8GB)
* **Cooling**: Official Raspberry Pi Active Cooler (essential to prevent thermal throttling during initial batch ML indexing)
* **Storage**: Raspberry Pi M.2 HAT+ (or Pineberry Pi HatDrive) with a 1TB–2TB NVMe PCIe SSD (e.g. Samsung 980, Crucial P3, WD Black SN770)
* **Power**: Official 27W USB-C Power Supply (delivers full 5A to power Pi 5 and NVMe without power drops)

---

## 🚀 2-Step Automated Installation

### Step 1: Clone Repository
```bash
git clone https://github.com/dongkeykong/PiCloudPhotos.git
cd PiCloudPhotos
chmod +x *.sh backup/*.sh
```

### Step 2: Run the Secure Installer
```bash
sudo ./install.sh
```
The automated installer will:
1. Initialize `.env` and generate a unique, cryptographically random database secret (`openssl rand -hex 18`).
2. Format and mount your NVMe SSD to `/mnt/nvme` with tuned write buffering, GPT partition tables, and automated weekly `fstrim.timer`.
3. Allocate a 4GB NVMe swapfile to guarantee ML/facial recognition stability on ARM64.
4. Launch the hardened Immich container suite routed directly through Tailscale's network namespace (`network_mode: "service:tailscale"`).

---

## 🧪 Pre-Flight Verification & Health Check

Before starting or after updates, you can run the built-in diagnostic test harness:
```bash
./verify.sh
```
This tests all container configurations, file permissions, safety guards, and network settings.

---

## 🏎️ Raspberry Pi 5 PCIe Gen 3 Optimization (Optional)

Unlock 850+ MB/s read/write speeds from your NVMe drive by enabling PCIe Gen 3:
```bash
sudo ./enable-pcie-gen3.sh
```
*(Prompts for a quick reboot to activate Gen 3 speed).*

---

## ☁️ Setting Up Encrypted 2TB Google Drive Backup

Back up your photo library to your included **2TB Google Drive (Gemini Advanced)** with **zero-knowledge client-side encryption**:

```bash
sudo ./backup/setup-google-backup.sh
```

### What Happens Automatically:
* **Nightly at 3:00 AM**: Generates a verified PostgreSQL dump (albums, facial tags, user accounts, metadata).
* **AES-256 Client-Side Encryption**: Photos and database snapshots are encrypted locally before leaving the Pi.
* **Anti-Wipe Versioning**: Deleted or modified local photos are archived in remote timestamped folders (`archive/YYYYMMDD`) instead of being wiped.
* **1-Click Disaster Recovery**: If your drive or Pi is ever destroyed, bring back your entire library in one command:
  ```bash
  sudo ./backup/restore-backup.sh
  ```

---

## 🔑 Linking Tailscale (One-Time Setup)

Once the installer finishes, connect the Tailscale sidecar to your free Tailscale account:
```bash
sudo docker exec -it immich_tailscale tailscale up
```
Click the printed link to approve the Pi in your browser. Your Pi is now joined to your private mesh VPN as **`picloud-photos`**!

---

## 📱 Family Phone Onboarding (Under 3 Minutes)

1. **Install Apps**:
   - Install **Tailscale** on family members' phones and sign in.
   - Install the free **Immich** app from the App Store (iOS) or Google Play (Android).
2. **Connect**:
   - Set the server URL in the Immich app to:
     ```text
     http://picloud-photos:2283
     ```
     *(Do NOT append `/api` — modern Immich mobile app connects directly to base URL!)*
3. **Turn on Background Backup**:
   - In Immich, tap **Profile ➔ Backup ➔ Enable Background Backup**.
   - Photos, Apple Live Photos, RAW images, and 4K HDR videos will now back up automatically over Wi-Fi or cellular data from anywhere in the world!

---

## 📥 Migrating from Google Takeout or iCloud

If you have thousands of existing photos in iCloud or Google Photos, migrate them cleanly with metadata preserved using `immich-go`:

```bash
# Download immich-go CLI
curl -s https://api.github.com/repos/simulot/immich-go/releases/latest \
  | grep "browser_download_url.*linux_arm64.tar.gz" \
  | cut -d : -f 2,3 | tr -d \" | wget -qi -
tar -xzf immich-go*linux_arm64.tar.gz

# Upload Google Takeout or iCloud export folder
./immich-go upload from-folder --server http://127.0.0.1:2283 --key <YOUR_API_KEY> /path/to/extracted/photos
```

---

## 📊 Diagnostics & System Status

Check thermals, NVMe free space, container health, and backup logs at any time:
```bash
./status.sh
```
