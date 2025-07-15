# OpenClash Advanced Debug Script

## ⚠️ Disclaimer
This script is a personal project created for fun and experimentation. It is not a professional tool and may contain bugs or behave unexpectedly. Use it at your own risk.

---

## What is this?
This is a shell script designed to automate the process of collecting debug logs for OpenClash on an OpenWrt router. It simplifies troubleshooting by performing several steps automatically and packaging all the necessary logs into a single, easy-to-manage archive file.

## Features
- **Interactive Secret/Token Input**: Prompts the user for the OpenClash API secret.
- **Connection & Auth Validation**: Checks if OpenClash is running and if the provided secret is correct before proceeding.
- **Automated Restart**: Restarts the OpenClash service to capture fresh, initial logs.
- **Dual Log Capture**:
    1.  Captures the initial, real-time log stream from the Clash API (the first 20 seconds after a restart).
    2.  Runs the standard, built-in OpenClash debug script (`/usr/share/openclash/openclash_debug.sh`).
- **Log Organization**: Automatically splits the captured API logs into two separate files: one for `info` messages and one for `debug` messages.
- **Automatic Archiving**: Packages the `info` log, `debug` log, and the system debug log into a single `.tar.gz` file, timestamped for convenience.
- **Self-Cleaning**: Removes all temporary log files after the archive is created.

## How to Use

1.  **Download the script to your OpenWrt router.**
    Connect to your router via SSH. We will place the script in `/usr/bin`, which allows it to be run from any directory.

    *Using `curl`:*
    ```sh
    curl -L [https://raw.githubusercontent.com/zzzt27/ikan-dugong/main/oc-debug/oc_debug.sh](https://raw.githubusercontent.com/zzzt27/ikan-dugong/main/oc-debug/oc_debug.sh) -o /usr/bin/oc_debug.sh
    ```

    *Or using `wget`:*
    ```sh
    wget [https://raw.githubusercontent.com/zzzt27/ikan-dugong/main/oc-debug/oc_debug.sh](https://raw.githubusercontent.com/zzzt27/ikan-dugong/main/oc-debug/oc_debug.sh) -O /usr/bin/oc_debug.sh
    ```

2.  **Make the script executable.**
    ```sh
    chmod +x /usr/bin/oc_debug.sh
    ```

3.  **Run the script.**
    You can now run the script from anywhere by simply typing its name:
    ```sh
    oc_debug.sh
    ```

4.  **Follow the on-screen prompts.**
    - The script will first ask for your OpenClash API secret. Enter it if you have one, or just press `Enter` if you don't.
    - The script will then perform all the debugging steps.

5.  **Retrieve the log package.**
    When the script is finished, it will provide the path to the final archive file (e.g., `/tmp/openclash_debug_package_YYYYMMDD_HHMMSS.tar.gz`). Use a tool like `scp` or WinSCP to download this file from your router to your computer for analysis.
