package main

import (
	"fmt"
	"net"
	"os"
	"os/exec"
	"runtime"
	"sort"
	"sync"
)

type NetworkInterface struct {
	Name   string
	IPNet  *net.IPNet
	IP     net.IP
}

type Device struct {
	IP       net.IP
	Online   bool
	Hostname string
}

func main() {
	fmt.Println("Network Visualization Tool")
	fmt.Println("==========================")

	interfaces, err := getNetworkInterfaces()
	if err != nil {
		fmt.Printf("Error getting network interfaces: %v\n", err)
		os.Exit(1)
	}

	for _, iface := range interfaces {
		fmt.Printf("\nInterface: %s (%s)\n", iface.Name, iface.IP.String())
		fmt.Printf("Network: %s\n", iface.IPNet.String())
		fmt.Println("Scanning for devices...")

		devices := scanSubnet(iface.IPNet)
		displayDevices(devices)
	}
}

func getNetworkInterfaces() ([]NetworkInterface, error) {
	var interfaces []NetworkInterface

	ifaces, err := net.Interfaces()
	if err != nil {
		return nil, err
	}

	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}

		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}

		for _, addr := range addrs {
			if ipnet, ok := addr.(*net.IPNet); ok && ipnet.IP.To4() != nil {
				interfaces = append(interfaces, NetworkInterface{
					Name:  iface.Name,
					IPNet: ipnet,
					IP:    ipnet.IP,
				})
			}
		}
	}

	return interfaces, nil
}

func scanSubnet(ipnet *net.IPNet) []Device {
	var devices []Device
	var wg sync.WaitGroup
	var mu sync.Mutex

	ip := ipnet.IP.Mask(ipnet.Mask)
	for ip := ip.Mask(ipnet.Mask); ipnet.Contains(ip); incrementIP(ip) {
		if ip[3] == 0 || ip[3] == 255 {
			continue
		}

		wg.Add(1)
		go func(targetIP net.IP) {
			defer wg.Done()
			online := pingHost(targetIP.String())
			
			if online {
				hostname := resolveHostname(targetIP.String())
				mu.Lock()
				devices = append(devices, Device{
					IP:       make(net.IP, len(targetIP)),
					Online:   online,
					Hostname: hostname,
				})
				copy(devices[len(devices)-1].IP, targetIP)
				mu.Unlock()
			}
		}(append(net.IP(nil), ip...))
	}

	wg.Wait()
	
	sort.Slice(devices, func(i, j int) bool {
		return devices[i].IP[3] < devices[j].IP[3]
	})

	return devices
}

func incrementIP(ip net.IP) {
	for j := len(ip) - 1; j >= 0; j-- {
		ip[j]++
		if ip[j] > 0 {
			break
		}
	}
}

func pingHost(host string) bool {
	var cmd *exec.Cmd
	
	if runtime.GOOS == "windows" {
		cmd = exec.Command("ping", "-n", "1", "-w", "1000", host)
	} else {
		cmd = exec.Command("ping", "-c", "1", "-W", "1", host)
	}
	
	cmd.Run()
	return cmd.ProcessState.Success()
}

func resolveHostname(ip string) string {
	names, err := net.LookupAddr(ip)
	if err != nil || len(names) == 0 {
		return ""
	}
	
	hostname := names[0]
	if hostname[len(hostname)-1] == '.' {
		hostname = hostname[:len(hostname)-1]
	}
	
	return hostname
}

func displayDevices(devices []Device) {
	if len(devices) == 0 {
		fmt.Println("\nNo online devices found")
		return
	}
	
	fmt.Println("\nOnline devices:")
	fmt.Println("---------------")
	
	for _, device := range devices {
		if device.Hostname != "" {
			fmt.Printf("  %-15s - %s\n", device.IP.String(), device.Hostname)
		} else {
			fmt.Printf("  %-15s - (no hostname)\n", device.IP.String())
		}
	}
	
	fmt.Printf("\nTotal online devices: %d\n", len(devices))
}
