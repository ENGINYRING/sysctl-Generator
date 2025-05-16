#!/bin/bash
# ============================================================================
# Automatic sysctl.conf Optimized Generator for Containers and Bare Metal
# Auto-detects hardware and generates tuned sysctl parameters
# Version 1.1.0
# ============================================================================

set -e

OUTPUT_FILE="$HOME/sysctl-suggestion.conf"
DISABLE_IPV6=false
IS_CONTAINER=false
CONTAINER_TYPE="unknown"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================================
# Use Case Descriptions and Functions
# ============================================================================

print_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "                        _    _   _____                                 _               "
    echo "                       | |  | | |  __ \                               | |              "
    echo " ___  _   _  ___   ___ | |_ | | | |  \/  ___  _ __    ___  _ __  __ _ | |_  ___   _ __ "
    echo "/ __|| | | |/ __| / __|| __|| | | | __  / _ \| '_ \  / _ \| '__|/ _\` || __|/ _ \ | '__|"
    echo "\__ \| |_| |\__ \| (__ | |_ | | | |_\ \|  __/| | | ||  __/| |  | (_| || |_| (_) || |   "
    echo "|___/ \__, ||___/ \___| \__||_|  \____/ \___||_| |_| \___||_|   \__,_| \__|\___/ |_|   "
    echo "       __/ |                                                                            "
    echo "      |___/                                                                             "
    echo -e "${NC}"
    echo -e "${CYAN}Automatic sysctl.conf Optimizer${NC}"
    echo -e "Analyzes your system and generates optimized kernel parameters\n"
    echo -e "${YELLOW}GitHub:${NC} https://github.com/ENGINYRING/sysctl-Generator"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}ENGINYRING${NC} - ${CYAN}High-Performance Web Hosting & VPS Services${NC}"
    echo -e "Optimized infrastructure for your applications - ${BOLD}www.enginyring.com${NC}\n"
}

# Define Use Cases with descriptions
declare -A USE_CASES
USE_CASES=(
    ["general"]="General Purpose: Balanced tuning for mixed workloads"
    ["virtualization"]="Virtualization Host: For KVM/QEMU/Proxmox/ESXi/etc."
    ["web"]="Web Server: Optimized for HTTP traffic"
    ["database"]="Database Server: Tuned for MySQL/PostgreSQL/etc."
    ["cache"]="Caching Server: For Redis/Memcached/etc."
    ["compute"]="HPC / Compute Node: For computational workloads"
    ["fileserver"]="File Server: For NFS/SMB/file storage"
    ["network"]="Network Appliance: For routers/firewalls/gateways"
    ["container"]="Container Host: For Docker/Kubernetes nodes"
    ["development"]="Development Machine: For coding workstations"
)

# ============================================================================
# Container Detection Functions
# ============================================================================

detect_container() {
    # Check for common container indicators
    if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        IS_CONTAINER=true
        CONTAINER_TYPE="docker"
    elif grep -q -E '/(lxc|docker)/' /proc/1/cgroup 2>/dev/null; then
        IS_CONTAINER=true
        if grep -q lxc /proc/1/cgroup; then
            CONTAINER_TYPE="lxc"
        else
            CONTAINER_TYPE="docker"
        fi
    elif [ -f /run/.containerenv ]; then
        IS_CONTAINER=true
        CONTAINER_TYPE="podman"
    fi

    if $IS_CONTAINER; then
        echo -e "${YELLOW}Running in a ${CONTAINER_TYPE} container environment${NC}"
        echo -e "${YELLOW}Note: Container-specific optimizations will be applied${NC}\n"
    fi
}

# ============================================================================
# Hardware Detection Functions
# ============================================================================

detect_os() {
    if [ -f /etc/redhat-release ] || [ -f /etc/centos-release ] || [ -f /etc/fedora-release ]; then
        OS="rhel"
        INSTALL_PATH="/etc/sysctl.d/99-custom.conf"
    else
        OS="deb"
        INSTALL_PATH="/etc/sysctl.conf"
    fi
}

detect_cpu() {
    # Always use nproc, which respects cgroup/cpuset CPU limits (correct for Docker, LXC, and bare metal)
    if command -v nproc >/dev/null 2>&1; then
        CORES=$(nproc)
        THREADS=$CORES
        echo -e "CPU: ${GREEN}${CORES}${NC} cores / ${GREEN}${THREADS}${NC} threads"
        return
    fi

    # Fallback: count processors in /proc/cpuinfo
    CORES=$(grep -c ^processor /proc/cpuinfo)
    THREADS=$CORES
    echo -e "CPU: ${GREEN}${CORES}${NC} cores / ${GREEN}${THREADS}${NC} threads (fallback)"
}

