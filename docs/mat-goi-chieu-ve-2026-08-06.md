# Mất gói chiều ra của VPS — 2026-08-06

Hồ sơ chẩn đoán sự cố người chơi bị giật trên server DST. Kết luận: **mạng chiều
ra của VPS rớt 10–17% gói**, không phải lỗi server, không phải lỗi mạng người chơi.

## Triệu chứng

Người chơi giật liên tục, ở nhiều mạng khác nhau (không riêng một người, không
riêng một nhà mạng). Bắt đầu ghi nhận ngày 2026-08-06.

## Bằng chứng quyết định — mất gói chỉ ở CHIỀU VỀ

Đếm bằng bộ đếm ICMP của kernel (`/proc/net/snmp`) tại VPS, đối chiếu với số gói
máy khách nhận lại:

| | số gói |
|---|---|
| Máy khách gửi đi | 60 |
| **VPS nhận được** | **60 / 60 → chiều đi mất 0,0%** |
| VPS trả lời | 60 |
| **Máy khách nhận lại** | **50 / 60 → chiều về mất 16,7%** |

Gói đi tới VPS **không mất một cái nào**. Toàn bộ mất mát nằm ở chặng VPS → người chơi.

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

> Kính gửi bộ phận kỹ thuật,
>
> VPS **116.118.51.158** của tôi đang mất **10–17% gói ở chiều ra** (từ VPS đi
> tới người dùng). Chiều vào hoàn toàn bình thường.
>
> Bằng chứng: dùng bộ đếm ICMP của kernel tại VPS, trong 60 gói gửi từ máy khách
> thì VPS **nhận đủ 60/60** và **trả lời đủ 60**, nhưng máy khách chỉ **nhận lại
> 50**. Thử lại bằng UDP 206 byte ở nhịp 20 gói/giây cũng mất 10,0%. Cùng máy
> khách đó, cùng thời điểm, ping 1.1.1.1 và 8.8.8.8 đều **0,0% mất gói**.
>
> Phía VPS đã kiểm tra và loại trừ: card mạng `TX dropped = 0`, `TX errors = 0`,
> băng thông đang dùng chỉ 0,02 Mbit/s vào và 0,00 Mbit/s ra (gần như rỗng),
> không có traffic shaping, tường lửa không có luật nào, CPU 40%, RAM còn 1,3 GB,
> swap không dùng. Gói rời card mạng bình thường nhưng không tới được đích.
>
> Đã thử khởi động lại VPS, tình trạng không đổi.
>
> Nhờ anh/chị kiểm tra tuyến ra của node đang chứa VPS này, hoặc chuyển VPS sang
> node khác giúp tôi. Nhiều người dùng ở các nhà mạng khác nhau đều bị ảnh hưởng.
>
> Xin cảm ơn.

## Cách đo lại

```bash
# Chiều nào mất gói — chạy từ máy khách
ssh dst 'grep "^Icmp" /proc/net/snmp'      # ghi lại InEchos, OutEchoReps
ping -c 60 -i 0.5 116.118.51.158
ssh dst 'grep "^Icmp" /proc/net/snmp'      # lấy hiệu số

# InEchos tăng đủ 60  → chiều đi tốt
# máy khách nhận < 60 → mất ở chiều về
```
