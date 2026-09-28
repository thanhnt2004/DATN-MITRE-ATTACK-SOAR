# Kế hoạch triển khai hệ thống

## Giai đoạn 1 – Chuẩn hóa hạ tầng

- Chuẩn hóa GitHub repository.
- Ghi lại cấu hình server.
- Cài Docker/Docker Compose.
- Thiết lập backup cấu hình.
- Kiểm tra tài nguyên CPU/RAM/Disk.

## Giai đoạn 2 – ELK

- Triển khai Elasticsearch.
- Triển khai Kibana.
- Triển khai Logstash nếu cần.
- Kiểm tra cluster health.
- Kiểm tra ingest log.
- Tạo index/data view.

## Giai đoạn 3 – Endpoint

Tối thiểu nên có:

- Windows endpoint.
- Linux endpoint.

Kiểm tra:

- endpoint gửi log,
- timestamp đúng,
- hostname/source rõ ràng,
- sự kiện có thể truy vấn trên Kibana.

## Giai đoạn 4 – Sigma

Cấu trúc gợi ý:

```text
sigma/
├── rules/
├── converted/
└── README.md
```

Mỗi rule nên ghi:

- title,
- logsource,
- detection,
- level,
- tags,
- MITRE ATT&CK Technique ID.

## Giai đoạn 5 – Atomic Red Team

Mỗi bài kiểm thử cần xác định:

1. Technique.
2. Atomic test.
3. Máy chạy.
4. Log dự kiến.
5. Sigma rule.
6. Kết quả detection.
7. Evidence.

## Giai đoạn 6 – Shuffle SOAR

Tạo workflow theo hướng:

```text
Detection
   |
   v
Webhook
   |
   v
Shuffle
   |
   +--> Enrichment
   +--> Notification
   +--> Case
   +--> Response
```

Không lưu API key/token thật trong workflow export được commit public.

## Giai đoạn 7 – Đánh giá

Các chỉ số có thể đo:

- số kỹ thuật ATT&CK kiểm thử,
- số kỹ thuật phát hiện thành công,
- detection coverage,
- false positive,
- thời gian phát hiện,
- thời gian phản ứng,
- số bước manual được tự động hóa.

## Giai đoạn 8 – Hoàn thiện

- Chụp evidence.
- Chuẩn hóa sơ đồ.
- Backup cấu hình.
- Export rule/workflow.
- Hoàn thiện bảng kết quả.
- Viết báo cáo.
- Chuẩn bị demo.
