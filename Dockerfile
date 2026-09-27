FROM python:3.11-alpine

WORKDIR /app

# ۱. نصب کتابخانه‌های آماده آلپاین بدون کامپایل و بدون مصرف رم (زیر ۵ ثانیه)
RUN apk add --no-cache git py3-cryptography

# ۲. دانلود مستقیم فایل‌های سورس بدون استفاده از pip
RUN git clone --depth 1 https://github.com/alexandersp/mtprotoproxy.git /app/mtprotoproxy_src

# ۳. اسکریپت سبک برای پاس کردن Health Check و اجرای پروکسی
RUN echo 'import os, asyncio, sys, threading\n\
sys.path.insert(0, "/app/mtprotoproxy_src")\n\
os.environ["PORT"] = "8888"\n\
def run_mtproto():\n\
    import mtprotoproxy.__main__\n\
threading.Thread(target=run_mtproto, daemon=True).start()\n\
PUBLIC_PORT = int(os.environ.get("PORT", 8080))\n\
async def handle_connection(reader, writer):\n\
    try:\n\
        peek_data = await reader.read(4)\n\
        if peek_data.startswith(b"GET") or peek_data.startswith(b"HEAD") or peek_data.startswith(b"POST"):\n\
            writer.write(b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK")\n\
            await writer.drain()\n\
            writer.close()\n\
        else:\n\
            target_reader, target_writer = await asyncio.open_connection("127.0.0.1", 8888)\n\
            target_writer.write(peek_data)\n\
            await target_writer.drain()\n\
            async def forward(src, dst):\n\
                try:\n\
                    while True:\n\
                        data = await src.read(4096)\n\
                        if not data: break\n\
                        dst.write(data)\n\
                        await dst.drain()\n\
                except Exception: pass\n\
                finally: dst.close()\n\
            await asyncio.gather(forward(reader, target_writer), forward(target_reader, writer), return_exceptions=True)\n\
    except Exception:\n\
        try: writer.close()\n\
        except Exception: pass\n\
async def start_server():\n\
    server = await asyncio.start_server(handle_connection, "0.0.0.0", PUBLIC_PORT)\n\
    await server.serve_forever()\n\
if __name__ == "__main__":\n\
    asyncio.run(start_server())\n\
' > /app/main.py

EXPOSE 8080

CMD ["python3", "/app/main.py"]
