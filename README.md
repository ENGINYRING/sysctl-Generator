[![ENGINYRING](https://cdn.enginyring.com/img/logo_dark.png)](https://www.enginyring.com)

# sysctl-Generator

![sysctl-Generator Banner](https://img.shields.io/badge/sysctl--Generator-v1.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

A powerful, adaptive system optimizer that automatically generates optimized kernel parameters for Linux systems. This tool detects your hardware configuration and creates a customized `sysctl.conf` file tailored to your specific use case.

**Project URL**: [https://github.com/ENGINYRING/sysctl-Generator](https://github.com/ENGINYRING/sysctl-Generator)  
**Author**: [ENGINYRING](https://www.enginyring.com)

## 📋 Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Use Cases](#use-cases)
- [Example Output](#example-output)
- [Hardware Detection](#hardware-detection)
- [Container Support](#container-support)
- [Requirements](#requirements)
- [Security Considerations](#security-considerations)
- [Disclaimer](#disclaimer)
- [License](#license)

## 🚀 Features

- **Automatic hardware detection**: CPU cores/threads, RAM, network speed, disk type
- **Multiple optimization profiles**: Choose from 10 specialized use cases
- **Container awareness**: Detects and adapts to container environments (Docker, LXC, Podman)
- **Manual parameter override**: Option to use custom hardware parameters
- **IPv6 configuration**: Option to enable or disable IPv6
- **Clear output**: Generates well-formatted and commented sysctl configuration
- **User-friendly interface**: Interactive command-line menu with guidance
- **Detailed reporting**: Shows exactly what was configured and why

## 💻 Installation

```bash
# Clone the repository
git clone https://github.com/ENGINYRING/sysctl-Generator.git

# Change directory
cd sysctl-Generator

# Make the script executable
chmod +x sysctlgen.sh
```

## 🔧 Usage

```bash
./sysctlgen.sh
```

The script will:
1. Detect your hardware configuration
2. Allow you to use detected or custom hardware parameters
3. Prompt you to select a use case
4. Configure IPv6 settings
5. Generate an optimized sysctl.conf file
6. Provide instructions for applying the configuration

## 📊 Use Cases

The script supports the following optimization profiles:

1. **General Purpose**: Balanced tuning for mixed workloads
2. **Virtualization Host**: Optimized for hypervisors (KVM/QEMU/Proxmox/ESXi)
3. **Web Server**: Tuned for HTTP/HTTPS traffic and web applications
4. **Database Server**: Optimized for MySQL/PostgreSQL/MongoDB/etc.
5. **Caching Server**: Performance-tuned for Redis/Memcached/etc.
6. **HPC / Compute Node**: For computational and scientific workloads
7. **File Server**: Optimized for NFS/SMB/file storage operations
8. **Network Appliance**: For routers/firewalls/gateways/proxies
9. **Container Host**: Specialized for Docker/Kubernetes nodes
10. **Development Machine**: Balanced for coding workstations

## 📝 Example Output

The generated configuration file includes a detailed header and organized parameter sections:

```
# Optimized sysctl.conf for Web Server
# Hardware: 8 cores / 16 threads, 32GB RAM, 1000Mb/s NIC, SSD
# Generated on: 2025-05-15 14:22:33
#
# Apply changes with: sudo sysctl -p /etc/sysctl.conf
#
# IMPORTANT: Test these settings with your specific workload.
#
fs.aio-max-nr = 1048576
fs.file-max = 33554432
fs.inotify.max_user_instances = 8192
...
```

## 🖥️ Hardware Detection

The script automatically detects:

- **CPU**: Number of cores and threads
- **RAM**: Available system memory in GB
- **Network**: Active interface speed in Mbps
- **Disk**: Type (HDD, SSD, or NVMe)

You can also manually specify hardware parameters if the automatic detection doesn't match your requirements or if you want to generate a configuration for a different system.

## 🐳 Container Support

sysctl-Generator detects if it's running inside a container environment and adapts accordingly:

- Identifies Docker, LXC, and Podman containers
- Adjusts resource calculations based on container limits
- Provides container-specific optimizations
- Warns about parameters that require host-level privileges

## ⚙️ Requirements

- Bash shell
- Root access (for applying the generated configuration)
- Optional tools that improve detection accuracy:
  - `ethtool` (for better network speed detection)
  - `lsblk` (for disk type detection)
  - `bc` (for more precise calculations)

## 🔒 Security Considerations

While the script generates optimal parameters for performance, some system environments may require additional security-focused tuning. Always review the generated configuration before applying it to production systems.

## ⚠️ Disclaimer

**IMPORTANT**: This tool is provided "as is" without warranties or guarantees of any kind, express or implied. 

- ENGINYRING is **NOT RESPONSIBLE** for any system instability, performance issues, data loss, or any other problems that may arise from using this tool or applying the generated configurations.
- Always **TEST CONFIGURATIONS** in a non-production environment before deploying to production systems.
- The generated parameters are **RECOMMENDATIONS ONLY** and should be reviewed by a system administrator with knowledge of the specific environment.
- We **DO NOT GUARANTEE** performance improvements or system stability with these configurations.
- By using this tool, you acknowledge that you are making changes to system parameters **AT YOUR OWN RISK**.
- **ALWAYS BACKUP** your original configuration before applying any changes.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file in the repository for details.

```
MIT License

Copyright (c) 2025 ENGINYRING

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

<p align="center">
  <a href="https://www.enginyring.com">
    <img src="https://img.shields.io/badge/Powered%20by-ENGINYRING-blue" alt="Powered by ENGINYRING">
  </a>
  <br>
  High-Performance Web Hosting & VPS Services
</p>