detect_ram() {
    # For containers, check cgroup memory limits first
    if $IS_CONTAINER; then
        local mem_limit=""
        
        if [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
            # cgroups v1
            mem_limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
        elif [ -f /sys/fs/cgroup/memory.max ]; then
            # cgroups v2
            mem_limit=$(cat /sys/fs/cgroup/memory.max)
        fi
        
        # If a valid limit exists and is not the max value
        if [[ -n "$mem_limit" && "$mem_limit" != "max" && "$mem_limit" != "9223372036854771712" ]]; then
            # Convert bytes to GB
            RAM=$(( mem_limit / 1024 / 1024 / 1024 ))
            if [ "$RAM" -eq 0 ]; then
                # If less than 1GB, round up to 1
                RAM=1
            fi
            echo -e "Container RAM Limit: ${GREEN}${RAM}${NC} GB"
            return
        fi
    fi

    # Regular detection from /proc/meminfo for both containers and non-containers
    local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    
    # Calculate RAM in GB without bc
    if command -v bc >/dev/null 2>&1; then
        # If bc is available, use it for precise calculation
        RAM=$(echo "scale=1; $mem_kb / 1024 / 1024" | bc)
        # Round up to nearest integer for simplicity
        RAM=$(echo "($RAM+0.5)/1" | bc)
    else
        # Alternative calculation without bc (less precise but works)
        RAM=$(( mem_kb / 1024 / 1024 ))
        # Add 1 to round up if needed
        if [[ $mem_kb -gt $(( RAM * 1024 * 1024 )) ]]; then
            RAM=$(( RAM + 1 ))
        fi
    fi
    
    # Fallback if detection fails
    if [[ -z "$RAM" || "$RAM" -eq 0 ]]; then
        RAM=1
    fi
    
    echo -e "RAM: ${GREEN}${RAM}${NC} GB"
}

detect_nic_speed() {
    # Initialize NIC speed to 1000 Mbps default
    NIC=1000

    # Find the active network interface
    if command -v ip >/dev/null 2>&1; then
        ACTIVE_IF=$(ip -o route get 1 | awk '{print $5; exit}')
    else
        ACTIVE_IF=$(route -n | grep "^0.0.0.0" | head -1 | awk '{print $8}')
    fi

    # If no active interface found, try to get the first non-loopback interface
    if [[ -z "$ACTIVE_IF" || "$ACTIVE_IF" == "lo" ]]; then
        ACTIVE_IF=$(ip -o link show | grep -v "link/loopback" | awk -F': ' '{print $2; exit}')
    fi

    # Get speed using ethtool if available
    if [[ -n "$ACTIVE_IF" ]] && command -v ethtool >/dev/null 2>&1; then
        local SPEED=$(ethtool $ACTIVE_IF 2>/dev/null | grep "Speed:" | awk '{print $2}' | sed 's/[^0-9]//g')
        if [[ -n "$SPEED" && "$SPEED" -gt 0 ]]; then
            NIC=$SPEED
        fi
    fi

    # Check /sys filesystem for speed
    if [[ -n "$ACTIVE_IF" && -f "/sys/class/net/$ACTIVE_IF/speed" ]]; then
        local SPEED=$(cat "/sys/class/net/$ACTIVE_IF/speed" 2>/dev/null)
        if [[ -n "$SPEED" && "$SPEED" -gt 0 ]]; then
            NIC=$SPEED
        fi
    fi
    
    # For containers, we can't reliably determine network speed limitations
    # So if we're in a container, add a note
    if $IS_CONTAINER; then
        echo -e "Network: ${GREEN}${NIC}${NC} Mbps (${ACTIVE_IF}) ${YELLOW}[Container shared network]${NC}"
    else
        echo -e "Network: ${GREEN}${NIC}${NC} Mbps (${ACTIVE_IF})"
    fi
}

detect_disk_type() {
    # Default to HDD
    DISK_TYPE="hdd"
    
    # In containers, disk is usually the host's, but often limited by I/O controls
    if $IS_CONTAINER; then
        # Check for IO limits in cgroups
        local has_io_limits=false
        if [ -d /sys/fs/cgroup/blkio ] || [ -f /sys/fs/cgroup/io.max ]; then
            has_io_limits=true
        fi
        
        # Check if it's likely a cloud container (which typically have SSD backends)
        if grep -q "^Amazon\|^Google\|^Azure\|^Digital Ocean" /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null; then
            DISK_TYPE="ssd"
        fi
        
        local DISK_TYPE_FRIENDLY="Host System Storage"
        if [[ "$DISK_TYPE" == "ssd" ]]; then
            DISK_TYPE_FRIENDLY="Host System SSD (likely)"
        fi
        
        if $has_io_limits; then
            echo -e "Disk: ${GREEN}${DISK_TYPE_FRIENDLY}${NC} ${YELLOW}[I/O limits detected]${NC}"
        else
            echo -e "Disk: ${GREEN}${DISK_TYPE_FRIENDLY}${NC} ${YELLOW}[shared with host]${NC}"
        fi
        return
    fi
    
    # Regular disk detection for non-containers
    # Try to find the system disk
    ROOT_DEVICE=$(df / | grep -v Filesystem | awk '{print $1}' | sed -E 's/\/dev\/(sd[a-z]|nvme[0-9]+n[0-9]+|xvd[a-z]|vd[a-z]).*/\1/')
    
    # Check if it's NVMe
    if [[ "$ROOT_DEVICE" == nvme* ]]; then
        DISK_TYPE="nvme"
    else
        # Check if SSD using lsblk or rotation flag
        if command -v lsblk >/dev/null 2>&1; then
            # Check if rotational = 0 (SSD)
            local ROTATIONAL
            if [[ -n "$ROOT_DEVICE" ]]; then
                ROTATIONAL=$(lsblk -d -o name,rota | grep "$ROOT_DEVICE" | awk '{print $2}')
            else
                # Just check the first disk
                ROTATIONAL=$(lsblk -d -o name,rota | grep -v NAME | head -1 | awk '{print $2}')
            fi
            
            if [[ "$ROTATIONAL" == "0" ]]; then
                DISK_TYPE="ssd"
            fi
        elif [[ -n "$ROOT_DEVICE" && -f "/sys/block/$ROOT_DEVICE/queue/rotational" ]]; then
            # Check directly in sysfs
            local ROTATIONAL=$(cat "/sys/block/$ROOT_DEVICE/queue/rotational")
            if [[ "$ROTATIONAL" == "0" ]]; then
                DISK_TYPE="ssd"
            fi
        fi
    fi
    
    local DISK_TYPE_FRIENDLY="Hard Disk Drive (HDD)"
    if [[ "$DISK_TYPE" == "ssd" ]]; then
        DISK_TYPE_FRIENDLY="Solid State Drive (SSD)"
    elif [[ "$DISK_TYPE" == "nvme" ]]; then
        DISK_TYPE_FRIENDLY="NVMe SSD"
    fi
    
    echo -e "Disk: ${GREEN}${DISK_TYPE_FRIENDLY}${NC}"
}

confirm_or_input_hardware() {
    echo -e "\n${BLUE}${BOLD}Hardware Parameters:${NC}"
    echo -e "Current detected values:"
    echo -e "  1. CPU: ${GREEN}${CORES}${NC} cores / ${GREEN}${THREADS}${NC} threads"
    echo -e "  2. RAM: ${GREEN}${RAM}${NC} GB"
    echo -e "  3. Network: ${GREEN}${NIC}${NC} Mbps"
    echo -e "  4. Disk: ${GREEN}$(if [[ "$DISK_TYPE" == "ssd" ]]; then echo "SSD"; elif [[ "$DISK_TYPE" == "nvme" ]]; then echo "NVMe"; else echo "HDD"; fi)${NC}"
    
    echo -e "\nDo you want to use these detected values or manually input your own?"
    echo "1) Use detected values (default)"
    echo "2) Manually input values"
    
    local selection
    while true; do
        echo -ne "\nEnter selection [1-2]: "
        read selection
        
        if [[ "$selection" == "1" || "$selection" == "" ]]; then
            echo -e "Using detected hardware values."
            break
        elif [[ "$selection" == "2" ]]; then
            # CPU input
            while true; do
                echo -ne "\nEnter number of CPU cores: "
                read input_cores
                if [[ "$input_cores" =~ ^[0-9]+$ && "$input_cores" -gt 0 ]]; then
                    CORES=$input_cores
                    break
                else
                    echo -e "${RED}Invalid input. Please enter a positive number.${NC}"
                fi
            done
            
            while true; do
                echo -ne "Enter number of CPU threads: "
                read input_threads
                if [[ "$input_threads" =~ ^[0-9]+$ && "$input_threads" -gt 0 ]]; then
                    THREADS=$input_threads
                    break
                else
                    echo -e "${RED}Invalid input. Please enter a positive number.${NC}"
                fi
            done
            
            # RAM input
            while true; do
                echo -ne "\nEnter RAM amount in GB: "
                read input_ram
                if [[ "$input_ram" =~ ^[0-9]+$ && "$input_ram" -gt 0 ]]; then
                    RAM=$input_ram
                    break
                else
                    echo -e "${RED}Invalid input. Please enter a positive number.${NC}"
                fi
            done
            
            # Network speed input
            while true; do
                echo -ne "\nEnter network speed in Mbps (e.g., 1000 for 1Gbps): "
                read input_nic
                if [[ "$input_nic" =~ ^[0-9]+$ && "$input_nic" -gt 0 ]]; then
                    NIC=$input_nic
                    break
                else
                    echo -e "${RED}Invalid input. Please enter a positive number.${NC}"
                fi
            done
            
            # Disk type input
            echo -e "\nSelect disk type:"
            echo "1) HDD (Hard Disk Drive)"
            echo "2) SSD (Solid State Drive)"
            echo "3) NVMe SSD"
            
            while true; do
                echo -ne "\nEnter selection [1-3]: "
                read disk_selection
                
                if [[ "$disk_selection" == "1" ]]; then
                    DISK_TYPE="hdd"
                    break
                elif [[ "$disk_selection" == "2" ]]; then
                    DISK_TYPE="ssd"
                    break
                elif [[ "$disk_selection" == "3" ]]; then
                    DISK_TYPE="nvme"
                    break
                else
                    echo -e "${RED}Invalid selection. Please try again.${NC}"
                fi
            done
            
            echo -e "\n${GREEN}Hardware parameters updated:${NC}"
            echo -e "  - CPU: ${CORES} cores / ${THREADS} threads"
            echo -e "  - RAM: ${RAM} GB"
            echo -e "  - Network: ${NIC} Mbps"
            echo -e "  - Disk: $(if [[ "$DISK_TYPE" == "ssd" ]]; then echo "SSD"; elif [[ "$DISK_TYPE" == "nvme" ]]; then echo "NVMe"; else echo "HDD"; fi)"
            break
        else
            echo -e "${RED}Invalid selection. Please try again.${NC}"
        fi
    done
}

get_use_case() {
    echo -e "\n${BLUE}${BOLD}Select your server's primary use case:${NC}"
    echo -e "This will determine which optimization profile to use.\n"
    
    local i=1
    local keys=()
    for key in "${!USE_CASES[@]}"; do
        keys[$i]=$key
        printf "%2d) ${YELLOW}%-20s${NC} %s\n" $i "${key}" "${USE_CASES[$key]}"
        ((i++))
    done
    
    local selection
    while true; do
        echo -ne "\nEnter selection [1-$((i-1))]: "
        read selection
        
        if [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -lt "$i" ]]; then
            USE_CASE="${keys[$selection]}"
            break
        else
            echo -e "${RED}Invalid selection. Please try again.${NC}"
        fi
    done
    
    echo -e "\nSelected: ${YELLOW}${USE_CASE}${NC} - ${USE_CASES[$USE_CASE]}"
}

ask_ipv6() {
    echo -e "\n${BLUE}${BOLD}IPv6 Configuration:${NC}"
    echo -e "Do you want to disable IPv6 on this system?\n"
    echo "1) No, keep IPv6 enabled (default)"
    echo "2) Yes, disable IPv6 completely"
    
    local selection
    while true; do
        echo -ne "\nEnter selection [1-2]: "
        read selection
        
        if [[ "$selection" == "1" || "$selection" == "" ]]; then
            DISABLE_IPV6=false
            break
        elif [[ "$selection" == "2" ]]; then
            DISABLE_IPV6=true
            break
        else
            echo -e "${RED}Invalid selection. Please try again.${NC}"
        fi
    done
    
    if $DISABLE_IPV6; then
        echo -e "IPv6 will be ${RED}disabled${NC} in the generated configuration."
    else
        echo -e "IPv6 will be ${GREEN}enabled${NC} in the generated configuration."
    fi
}

