# Chạy hai world cùng lúc trên một máy

Mặc định hạ tầng này chỉ chạy **một** world (`dst switch` dừng world cũ rồi bật
world mới). Muốn chạy thêm một world test song song mà không đụng world chính
thì dùng **git worktree** — mỗi world một thư mục làm việc riêng, có `data/`,
`.world.env` và `tokens.env` riêng.

## Ba thứ BẮT BUỘC phải khác nhau

Thiếu bất kỳ cái nào là hai world giẫm lên nhau.

**1. Compose project name.** Đây là cái đã làm sập myth-words ngày 30/08/2026.
Docker Compose lấy tên project theo *thư mục chứa file compose* — cả hai world
đều là `cli/`, nên lệnh `up` của world thứ hai coi container của world đang chạy
là cùng project và **thay thế** chúng. Đã sửa trong `cli/dst`:

```bash
docker compose -p "dst-$b" --env-file ... -f ...
```

Kiểm: `docker ps --format '{{.Names}}\t{{.Label "com.docker.compose.project"}}'`

**2. Cổng.** `network_mode: host` nên mọi cổng dùng chung không gian của máy:

| | myth-words | test-world |
|---|---|---|
| game Master | 11999 | 12999 |
| game Caves | 11998 | 12998 |
| shard | 11888 | 12888 |
| steam master | 27017 | 27019 |
| steam auth | 8767 | 8769 |

Cổng Caves lấy từ biến `DST_CAVES_PORT` trong `.world.env`, **không** lấy từ
service `caves` trong `server/docker-compose.yml` — `cli/extract-env.py` chỉ đọc
service `master`. Nên phải khai `DST_CAVES_PORT` trong service **master**.

**3. Token Klei.** Hai server dùng chung một token thì Klei ngắt cái cũ. Mỗi
worktree giữ `tokens.env` riêng (file này gitignore) với `ACTIVE_TOKEN` khác nhau.

## Dựng một world test

```bash
cd ~/dst-server-docker
git fetch origin <nhánh>
git worktree add ~/dst-test <nhánh>

cd ~/dst-test
cp ~/dst-server-docker/tokens.env .
sed -i 's/^ACTIVE_TOKEN=.*/ACTIVE_TOKEN=<tên token khác>/' tokens.env

# tạo sẵn data/ để `dst start` không đi kéo world từ Google Drive
mkdir -p data/Master data/Caves && touch data/Master/.keep data/Caves/.keep

./cli/dst init      # sinh .world.env từ server/docker-compose.yml của nhánh
./cli/dst start
```

Từ đó về sau dùng `dst` như bình thường, chỉ cần **đứng đúng thư mục**:
`~/dst-server-docker` cho world chính, `~/dst-test` cho world test.

## Gỡ world test

```bash
cd ~/dst-test && ./cli/dst stop
cd ~/dst-server-docker && git worktree remove ~/dst-test
```

`dst stop` chỉ hạ đúng project của nó — world còn lại không ảnh hưởng.
