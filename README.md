# gentoo-utils

This repository aims to deliver useful tools for
[Gentoo Linux](https://www.gentoo.org/).

## Installer for Gentoo on Hetzner's arm64/amd64 Cloud Servers

### Why

If you want to setup [Gentoo Linux](https://www.gentoo.org/) on **arm64**
or **amd64** hardware in the cloud, then

* Checkout [Hetzner](https://www.hetzner.com/?country=en) and their Linux
  based **Cloud** servers for **arm64** or **amd64**. While Gentoo is not
  amoung the prepared ISOs you can install it manually, too.
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

2. Create a server.

   * When you have your account, enter the **Cloud** administrative
     dashboard.
   * The following procedure configures the new cloud server, **but also
     sets up another arbitrary Linux OS** which will not actually be used.
   * Select **Servers** and then **Add Server**.
   * Go through all necessary configuration steps. The minimum required here
     are: Location, Image (use Debian which sets up in seconds), Type (use
     **vCPU + Arm64** or **vCPU + Amd64**), Networking (do not disable IPv4),
     SSH keys (**crucial: Paste your ssh pubkey**), the rest is not required.
   * Wait some seconds for the server to be setup.
   * You will receive an IP address. You may access the system via ssh but
     this is not required.

3. Reboot the newly installed server into the **Rescue** mode.

   * Select **Servers** from the menu on the left.
   * Select your server.
   * Select **Rescue** from the menu and then **Enable rescue & power cycle**.
   * Select **linux64** and **your previously selected ssh pubkey**.

4. Run the installer script on the rescue server.

   * Wait some seconds until the rescue system has booted.
   * Enter the rescue system: `ssh root@IPADDR`.
   * Download the
    [Installer Script](scripts/installer/gentoo-setup-on-hetzner.sh),
    make it executable and run it:

    ```bash
    wget https://raw.githubusercontent.com/m1027/gentoo-utils/main/scripts/installer/gentoo-setup-on-hetzner.sh
    chmod u+x gentoo-setup-on-hetzner.sh
    ./gentoo-setup-on-hetzner.sh ARCH  # <- Replace ARCH with arm64 or amd64
    ```

Enjoy!

### If the installation fails

* The script is designed to skip downloads when re-run after failures.
* In case you need to reboot **into** the rescue system again, remember to
  enable the rescue mode again, before rebooting (normally, rebooting the
  rescue system boots your server build next).
* There is a `vnc`-like view for running servers. Locate the console icon
  in Hetzner's web interface.

### Known issues && Todo

* The created kernel will be stripped down during installation but probably
  not to the bare minium.
* Due to changed fingerprints `ssh` may refuse to connect to your server. You
  may need to edit your `~/.ssh/known_hosts` once.
* For amd64 (not arm64): While ssh access works, Hetzner's `vnc`-like view
  for running servers may not yet show a correct console buffer to login from
  there.
