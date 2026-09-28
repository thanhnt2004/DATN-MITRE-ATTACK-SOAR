# Nâng RAM cho AWS EC2 DATN

## 1. EC2 không ghép RAM vật lý
Instance hiện tại là AWS EC2 nên không thể gắn thêm thanh RAM như máy vật lý. Muốn tăng RAM phải **đổi Instance Type**.

Hiện tại:
```text
m7i-flex.large
2 vCPU
~8 GiB RAM
```

## 2. Quy trình nâng RAM

### Bước 1 – Kiểm tra trước khi dừng
```bash
uptime
free -h
df -h
docker ps
```

Nếu đang chạy Docker Compose:
```bash
docker compose down
```

### Bước 2 – Stop instance
```text
EC2 → Instances → DATN_TB → Instance state → Stop instance
```

Đợi trạng thái `Stopped`.

### Bước 3 – Đổi Instance Type
```text
Actions → Instance settings → Change instance type
```

Chọn instance có RAM cao hơn. Với ELK + Shuffle trên cùng máy, mục tiêu khoảng 16 GiB RAM là hợp lý cho lab.

### Bước 4 – Start lại
```text
Instance state → Start instance
```

Đợi `2/2 status checks passed`.

### Bước 5 – Kiểm tra
```bash
free -h
lscpu
uname -a
lsblk
df -h
```

## 3. Lưu ý Public IP
Nếu dùng auto-assigned Public IPv4, IP có thể thay đổi sau stop/start. Không hard-code IP public vào repository, Sigma rule hoặc Shuffle workflow.

## 4. Dữ liệu
EBS thường vẫn giữ dữ liệu qua stop/start và đổi instance type, nhưng trước thay đổi lớn nên:
- commit config lên GitHub;
- backup/export workflow và rules;
- cân nhắc snapshot EBS;
- kiểm tra Docker volume / Elasticsearch data path.

## 5. Swap
Nếu đã tạo swap 4 GiB có thể giữ lại:
```bash
swapon --show
free -h
```

## 6. Theo dõi thay đổi

| Ngày | Instance trước | Instance sau | RAM trước | RAM sau | Lý do |
|---|---|---|---:|---:|---|
| YYYY-MM-DD | m7i-flex.large | TBD | ~8 GiB | TBD | TBD |
