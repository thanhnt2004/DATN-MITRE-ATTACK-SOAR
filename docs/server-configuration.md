# Cấu hình Server DATN

## 1. Vai trò server

Server trung tâm dự kiến chạy:

- Docker Engine
- Docker Compose
- Elasticsearch
- Kibana
- Logstash (nếu cần)
- Shuffle SOAR
- Sigma rules/configuration
- Script quản trị và backup

## 2. Thông tin cần ghi lại

Khi triển khai thực tế, cập nhật bảng sau:

| Thông tin | Giá trị |
|---|---|
| Provider / Hypervisor | TBD |
| OS | Ubuntu Server |
| Hostname | TBD |
| Public IP | Không commit nếu không cần thiết |
| Private IP | TBD |
| vCPU | TBD |
| RAM | TBD |
| Disk | TBD |
| Docker version | TBD |
| Docker Compose version | TBD |

Không lưu password, SSH private key, token hoặc secret trực tiếp trong repository.

## 3. Lệnh kiểm tra cấu hình Ubuntu

### CPU

```bash
lscpu
nproc
```

### RAM

```bash
free -h
sudo dmidecode --type memory
```

### Disk

```bash
lsblk
df -h
```

### Network

```bash
ip addr
ip route
ss -tulpn
```

### OS

```bash
cat /etc/os-release
uname -a
```

### Docker

```bash
docker --version
docker compose version
docker ps
docker system df
```

## 4. Cấu hình tài nguyên khuyến nghị cho lab

Cấu hình phụ thuộc lượng log và số container. Với lab 2 thành viên:

- 4 vCPU trở lên: hợp lý cho giai đoạn đầu.
- 8 GB RAM: mức tối thiểu thực tế nếu chạy nhiều dịch vụ cùng lúc.
- 12–16 GB RAM: thuận lợi hơn cho ELK + Shuffle.
- SSD: ưu tiên hơn HDD.
- Dung lượng disk nên theo dõi thường xuyên do Elasticsearch tăng nhanh theo lượng log.

Đây là cấu hình lab tham khảo, không phải sizing cho production.

## 5. Kiểm tra dịch vụ sau reboot

```bash
uptime
who -b
last reboot | head
systemctl --failed
docker ps
```

## 6. Theo dõi tài nguyên

```bash
htop
free -h
df -h
docker stats
```

Nếu thiếu `htop`:

```bash
sudo apt update
sudo apt install -y htop
```

## 7. Quy tắc cấu hình

Mọi thay đổi quan trọng nên được ghi vào repository, ví dụ:

- tăng RAM,
- tăng disk,
- thay đổi port,
- thêm container,
- thay đổi heap Elasticsearch,
- thêm endpoint,
- thay đổi network/security group.
