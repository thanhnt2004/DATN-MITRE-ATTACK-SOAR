# DATN – MITRE ATT&CK Detection & Automated Response

## 1. Đề tài

**Xây dựng và đánh giá hệ thống phát hiện và ứng phó tự động theo MITRE ATT&CK**

Mục tiêu của đồ án là xây dựng một môi trường SOC lab có khả năng:

- Thu thập và tập trung log bằng ELK.
- Phát hiện hành vi tấn công bằng Sigma.
- Mô phỏng kỹ thuật tấn công bằng Atomic Red Team.
- Ánh xạ sự kiện/phát hiện theo MITRE ATT&CK.
- Tự động hóa quy trình phản ứng bằng Shuffle SOAR.
- Đánh giá khả năng phát hiện và phản ứng của hệ thống.

## 2. Công nghệ dự kiến

| Thành phần | Công nghệ |
|---|---|
| SIEM / Log Management | ELK Stack |
| Detection Rule | Sigma |
| Attack Simulation | Atomic Red Team |
| SOAR | Shuffle |
| Framework | MITRE ATT&CK |
| Deployment | Docker / Linux |
| Version Control | GitHub |

## 3. Cấu trúc repository

```text
DATN-MITRE-ATTACK-SOAR/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── server-configuration.md
│   ├── ram-expansion.md
│   └── deployment-guide.md
├── elk/
├── sigma/
├── atomic-red-team/
├── shuffle/
├── agents/
├── scripts/
└── diagrams/
```

> Git không lưu thư mục rỗng. Các thư mục thành phần sẽ xuất hiện khi có cấu hình, script hoặc tài liệu tương ứng.

## 4. Kiến trúc tổng quan

```text
Endpoint / Victim VMs
        |
        | logs
        v
+------------------+
|      ELK         |
| Elasticsearch    |
| Logstash         |
| Kibana           |
+------------------+
        |
        | detection
        v
+------------------+
| Sigma Rules      |
+------------------+
        |
        | alert
        v
+------------------+
| Shuffle SOAR     |
+------------------+
        |
        | response
        v
Endpoint / Analyst

Atomic Red Team
      |
      +----> tạo hành vi kiểm thử theo MITRE ATT&CK
```

## 5. Tài liệu

- [Kiến trúc hệ thống](docs/architecture.md)
- [Cấu hình server](docs/server-configuration.md)
- [Ghép / nâng cấp RAM](docs/ram-expansion.md)
- [Kế hoạch triển khai](docs/deployment-guide.md)

## 6. Nguyên tắc làm việc

- Không commit password, API key, token, private key hoặc file `.env` chứa secret.
- Thay đổi cấu hình quan trọng cần được ghi lại trong tài liệu.
- Detection rule nên ghi rõ MITRE ATT&CK Technique ID.
- Mỗi kịch bản kiểm thử cần lưu evidence và kết quả.
- Ưu tiên cấu hình có thể tái tạo bằng Docker Compose và script.

## 7. Tiến độ chính

1. Chuẩn hóa server và repository.
2. Triển khai ELK.
3. Kết nối endpoint/log source.
4. Xây dựng Sigma detection.
5. Mô phỏng Atomic Red Team.
6. Ánh xạ MITRE ATT&CK.
7. Tích hợp Shuffle SOAR.
8. Xây dựng playbook phản ứng.
9. Kiểm thử và đo lường.
10. Hoàn thiện báo cáo đồ án.
