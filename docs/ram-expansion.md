# Hướng dẫn ghép / nâng cấp RAM cho Server

Tài liệu này dùng để ghi lại cả hai trường hợp: server vật lý và máy ảo/cloud.

## 1. Kiểm tra RAM hiện tại

```bash
free -h
sudo dmidecode --type memory
```

Có thể xem nhanh:

```bash
sudo dmidecode -t memory | grep -E "Size:|Type:|Speed:|Manufacturer:|Part Number:"
```

## 2. Nếu là máy vật lý

Trước khi mua/thêm RAM cần xác định:

- loại RAM: DDR4/DDR5,
- chuẩn DIMM/SODIMM,
- số khe RAM,
- dung lượng tối đa mainboard hỗ trợ,
- dung lượng tối đa mỗi khe,
- bus RAM hỗ trợ,
- RAM ECC hay non-ECC,
- các thanh RAM hiện có.

Ưu tiên ghép RAM có cùng:

- loại DDR,
- điện áp,
- bus,
- dung lượng,
- timing,
- hãng/model nếu có thể.

Ví dụ:

```text
Slot 1: 8 GB DDR4 3200
Slot 2: 8 GB DDR4 3200
Total : 16 GB
```

### Quy trình

1. Shutdown server an toàn.
2. Ngắt nguồn điện.
3. Chống tĩnh điện.
4. Kiểm tra đúng khe RAM.
5. Lắp RAM chắc chắn.
6. Khởi động máy.
7. Kiểm tra BIOS/UEFI.
8. Kiểm tra lại trong Ubuntu.

```bash
free -h
sudo dmidecode --type memory
```

Không tháo/lắp RAM khi máy đang bật.

## 3. Nếu là VMware/VirtualBox/Hyper-V

Tắt hoàn toàn VM trước khi đổi RAM.

Sau đó:

1. mở cấu hình VM,
2. tăng Memory/RAM,
3. lưu cấu hình,
4. bật VM,
5. kiểm tra bằng:

```bash
free -h
```

## 4. Nếu là cloud

Cloud VM thường không "ghép thanh RAM". Cần đổi instance shape/type sang cấu hình có nhiều RAM hơn.

Quy trình tổng quát:

1. backup/snapshot nếu cần,
2. stop instance nếu provider yêu cầu,
3. resize/change instance type,
4. start instance,
5. kiểm tra:

```bash
nproc
free -h
lsblk
```

Trước khi resize phải kiểm tra chi phí vì tăng RAM/vCPU thường làm tăng giá.

## 5. Sau khi tăng RAM cho ELK

Kiểm tra container:

```bash
docker stats
```

Nếu Elasticsearch dùng Docker và có cấu hình heap:

```yaml
environment:
  - ES_JAVA_OPTS=-Xms2g -Xmx2g
```

Không nên tự động cấp toàn bộ RAM của máy cho Elasticsearch. Phải chừa tài nguyên cho hệ điều hành, Docker, Kibana, Logstash và Shuffle.

## 6. Ghi lại thay đổi

Sau mỗi lần nâng cấp, cập nhật:

| Ngày | RAM trước | RAM sau | Lý do | Người thực hiện |
|---|---:|---:|---|---|
| YYYY-MM-DD | TBD | TBD | TBD | TBD |
