# Mất gói chiều ra của VPS — 2026-08-06

Hồ sơ chẩn đoán sự cố người chơi bị giật trên server DST. Kết luận: **mạng chiều
ra của VPS rớt 10–17% gói**, không phải lỗi server, không phải lỗi mạng người chơi.

## Triệu chứng

Người chơi giật liên tục, ở nhiều mạng khác nhau (không riêng một người, không
riêng một nhà mạng). Bắt đầu ghi nhận ngày 2026-08-06.

## Bằng chứng quyết định — mất gói chỉ ở CHIỀU VỀ

Đếm bằng bộ đếm ICMP của kernel (`/proc/net/snmp`) tại VPS, đối chiếu với số gói
máy khách nhận lại. Mẫu lớn, 300 gói trong 2 phút:

| | số gói |
|---|---|
| Máy khách gửi đi | 300 |
| **VPS nhận được** | **300 / 300 → chiều đi mất 0,0%** |
| VPS trả lời | 300 |
| **Máy khách nhận lại** | **254 / 300 → chiều về mất 15,3%** |

Gói đi tới VPS **không mất một cái nào trong 300 gói**. Toàn bộ mất mát nằm ở
chặng VPS → người chơi.

Lặp lại nhiều lần trong khoảng 12:10–13:20 ngày 2026-08-06, chiều đi luôn 0,0%,
chiều về dao động 10–24%.

## Đã loại trừ cả yếu tố ứng dụng — đổi world không đổi kết quả

Chuyển hẳn sang một world khác (khác bộ mod, khác dữ liệu, khác tiến trình game)
rồi đo lại:

| | world `newconstant` (14 mod) | world `dang-tien` (8 mod) |
|---|---|---|
| VPS nhận được | 60 / 60 | 60 / 60 |
| Mất chiều đi | 0,0% | 0,0% |
| **Mất chiều về** | **16,7%** | **21,7%** |
| 1.1.1.1 đo cùng lúc | 0,0% | 0,0% |

Đổi toàn bộ phần mềm và dữ liệu mà mất gói không đổi → lỗi nằm ở hạ tầng mạng,
không nằm ở ứng dụng.

## Không phải do ICMP bị bóp riêng

Thử lại bằng UDP — đúng loại gói mà game dùng, kích thước 206 byte, nhịp 20 gói/giây:

```
gửi 120 gói UDP  →  nhận lại 108  →  mất 10,0%
RTT: thấp nhất 33,9 ms | giữa 49,6 ms | cao nhất 312,8 ms
```

Và ping chậm 1 gói/giây vẫn mất 12% — nếu là giới hạn tần suất ICMP thì con số
này phải về 0.

## Đối chứng từ cùng một máy khách, cùng thời điểm

| Đích | Mất gói |
|---|---|
| **VPS 116.118.51.158** | **12–24%** |
| 1.1.1.1 | 0,0% (50/50) |
| 8.8.8.8 | 0,0% (30/30) |
| Cổng hotspot 172.20.10.1 | 0,0% (50/50) |

Mạng của máy khách tốt. Chỉ riêng đường tới VPS mất gói.

## Đã loại trừ hết phía VPS

| Hạng mục | Số đo |
|---|---|
| Card mạng eth0 | RX errors 0, TX errors 0, **TX dropped 0** |
| RX dropped | 6 / 379.602 = 0,0016% |
| Băng thông đang dùng | vào 0,02 Mbit/s, ra 0,00 Mbit/s — gần như rỗng |
| Hình dạng lưu lượng (tc) | `fq_codel` mặc định, không ai bóp |
| UDP | 0 lỗi nhận, 0 tràn bộ đệm nhận, 0 tràn bộ đệm gửi |
| Tường lửa | INPUT policy ACCEPT, không có luật nào, 0 gói bị DROP |
| CPU | 38–49% trên 4 nhân |
| Load | 0.75 / 4 |
| RAM | còn trống 1,3 GB / 3,9 GB |
| Swap | 0 MB dùng, si = 0, so = 0 |
| VPS → 8.8.8.8 | 0% mất gói, 32,2 ms, dao động 0,037 ms |

Gói **rời khỏi card mạng VPS bình thường** (TX dropped = 0) nhưng không tới được
người chơi. Uplink đang rỗng nên không phải nghẽn do chính mình.

## Phía ứng dụng cũng đã loại trừ

Đo nhịp mô phỏng của server game lúc có người chơi: **3.720 tick trong 124 giây
= 30,0 tick/giây**, đúng bằng chuẩn, không rớt nhịp nào. Server không hề đuối.

