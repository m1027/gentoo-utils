# gentoo-utils

This repository aims to deliver useful tools for
[Gentoo Linux](https://www.gentoo.org/).

## Installer for Gentoo on Hetzner's arm64 Cloud Servers

### Why

If you want to setup [Gentoo Linux](https://www.gentoo.org/) on **arm64**
hardware in the cloud, then

* Checkout [Hetzner](https://www.hetzner.com/?country=en) and their Linux
  based **Cloud** servers for **arm64**. While Gentoo is not amoung the
  prepared ISOs you can install it manually, too.
* Use the **documentation** and **installer script** below to
  simplify the Gentoo setup.

### Feature overview of this approach

* Cloud server costs: As there are no setup fees and a price per 
  hour, testing this setup is affordable. Servers can be deleted again at
  any time to avoid paying for it.
* The installer script entirely wipes the server disk (from a rescue system),
  sets up Gentoo Linux and also builds a vanilla Linux kernel without user
  interaction in at most 25 minutes (for the minimum 2-core server).
* After installation you will be able to `ssh` into Gentoo Linux.
  
### How

1. Get an account at Hetzner's.

   * Read about the **Cloud** offers at
     [Hetzner.com](https://www.hetzner.com/?country=en).
   * Register an account without fee. Authorization may work entirely online.

2. Create an arm64 server.

   * When you have your account, enter the **Cloud** administrative
     dashboard.
   * The following procedure configures the new cloud server, **but also
     sets up another arbitrary Linux OS** which will not actually be used.
   * Select **Servers** and then **Add Server**.
   * Go through all necessary configuration steps. The minimum required here
     are: Location, Image (use Debian which sets up in seconds), Type (use
     **vCPU + Arm64**), Networking (do not disable IPv4), SSH keys
     (**crucial: Paste your ssh pubkey**), the rest is not required.
   * Wait some seconds for the server to be setup.
   * You will receive an IP address. You may access the system via ssh but
     this is not required.

3. Reboot the newly installed server into the **Rescue** mode.

   * Select **Servers** from the menu on the left.
   * Select your server.
   * Select **Rescue** from the menu and then **Enable rescue & power cycle**.
   * Select **linux64** and **your previously selected ssh pubkey**.
   * Wait some seconds until the rescue system has booted.
   * You should now `ssh root@IPADDR` into the rescue system. **You will
     access your server's disk and install Gentoo from here.**
   * Leave this session open.

4. Download the installer script.

   * Download the 
    [Installer Script](scripts/installer/gentoo-arm64-setup-on-hetzner.sh) 
    from this repo.
   * Assert the script is executable: `chmod 700 SCRIPT`.
   * Copy the script to the rescue server: `rsync SCRIPT root@IPADDR:/root`.

5. Run the installer script on the rescue server.

   * Execute the script: `./gentoo-arm64-setup-on-hetzner.sh`
   * Confirm the installation with `y`.

Enjoy!

### If the installation fails

* In case of an installation failure observe the error message and try to
  fix the root cause. Else file an issue.
* The script is designed to skip downloads when re-run after failures.
* In case you need to reboot **into** the rescue system again, remember to
  enable the rescue mode previously again. Normally, rebooting the rescue
  system boots your server build next.
* There is a `vnc`-like view for running servers. Locate the console icon
  in Hetzner's web interface.

### Todo

* The installer script does not lookup for the most recent `stage3` OS build
  yet. So the download link may become outdated or invalid. Adjust the URL
  in that case.
* The created kernel will be stripped down during installation but probably
  not to the bare minium.
* Due to changed fingerprints `ssh` may refuse to connect to your server. You
  may fix that by editing your `~/.ssh/known_hosts`.

