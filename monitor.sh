#!/bin/bash

# Real-time ASCII System Monitor for Radxa Rock
# Monitors CPU, RAM, Temperature, Disk I/O with ASCII graphics

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Characters for graphs
FILLED_CHAR="█"
HALF_CHAR="▌"
EMPTY_CHAR="░"
TEMP_CHAR="🌡"
CPU_CHAR="⚡"
RAM_CHAR="💾"
DISK_CHAR="💿"

# Global variables
TERM_WIDTH=$(tput cols)
GRAPH_WIDTH=$((TERM_WIDTH - 30))
HISTORY_SIZE=60
declare -a CPU_HISTORY=()
declare -a RAM_HISTORY=()
declare -a TEMP_HISTORY=()
declare -a DISK_READ_HISTORY=()
declare -a DISK_WRITE_HISTORY=()

# Previous values for calculating differences
PREV_DISK_READ=0
PREV_DISK_WRITE=0
PREV_TIME=0

# Initialize cursor control
init_display() {
    clear
    # Hide cursor
    tput civis
    # Set up trap to restore cursor on exit
    trap 'tput cnorm; clear; exit' INT TERM EXIT
}

# Get terminal dimensions
update_dimensions() {
    TERM_WIDTH=$(tput cols)
    GRAPH_WIDTH=$((TERM_WIDTH - 30))
    if [ $GRAPH_WIDTH -lt 20 ]; then
        GRAPH_WIDTH=20
    fi
}

# Get CPU usage percentage
get_cpu_usage() {
    # Read current CPU stats
    local cpu_line=$(head -1 /proc/stat)
    local cpu_times=($cpu_line)

    # Calculate totals (skip 'cpu' label)
    local user=${cpu_times[1]}
    local nice=${cpu_times[2]}
    local system=${cpu_times[3]}
    local idle=${cpu_times[4]}
    local iowait=${cpu_times[5]}
    local irq=${cpu_times[6]}
    local softirq=${cpu_times[7]}
    local steal=${cpu_times[8]:-0}

    local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    local work=$((user + nice + system + irq + softirq + steal))

    if [ -n "$PREV_CPU_TOTAL" ] && [ -n "$PREV_CPU_WORK" ]; then
        local total_diff=$((total - PREV_CPU_TOTAL))
        local work_diff=$((work - PREV_CPU_WORK))

        if [ $total_diff -gt 0 ]; then
            local cpu_usage=$((work_diff * 100 / total_diff))
            echo $cpu_usage
        else
            echo 0
        fi
    else
        echo 0
    fi

    PREV_CPU_TOTAL=$total
    PREV_CPU_WORK=$work
}

# Get individual CPU core usage
get_cpu_cores() {
    local cores=()
    local core_num=0

    # Read all CPU core lines
    grep "^cpu[0-9]" /proc/stat | while read line; do
        local cpu_times=($line)

        # Calculate totals for this core
        local user=${cpu_times[1]}
        local nice=${cpu_times[2]}
        local system=${cpu_times[3]}
        local idle=${cpu_times[4]}
        local iowait=${cpu_times[5]}
        local irq=${cpu_times[6]}
        local softirq=${cpu_times[7]}
        local steal=${cpu_times[8]:-0}

        local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
        local work=$((user + nice + system + irq + softirq + steal))

        local prev_total_var="PREV_CPU${core_num}_TOTAL"
        local prev_work_var="PREV_CPU${core_num}_WORK"

        if [ -n "${!prev_total_var}" ] && [ -n "${!prev_work_var}" ]; then
            local total_diff=$((total - ${!prev_total_var}))
            local work_diff=$((work - ${!prev_work_var}))

            if [ $total_diff -gt 0 ]; then
                local cpu_usage=$((work_diff * 100 / total_diff))
                echo "$cpu_usage"
            else
                echo "0"
            fi
        else
            echo "0"
        fi

        declare -g "$prev_total_var=$total"
        declare -g "$prev_work_var=$work"

        ((core_num++))
    done
}

