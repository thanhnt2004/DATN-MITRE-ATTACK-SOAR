# ELK

Khu vực lưu cấu hình ELK 9.5.4 đang sử dụng trong lab.

```text
elk/
├── docker-compose.yml
├── filebeat/
│   └── filebeat.yml
├── rsyslog/
│   └── 30-pfsense.conf
└── logstash/
    └── pipeline/
        └── logstash.conf
```

## Luồng ingest

- Ubuntu/Nginx → Filebeat → TLS/TCP 5044 → Logstash → `datn-ubuntu-*`.
- pfSense → UDP 5514 → rsyslog Ubuntu → Filebeat → TLS/TCP 5044 → Logstash → `datn-pfsense-*`.
- Windows được định tuyến vào `datn-windows-*` khi đi qua pipeline.

## Lưu ý

- Thư mục chứng chỉ runtime là `/opt/elk/logstash/certs` trên EC2 và không được commit.
- Không commit password, private key, token, AWS credential hoặc dữ liệu Elasticsearch.
- Elastic Security hiện tắt; phải giới hạn Security Group theo IP nguồn cho đến khi bật xác thực.
- Xem [báo cáo rà soát hạ tầng](../docs/2026-10-13-infrastructure-audit.md) và [kiểm kê backup](../docs/backup-inventory.md).
