# 📊 Real-time ASCII System Monitor

A comprehensive real-time system monitoring tool designed for Radxa Rock and other Linux systems. Features beautiful ASCII graphics, color-coded displays, and historical data visualization.

![System Monitor Demo](https://img.shields.io/badge/Platform-Linux-blue) ![License](https://img.shields.io/badge/License-MIT-green) ![Shell](https://img.shields.io/badge/Shell-Bash-orange)

## 🎯 Features

### 📈 **Real-time Monitoring**
- **CPU Usage**: Overall system load with color indicators
- **Memory Usage**: RAM consumption in MB/GB with percentage
- **Temperature**: All thermal sensors with color-coded warnings
- **Disk I/O**: Real-time read/write speeds across all storage devices

### 🎨 **Visual Elements**
- **ASCII Progress Bars**: Color-coded (Green → Yellow → Red)
- **Sparkline Graphs**: Historical trends using Unicode characters
- **Responsive Layout**: Adapts to terminal width automatically
- **No Scrolling**: Fixed-height display that updates in place

### 🚀 **Performance**
- **1-second Updates**: Real-time monitoring without lag
- **Low Resource Usage**: Minimal CPU and memory footprint
- **Smart Detection**: Automatically finds all storage devices
- **Cross-platform**: Works on various ARM and x86 Linux systems

## 📦 Installation

### Quick Install

```bash
# Download the script
wget https://raw.githubusercontent.com/wronai/ollama/main/system_monitor.sh

# Make executable
chmod +x system_monitor.sh

# Run
./system_monitor.sh
```

### Manual Installation

```bash
# Clone repository
git clone https://github.com/wronai/ollama.git
cd ollama

# Make executable
chmod +x system_monitor.sh

# Run monitor
./system_monitor.sh
```

## 🖥️ Usage

### Basic Usage

```bash
# Start the monitor
./system_monitor.sh

# Exit with Ctrl+C or press 'q'
```

### Controls

| Key | Action |
|-----|--------|
| `Ctrl+C` | Exit monitor |
| `q` | Quit monitor |
| `Q` | Quit monitor |

## 📊 Display Sections

### ⚡ CPU Usage
```
⚡ CPU Usage: 25%
  Overall: ███████░░░░░░░░░░░░░░ [25%]
  History: ▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▄▅▆
```
- **Real-time percentage**: Current CPU load
- **Progress bar**: Visual representation with colors
- **History sparkline**: Last 60 seconds of activity

### 💾 Memory Usage
```
💾 Memory Usage: 45% (3584MB / 7928MB)
  Usage:   ███████████░░░░░░░░░ [45%]
  History: ▃▄▅▄▃▄▅▆▅▄▃▄▅▄▃▄▅▄▃▄
```
- **Percentage and absolute values**: Used/Total in MB
- **Visual progress bar**: Current memory usage
- **Historical trend**: Memory usage over time

### 🌡️ Temperature
```
🌡️ Temperature: 42°C (38°C 41°C 42°C 39°C)
  Current: ████████░░░░░░░░░░░░ [42°C]
  History: ▃▃▄▄▅▅▄▄▃▃▄▄▅▅▆▆▅▅▄▄
```
- **Highest temperature**: From all thermal sensors
- **All sensor readings**: Individual temperature values
- **Color coding**: Green (< 50°C), Yellow (50-70°C), Red (> 70°C)

### 💿 Disk I/O
```
💿 Disk I/O: Read: 15.2MB/s Write: 8.7MB/s
  Read:    ████████████░░░░░░░░ [15.2MB/s]
  Write:   ██████░░░░░░░░░░░░░░ [8.7MB/s]
  R.Hist:  ▁▂▃▄▅▆▇▆▅▄▃▂▁▂▃▄▅▆▇▆
  W.Hist:  ▁▁▂▂▃▃▄▄▅▅▄▄▃▃▂▂▁▁▂▂
```
- **Combined I/O rates**: All storage devices summed
- **Separate read/write tracking**: Independent monitoring
- **Historical graphs**: I/O patterns over time
- **Auto-scaling**: Adjusts to current activity levels

## 🎨 Color Scheme

### Status Colors
- 🟢 **Green**: Good (0-30% usage, < 50°C)
- 🟡 **Yellow**: Warning (30-70% usage, 50-70°C)
- 🔴 **Red**: Critical (70%+ usage, > 70°C)

### Section Colors
- **CPU**: Dynamic based on load
- **Memory**: Dynamic based on usage
- **Temperature**: Dynamic based on heat
- **Disk Read**: Green bars
- **Disk Write**: Magenta bars

## 🔧 Configuration

### Supported Systems

| System | CPU | Memory | Temperature | Disk I/O |
|--------|-----|--------|-------------|----------|
| **Radxa Rock** | ✅ | ✅ | ✅ | ✅ |
| **Raspberry Pi** | ✅ | ✅ | ✅ | ✅ |
| **Generic ARM** | ✅ | ✅ | ⚠️* | ✅ |
| **x86/x64 Linux** | ✅ | ✅ | ⚠️* | ✅ |

*Temperature monitoring depends on available thermal sensors

### Storage Device Detection

The monitor automatically detects and monitors:

| Device Type | Examples | Detection Method |
|-------------|----------|------------------|
| **NVMe SSD** | `nvme0n1`, `nvme1n1` | `/sys/block/nvme*` |
| **SATA/USB** | `sda`, `sdb`, `sdc` | `/sys/block/sd*` |
| **eMMC/SD** | `mmcblk0`, `mmcblk1` | `/sys/block/mmc*` |
| **IDE (legacy)** | `hda`, `hdb` | `/sys/block/hd*` |

### Terminal Requirements

- **Minimum width**: 80 characters
- **Unicode support**: For sparkline characters
- **Color support**: 256-color terminal recommended
- **Bash version**: 4.0+ recommended

## 🛠️ Troubleshooting

### Common Issues

#### No Temperature Data
```bash
# Check available thermal sensors
ls /sys/class/thermal/thermal_zone*/temp

# Manual temperature check
cat /sys/class/thermal/thermal_zone0/temp
```

#### No Disk I/O Data
```bash
# Check available block devices
ls /sys/block/

# Check diskstats
cat /proc/diskstats | head -5

# Test disk activity
dd if=/dev/zero of=/tmp/test bs=1M count=100
```

#### CPU Usage Always 0%
```bash
# Check /proc/stat
head -5 /proc/stat

# Generate CPU load for testing
yes > /dev/null &
# Kill with: killall yes
```

#### Display Issues
```bash
# Check terminal size
echo "Width: $(tput cols), Height: $(tput lines)"

# Test Unicode support
echo "▁▂▃▄▅▆▇█ ░▌█"

# Reset terminal if corrupted
reset
```

### Performance Testing

Generate system load for testing:

```bash
# CPU stress test
stress --cpu 4 --timeout 30s

# Memory stress test  
stress --vm 2 --vm-bytes 1G --timeout 30s

# Disk I/O test
# Write test
dd if=/dev/zero of=/tmp/write_test bs=1M count=500

# Read test
dd if=/tmp/write_test of=/dev/null bs=1M

# Cleanup
rm /tmp/write_test
```

### Debug Mode

Enable debug output:

```bash
# Add debug prints to the script
sed -i 's/# echo "Debug:/echo "Debug:/' system_monitor.sh

# Or manually add debug lines
echo "Available devices:" >&2
ls /sys/block/ >&2
```

## ⚙️ Customization

### Modify Update Interval

Change the sleep interval in the main loop:

```bash
# Edit the script
nano system_monitor.sh

# Find this line:
sleep 1

# Change to desired interval (e.g., 2 seconds):
sleep 2
```

### Adjust Graph Width

Modify the graph width calculation:

```bash
# Find this line:
GRAPH_WIDTH=$((TERM_WIDTH - 30))

# Adjust the offset (30) to your preference:
GRAPH_WIDTH=$((TERM_WIDTH - 25))
```

### Change Color Thresholds

Edit the `get_color_by_percent` function:

```bash
get_color_by_percent() {
    local percent=$1
    if [ $percent -lt 20 ]; then      # Changed from 30
        echo $GREEN
    elif [ $percent -lt 60 ]; then   # Changed from 70
        echo $YELLOW
    else
        echo $RED
    fi
}
```

### Add Custom Sensors

Extend temperature monitoring:

```bash
# Add custom temperature source
get_custom_temp() {
    # Example: GPU temperature
    if [ -f /sys/class/hwmon/hwmon0/temp1_input ]; then
        local temp=$(cat /sys/class/hwmon/hwmon0/temp1_input)
        echo $((temp / 1000))
    fi
}
```

## 📋 System Requirements

### Minimum Requirements
- **OS**: Linux (any distribution)
- **Shell**: Bash 4.0+
- **Memory**: 10MB RAM
- **Storage**: 50KB disk space
- **CPU**: Any (minimal usage)

### Recommended Requirements
- **Terminal**: 100+ columns wide
- **Unicode**: Full Unicode support
- **Colors**: 256-color terminal
- **Sensors**: Hardware monitoring support

### Dependencies

The script uses only standard Linux utilities:

```bash
# Check if all dependencies are available
which cat grep awk sed tput date head tail
```

Required files/directories:
- `/proc/stat` - CPU statistics
- `/proc/meminfo` - Memory information
- `/proc/diskstats` - Disk I/O statistics
- `/sys/class/thermal/` - Temperature sensors
- `/sys/block/` - Block device information

## 🚀 Advanced Usage

### Run as Service

Create a systemd service for continuous monitoring:

```bash
# Create service file
sudo nano /etc/systemd/system/system-monitor.service
```

```ini
[Unit]
Description=System Monitor
After=network.target

[Service]
Type=simple
User=pi
ExecStart=/home/pi/system_monitor.sh
Restart=always
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start service
sudo systemctl enable system-monitor
sudo systemctl start system-monitor

# View output
journalctl -u system-monitor -f
```

### Remote Monitoring

Monitor remote systems via SSH:

```bash
# Direct execution
ssh user@remote-host 'bash -s' < system_monitor.sh

# With tmux/screen for persistent session
ssh user@remote-host
tmux new-session -d -s monitor './system_monitor.sh'
tmux attach -t monitor
```

### Log to File

Capture monitoring data:

```bash
# Run with timestamp logging
./system_monitor.sh | while read line; do
    echo "$(date): $line" >> /var/log/system-monitor.log
done

# Rotate logs
logrotate -d /etc/logrotate.d/system-monitor
```

## 🤝 Contributing

### Bug Reports

Found a bug? Please include:

1. **System information**:
   ```bash
   uname -a
   cat /etc/os-release
   ```

2. **Terminal information**:
   ```bash
   echo $TERM
   tput cols; tput lines
   ```

3. **Error output**:
   ```bash
   bash -x system_monitor.sh 2>&1 | head -50
   ```

### Feature Requests

Ideas for new features:
- Network I/O monitoring
- GPU usage tracking
- Process monitoring
- Alert notifications
- Web dashboard
- Mobile app companion

### Development

```bash
# Fork the repository
git clone https://github.com/yourusername/ollama.git

# Create feature branch
git checkout -b feature-name

# Make changes and test
./system_monitor.sh

# Commit and push
git add system_monitor.sh
git commit -m "Add: new feature description"
git push origin feature-name

# Create pull request
```

## 📄 License

This project is open source and available under the MIT License.

```
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software.
```

## 🙏 Acknowledgments

- **Linux kernel developers** - For `/proc` and `/sys` interfaces
- **Unicode Consortium** - For sparkline and progress bar characters
- **Open source community** - For inspiration and feedback
- **Radxa** - For excellent ARM single-board computers

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/wronai/ollama/issues)
- **Discussions**: [GitHub Discussions](https://github.com/wronai/ollama/discussions)
- **Documentation**: This README and inline comments

---

**Happy monitoring! 📊🚀**

---

## 📚 Additional Resources

### Related Projects
- [htop](https://htop.dev/) - Interactive process viewer
- [glances](https://nicolargo.github.io/glances/) - Cross-platform monitoring
- [nmon](http://nmon.sourceforge.net/) - Performance monitoring
- [iotop](http://guichaz.free.fr/iotop/) - I/O monitoring

### Learning Resources
- [Linux Performance Analysis](https://brendangregg.com/linuxperf.html)
- [Understanding /proc/stat](https://www.kernel.org/doc/Documentation/filesystems/proc.txt)
- [Thermal Management in Linux](https://www.kernel.org/doc/html/latest/driver-api/thermal/)
- [Block Layer Statistics](https://www.kernel.org/doc/Documentation/block/stat.txt)