# Cấu hình Server DATN

## 1. Thông tin thực tế đã kiểm tra

| Hạng mục | Giá trị |
|---|---|
| Provider | AWS EC2 |
| Instance type | `m7i-flex.large` |
| OS | Ubuntu 24.04.4 LTS |
| Kernel | Linux 6.17.0-1017-aws |
| Architecture | x86-64 |
| CPU model | Intel Xeon Platinum 8488C |
| vCPU | 2 |
| RAM usable | 7.6 GiB (~8 GiB) |
| Swap | 0 B tại thời điểm kiểm tra |
| Disk | 80 GB EBS |
| Root filesystem | ~77 GB |
| Root used | ~1.9 GB |
| Root available | ~75 GB |
| Timezone | Asia/Ho_Chi_Minh (+07) |
| UFW | inactive |
| Docker | chưa cài tại thời điểm kiểm tra |
| SSH | TCP/22 đang listen |

Không lưu Public IPv4, AWS Account ID, SSH private key hoặc credential trong repository public.

## 2. CPU

```text
CPU(s): 2
Model name: Intel(R) Xeon(R) Platinum 8488C
Thread(s) per core: 2
Core(s) per socket: 1
Socket(s): 1
```

## 3. RAM

```text
Total:      7.6 GiB
Used:       ~466 MiB
Available:  ~7.1 GiB
Swap:       0 B
```

### Tạo swap 4 GiB
```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

Kiểm tra:
```bash
free -h
swapon --show
```

Swap là vùng dự phòng, không thay thế RAM thật.

## 4. Storage

```text
nvme0n1      80G
└─nvme0n1p1  ~79G mounted at /
```

Elasticsearch có thể tăng disk nhanh theo lượng log; cần theo dõi retention/ILM.

## 5. Network

Private IPv4 tại thời điểm kiểm tra:
```text
172.31.44.226/20
```

Default gateway:
```text
172.31.32.1
```

AWS VPC DNS:
```text
172.31.0.2
```

Port listen lúc kiểm tra: SSH TCP/22.

## 6. Firewall / Security Group

UFW đang inactive. Trên EC2 nên kiểm soát truy cập bằng Security Group:

- SSH 22: chỉ IP quản trị.
- Kibana 5601: giới hạn IP/VPN.
- Elasticsearch 9200: không public Internet.
- Shuffle: chỉ mở cổng web/API cần thiết.

## 7. Lệnh kiểm tra nhanh

```bash
hostnamectl
lscpu
free -h
lsblk
df -h
ip addr
ip route
resolvectl status
sudo ss -tulpn
sudo ufw status verbose
timedatectl
docker --version
docker compose version
```

## 8. Đánh giá tài nguyên

2 vCPU / 8 GiB RAM / 80 GB phù hợp cho PoC/lab nhỏ. Khi chạy ELK + Shuffle đồng thời, 16 GiB RAM sẽ an toàn hơn hoặc tách Shuffle sang máy khác.