confirm_selection() {
    local disk_type_name="HDD"
    [[ "$DISK_TYPE" == "ssd" ]] && disk_type_name="SSD" 
    [[ "$DISK_TYPE" == "nvme" ]] && disk_type_name="NVMe"
    
    echo -e "\n${BLUE}${BOLD}Configuration Summary:${NC}"
    echo -e "  - Use Case: ${YELLOW}${USE_CASE}${NC} (${USE_CASES[$USE_CASE]})"
    echo -e "  - CPU: ${CORES} cores / ${THREADS} threads"
    echo -e "  - RAM: ${RAM} GB"
    echo -e "  - Network: ${NIC} Mbps"
    echo -e "  - Disk: ${disk_type_name}"
    if $IS_CONTAINER; then
        echo -e "  - Environment: ${CONTAINER_TYPE} container"
    fi
    echo -e "  - IPv6: $(if $DISABLE_IPV6; then echo "${RED}Disabled${NC}"; else echo "${GREEN}Enabled${NC}"; fi)"
    echo -e "  - Output file: ${OUTPUT_FILE}"
    
    while true; do
        echo -ne "\nGenerate sysctl.conf with these settings? [Y/n]: "
        read confirmation
        
        if [[ "$confirmation" == "" || "$confirmation" == "y" || "$confirmation" == "Y" ]]; then
            return 0
        elif [[ "$confirmation" == "n" || "$confirmation" == "N" ]]; then
            echo -e "${RED}Aborted by user.${NC}"
            exit 0
        else
            echo -e "${RED}Invalid choice. Please enter Y or n.${NC}"
        fi
    done
}

# ============================================================================
# sysctl.conf Generation Functions
# ============================================================================

