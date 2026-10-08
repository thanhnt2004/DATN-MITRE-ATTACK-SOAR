# DATN – MITRE ATT&CK Detection & Automated Response

## Đề tài
**Xây dựng và đánh giá hệ thống phát hiện và ứng phó tự động theo MITRE ATT&CK**

Repository này là nơi lưu cấu hình, tài liệu, rule, workflow và evidence phục vụ đồ án.

## Mục tiêu
Pipeline cốt lõi:

```text
Atomic Red Team
      ↓
Windows/Linux Endpoint
      ↓
ELK (Logstash / Elasticsearch / Kibana)
      ↓
Sigma / Elastic Detection
      ↓
Elastic Alert / Webhook
      ↓
Shuffle SOAR
      ↓
Investigation → Decision → Response → Report
      ↓
Evaluation
```

Phạm vi dự kiến: 8–10 kỹ thuật ATT&CK, 15–20 detection rules, 15–20 Atomic test case và 6–8 Shuffle playbook.

## Cấu trúc repository

```text
DATN-MITRE-ATTACK-SOAR/
├── README.md
├── .gitignore
├── docs/
│   ├── architecture.md
│   ├── deployment-guide.md
│   ├── project-plan.md
│   ├── server-configuration.md
│   └── ram-expansion.md
├── elk/
│   ├── README.md
│   ├── config/
│   └── pipelines/
├── sigma/
│   ├── README.md
│   ├── rules/
│   └── converted/
├── shuffle/
│   ├── README.md
│   └── workflows/
├── atomic-red-team/
│   ├── README.md
│   └── test-cases/
├── agents/
│   └── README.md
├── scripts/
│   └── README.md
├── evidence/
│   └── README.md
├── report/
│   └── README.md
└── diagrams/
    └── README.md
```

> Git không lưu thư mục rỗng; README trong mỗi khu vực giữ cấu trúc và mô tả mục đích.

## Server hiện tại
- AWS EC2: `m7i-flex.large`
- Ubuntu 24.04.4 LTS
- 2 vCPU
- ~8 GiB RAM
- 80 GB EBS
- Timezone: Asia/Ho_Chi_Minh
- Docker/Compose: đã cài và đang chạy Elasticsearch, Kibana, Logstash `9.5.4`

## Trạng thái lab mới nhất

- Ubuntu `prod-web-01`: Nginx -> Gunicorn -> Flaskr/SQLite, đặt sau pfSense trên VMnet10.
- Logstash: Beats input `5044/TCP`, dành cho nguồn telemetry của lab Thanh.
- Hai nguồn của Bình: Winlogbeat và Auditbeat đang gửi trực tiếp đến Elasticsearch `9200/TCP` theo ngoại lệ tạm thời của nhóm.
- Cảnh báo: Elastic security hiện tắt; Kibana và các API chỉ được phép mở cho đúng IP nguồn `/32`, không dùng `0.0.0.0/0`.

Xem [báo cáo đối chiếu 2026-10-08](docs/2026-10-08-lab-web-elk-status.md).

Xem chi tiết tại [docs/server-configuration.md](docs/server-configuration.md).

## Nguyên tắc backup
- Mọi thay đổi cấu hình quan trọng phải commit.
- Không commit password, API key, token, SSH private key, AWS credential hoặc `.env`.
- Export rule/workflow trước các mốc demo.
- Evidence phải loại bỏ secret và dữ liệu nhạy cảm.
- Trước thay đổi lớn trên EC2 nên có snapshot/backup phù hợp.
