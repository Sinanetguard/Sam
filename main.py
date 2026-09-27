import os
import asyncio
import threading

# تنظیم پورت داخلی پروکسی MTProto
os.environ["PORT"] = "8888"

def run_mtproto():
    import mtprotoproxy.__main__

# اجرای پروکسی در یک ترِد مجزا
threading.Thread(target=run_mtproto, daemon=True).start()

PUBLIC_PORT = int(os.environ.get("PORT_PUBLIC", 8080))

async def handle_connection(reader, writer):
    try:
        peek_data = await reader.read(4)
        # اگر درخواست از سمت Health Check سایت بود
        if peek_data.startswith(b'GET') or peek_data.startswith(b'HEAD') or peek_data.startswith(b'POST'):
            writer.write(b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK")
            await writer.drain()
            writer.close()
        else:
            # هدایت ترافیک واقعی تلگرام به پروکسی
            target_reader, target_writer = await asyncio.open_connection('127.0.0.1', 8888)
            target_writer.write(peek_data)
            await target_writer.drain()

            async def forward(src, dst):
                try:
                    while True:
                        data = await src.read(4096)
                        if not data:
                            break
                        dst.write(data)
                        await dst.drain()
                except Exception:
                    pass
                finally:
                    dst.close()

            await asyncio.gather(
                forward(reader, target_writer),
                forward(target_reader, writer),
                return_exceptions=True
            )
    except Exception:
        try:
            writer.close()
        except Exception:
            pass

async def start_server():
    server = await asyncio.start_server(handle_connection, '0.0.0.0', PUBLIC_PORT)
    await server.serve_forever()

if __name__ == '__main__':
    asyncio.run(start_server())
