# Agents / Endpoints

Các endpoint chính của lab:

| Endpoint | Địa chỉ lab | Agent/nguồn | Đường gửi |
|---|---:|---|---|
| pfSense | `192.168.10.1` | system/firewall syslog | UDP/5514 → Ubuntu relay |
| Windows 10 | `192.168.10.101` | Winlogbeat 9.4.5; Windows Event/PowerShell | Elasticsearch 9200 theo đường cũ hoặc Logstash TLS/5044 theo kiến trúc chuẩn |
| Kali test | `192.168.10.102` | nguồn kiểm thử | sinh lưu lượng lab |
| Ubuntu `prod-web-01` | `192.168.10.103` | Filebeat 9.5.4; rsyslog relay | TLS/TCP 5044 → Logstash |

Cấu hình chi tiết, lệnh kiểm tra, PowerShell logging, pfSense Remote Logging và bảng port nằm trong [tài liệu cấu hình hợp nhất](../docs/2026-10-22_configuration-inventory-and-network-guide.md). Không lưu credential endpoint, certificate private key hoặc token trong thư mục này.
