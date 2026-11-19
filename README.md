# 📸 PiCloud Photos: Secure Family iCloud Replacement
### Built for Raspberry Pi 4 / 5 + NVMe SSD with Zero-Trust Tailscale VPN

Replace paid iCloud and Google Photos subscriptions with an automated, blazing-fast self-hosted backup engine running on your **Raspberry Pi** and an **NVMe SSD**.

---

## 🔒 Security Hardening Architecture

When hosting family photos, **security is priority #1**. Most self-hosted tutorials tell you to open port 2283 on your home Wi-Fi router (port forwarding), which exposes your private family photos to internet port scanners and automated bots.

**PiCloud Photos uses a Zero-Trust WireGuard Mesh architecture instead:**

```text
       [ iPhone / Android (Family Members) ]
                         │
        (Encrypted WireGuard Mesh Tunnel - Tailscale)
                         │  (NO OPEN ROUTER PORTS!)
                         ▼
        [ Raspberry Pi: Tailscale VPN Sidecar ]
                         │  (Isolated Docker Internal Network)
                         ▼
        [ Immich Photo Server + PostgreSQL Vector DB ]
                         │
        [ High-Speed NVMe Storage (/mnt/nvme/immich) ]
```

### Security Safeguards Implemented:
1. **Zero Open Router Ports**: You never have to configure UPnP or port forward port 80, 443, or 2283 on your home router.
2. **End-to-End Encryption**: All traffic between your family's phones and the Pi is encrypted with peer-to-peer WireGuard (via Tailscale).
3. **Database Isolation**: PostgreSQL and Redis are bound strictly to Docker's internal private bridge; they are completely invisible to external networks.
4. **POSIX Storage Permissions**: Storage directories enforce strict user permissions (`chmod 700` on database files) so other processes cannot read raw photo chunks.

---

## 🚀 2-Step Automated Installation

### Step 1: Copy to Your Raspberry Pi
```bash
git clone https://github.com/dongkeykong/PiCloudPhotos.git # (or copy this folder)
cd PiCloudPhotos
chmod +x setup-nvme.sh install.sh
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

## 🔑 Linking Tailscale (One-Time Setup)

Once the installer finishes, run:
```bash
sudo docker exec -it immich_tailscale tailscale up
```
1. It prints a short `https://login.tailscale.com/a/...` authorization URL in your terminal.
2. Open that link in any browser, log in with your free Tailscale account, and click **Approve**.
3. Your Raspberry Pi is now securely joined to your private mesh VPN as **`picloud-photos`**!

---

## 📱 Family Phone Onboarding (Under 3 Minutes)

1. **Install Apps**:
   - Install **Tailscale** on your family members' phones and log into your Tailscale network.
   - Install the free **Immich** app from the App Store (iOS) or Google Play (Android).
2. **Connect**:
   - Open the Immich app on their phone.
   - Set the server URL to:
     ```text
     http://picloud-photos:2283/api
     ```
   *(Or use the local Wi-Fi IP `http://192.168.1.x:2283/api` when at home).*
3. **Turn on Background Backup**:
   - In Immich, tap **Profile ➔ Backup ➔ Enable Background Backup**.
   - Photos, Apple Live Photos, and 4K videos will now back up automatically over Wi-Fi or cellular data from anywhere in the world!