generate_sysctl_conf() {
    # Calculate derived values
    local swappiness=10
    local dirty_ratio=10
    local dirty_bg=5
    local min_free_kb
    local nr_hugepages

    # Adjust values based on disk type
    if [[ "$DISK_TYPE" == "ssd" || "$DISK_TYPE" == "nvme" ]]; then
        swappiness=5
    fi

    # Adjust values based on RAM
    if (( RAM >= 16 )); then
        dirty_ratio=5
        dirty_bg=2
    fi

    # Calculate min_free_kb based on RAM (multiply by 4096)
    min_free_kb=$(( RAM * 4096 ))
    
    # Calculate nr_hugepages based on RAM
    nr_hugepages=$(( RAM * 156 ))

    # Network buffers based on NIC speed
    local rmax
    local wmax
    local opts

    if (( NIC >= 10000 )); then
        rmax=67108864
        wmax=67108864
        opts="4096 262144 33554432"
    elif (( NIC >= 1000 )); then
        rmax=16777216
        wmax=16777216
        opts="4096 262144 16777216"
    else
        rmax=4194304
        wmax=4194304
        opts="4096 131072 4194304"
    fi

    # Build baseline sysctl settings
    local all_settings=(
        "net.core.rmem_max = $rmax"
        "net.core.wmem_max = $wmax"
        "net.core.rmem_default = 2097152"
        "net.core.wmem_default = 2097152"
        "net.core.optmem_max = 4194304"
        "net.ipv4.tcp_rmem = $opts"
        "net.ipv4.tcp_wmem = $opts"
        "net.ipv4.udp_mem = 4194304 8388608 16777216"
        "net.ipv4.tcp_mem = 786432 1048576 26777216"
        "net.ipv4.udp_rmem_min = 16384"
        "net.ipv4.udp_wmem_min = 16384"
        "net.core.netdev_max_backlog = $(( NIC >= 10000 ? 250000 : 30000 ))"
        "net.core.somaxconn = $(( THREADS * 1024 ))"
        "net.ipv4.tcp_max_syn_backlog = 16384"
        "net.core.busy_poll = 50"
        "net.core.busy_read = 50"
        "net.ipv4.tcp_fastopen = 3"
        "net.ipv4.tcp_notsent_lowat = 16384"
        "net.core.netdev_budget_usecs = 4000"
        "net.core.dev_weight = 64"
        "net.ipv4.tcp_max_tw_buckets = 2000000"
        "net.ipv4.ip_local_port_range = 1024 65535"
        "net.ipv4.tcp_congestion_control = bbr"
        "net.core.default_qdisc = fq"
        "net.ipv4.tcp_window_scaling = 1"
        "net.ipv4.tcp_timestamps = 1"
        "net.ipv4.tcp_sack = 1"
        "net.ipv4.tcp_dsack = 1"
        "net.ipv4.tcp_slow_start_after_idle = 0"
        "net.ipv4.tcp_fin_timeout = 10"
        "net.ipv4.tcp_keepalive_time = 300"
        "net.ipv4.tcp_keepalive_intvl = 10"
        "net.ipv4.tcp_keepalive_probes = 6"
        "net.ipv4.tcp_moderate_rcvbuf = 1"
        "net.ipv4.tcp_frto = 2"
        "net.ipv4.tcp_mtu_probing = 1"
        "net.ipv4.conf.all.rp_filter = 1"
        "net.ipv4.conf.default.rp_filter = 1"
        "net.ipv4.conf.all.accept_redirects = 0"
        "net.ipv4.conf.default.accept_redirects = 0"
        "net.netfilter.nf_conntrack_max = 1048576"
        "kernel.sched_min_granularity_ns = 10000"
        "kernel.sched_wakeup_granularity_ns = 15000"
        "kernel.sched_latency_ns = 60000"
        "kernel.sched_rt_runtime_us = 980000"
        "kernel.sched_migration_cost_ns = 50000"
        "kernel.sched_autogroup_enabled = 0"
        "kernel.sched_cfs_bandwidth_slice_us = 3000"
        "vm.swappiness = $swappiness"
        "vm.dirty_ratio = $dirty_ratio"
        "vm.dirty_background_ratio = $dirty_bg"
        "vm.dirty_expire_centisecs = 1000"
        "vm.dirty_writeback_centisecs = 100"
        "vm.zone_reclaim_mode = 0"
        "vm.min_free_kbytes = $min_free_kb"
        "vm.vfs_cache_pressure = 50"
        "vm.overcommit_memory = 0"
        "vm.overcommit_ratio = 50"
        "vm.max_map_count = 1048576"
        "vm.page-cluster = 0"
        "vm.oom_kill_allocating_task = 1"
        "fs.file-max = 26214400"
        "fs.nr_open = 26214400"
        "fs.aio-max-nr = 1048576"
        "fs.inotify.max_user_instances = 8192"
        "fs.inotify.max_user_watches = 1048576"
        "kernel.pid_max = 4194304"
    )

    # Add use-case specific settings
    declare -A extra_settings

    case "$USE_CASE" in
        "virtualization")
            # Network buffer settings - optimized for VM traffic
            extra_settings["net.core.rmem_max"]=$(( NIC >= 25000 ? 134217728 : (NIC >= 10000 ? 67108864 : 33554432) ))
            extra_settings["net.core.wmem_max"]=$(( NIC >= 25000 ? 134217728 : (NIC >= 10000 ? 67108864 : 33554432) ))
            extra_settings["net.core.rmem_default"]=8388608
            extra_settings["net.core.wmem_default"]=8388608
            extra_settings["net.core.optmem_max"]=16777216
            
            # Fix TCP rmem and wmem settings using if/then/else instead of ternary operators for strings
            if [ "$NIC" -ge 25000 ]; then
                extra_settings["net.ipv4.tcp_rmem"]="8192 262144 134217728"
                extra_settings["net.ipv4.tcp_wmem"]="8192 262144 134217728"
            else
                extra_settings["net.ipv4.tcp_rmem"]="4096 131072 67108864"
                extra_settings["net.ipv4.tcp_wmem"]="4096 131072 67108864"
            fi
            
            extra_settings["net.ipv4.udp_mem"]="16777216 33554432 67108864"
            extra_settings["net.ipv4.tcp_mem"]="16777216 33554432 67108864"
            
            # Network settings for VM traffic
            extra_settings["net.ipv4.ip_forward"]=1
            extra_settings["net.ipv6.conf.all.forwarding"]=1
            extra_settings["net.bridge.bridge-nf-call-iptables"]=0
            extra_settings["net.bridge.bridge-nf-call-ip6tables"]=0
            extra_settings["net.bridge.bridge-nf-call-arptables"]=0
            extra_settings["net.core.netdev_max_backlog"]=$(( NIC >= 10000 ? 250000 : 100000 ))
            extra_settings["net.core.somaxconn"]=$(( THREADS * 1024 < 65535 ? THREADS * 1024 : 65535 ))
            extra_settings["net.ipv4.tcp_max_syn_backlog"]=$(( THREADS * 1024 < 262144 ? (THREADS * 1024 > 16384 ? THREADS * 1024 : 16384) : 262144 ))
            extra_settings["net.ipv4.tcp_tw_reuse"]=1
            extra_settings["net.ipv4.tcp_fin_timeout"]=15
            
            # Memory settings for VMs
            extra_settings["vm.nr_hugepages"]=$(( RAM >= 128 ? RAM * 200 / (CORES + 1) : RAM * 156 / (CORES + 1) ))
            extra_settings["vm.nr_hugepages"]=$(( extra_settings["vm.nr_hugepages"] < 2 ? 2 : extra_settings["vm.nr_hugepages"] ))
            extra_settings["vm.hugetlb_shm_group"]=0
            extra_settings["vm.transparent_hugepage.enabled"]="madvise"
            extra_settings["vm.transparent_hugepage.defrag"]=$(( RAM >= 64 ? "madvise" : "never" ))
            extra_settings["vm.swappiness"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 5 : 10 ))
            extra_settings["vm.dirty_ratio"]=$(( RAM >= 64 ? 10 : (RAM >= 16 ? 20 : 30) ))
            extra_settings["vm.dirty_background_ratio"]=$(( RAM >= 64 ? 3 : (RAM >= 16 ? 5 : 10) ))
            extra_settings["vm.overcommit_memory"]=1
            extra_settings["vm.overcommit_ratio"]=$(( 50 + RAM / 8 < 95 ? 50 + RAM / 8 : 95 ))
            extra_settings["vm.zone_reclaim_mode"]=0
            extra_settings["vm.min_free_kbytes"]=$(( min_free_kb < RAM * 2048 ? RAM * 2048 : min_free_kb ))
            extra_settings["vm.vfs_cache_pressure"]=$(( RAM >= 64 ? 50 : 75 ))
            
            # CPU scheduler optimized for VMs
            extra_settings["kernel.sched_migration_cost_ns"]=$(( CORES <= 4 ? 1000000 : 5000000 ))
            extra_settings["kernel.sched_autogroup_enabled"]=0
            extra_settings["kernel.pid_max"]=$(( RAM * 16384 < 4194304 * 2 ? RAM * 16384 : 4194304 * 2 ))
            
            # Connection tracking scaled to RAM
            extra_settings["net.netfilter.nf_conntrack_max"]=$(( RAM * 16384 < 4194304 ? RAM * 16384 : 4194304 ))
            extra_settings["net.netfilter.nf_conntrack_tcp_timeout_established"]=86400
            
            # NFS/storage tuning for VM images
            extra_settings["sunrpc.tcp_slot_table_entries"]=$(( RAM / 4 < 64 ? 64 : (RAM / 4 > 256 ? 256 : RAM / 4) ))
            extra_settings["sunrpc.udp_slot_table_entries"]=$(( RAM / 4 < 64 ? 64 : (RAM / 4 > 256 ? 256 : RAM / 4) ))
            
            # KVM/QEMU specifics
            extra_settings["kernel.tsc_reliable"]=1
            extra_settings["kernel.randomize_va_space"]=0
            
            # File descriptor limits scaled to RAM
            extra_settings["fs.file-max"]=$(( RAM * 2097152 < 1073741824 ? RAM * 2097152 : 1073741824 ))
            extra_settings["fs.inotify.max_user_watches"]=$(( RAM * 65536 < 8388608 ? RAM * 65536 : 8388608 ))
            extra_settings["fs.inotify.max_user_instances"]=$(( RAM * 32 < 8192 ? RAM * 32 : 8192 ))
            ;;
            
        "web")
            # Network buffer settings optimized for web servers
            extra_settings["net.core.rmem_max"]=$(( NIC >= 10000 ? 33554432 : 16777216 ))
            extra_settings["net.core.wmem_max"]=$(( NIC >= 10000 ? 33554432 : 16777216 ))
            extra_settings["net.core.rmem_default"]=1048576
            extra_settings["net.core.wmem_default"]=1048576
            extra_settings["net.core.optmem_max"]=4194304
            
            # Fix TCP rmem and wmem settings using if/then/else
            if [ "$NIC" -ge 10000 ]; then
                extra_settings["net.ipv4.tcp_rmem"]="4096 131072 33554432"
                extra_settings["net.ipv4.tcp_wmem"]="4096 131072 33554432" 
            else
                extra_settings["net.ipv4.tcp_rmem"]="4096 65536 16777216"
                extra_settings["net.ipv4.tcp_wmem"]="4096 65536 16777216"
            fi
            
            extra_settings["net.ipv4.udp_mem"]="4194304 8388608 16777216"
            extra_settings["net.ipv4.tcp_mem"]="786432 1048576 26777216"
            
            # Memory tuning for web services
            extra_settings["vm.swappiness"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 10 : 30 ))
            extra_settings["vm.vfs_cache_pressure"]=70
            extra_settings["vm.min_free_kbytes"]=$(( min_free_kb * 3/2 < RAM * 1024 ? RAM * 1024 : min_free_kb * 3/2 ))
            
            # Low dirty ratio for SSD/NVMe
            if [[ "$DISK_TYPE" == "ssd" || "$DISK_TYPE" == "nvme" ]]; then
                extra_settings["vm.dirty_ratio"]=$(( RAM >= 32 ? 5 : 10 ))
                extra_settings["vm.dirty_background_ratio"]=$(( RAM >= 32 ? 2 : 5 ))
                extra_settings["vm.dirty_expire_centisecs"]=300
                extra_settings["vm.dirty_writeback_centisecs"]=100
            else
                extra_settings["vm.dirty_ratio"]=$(( RAM >= 32 ? 3 : 5 ))
                extra_settings["vm.dirty_background_ratio"]=$(( RAM >= 32 ? 1 : 2 ))
                extra_settings["vm.dirty_expire_centisecs"]=500
                extra_settings["vm.dirty_writeback_centisecs"]=250
            fi
            
            # Network tuning for many connections
            extra_settings["net.core.somaxconn"]=$(( THREADS * 1024 < 4096 ? 4096 : (THREADS * 1024 > 262144 ? 262144 : THREADS * 1024) ))
            extra_settings["net.core.netdev_max_backlog"]=$(( NIC >= 10000 ? 250000 : (30000 > 65536 ? 30000 : 65536) ))
            extra_settings["net.ipv4.tcp_max_syn_backlog"]=$(( THREADS * 1024 > 8192 ? THREADS * 1024 : 8192 ))
            extra_settings["net.ipv4.tcp_fin_timeout"]=$(( NIC >= 10000 ? 10 : 15 ))
            extra_settings["net.ipv4.tcp_keepalive_time"]=600
            extra_settings["net.ipv4.tcp_max_tw_buckets"]=$(( RAM * 50000 < 6000000 ? RAM * 50000 : 6000000 ))
            extra_settings["net.ipv4.tcp_tw_reuse"]=1
            extra_settings["net.ipv4.tcp_fastopen"]=3
            extra_settings["net.ipv4.tcp_slow_start_after_idle"]=0
            
            # File descriptor limits scaled to RAM
            extra_settings["fs.file-max"]=$(( RAM * 1048576 < 104857600 ? RAM * 1048576 : 104857600 ))
            extra_settings["fs.inotify.max_user_watches"]=$(( RAM * 131072 < 8388608 ? RAM * 131072 : 8388608 ))
            
            # Kernel settings based on CPU count
            extra_settings["kernel.sched_min_granularity_ns"]=$(( CORES >= 16 ? 15000000 : 10000000 ))
            extra_settings["kernel.sched_wakeup_granularity_ns"]=$(( CORES >= 16 ? 20000000 : 15000000 ))
            extra_settings["kernel.pid_max"]=$(( RAM * 8192 < 1048576 ? 1048576 : (RAM * 8192 > 4194304 ? 4194304 : RAM * 8192) ))
            ;;
            
        "database")
            # Network buffer settings
            extra_settings["net.core.rmem_max"]=$(( NIC >= 10000 ? 67108864 : 33554432 ))
            extra_settings["net.core.wmem_max"]=$(( NIC >= 10000 ? 67108864 : 33554432 ))
            extra_settings["net.core.rmem_default"]=4194304
            extra_settings["net.core.wmem_default"]=4194304
            extra_settings["net.core.optmem_max"]=8388608
            extra_settings["net.ipv4.tcp_rmem"]=$(( NIC >= 10000 ? "8192 262144 67108864" : "4096 131072 33554432" ))
            extra_settings["net.ipv4.tcp_wmem"]=$(( NIC >= 10000 ? "8192 262144 67108864" : "4096 131072 33554432" ))
            extra_settings["net.ipv4.udp_mem"]="8388608 16777216 33554432"
            extra_settings["net.ipv4.tcp_mem"]="1048576 4194304 33554432"
            
            # Shared memory settings scaled to RAM
            extra_settings["kernel.shmmax"]=$(( RAM * 1024 * 1024 * 1024 * (RAM >= 64 ? 80 : 90) / 100 ))
            extra_settings["kernel.shmall"]=$(( extra_settings["kernel.shmmax"] / 4096 ))
            extra_settings["kernel.shmmni"]=$(( RAM * 32 < 4096 ? 4096 : RAM * 32 ))
            
            # Memory management
            extra_settings["vm.swappiness"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 1 : 5 ))
            
            # Dirty ratios based on disk type and RAM
            if [[ "$DISK_TYPE" == "ssd" || "$DISK_TYPE" == "nvme" ]]; then
                extra_settings["vm.dirty_ratio"]=$(( RAM >= 32 ? 20 : 40 ))
                extra_settings["vm.dirty_background_ratio"]=$(( RAM >= 32 ? 5 : 10 ))
                extra_settings["vm.dirty_expire_centisecs"]=500
                extra_settings["vm.dirty_writeback_centisecs"]=100
            else
                extra_settings["vm.dirty_ratio"]=$(( RAM >= 32 ? 10 : 20 ))
                extra_settings["vm.dirty_background_ratio"]=$(( RAM >= 32 ? 3 : 5 ))
                extra_settings["vm.dirty_expire_centisecs"]=1000
                extra_settings["vm.dirty_writeback_centisecs"]=500
            fi
            
            extra_settings["vm.zone_reclaim_mode"]=0
            extra_settings["vm.min_free_kbytes"]=$(( min_free_kb * 2 < RAM * 2048 ? RAM * 2048 : min_free_kb * 2 ))
            
            # I/O settings based on disk type
            extra_settings["vm.vfs_cache_pressure"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 50 : 125 ))
            extra_settings["vm.page-cluster"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 0 : 3 ))
            
            # Network settings for database connections
            extra_settings["net.core.somaxconn"]=$(( THREADS * 256 < 4096 ? 4096 : (THREADS * 256 > 65535 ? 65535 : THREADS * 256) ))
            extra_settings["net.ipv4.tcp_max_syn_backlog"]=$(( THREADS * 2048 < 131072 ? THREADS * 2048 : 131072 ))
            extra_settings["net.ipv4.tcp_keepalive_time"]=90
            extra_settings["net.ipv4.tcp_keepalive_intvl"]=10
            extra_settings["net.ipv4.tcp_keepalive_probes"]=9
            extra_settings["net.ipv4.tcp_max_tw_buckets"]=2000000
            extra_settings["net.ipv4.tcp_tw_reuse"]=0
            
            # File descriptor limits scaled to RAM
            extra_settings["fs.aio-max-nr"]=$(( RAM * 65536 < 4194304 ? RAM * 65536 : 4194304 ))
            extra_settings["fs.file-max"]=$(( RAM * 2097152 < 104857600 ? RAM * 2097152 : 104857600 ))
            
            # Scheduler tuning
            extra_settings["kernel.sched_migration_cost_ns"]=$(( CORES >= 16 ? 5000000 : 1000000 ))
            extra_settings["kernel.sched_min_granularity_ns"]=10000
            extra_settings["kernel.sched_wakeup_granularity_ns"]=15000
            extra_settings["kernel.sched_autogroup_enabled"]=0
            ;;
            
        "cache")
            # Network buffer settings - optimized for many small responses
            extra_settings["net.core.rmem_max"]=$(( NIC >= 10000 ? 33554432 : 16777216 ))
            extra_settings["net.core.wmem_max"]=$(( NIC >= 10000 ? 67108864 : 33554432 ))
            extra_settings["net.core.rmem_default"]=1048576
            extra_settings["net.core.wmem_default"]=4194304
            extra_settings["net.core.optmem_max"]=4194304
            
            # Fix TCP rmem and wmem settings using if/then/else
            if [ "$NIC" -ge 10000 ]; then
                extra_settings["net.ipv4.tcp_rmem"]="4096 65536 33554432"
                extra_settings["net.ipv4.tcp_wmem"]="4096 131072 67108864"
            else
                extra_settings["net.ipv4.tcp_rmem"]="4096 32768 16777216"
                extra_settings["net.ipv4.tcp_wmem"]="4096 65536 33554432"
            fi
            
            extra_settings["net.ipv4.udp_mem"]="8388608 16777216 33554432"
            extra_settings["net.ipv4.tcp_mem"]="1048576 4194304 33554432"
            
            # Memory-heavy settings for caching servers
            extra_settings["vm.swappiness"]=0
            extra_settings["vm.overcommit_memory"]=1
            extra_settings["vm.overcommit_ratio"]=$(( 50 + RAM / 4 < 95 ? 50 + RAM / 4 : 95 ))
            extra_settings["vm.min_free_kbytes"]=$(( min_free_kb * 3/2 < RAM * 1024 ? RAM * 1024 : min_free_kb * 3/2 ))
            extra_settings["vm.vfs_cache_pressure"]=$(( 50 - RAM / 8 < 5 ? 5 : 50 - RAM / 8 ))
            extra_settings["vm.dirty_ratio"]=$(( RAM >= 64 ? 3 : 5 ))
            extra_settings["vm.dirty_background_ratio"]=$(( RAM >= 64 ? 1 : 2 ))
            extra_settings["vm.zone_reclaim_mode"]=0
            
            # Network tuning for many small requests
            extra_settings["net.core.somaxconn"]=$(( THREADS * 2048 < 65535 ? 65535 : (THREADS * 2048 > 524288 ? 524288 : THREADS * 2048) ))
            extra_settings["net.ipv4.tcp_max_syn_backlog"]=$(( THREADS * 4096 < 65536 ? 65536 : (THREADS * 4096 > 262144 ? 262144 : THREADS * 4096) ))
            extra_settings["net.ipv4.tcp_max_tw_buckets"]=6000000
            extra_settings["net.ipv4.tcp_tw_reuse"]=1
            extra_settings["net.ipv4.tcp_fin_timeout"]=$(( NIC >= 10000 ? 5 : 10 ))
            extra_settings["net.core.netdev_max_backlog"]=$(( NIC >= 10000 ? 250000 : (30000 > 100000 ? 30000 : 100000) ))
            
            # CPU settings to reduce latency
            extra_settings["kernel.sched_min_granularity_ns"]=$(( CORES <= 4 ? 5000 : 10000 ))
            extra_settings["kernel.sched_wakeup_granularity_ns"]=$(( CORES <= 4 ? 10000 : 15000 ))
            extra_settings["kernel.numa_balancing"]=0
            extra_settings["kernel.sched_migration_cost_ns"]=$(( CORES <= 8 ? 5000 : (CORES * 10000 > 100000 ? CORES * 10000 : 100000) ))
            extra_settings["kernel.sched_autogroup_enabled"]=0
            
            # File descriptor limits scaled to RAM
            extra_settings["fs.file-max"]=$(( RAM * 2097152 < 104857600 ? RAM * 2097152 : 104857600 ))
            extra_settings["fs.aio-max-nr"]=$(( RAM * 8192 < 1048576 ? RAM * 8192 : 1048576 ))
            ;;
            
        "compute")
            # Network buffer settings
            extra_settings["net.core.rmem_max"]=$(( NIC >= 10000 ? 33554432 : 16777216 ))
            extra_settings["net.core.wmem_max"]=$(( NIC >= 10000 ? 33554432 : 16777216 ))
            extra_settings["net.core.rmem_default"]=2097152
            extra_settings["net.core.wmem_default"]=2097152
            extra_settings["net.core.optmem_max"]=4194304
            extra_settings["net.ipv4.tcp_rmem"]=$(( NIC >= 10000 ? "4096 131072 33554432" : "4096 65536 16777216" ))
            extra_settings["net.ipv4.tcp_wmem"]=$(( NIC >= 10000 ? "4096 131072 33554432" : "4096 65536 16777216" ))
            extra_settings["net.ipv4.udp_mem"]="4194304 8388608 16777216"
            extra_settings["net.ipv4.tcp_mem"]="1048576 4194304 16777216"
            
            # CPU scheduler tuned to core count
            extra_settings["kernel.sched_min_granularity_ns"]=$(( CORES <= 4 ? 3000 : 5000 ))
            extra_settings["kernel.sched_wakeup_granularity_ns"]=$(( CORES <= 4 ? 5000 : 10000 ))
            extra_settings["kernel.sched_latency_ns"]=$(( CORES * 1000 < 10000 ? 10000 : (CORES * 1000 > 60000 ? 60000 : CORES * 1000) ))
            extra_settings["kernel.sched_migration_cost_ns"]=$(( CORES * 5000 < 50000 ? 50000 : CORES * 5000 ))
            extra_settings["kernel.sched_autogroup_enabled"]=0
            extra_settings["kernel.numa_balancing"]=$(( CORES >= 32 ? 1 : 0 ))
            extra_settings["kernel.sched_rt_runtime_us"]=990000
            
            # Memory settings
            extra_settings["vm.swappiness"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 1 : 5 ))
            extra_settings["vm.overcommit_ratio"]=$(( 50 + RAM / 16 < 95 ? 50 + RAM / 16 : 95 ))
            extra_settings["vm.min_free_kbytes"]=$(( min_free_kb * 6/5 < RAM * 512 ? RAM * 512 : min_free_kb * 6/5 ))
            extra_settings["vm.zone_reclaim_mode"]=$(( RAM >= 64 && CORES >= 16 ? 1 : 0 ))
            extra_settings["vm.transparent_hugepage.enabled"]=$(( RAM >= 16 ? "always" : "madvise" ))
            extra_settings["vm.transparent_hugepage.defrag"]=$(( RAM >= 32 ? "always" : "madvise" ))
            
            # Process limits scaled to RAM and cores
            extra_settings["kernel.pid_max"]=$(( RAM * 32768 < 4194304 ? 4194304 : (RAM * 32768 > 4194304 * 4 ? 4194304 * 4 : RAM * 32768) ))
            extra_settings["kernel.threads-max"]=$(( RAM * 32768 < 4194304 ? 4194304 : (RAM * 32768 > 4194304 * 4 ? 4194304 * 4 : RAM * 32768) ))
            
            # Network performance scaled to NIC speed
            extra_settings["net.core.busy_poll"]=$(( NIC >= 10000 ? 50 : 25 ))
            extra_settings["net.core.busy_read"]=$(( NIC >= 10000 ? 50 : 25 ))
            extra_settings["net.core.netdev_budget"]=$(( CORES * 20 < 300 ? 300 : (CORES * 20 > 1000 ? 1000 : CORES * 20) ))
            extra_settings["net.core.somaxconn"]=$(( THREADS * 128 < 1024 ? 1024 : (THREADS * 128 > 65535 ? 65535 : THREADS * 128) ))
            
            # File descriptor limits
            extra_settings["fs.file-max"]=$(( RAM * 1048576 < 52428800 ? RAM * 1048576 : 52428800 ))
            extra_settings["fs.aio-max-nr"]=$(( RAM * 4096 < 1048576 ? RAM * 4096 : 1048576 ))
            ;;
            
        "fileserver")
            # Network settings for large transfers
            extra_settings["net.core.rmem_max"]=$(( NIC >= 40000 ? 134217728 : (NIC >= 10000 ? 67108864 : 33554432) ))
            extra_settings["net.core.wmem_max"]=$(( NIC >= 40000 ? 134217728 : (NIC >= 10000 ? 67108864 : 33554432) ))
            extra_settings["net.core.rmem_default"]=8388608
            extra_settings["net.core.wmem_default"]=8388608
            extra_settings["net.core.optmem_max"]=16777216
            
            # Fix TCP rmem and wmem settings using if/then/else
            if [ "$NIC" -ge 25000 ]; then
                extra_settings["net.ipv4.tcp_rmem"]="8192 262144 134217728"
                extra_settings["net.ipv4.tcp_wmem"]="8192 262144 134217728"
            else
                extra_settings["net.ipv4.tcp_rmem"]="4096 131072 67108864"
                extra_settings["net.ipv4.tcp_wmem"]="4096 131072 67108864"
            fi
            
            extra_settings["net.ipv4.udp_mem"]="16777216 33554432 67108864"
            extra_settings["net.ipv4.tcp_mem"]="16777216 33554432 67108864"
            
            # TCP optimizations
            extra_settings["net.ipv4.tcp_window_scaling"]=1
            extra_settings["net.ipv4.tcp_timestamps"]=1
            extra_settings["net.ipv4.tcp_sack"]=1
            extra_settings["net.ipv4.tcp_slow_start_after_idle"]=0
            extra_settings["net.ipv4.tcp_fin_timeout"]=20
            extra_settings["net.core.netdev_max_backlog"]=$(( NIC >= 10000 ? 250000 : 100000 ))
            extra_settings["net.core.somaxconn"]=$(( THREADS * 512 < 2048 ? 2048 : (THREADS * 512 > 65535 ? 65535 : THREADS * 512) ))
            
            # NFS/SMB server settings
            extra_settings["sunrpc.tcp_slot_table_entries"]=$(( RAM * 8 < 128 ? 128 : (RAM * 8 > 2048 ? 2048 : RAM * 8) ))
            extra_settings["sunrpc.udp_slot_table_entries"]=$(( RAM * 8 < 128 ? 128 : (RAM * 8 > 2048 ? 2048 : RAM * 8) ))
            extra_settings["fs.nfsd.max_connections"]=$(( RAM * 64 < 256 ? 256 : (RAM * 64 > 65536 ? 65536 : RAM * 64) ))
            
            # File descriptor limits
            extra_settings["fs.file-max"]=$(( RAM * 4194304 < 1073741824 ? RAM * 4194304 : 1073741824 ))
            extra_settings["fs.inotify.max_user_watches"]=$(( RAM * 131072 < 8388608 ? RAM * 131072 : 8388608 ))
            extra_settings["fs.inotify.max_user_instances"]=$(( RAM * 256 < 65536 ? RAM * 256 : 65536 ))
            extra_settings["fs.aio-max-nr"]=$(( RAM * 32768 < 4194304 ? RAM * 32768 : 4194304 ))
            
            # Memory for caching
            if [[ "$DISK_TYPE" == "ssd" || "$DISK_TYPE" == "nvme" ]]; then
                extra_settings["vm.dirty_ratio"]=$(( RAM >= 32 ? 15 : 30 ))
                extra_settings["vm.dirty_background_ratio"]=$(( RAM >= 32 ? 3 : 5 ))
                extra_settings["vm.vfs_cache_pressure"]=50
                extra_settings["vm.swappiness"]=10
                extra_settings["vm.dirty_expire_centisecs"]=1500
                extra_settings["vm.dirty_writeback_centisecs"]=250
            else
                extra_settings["vm.dirty_ratio"]=$(( RAM >= 32 ? 10 : 20 ))
                extra_settings["vm.dirty_background_ratio"]=$(( RAM >= 32 ? 2 : 3 ))
                extra_settings["vm.vfs_cache_pressure"]=10
                extra_settings["vm.swappiness"]=20
                extra_settings["vm.dirty_expire_centisecs"]=3000
                extra_settings["vm.dirty_writeback_centisecs"]=500
            fi
            
            extra_settings["vm.min_free_kbytes"]=$(( min_free_kb * 3/2 < RAM * 1024 ? RAM * 1024 : min_free_kb * 3/2 ))
            ;;
            
        "network")
            # Network buffer settings - maximum throughput and buffering
            extra_settings["net.core.rmem_max"]=$(( NIC >= 40000 ? 268435456 : (NIC >= 10000 ? 134217728 : 67108864) ))
            extra_settings["net.core.wmem_max"]=$(( NIC >= 40000 ? 268435456 : (NIC >= 10000 ? 134217728 : 67108864) ))
            extra_settings["net.core.rmem_default"]=16777216
            extra_settings["net.core.wmem_default"]=16777216
            extra_settings["net.core.optmem_max"]=$(( NIC >= 25000 ? 67108864 : 33554432 ))
            
            # Fix TCP rmem and wmem settings using if/then/else
            if [ "$NIC" -ge 40000 ]; then
                extra_settings["net.ipv4.tcp_rmem"]="16384 1048576 268435456"
                extra_settings["net.ipv4.tcp_wmem"]="16384 1048576 268435456"
            elif [ "$NIC" -ge 10000 ]; then
                extra_settings["net.ipv4.tcp_rmem"]="8192 524288 134217728"
                extra_settings["net.ipv4.tcp_wmem"]="8192 524288 134217728"
            else
                extra_settings["net.ipv4.tcp_rmem"]="4096 262144 67108864"
                extra_settings["net.ipv4.tcp_wmem"]="4096 262144 67108864"
            fi
            
            # Fix UDP mem/TCP mem settings using if/then/else
            if [ "$NIC" -ge 25000 ]; then
                extra_settings["net.ipv4.udp_mem"]="33554432 67108864 134217728"
                extra_settings["net.ipv4.tcp_mem"]="33554432 67108864 134217728"
            else
                extra_settings["net.ipv4.udp_mem"]="16777216 33554432 67108864"
                extra_settings["net.ipv4.tcp_mem"]="16777216 33554432 67108864"
            fi
            
            # Routing and forwarding
            extra_settings["net.ipv4.ip_forward"]=1
            extra_settings["net.ipv6.conf.all.forwarding"]=1
            extra_settings["net.ipv4.conf.all.route_localnet"]=1
            extra_settings["net.ipv4.conf.all.rp_filter"]=2
            extra_settings["net.ipv4.conf.default.rp_filter"]=2
            
            # Connection tracking scaled to RAM and NIC
            extra_settings["net.netfilter.nf_conntrack_max"]=$(( RAM * 65536 < 8388608 ? RAM * 65536 : 8388608 ))
            extra_settings["net.netfilter.nf_conntrack_tcp_timeout_established"]=432000
            extra_settings["net.netfilter.nf_conntrack_tcp_timeout_time_wait"]=30
            
            # TCP tuning for network appliances
            extra_settings["net.core.netdev_max_backlog"]=$(( NIC >= 40000 ? 1000000 : 250000 ))
            extra_settings["net.core.netdev_budget"]=$(( CORES * 25 < 300 ? 300 : (CORES * 25 > 1000 ? 1000 : CORES * 25) ))
            extra_settings["net.core.netdev_budget_usecs"]=$(( NIC <= 1000 ? 4000 : 8000 ))
            extra_settings["net.core.netdev_budget_usecs"]=$(( extra_settings["net.core.netdev_budget_usecs"] < 2000 ? 2000 : (extra_settings["net.core.netdev_budget_usecs"] > 16000 ? 16000 : extra_settings["net.core.netdev_budget_usecs"]) ))
            extra_settings["net.core.dev_weight"]=600
            
            # Packet processing scaled to threads and NIC
            extra_settings["net.core.somaxconn"]=$(( THREADS * 2048 < 65535 ? 65535 : (THREADS * 2048 > 1048576 ? 1048576 : THREADS * 2048) ))
            extra_settings["net.ipv4.tcp_max_syn_backlog"]=$(( THREADS * 2048 < 65536 ? 65536 : (THREADS * 2048 > 1048576 ? 1048576 : THREADS * 2048) ))
            extra_settings["net.ipv4.tcp_adv_win_scale"]=$(( NIC >= 10000 ? 1 : 2 ))
            extra_settings["net.ipv4.tcp_no_metrics_save"]=1
            extra_settings["net.ipv4.tcp_slow_start_after_idle"]=0
            extra_settings["net.ipv4.tcp_max_tw_buckets"]=$(( RAM * 20000 < 2000000 ? 2000000 : (RAM * 20000 > 6000000 ? 6000000 : RAM * 20000) ))
            
            # Memory settings
            extra_settings["vm.min_free_kbytes"]=$(( min_free_kb * 2 < RAM * 2048 ? RAM * 2048 : min_free_kb * 2 ))
            extra_settings["vm.swappiness"]=10
            extra_settings["vm.dirty_ratio"]=5
            extra_settings["vm.dirty_background_ratio"]=2
            
            # File descriptor limits
            extra_settings["fs.file-max"]=$(( RAM * 1048576 < 104857600 ? RAM * 1048576 : 104857600 ))
            extra_settings["fs.nr_open"]=$(( RAM * 1048576 < 104857600 ? RAM * 1048576 : 104857600 ))
            ;;
            
        "container")
            # Network buffer settings
            extra_settings["net.core.rmem_max"]=$(( NIC >= 10000 ? 67108864 : 33554432 ))
            extra_settings["net.core.wmem_max"]=$(( NIC >= 10000 ? 67108864 : 33554432 ))
            extra_settings["net.core.rmem_default"]=4194304
            extra_settings["net.core.wmem_default"]=4194304
            extra_settings["net.core.optmem_max"]=8388608
            extra_settings["net.ipv4.tcp_rmem"]=$(( NIC >= 10000 ? "4096 262144 67108864" : "4096 131072 33554432" ))
            extra_settings["net.ipv4.tcp_wmem"]=$(( NIC >= 10000 ? "4096 262144 67108864" : "4096 131072 33554432" ))
            extra_settings["net.ipv4.udp_mem"]="8388608 16777216 33554432"
            extra_settings["net.ipv4.tcp_mem"]="4194304 8388608 33554432"
            
            # Memory management
            extra_settings["vm.overcommit_memory"]=1
            extra_settings["vm.overcommit_ratio"]=$(( 50 + RAM / 4 < 95 ? 50 + RAM / 4 : 95 ))
            extra_settings["kernel.panic_on_oom"]=0
            extra_settings["vm.swappiness"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 0 : 5 ))
            extra_settings["vm.vfs_cache_pressure"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 50 : 75 ))
            extra_settings["vm.min_free_kbytes"]=$(( min_free_kb * 3/2 < RAM * 1024 ? RAM * 1024 : min_free_kb * 3/2 ))
            extra_settings["vm.dirty_ratio"]=10
            extra_settings["vm.dirty_background_ratio"]=5
            extra_settings["vm.dirty_expire_centisecs"]=500
            extra_settings["vm.dirty_writeback_centisecs"]=100
            
            # Namespace settings
            extra_settings["kernel.keys.root_maxkeys"]=$(( RAM * 4096 < 10000 ? 10000 : (RAM * 4096 > 2000000 ? 2000000 : RAM * 4096) ))
            extra_settings["kernel.keys.root_maxbytes"]=$(( RAM * 100000 < 1000000 ? 1000000 : (RAM * 100000 > 50000000 ? 50000000 : RAM * 100000) ))
            extra_settings["kernel.keys.maxkeys"]=$(( RAM * 16 < 1000 ? 1000 : (RAM * 16 > 4000 ? 4000 : RAM * 16) ))
            extra_settings["kernel.keys.maxbytes"]=$(( RAM * 16000 < 1000000 ? 1000000 : (RAM * 16000 > 4000000 ? 4000000 : RAM * 16000) ))
            extra_settings["user.max_user_namespaces"]=$(( RAM * 256 < 5000 ? 5000 : (RAM * 256 > 30000 ? 30000 : RAM * 256) ))
            extra_settings["user.max_ipc_namespaces"]=$(( RAM * 256 < 5000 ? 5000 : (RAM * 256 > 30000 ? 30000 : RAM * 256) ))
            extra_settings["user.max_pid_namespaces"]=$(( RAM * 256 < 5000 ? 5000 : (RAM * 256 > 30000 ? 30000 : RAM * 256) ))
            extra_settings["user.max_net_namespaces"]=$(( RAM * 256 < 5000 ? 5000 : (RAM * 256 > 30000 ? 30000 : RAM * 256) ))
            extra_settings["user.max_mnt_namespaces"]=$(( RAM * 256 < 5000 ? 5000 : (RAM * 256 > 30000 ? 30000 : RAM * 256) ))
            extra_settings["user.max_uts_namespaces"]=$(( RAM * 256 < 5000 ? 5000 : (RAM * 256 > 30000 ? 30000 : RAM * 256) ))
            
            # Process limits
            extra_settings["kernel.pid_max"]=$(( RAM * 32768 < 4194304 ? 4194304 : (RAM * 32768 > 4194304 * 4 ? 4194304 * 4 : RAM * 32768) ))
            extra_settings["kernel.threads-max"]=$(( RAM * 32768 < 4194304 ? 4194304 : (RAM * 32768 > 4194304 * 4 ? 4194304 * 4 : RAM * 32768) ))
            
            # Network for containers
            extra_settings["net.ipv4.ip_forward"]=1
            extra_settings["net.ipv6.conf.all.forwarding"]=1
            extra_settings["net.bridge.bridge-nf-call-ip6tables"]=1
            extra_settings["net.bridge.bridge-nf-call-iptables"]=1
            extra_settings["net.ipv4.conf.default.rp_filter"]=0
            extra_settings["net.ipv4.conf.all.rp_filter"]=0
            extra_settings["net.core.somaxconn"]=$(( THREADS * 1024 < 8192 ? 8192 : (THREADS * 1024 > 262144 ? 262144 : THREADS * 1024) ))
            extra_settings["net.ipv4.tcp_max_syn_backlog"]=$(( THREADS * 1024 < 8192 ? 8192 : (THREADS * 1024 > 262144 ? 262144 : THREADS * 1024) ))
            
            # File descriptor limits
            extra_settings["fs.file-max"]=$(( RAM * 4194304 < 1073741824 ? RAM * 4194304 : 1073741824 ))
            extra_settings["fs.inotify.max_user_instances"]=$(( RAM * 512 < 65536 ? RAM * 512 : 65536 ))
            extra_settings["fs.inotify.max_user_watches"]=$(( RAM * 131072 < 16777216 ? RAM * 131072 : 16777216 ))
            extra_settings["fs.aio-max-nr"]=$(( RAM * 8192 < 1048576 ? RAM * 8192 : 1048576 ))
            ;;
            
        "development")
            # Network buffer settings
            extra_settings["net.core.rmem_max"]=8388608
            extra_settings["net.core.wmem_max"]=8388608
            extra_settings["net.core.rmem_default"]=1048576
            extra_settings["net.core.wmem_default"]=1048576
            extra_settings["net.core.optmem_max"]=2097152
            extra_settings["net.ipv4.tcp_rmem"]="4096 65536 8388608"
            extra_settings["net.ipv4.tcp_wmem"]="4096 65536 8388608"
            extra_settings["net.ipv4.udp_mem"]="4194304 4194304 8388608"
            extra_settings["net.ipv4.tcp_mem"]="786432 1048576 4194304"
            
            # Desktop-friendly memory settings
            extra_settings["vm.swappiness"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 10 : 20 ))
            extra_settings["vm.vfs_cache_pressure"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 50 : 70 ))
            extra_settings["vm.dirty_ratio"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 10 : 20 ))
            extra_settings["vm.dirty_background_ratio"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 3 : 5 ))
            extra_settings["vm.dirty_expire_centisecs"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 1500 : 3000 ))
            extra_settings["vm.dirty_writeback_centisecs"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 250 : 500 ))
            extra_settings["vm.min_free_kbytes"]=$(( min_free_kb < RAM * 512 ? RAM * 512 : min_free_kb ))
            
            # Interactive scheduler settings
            extra_settings["kernel.sched_autogroup_enabled"]=1
            extra_settings["kernel.sched_child_runs_first"]=1
            extra_settings["kernel.sched_min_granularity_ns"]=$(( CORES * 150000 < 1000000 ? 1000000 : (CORES * 150000 > 10000000 ? 10000000 : CORES * 150000) ))
            extra_settings["kernel.sched_wakeup_granularity_ns"]=$(( CORES * 200000 < 2000000 ? 2000000 : (CORES * 200000 > 15000000 ? 15000000 : CORES * 200000) ))
            extra_settings["kernel.sched_latency_ns"]=$(( CORES * 1000000 < 6000000 ? 6000000 : (CORES * 1000000 > 30000000 ? 30000000 : CORES * 1000000) ))
            extra_settings["kernel.sched_migration_cost_ns"]=$(( CORES * 30000 < 100000 ? 100000 : (CORES * 30000 > 2000000 ? 2000000 : CORES * 30000) ))
            
            # Moderate network settings
            extra_settings["net.core.somaxconn"]=$(( NIC >= 1000 ? 4096 : 1024 ))
            extra_settings["net.ipv4.tcp_fastopen"]=3
            extra_settings["net.ipv4.tcp_keepalive_time"]=600
            extra_settings["net.ipv4.tcp_max_syn_backlog"]=$(( NIC >= 1000 ? 2048 : 512 ))
            
            # File descriptor limits for IDEs
            extra_settings["fs.inotify.max_user_watches"]=$(( RAM * 65536 < 8388608 ? RAM * 65536 : 8388608 ))
            extra_settings["fs.file-max"]=$(( RAM * 32768 < 4194304 ? RAM * 32768 : 4194304 ))
            ;;
            
        "general")
            # Network buffer settings
            extra_settings["net.core.rmem_max"]=$(( NIC >= 10000 ? 33554432 : 16777216 ))
            extra_settings["net.core.wmem_max"]=$(( NIC >= 10000 ? 33554432 : 16777216 ))
            extra_settings["net.core.rmem_default"]=2097152
            extra_settings["net.core.wmem_default"]=2097152
            extra_settings["net.core.optmem_max"]=4194304
            extra_settings["net.ipv4.tcp_rmem"]=$(( NIC >= 10000 ? "4096 131072 33554432" : "4096 65536 16777216" ))
            extra_settings["net.ipv4.tcp_wmem"]=$(( NIC >= 10000 ? "4096 131072 33554432" : "4096 65536 16777216" ))
            extra_settings["net.ipv4.udp_mem"]="4194304 8388608 16777216"
            extra_settings["net.ipv4.tcp_mem"]="786432 1048576 16777216"
            
            # Network settings
            extra_settings["net.core.somaxconn"]=$(( THREADS * 256 < 4096 ? 4096 : (THREADS * 256 > 65535 ? 65535 : THREADS * 256) ))
            extra_settings["net.ipv4.tcp_max_syn_backlog"]=$(( THREADS * 512 < 8192 ? 8192 : (THREADS * 512 > 65536 ? 65536 : THREADS * 512) ))
            extra_settings["net.core.netdev_max_backlog"]=$(( NIC >= 10000 ? 250000 : 30000 ))
            
            # Memory settings
            extra_settings["vm.swappiness"]=$(( DISK_TYPE == "ssd" || DISK_TYPE == "nvme" ? 10 : 20 ))
            extra_settings["vm.vfs_cache_pressure"]=50
            extra_settings["vm.dirty_ratio"]=$(( RAM >= 32 ? 10 : 20 ))
            extra_settings["vm.dirty_background_ratio"]=$(( RAM >= 32 ? 3 : 5 ))
            extra_settings["vm.min_free_kbytes"]=$(( min_free_kb < RAM * 1024 ? RAM * 1024 : min_free_kb ))
            
            # Process limits
            extra_settings["kernel.pid_max"]=$(( RAM * 16384 < 4194304 ? RAM * 16384 : 4194304 ))
            extra_settings["fs.file-max"]=$(( RAM * 262144 < 26214400 ? RAM * 262144 : 26214400 ))
            
            # CPU scheduler settings
            extra_settings["kernel.sched_migration_cost_ns"]=$(( CORES <= 4 ? 100000 : 500000 ))
            extra_settings["kernel.sched_min_granularity_ns"]=10000
            extra_settings["kernel.sched_wakeup_granularity_ns"]=15000
            ;;
    esac

    # IPv6 settings based on user choice
    if $DISABLE_IPV6; then
        extra_settings["net.ipv6.conf.all.disable_ipv6"]=1
        extra_settings["net.ipv6.conf.default.disable_ipv6"]=1
        extra_settings["net.ipv6.conf.lo.disable_ipv6"]=1
    else
        # IPv6 tuned similarly to IPv4
        extra_settings["net.ipv6.conf.all.accept_redirects"]=0
        extra_settings["net.ipv6.conf.default.accept_redirects"]=0
        extra_settings["net.ipv6.conf.all.accept_ra"]=0
        extra_settings["net.ipv6.conf.default.accept_ra"]=0
        extra_settings["net.ipv6.neigh.default.gc_thresh1"]=1024
        extra_settings["net.ipv6.neigh.default.gc_thresh2"]=4096
        extra_settings["net.ipv6.neigh.default.gc_thresh3"]=8192
        extra_settings["net.ipv6.conf.all.disable_ipv6"]=0
        extra_settings["net.ipv6.conf.default.disable_ipv6"]=0
    fi

    # Merge extra_settings into all_settings
    for key in "${!extra_settings[@]}"; do
        for i in "${!all_settings[@]}"; do
            if [[ "${all_settings[$i]}" =~ ^"$key = " ]]; then
                all_settings[$i]="$key = ${extra_settings[$key]}"
                unset extra_settings[$key]
                break
            fi
        done
    done

    # Add any remaining extra_settings
    for key in "${!extra_settings[@]}"; do
        all_settings+=("$key = ${extra_settings[$key]}")
    done

    # Sort settings by key for better organization
    IFS=$'\n' all_settings=($(sort <<<"${all_settings[*]}"))
    unset IFS

    # Generate header for the config file
    local disk_type_name="HDD"
    [[ "$DISK_TYPE" == "ssd" ]] && disk_type_name="SSD" 
    [[ "$DISK_TYPE" == "nvme" ]] && disk_type_name="NVMe"
    
    local header="# Optimized sysctl.conf for ${USE_CASES[$USE_CASE]%%:*}
