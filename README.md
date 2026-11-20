# 📸 PiCloud Photos: Secure Family iCloud Replacement
### Built for Raspberry Pi 4 / 5 + NVMe SSD with Zero-Trust Tailscale VPN & Automated 2TB Google Drive Offsite Backup

Replace paid iCloud and Google Photos subscriptions with an automated, blazing-fast self-hosted backup engine running on your **Raspberry Pi** and an **NVMe SSD**, backed by **encrypted 2TB offsite disaster recovery**.

---

## 🔒 Security & Privacy Architecture

When hosting family photos, **privacy is non-negotiable**. PiCloud Photos uses a multi-layered security and redundancy design:

```text
       [ iPhone / Android (Family Members) ]
                         │
      (End-to-End Encrypted WireGuard Tunnel via Tailscale)
                         │  (NO OPEN ROUTER PORTS!)
                         ▼
        [ immich_tailscale Container Sidecar ]
                         │  (Internal Docker Network)
                         ▼
        [ immich_server + PostgreSQL Vector DB + Redis ]
                         │
        [ High-Speed Local NVMe Storage (/mnt/nvme/immich) ]
                         │
                         ▼ (Every Night at 3:00 AM via cron)
        [ Automated Client-Side AES-256 Encrypted Sync ]
                         │
                         ▼
        [ Your 2TB Google Drive (Gemini Advanced Plan) ]
        (100% Zero-Knowledge: Google cannot scan or view your photos!)
```

---

## 🚀 2-Step Automated Installation

### Step 1: Copy to Your Raspberry Pi
```bash
git clone https://github.com/dongkeykong/PiCloudPhotos.git
cd PiCloudPhotos
chmod +x setup-nvme.sh install.sh backup/*.sh
```

### Step 2: Run the Installer
```bash
sudo ./install.sh
```
The script will:
1. Format and mount your NVMe SSD to `/mnt/nvme` with tuned write buffering.
2. Launch the Immich container suite alongside the Tailscale zero-trust sidecar.
3. Output the exact links to link your account.

---

## ☁️ Leveraging Your 2TB Google One / Gemini Storage (Zero Extra Cost)

Never lose family memories even in a house fire or drive failure. Back up your NVMe drive to your included **2TB Google Drive** with **zero-knowledge client-side encryption**:

### 1. Run the Google Backup Setup Wizard
```bash
./backup/setup-google-backup.sh
```
Follow the short terminal prompts to link your Google account and set your master encryption password.

### What Happens Automatically:
* **Nightly at 3:00 AM**: Dumps your PostgreSQL database (albums, tags, user accounts, and facial recognition data).
* **AES-256 Client-Side Encryption**: Photos and videos are encrypted on the Pi *before* uploading to Google Drive.
* **100% Private**: Google only sees unreadable encrypted chunks.
* **Incremental Sync**: Only uploads newly taken photos each night.
* **1-Click Disaster Recovery**: If your Pi or NVMe ever dies, run `./backup/restore-backup.sh` on a new drive to bring back everything in one command.

---

## 🔑 Linking Tailscale (One-Time Setup)

Once the installer finishes, run:
```bash
sudo docker exec -it immich_tailscale tailscale up
```
Click the printed link to approve the Pi in your free Tailscale account. Your Pi is now joined to your private mesh VPN as **`picloud-photos`**!

---

## 📱 Family Phone Onboarding (Under 3 Minutes)

1. **Install Apps**:
   - Install **Tailscale** on your family members' phones and log in.
   - Install the free **Immich** app from the App Store (iOS) or Google Play (Android).
2. **Connect**:
   - Set the server URL to: `http://picloud-photos:2283/api`.
3. **Turn on Background Backup**:
   - In Immich, tap **Profile ➔ Backup ➔ Enable Background Backup**.
   - Photos, Apple Live Photos, and 4K videos will now back up automatically over Wi-Fi or cellular data from anywhere in the world!
