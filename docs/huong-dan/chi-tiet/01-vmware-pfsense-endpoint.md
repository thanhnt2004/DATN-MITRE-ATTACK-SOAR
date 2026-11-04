# VMware, pfSense và endpoint

## VMware

Trên Windows host, kiểm tra VMware Workstation và `C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe`. Các VMX đã ghi nhận:

| VM | VMX |
|---|---|
| pfSense | `C:\Users\taola\OneDrive\Documents\Virtual Machines\FreeBSD version 10 and earlier 64-bit\FreeBSD version 10 and earlier 64-bit.vmx` |
| Windows 10 | `D:\tool\Windows 10 x64\Windows 10 x64.vmx` |
| Kali | `D:\tool\Kali Linux\kali-linux-2025.4-vmware-amd64\kali-linux-2025.4-vmware-amd64.vmwarevm\kali-linux-2025.4-vmware-amd64.vmx` |
| Ubuntu Server | `D:\tool\Ubutu server\Ubuntu Server.vmx` |

pfSense NIC0 là NAT, NIC1 custom VMnet10; Windows, Ubuntu, Kali dùng custom VMnet10. `vmrun list` liệt kê máy chạy, `vmrun -T ws start <VMX> nogui` khởi động, `vmrun -T ws getGuestIPAddress <VMX> -wait` lấy IP khi VMware Tools hỗ trợ. Máy suspended cần giữ cấu hình RAM tương ứng checkpoint khi resume; không xóa hoặc revert snapshot để ép khởi động.

## pfSense và Ubuntu relay

LAN pfSense `192.168.10.1`; Ubuntu `192.168.10.103` nghe syslog UDP 5514. Cấu hình rsyslog tham khảo `elk/rsyslog/30-pfsense.conf`, Filebeat `elk/filebeat/filebeat.yml`; script `scripts/configure-ubuntu-ingest.sh` là script cũ và có bước tạo/truncate log, đọc từng lệnh và sao lưu trước khi sử dụng lại. Đối chiếu source IP, firewall và đường đi thực tế.

PB04 đã bật Unbound `log-queries: yes` trong custom options và Remote Logging → DNS Events; cần Save và Apply Changes. Xác minh bằng truy vấn tên lab và tìm cùng marker trong log resolver rồi `datn-pfsense-*`. Xem báo cáo PB04 để biết cách thực hiện và điều kiện hoàn nguyên. Mật khẩu nằm trong kho riêng; không đưa vào lệnh ghi lịch sử shell.

## Windows 10

Windows `192.168.10.101` đã cài Sysmon64, PowerShell Script Block Logging và Winlogbeat 9.5.4. Cấu hình hiện tại xuất phát từ T1059, sau đó T1105 bổ sung Sysmon NetworkConnect cho IP Kali và FileCreate trong `C:\DATN-T1105\incoming`; Winlogbeat chọn Event 1/3/11 và 4104. Cấu hình đầy đủ, package, CA, service, kiểm thử và rollback được ghi trong [T1059](../MD%20Playbook/2026-11-04_t1059-001-install-test-report.md) và [T1105](../MD%20Playbook/2026-11-04_t1105-cai-dat-kiem-thu-quarantine.md).

```powershell
Get-Service Sysmon64,winlogbeat
& 'C:\Program Files\Winlogbeat\winlogbeat.exe' test config -c 'C:\Program Files\Winlogbeat\winlogbeat.yml'
& 'C:\Program Files\Winlogbeat\winlogbeat.exe' test output -c 'C:\Program Files\Winlogbeat\winlogbeat.yml'
```

Sysmon mặc định không ghi NetworkConnect; T1105 chỉ bật phạm vi lab. Không thay cấu hình agent có sẵn nếu chưa sao lưu và so sánh. PowerShell Event 4104 có thể chứa nội dung nhạy cảm; kiểm soát truy cập và retention.

## Kali

Kali `192.168.10.102` có Packetbeat 9.5.4 bắt DNS trên eth0, `fields.log_source=pb04-dns`, output Logstash TLS với CA. Xác minh `systemctl is-active packetbeat`, `sudo packetbeat test config` và `sudo packetbeat test output`. Atomic PB01/PB04 chạy trên Kali; T1105 dùng Kali làm HTTP server marker, Atomic chạy trên Windows. Xem báo cáo từng playbook để tránh nhầm nguồn kiểm thử với máy ghi event.
