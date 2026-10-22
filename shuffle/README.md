# Shuffle SOAR

```text
shuffle/
├── workflows/
└── README.md
```

Lưu workflow export, alert schema và tài liệu integration. Không commit API key/token thật. Workflow có response rủi ro phải có analyst approval.

## Runtime hiện tại

- Frontend: host port `3001/TCP` và `3443/TCP`.
- Backend API: `5001/TCP`.
- OpenSearch: host port `9201/TCP`, chỉ phục vụ quản trị có kiểm soát.
- Orborus chạy với `SHUFFLE_SWARM_CONFIG=run`.
- Docker Swarm một node dùng overlay `shuffle_swarm_executions` (`10.224.224.0/24`).
- Worker `1/1`; các app đã kiểm tra chạy `3/3` replicas.
- Kibana và `shuffle-frontend` cùng tham gia bridge ngoài `elk-shuffle-integration`.

Sao chép [`.env.example`](.env.example) thành `/opt/Shuffle/.env`, sinh secret riêng và không commit `.env`. `SHUFFLE_ENCRYPTION_MODIFIER` phải được đặt trước khi lưu credential/app authentication mới; không thay đổi giá trị sau khi đã dùng để mã hóa.

Xem toàn bộ quy trình cài đặt, Swarm, network và webhook tại [tài liệu cấu hình hợp nhất](../docs/2026-10-22_configuration-inventory-and-network-guide.md).
