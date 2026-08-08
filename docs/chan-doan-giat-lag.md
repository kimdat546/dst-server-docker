# Quy trình chẩn đoán giật/lag

Rút ra từ hai ngày mổ xẻ 06/08 và 08/08/2026. Mục đích: lần sau ai kêu giật thì
đi theo thứ tự này, đừng mò như hôm đó.

## Nguyên tắc

**Đo trước, sửa sau.** Ngày 08/08 mất gần cả buổi vì đi sửa trước khi đo: gỡ
Tailscale, đổi DNS, nâng tick rate, tắt mod, lùi hạ tầng về ba tháng trước, dựng
world mới — không cái nào đúng. Phép đo TPS đầu tiên làm đúng cách đã trả lời
trong 2 phút.

**Ba tầng, đo từ trong ra ngoài.** Server → đường truyền → máy khách. Mỗi tầng
có một phép đo dứt khoát, làm xong tầng nào thì loại hẳn tầng đó.

---

## Bước 1 — Đo TPS server (2 phút, loại trừ được nhiều nhất)

Điều kiện: `cli/compose.yml` phải có `stdin_open: true` và container phải được
**tạo lại** sau khi thêm dòng đó (`dst restart --fresh`, không phải `dst restart`).

```bash
ssh dst 'cd ~/dst-server-docker && ./cli/dst console "print(\"A \" .. TheSim:GetTick())"'
sleep 10
ssh dst 'cd ~/dst-server-docker && ./cli/dst console "print(\"B \" .. TheSim:GetTick())"'
ssh dst 'docker logs --tail 60 dst-master-<world> 2>&1 | grep -aE "^\[.*\] (A|B) "'
```

TPS = (B − A) / số giây thật giữa hai lần đo.

**Phải có người đang chơi.** Không có ai thì DST ghi `Sim paused`, tick đứng im và
TPS đọc ra 0 — đó là bình thường, không phải server hỏng.

**Đừng giả định khoảng thời gian.** Lần đầu đo tôi chia cho 5 giây trong khi vòng
lặp thật mất 8,3 giây, ra 49,6 thay vì 30,0. Luôn lấy mốc thời gian thật.

| Kết quả | Kết luận |
|---|---|
| **30,0** (chấp nhận 29,7–30,3) | Server vô can. Sang bước 2. Đừng đụng gì phía server nữa. |
| 20–28 | Server đuối thật. Xem số thực thể, mod nặng, CPU. |

Có bộ đo liên tục ở `docs/` lịch sử phiên: lấy mẫu mỗi 2,5 giây, ghi kèm số người
và CPU. Dùng khi giật không đều, cần bắt đúng thời điểm.

---

## Bước 2 — Đo đường truyền (từ MÁY NGƯỜI CHƠI, không phải từ VPS)

```bash
ping -c 100 116.118.51.158     # đích cần đo
ping -c 100 1.1.1.1            # đối chứng
```

Ping từ chính VPS về nó thì luôn 0% và không nói lên điều gì.

Đọc **hai** chỉ số, đừng chỉ nhìn mất gói:

**Mất gói** — trên 3% là đủ gây giật.

**Dao động độ trễ (jitter)** — quan trọng ngang mất gói và hay bị bỏ sót. Gói tới
đủ nhưng tới muộn thành cụm thì game vẫn khựng. Dấu hiệu: nền 30–45 ms nhưng xen
kẽ những đợt vọt 100–300 ms. Nếu các đợt vọt **lặp lại đều đặn** (ví dụ cứ ~14
giây) thì gần như chắc chắn là thiết bị mạng phía người chơi làm việc định kỳ —
máy quét Wi-Fi nền, hoặc modem di động báo hiệu.

### Xác định mất gói ở chiều nào

Dùng bộ đếm ICMP của kernel ngay tại VPS:

```bash
ssh dst 'grep "^Icmp" /proc/net/snmp'    # ghi lại InEchos, OutEchoReps
ping -c 300 -i 0.4 116.118.51.158        # từ máy người chơi
ssh dst 'grep "^Icmp" /proc/net/snmp'    # lấy hiệu số
```

- `InEchos` tăng đủ 300 → chiều đi sạch, mất ở **chiều về** (VPS → người chơi)
- `InEchos` tăng thiếu → mất ở **chiều đi**

Chiều về mất gói mà `TX dropped = 0` trên `eth0` thì gói đã rời máy chủ bình
thường — lỗi nằm ở nhà cung cấp. Xem `mat-goi-chieu-ve-2026-08-06.md`.

### Loại trừ chuyện ICMP bị bóp riêng

Nhiều nơi hạ ưu tiên ICMP nên ping mất gói mà UDP vẫn nguyên. Hai cách kiểm:

- Ping chậm lại 1 gói/giây. Nếu mất gói biến mất thì là giới hạn tần suất.
- Thử bằng UDP đúng cỡ gói game (206 byte, 20 gói/giây) — cách này chắc chắn hơn.

---

## Bước 3 — Máy khách

Tới đây mà server 30,0 TPS và đường truyền sạch thì nguyên nhân ở máy người chơi.

Hỏi đúng câu để phân biệt:

- **Mọi thứ khựng, cả camera lẫn giao diện** → máy đuối vì mod nặng phía client
  (Legion, Simple Health Bar vẽ thanh máu lên mọi sinh vật, Show Me).
- **Mình mượt nhưng người khác và quái nhảy cóc** → đường truyền, quay lại bước 2.

Phép thử rẻ nhất và loại trừ nhiều nhất: **nhờ một người ở mạng khác vào cùng
world**. Họ mượt mà mình giật thì dừng ngay việc vặn server.

---

## Cải thiện kết nối chia sẻ từ điện thoại

Xếp theo mức hiệu quả:

1. **Cắm cáp thay vì phát Wi-Fi.** Bỏ hẳn Wi-Fi khỏi đường đi thì không còn quét
   kênh, không còn nhiễu. Nhớ tắt Wi-Fi trên máy sau khi cắm.
2. **Tắt "Maximize Compatibility"** trong cài đặt hotspot → dùng 5 GHz thay vì
   2,4 GHz vốn đông đúc.
3. **Tắt Bluetooth** lúc chơi — chung băng 2,4 GHz với hotspot.
4. **Xoá bớt mạng Wi-Fi đã lưu** và tắt "Hỏi trước khi tham gia mạng" — càng ít
   mạng đã lưu, macOS càng ít quét nền.
5. **Tắt chế độ nguồn điện thấp**, cắm sạc, tránh để máy nóng.

Kiểm chứng từng cách bằng `ping -c 100` rồi so cột thời gian: hết các đợt vọt
100–300 ms là có tác dụng.

---

## Những thứ đã kiểm và KHÔNG phải nguyên nhân

Ghi lại để khỏi kiểm lại lần sau.

| Nghi vấn | Cách loại trừ | Ngày |
|---|---|---|
| `stdin_open` / `dns` / `logging` trong compose | chạy `cli/compose.yml` bản tháng 5 → vẫn giật | 08/08 |
| Gỡ Tailscale | 0 luật iptables sót, 0 gói DROP; world khác chạy mượt sau khi đã gỡ | 06+08/08 |
| `vm.swappiness` 60→10 | swap dùng 0 MB, `si=0 so=0` | 06/08 |
| Xoay vòng log Docker, giới hạn journald | vẫn bật trong lần chạy mượt | 08/08 |
| Bộ mod | tắt cả 14 mod → vẫn giật | 08/08 |
| Dữ liệu world tích tụ | world sinh mới 0 mod → vẫn giật | 08/08 |
| Kích thước world | cả ba world đều `world_size="small"` | 08/08 |
| `tick_rate` | giật xảy ra từ khi còn 15; nâng lên 30 không phải nguyên nhân | 08/08 |

## Bẫy đã dính, đừng dính lại

**`dst restart` không nạp lại biến môi trường.** Đổi bất kỳ biến `DST_*` nào thì
phải `dst restart --fresh` để tạo lại container. Đổi `modoverrides.lua` thì
`restart` thường là đủ.

**Tắt mod rồi chạy sẽ phá dữ liệu world.** DST xoá mọi thực thể thuộc mod không
còn nạp, và **ghi bản lưu ngay lúc tắt container** — nên chỉ dừng server thôi cũng
đã kịp hỏng. Luôn `tar -czf` toàn bộ `data/` trước, và khôi phục ngay sau khi thử
xong.

**`dst switch` chỉ đẩy lên Drive khi world ĐANG CHẠY.** Nếu container đã dừng thì
nó bỏ qua bước đẩy rồi `rm -rf data/` — mất dữ liệu chưa sao lưu. Kiểm bản lưu mới
nhất trong gói trên Drive trước khi tin nó:

```bash
rclone cat dst-storage:dst-worlds/<world>.tar.gz | tar -tz | grep -oE "save/session/[^/]+/0[0-9]+$" | sort | tail -3
```

**Ping song song nhiều đích làm nghẽn chính đường truyền đang đo.** Ngày 08/08 tôi
chạy 7 phép ping cùng lúc rồi kết luận nhầm là hotspot mất 17,5% gói; đo tuần tự
lại thì 0,0%. Luôn đo từng đích một.

**`pkill -f <tên script>` tự khớp với chính dòng lệnh chạy nó** và giết luôn shell.
Dùng `pkill -f "ten_script[.]py"` để tránh.