## Việc đã thử mà không giải quyết được

- Khởi động lại VPS — mất gói y nguyên (13–17% → 15,0%)
- Gỡ Tailscale và kiểm tra luật tường lửa sót lại — 0 luật, 0 gói DROP
- Hạ `vm.swappiness` 60 → 10 — swap chưa hề bị đụng tới, không liên quan
- Khai báo cứng DNS cho container — DNS không gây mất gói

## Nội dung gửi nhà cung cấp

Sao chép nguyên đoạn dưới đây.

---

**Tiêu đề:** VPS 116.118.51.158 — mất 15% gói ở chiều ra, chiều vào bình thường

Kính gửi bộ phận kỹ thuật,

VPS **116.118.51.158** của tôi đang mất khoảng **15% gói ở chiều ra** (từ VPS đi
tới người dùng). Chiều vào hoàn toàn bình thường. Tình trạng kéo dài từ sáng
06/08/2026, ảnh hưởng tới nhiều người dùng ở các nhà mạng khác nhau.

**Bằng chứng xác định hướng mất gói.** Tôi dùng bộ đếm ICMP của kernel ngay tại
VPS (`/proc/net/snmp`) để đếm số gói thực sự tới nơi, rồi đối chiếu với số gói
máy khách nhận lại. Mẫu 300 gói trong 2 phút:

| | số gói |
|---|---|
| Máy khách gửi đi | 300 |
| VPS nhận được | **300 / 300** — chiều vào mất 0,0% |
| VPS trả lời | 300 |
| Máy khách nhận lại | **254 / 300** — chiều ra mất **15,3%** |

Nghĩa là gói tới VPS không mất cái nào, VPS trả lời đủ, nhưng 46 gói trả lời
không về tới đích.

**Không phải do ICMP bị giới hạn.** Tôi thử lại bằng UDP kích thước 206 byte ở
nhịp 20 gói/giây (mô phỏng lưu lượng game) — mất 10,0%. Ping chậm 1 gói/giây
cũng vẫn mất 12%; nếu là giới hạn tần suất ICMP thì con số này phải bằng 0.

**Đối chứng từ cùng máy khách, cùng thời điểm:** ping 1.1.1.1 mất 0,0% (50/50),
ping 8.8.8.8 mất 0,0% (30/30). Chỉ riêng đường tới VPS mất gói.

**Phía VPS tôi đã kiểm tra và loại trừ:**

- Card mạng eth0: `TX errors = 0`, `TX dropped = 0`, `RX errors = 0`
- Băng thông đang dùng: 0,02 Mbit/s vào, 0,00 Mbit/s ra — gần như rỗng, không nghẽn
- Không có traffic shaping (`tc` chỉ có `fq_codel` mặc định)
- Tường lửa: `INPUT policy ACCEPT`, không có luật nào, 0 gói bị DROP
- UDP: 0 lỗi nhận, 0 tràn bộ đệm nhận, 0 tràn bộ đệm gửi
- CPU 40% / 4 nhân, load 0.75, RAM còn trống 1,3 GB, swap không dùng
- Từ VPS ping ra 8.8.8.8: 0% mất gói, 32,2 ms, độ dao động 0,037 ms

Gói rời card mạng của VPS bình thường nhưng không tới được người dùng.

**Đã thử mà không cải thiện:** khởi động lại VPS (mất gói không đổi), và thay
toàn bộ ứng dụng cùng dữ liệu sang một cấu hình khác hẳn (cũng không đổi).

**Nhờ anh/chị:** kiểm tra tuyến ra của node vật lý đang chứa VPS này, hoặc chuyển
VPS sang node khác giúp tôi.

Nếu cần, anh/chị có thể tự kiểm chứng bằng cách ping VPS này từ một máy bên ngoài
và so sánh với `TX dropped` trên card mạng của nó — sẽ thấy VPS gửi đi đủ nhưng
đầu kia không nhận đủ.

Xin cảm ơn.

---

## Cách đo lại

```bash
# Chiều nào mất gói — chạy từ máy khách
ssh dst 'grep "^Icmp" /proc/net/snmp'      # ghi lại InEchos, OutEchoReps
ping -c 60 -i 0.5 116.118.51.158
ssh dst 'grep "^Icmp" /proc/net/snmp'      # lấy hiệu số

# InEchos tăng đủ 60  → chiều đi tốt
# máy khách nhận < 60 → mất ở chiều về
```
