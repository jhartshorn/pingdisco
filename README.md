# PingDisco - Network Discovery Tool

A lightweight Go-based network discovery tool that scans local subnets to identify active devices and their hostnames.

## Features

- **Automatic Interface Detection**: Discovers all active network interfaces on your system
- **Subnet Scanning**: Scans entire subnets to find active devices using ICMP ping
- **Hostname Resolution**: Attempts to resolve hostnames via reverse DNS lookup for better device identification
- **Concurrent Scanning**: Uses goroutines for fast parallel network scanning
- **Clean Output**: Shows only online devices with their IP addresses and hostnames
- **Cross-Platform**: Works on Linux, macOS, and Windows

## Usage

```bash
./pingdisco
```

The tool will automatically:
1. Detect all active network interfaces
2. Scan each subnet for active devices
3. Display online devices with their hostnames (if available)

## Sample Output

```
Network Visualization Tool
==========================

Interface: wlp60s0 (192.168.86.132)
Network: 192.168.86.132/24
Scanning for devices...

Online devices:
---------------
  192.168.86.1    - _gateway
  192.168.86.86   - blackbird.lan
  192.168.86.107  - pihole.lan
  192.168.86.132  - nighthawk
  192.168.86.48   - (no hostname)

Total online devices: 5
```

## Building from Source

Requires Go 1.22.8 or later:

```bash
go build -o pingdisco ./cmd/pingdisco
```

## How It Works

1. **Interface Discovery**: Uses Go's `net` package to enumerate network interfaces
2. **Subnet Calculation**: Determines the network range for each interface using subnet masks
3. **Device Discovery**: Sends ICMP ping requests to all possible IPs in each subnet
4. **Hostname Resolution**: Performs reverse DNS lookups on responsive devices
5. **Results Display**: Shows only active devices with formatted output

## Requirements

- ICMP ping access (may require elevated privileges on some systems)
- Network access to target subnets
- DNS resolution for hostname lookups (optional)

## Use Cases

- Network administration and monitoring
- Security auditing to identify active devices
- IoT device discovery on local networks
- Network troubleshooting and mapping
- Home network inventory