# Hardware: $CORES cores / $THREADS threads, ${RAM}GB RAM, ${NIC}Mb/s NIC, $disk_type_name
# Generated on: $(date "+%Y-%m-%d %H:%M:%S")
#
# Apply changes with: sudo sysctl -p $INSTALL_PATH
#
# IMPORTANT: Test these settings with your specific workload.
#"

    # Combine header and settings
    echo "$header"
    printf "%s\n" "${all_settings[@]}"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    print_banner
    detect_container
    detect_os
    echo -e "${BLUE}${BOLD}System Hardware Detection:${NC}"
    detect_cpu
    detect_ram
    detect_nic_speed
    detect_disk_type
    
    confirm_or_input_hardware
    
    get_use_case
    ask_ipv6
    confirm_selection
    
    echo -e "\n${BLUE}${BOLD}Generating optimized sysctl.conf...${NC}"
    
    # Generate the configuration
    generate_sysctl_conf > "$OUTPUT_FILE"
    
    echo -e "\n${GREEN}${BOLD}Optimization complete!${NC}"
    echo -e "Configuration saved to: ${CYAN}${OUTPUT_FILE}${NC}"
    echo
    echo -e "To apply these settings:"
    echo -e "  1. Review the configuration: ${CYAN}less ${OUTPUT_FILE}${NC}"
    echo -e "  2. Copy it to system location: ${CYAN}sudo cp ${OUTPUT_FILE} ${INSTALL_PATH}${NC}"
    echo -e "  3. Apply the settings: ${CYAN}sudo sysctl -p ${INSTALL_PATH}${NC}"
    echo
    
    # Container-specific warnings
    if $IS_CONTAINER; then
        echo -e "${YELLOW}Container Environment Notes:${NC}"
        echo -e "- Some settings may require host privileges and might be ignored"
        echo -e "- For LXC containers, you may need to adjust permissions (e.g., 'lxc.cap.drop=' in your container config)"
        echo -e "- Consider applying security-critical settings on the host system instead"
        echo
    fi
    
    echo -e "${YELLOW}Note: Always test these settings in a staging environment before applying to production.${NC}"
}

main