# Get RAM usage percentage
get_ram_usage() {
    local mem_info=$(cat /proc/meminfo)
    local mem_total=$(echo "$mem_info" | grep MemTotal | awk '{print $2}')
    local mem_available=$(echo "$mem_info" | grep MemAvailable | awk '{print $2}')
    local mem_used=$((mem_total - mem_available))
    local ram_percent=$((mem_used * 100 / mem_total))
    echo "$ram_percent $mem_used $mem_total"
}

# Get temperature from thermal zones
get_temperature() {
    local max_temp=0
    local temp_sources=""

    for temp_file in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$temp_file" ]; then
            local temp=$(cat "$temp_file" 2>/dev/null)
            if [ -n "$temp" ] && [ "$temp" -gt 0 ]; then
                local temp_c=$((temp / 1000))
                if [ $temp_c -gt $max_temp ]; then
                    max_temp=$temp_c
                fi
                temp_sources="${temp_sources}${temp_c}°C "
            fi
        fi
    done

    echo "$max_temp $temp_sources"
}

# Get disk I/O statistics
get_disk_io() {
    local current_time=$(date +%s)
    local total_read=0
    local total_write=0
    local found_device=false
    local device_list=""

    # First, try to get data from /proc/diskstats which is more reliable
    while IFS= read -r line; do
        local stats_array=($line)
        local major=${stats_array[0]}
        local minor=${stats_array[1]}
        local device=${stats_array[2]}

        # Skip unwanted devices
        if [[ "$device" =~ ^(loop|ram|dm-|sr) ]]; then
            continue
        fi

        # Only count main devices (not partitions for most cases)
        # For nvme: count nvme0n1, nvme1n1 etc (not nvme0n1p1)
        # For sd: count sda, sdb etc (not sda1, sda2)
        # For mmc: count mmcblk0, mmcblk1 etc (not mmcblk0p1)
        if [[ "$device" =~ ^nvme[0-9]+n[0-9]+$ ]] || \
           [[ "$device" =~ ^sd[a-z]+$ ]] || \
           [[ "$device" =~ ^mmcblk[0-9]+$ ]] || \
           [[ "$device" =~ ^hd[a-z]+$ ]]; then

            local read_ios=${stats_array[3]}      # number of read I/Os processed
            local read_sectors=${stats_array[5]}  # number of sectors read
            local write_ios=${stats_array[7]}     # number of write I/Os processed
            local write_sectors=${stats_array[9]} # number of sectors written

            # Convert sectors to bytes (512 bytes per sector)
            local read_bytes=$((read_sectors * 512))
            local write_bytes=$((write_sectors * 512))

            # Sum up all devices
            total_read=$((total_read + read_bytes))
            total_write=$((total_write + write_bytes))
            found_device=true
            device_list="$device_list $device"
        fi
    done < /proc/diskstats

    # Fallback: if no main devices found, try /sys/block approach
    if [ "$found_device" = false ]; then
        for device_path in /sys/block/*; do
            local device=$(basename "$device_path")

            # Skip unwanted devices
            if [[ "$device" =~ ^(loop|ram|dm-|sr) ]]; then
                continue
            fi

            if [ -f "$device_path/stat" ]; then
                local stats=$(cat "$device_path/stat" 2>/dev/null)
                if [ -n "$stats" ]; then
                    local stats_array=($stats)
                    local read_sectors=${stats_array[0]}   # sectors read
                    local write_sectors=${stats_array[4]}  # sectors written

                    # Convert sectors to bytes
                    local read_bytes=$((read_sectors * 512))
                    local write_bytes=$((write_sectors * 512))

                    total_read=$((total_read + read_bytes))
                    total_write=$((total_write + write_bytes))
                    found_device=true
                    device_list="$device_list $device"
                fi
            fi
        done
    fi

    # Calculate rates
    if [ "$found_device" = true ]; then
        # For first run, just store values
        if [ "$PREV_DISK_READ" = "" ] || [ "$PREV_DISK_WRITE" = "" ] || [ "$PREV_TIME" = "" ]; then
            PREV_DISK_READ=$total_read
            PREV_DISK_WRITE=$total_write
            PREV_TIME=$current_time
            echo "0 0"
            return
        fi

        local time_diff=$((current_time - PREV_TIME))
        if [ $time_diff -gt 0 ]; then
            local read_diff=$((total_read - PREV_DISK_READ))
            local write_diff=$((total_write - PREV_DISK_WRITE))

            # Handle counter wraparound or negative values
            if [ $read_diff -lt 0 ]; then read_diff=0; fi
            if [ $write_diff -lt 0 ]; then write_diff=0; fi

            local read_rate=$((read_diff / time_diff))
            local write_rate=$((write_diff / time_diff))

            # Convert to KB/s
            read_rate=$((read_rate / 1024))
            write_rate=$((write_rate / 1024))

            echo "$read_rate $write_rate"
        else
            echo "0 0"
        fi

        PREV_DISK_READ=$total_read
        PREV_DISK_WRITE=$total_write
        PREV_TIME=$current_time
    else
        echo "0 0"
    fi
}

# Create ASCII bar graph
create_bar() {
    local value=$1
    local max_value=$2
    local width=$3
    local color=$4

    # Ensure we have valid numbers
    if [ -z "$value" ] || [ "$value" -lt 0 ]; then
        value=0
    fi
    if [ -z "$max_value" ] || [ "$max_value" -le 0 ]; then
        max_value=100
    fi
    if [ -z "$width" ] || [ "$width" -le 0 ]; then
        width=20
    fi

    local filled_width=$((value * width / max_value))
    if [ $filled_width -gt $width ]; then
        filled_width=$width
    fi

    local bar=""

    # Create filled portion
    for ((i=0; i<filled_width; i++)); do
        bar="${bar}${FILLED_CHAR}"
    done

    # Create empty portion
    for ((i=filled_width; i<width; i++)); do
        bar="${bar}${EMPTY_CHAR}"
    done

    echo -e "${color}${bar}${NC}"
}

# Create sparkline graph from history
create_sparkline() {
    local -n history_ref=$1
    local width=$2
    local max_val=$3
    local color=$4

    if [ ${#history_ref[@]} -eq 0 ]; then
        printf "%*s" $width ""
        return
    fi

    local sparkline=""
    local step=$((${#history_ref[@]} <= width ? 1 : ${#history_ref[@]} / width))

    for ((i=0; i<width; i++)); do
        local index=$((i * step))
        if [ $index -lt ${#history_ref[@]} ]; then
            local value=${history_ref[$index]}
            if [ $max_val -eq 0 ]; then
                max_val=1
            fi
            local normalized=$((value * 8 / max_val))

            case $normalized in
                0) sparkline="${sparkline} " ;;
                1) sparkline="${sparkline}▁" ;;
                2) sparkline="${sparkline}▂" ;;
                3) sparkline="${sparkline}▃" ;;
                4) sparkline="${sparkline}▄" ;;
                5) sparkline="${sparkline}▅" ;;
                6) sparkline="${sparkline}▆" ;;
                7) sparkline="${sparkline}▇" ;;
                *) sparkline="${sparkline}█" ;;
            esac
        else
            sparkline="${sparkline} "
        fi
    done

    echo -e "${color}${sparkline}${NC}"
}

# Update history arrays
update_history() {
    local cpu_usage=$1
    local ram_usage=$2
    local temp=$3
    local disk_read=$4
    local disk_write=$5

    # Add new values
    CPU_HISTORY+=($cpu_usage)
    RAM_HISTORY+=($ram_usage)
    TEMP_HISTORY+=($temp)
    DISK_READ_HISTORY+=($disk_read)
    DISK_WRITE_HISTORY+=($disk_write)

    # Limit history size
    if [ ${#CPU_HISTORY[@]} -gt $HISTORY_SIZE ]; then
        CPU_HISTORY=("${CPU_HISTORY[@]:1}")
    fi
    if [ ${#RAM_HISTORY[@]} -gt $HISTORY_SIZE ]; then
        RAM_HISTORY=("${RAM_HISTORY[@]:1}")
    fi
    if [ ${#TEMP_HISTORY[@]} -gt $HISTORY_SIZE ]; then
        TEMP_HISTORY=("${TEMP_HISTORY[@]:1}")
    fi
    if [ ${#DISK_READ_HISTORY[@]} -gt $HISTORY_SIZE ]; then
        DISK_READ_HISTORY=("${DISK_READ_HISTORY[@]:1}")
    fi
    if [ ${#DISK_WRITE_HISTORY[@]} -gt $HISTORY_SIZE ]; then
        DISK_WRITE_HISTORY=("${DISK_WRITE_HISTORY[@]:1}")
    fi
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$((bytes / 1024))KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

# Get color based on percentage
get_color_by_percent() {
    local percent=$1
    if [ $percent -lt 30 ]; then
        echo $GREEN
    elif [ $percent -lt 70 ]; then
        echo $YELLOW
    else
        echo $RED
    fi
}

# Main display function
display_stats() {
    # Move cursor to top
    tput cup 0 0

    # Update terminal dimensions
    update_dimensions

    # Get current stats
    local cpu_usage=$(get_cpu_usage)
    local ram_info=($(get_ram_usage))
    local ram_usage=${ram_info[0]}
    local ram_used_kb=${ram_info[1]}
    local ram_total_kb=${ram_info[2]}
    local temp_info=($(get_temperature))
    local temp=${temp_info[0]}
    local temp_sources="${temp_info[@]:1}"
    local disk_io=($(get_disk_io))
    local disk_read=${disk_io[0]}
    local disk_write=${disk_io[1]}

    # Update history
    update_history $cpu_usage $ram_usage $temp $disk_read $disk_write

    # Header
    printf "${BOLD}${CYAN}RADXA ROCK SYSTEM MONITOR${NC} ${WHITE}%s${NC}\n" "$(date +'%H:%M:%S')"
    printf "%*s\n" $TERM_WIDTH | tr ' ' '-'

    # CPU Section
    local cpu_color=$(get_color_by_percent $cpu_usage)
    echo -e "${CPU_CHAR} ${BOLD}CPU Usage:${NC} ${cpu_color}${cpu_usage}%${NC}"
    local cpu_bar=$(create_bar $cpu_usage 100 $((GRAPH_WIDTH - 5)) $cpu_color)
    echo -e "  Overall: ${cpu_bar} ${cpu_color}[${cpu_usage}%]${NC}"

    # CPU History
    local cpu_sparkline=$(create_sparkline CPU_HISTORY $((GRAPH_WIDTH)) 100 $cpu_color)
    echo -e "  History: ${cpu_sparkline}"
    echo ""

    # RAM Section
    local ram_color=$(get_color_by_percent $ram_usage)
    local ram_used_mb=$((ram_used_kb / 1024))
    local ram_total_mb=$((ram_total_kb / 1024))
    echo -e "${RAM_CHAR} ${BOLD}Memory Usage:${NC} ${ram_color}${ram_usage}%${NC} (${ram_used_mb}MB / ${ram_total_mb}MB)"
    local ram_bar=$(create_bar $ram_usage 100 $((GRAPH_WIDTH - 5)) $ram_color)
    echo -e "  Usage:   ${ram_bar} ${ram_color}[${ram_usage}%]${NC}"
    local ram_sparkline=$(create_sparkline RAM_HISTORY $((GRAPH_WIDTH)) 100 $ram_color)
    echo -e "  History: ${ram_sparkline}"
    echo ""

    # Temperature Section
    local temp_color=$GREEN
    if [ $temp -gt 70 ]; then
        temp_color=$RED
    elif [ $temp -gt 50 ]; then
        temp_color=$YELLOW
    fi

    echo -e "${TEMP_CHAR} ${BOLD}Temperature:${NC} ${temp_color}${temp}°C${NC} (${temp_sources})"
    local temp_bar=$(create_bar $temp 100 $((GRAPH_WIDTH - 5)) $temp_color)
    echo -e "  Current: ${temp_bar} ${temp_color}[${temp}°C]${NC}"
    local temp_sparkline=$(create_sparkline TEMP_HISTORY $((GRAPH_WIDTH)) 100 $temp_color)
    echo -e "  History: ${temp_sparkline}"
    echo ""

    # Disk I/O Section
    echo -e "${DISK_CHAR} ${BOLD}Disk I/O:${NC} Read: ${GREEN}$(format_bytes $((disk_read * 1024)))/s${NC} Write: ${MAGENTA}$(format_bytes $((disk_write * 1024)))/s${NC}"

    # Find max I/O for scaling (minimum 100KB/s for better visualization)
    local max_io=100
    for val in "${DISK_READ_HISTORY[@]}" "${DISK_WRITE_HISTORY[@]}"; do
        if [ $val -gt $max_io ]; then
            max_io=$val
        fi
    done

    # Only show bars if there's some activity or history
    if [ $disk_read -gt 0 ] || [ $disk_write -gt 0 ] || [ ${#DISK_READ_HISTORY[@]} -gt 0 ]; then
        local read_bar=$(create_bar $disk_read $max_io $((GRAPH_WIDTH - 10)) $GREEN)
        echo -e "  Read:    ${read_bar} ${GREEN}[$(format_bytes $((disk_read * 1024)))/s]${NC}"
        local write_bar=$(create_bar $disk_write $max_io $((GRAPH_WIDTH - 10)) $MAGENTA)
        echo -e "  Write:   ${write_bar} ${MAGENTA}[$(format_bytes $((disk_write * 1024)))/s]${NC}"

        local read_sparkline=$(create_sparkline DISK_READ_HISTORY $((GRAPH_WIDTH - 5)) $max_io $GREEN)
        echo -e "  R.Hist:  ${read_sparkline}"
        local write_sparkline=$(create_sparkline DISK_WRITE_HISTORY $((GRAPH_WIDTH - 5)) $max_io $MAGENTA)
        echo -e "  W.Hist:  ${write_sparkline}"
    else
        echo -e "  ${YELLOW}No disk activity detected${NC}"
    fi

    printf "%*s\n" $TERM_WIDTH | tr ' ' '-'

    # Controls
    echo -e "${BOLD}${WHITE}Controls:${NC} ${CYAN}Ctrl+C${NC} to exit | ${CYAN}q${NC} to quit | Updates every 1 second"

    # Clear rest of screen
    tput ed
}

# Handle user input
handle_input() {
    read -t 0.1 -n 1 key
    if [[ $key == "q" ]] || [[ $key == "Q" ]]; then
        exit 0
    fi
}

# Main loop
main() {
    # Check if running on supported system
    if [ ! -d "/sys/class/thermal" ]; then
        echo "Warning: Thermal monitoring may not be available on this system"
    fi

    init_display

    echo "Initializing system monitor..."

    # Wait for initial readings to stabilize
    echo "Detecting storage devices..."
    get_cpu_usage >/dev/null
    get_disk_io >/dev/null
    sleep 2
    echo "Calibrating sensors..."
    get_cpu_usage >/dev/null
    get_disk_io >/dev/null
    sleep 2
    echo "Starting monitor..."

    while true; do
        display_stats
        handle_input
        sleep 1
    done
}

# Run main function
main "$@"