import os
import glob
import yt_dlp


def cleanup_temp_files(download_path):
    # Удаляем все файлы с префиксом temp_final.*
    patterns = [
        os.path.join(download_path, "temp_final.f*.mp4"),
        os.path.join(download_path, "temp_final.f*.m4a"),
    ]
    for pattern in patterns:
        for file in glob.glob(pattern):
            try:
                os.remove(file)
                print(f"🧹 Удалён временный файл: {file}")
            except Exception as e:
                print(f"❌ Ошибка при удалении {file}: {e}")


def list_formats(url, mode="video+audio"):
    print(f"\n🔍 Доступные форматы ({mode}):\n")
    ydl_opts = {"quiet": True}
    available = []

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        formats = info.get("formats", [])

        for f in formats:
            has_video = f.get("vcodec") != "none"
            has_audio = f.get("acodec") != "none"
            fmt_id = f.get("format_id")
            ext = f.get("ext")
            res = f.get("height") or "audio"
            fps = f.get("fps") or "-"
            filesize = f.get("filesize", 0)
            size = f"{filesize / (1024 * 1024):.1f} MB" if filesize else "?"

            if mode == "video+audio" and has_video and has_audio:
                print(f"{fmt_id:10} | {res}p | {ext.upper():4} | A+V | {fps} fps | {size}")
                available.append(fmt_id)
            elif mode == "video" and has_video and not has_audio:
                print(f"{fmt_id:10} | {res}p | {ext.upper():4} | Video only | {fps} fps | {size}")
                available.append(fmt_id)
            elif mode == "audio" and not has_video and has_audio:
                abr = f.get("abr", "?")
                print(f"{fmt_id:10} | Audio | {ext.upper():4} | {abr} kbps | {size}")
                available.append(fmt_id)

    return available


def main():
    url = input("🔗 Введите ссылку на YouTube/плейлист: ").strip()

    print("\n📥 Что вы хотите скачать?")
    print("1. Только аудио (MP3)")
    print("2. Только видео (без звука)")
    print("3. Видео + аудио (выбор качества)")
    print("4. Лучшее готовое видео (однофайловое, mp4)")
    choice = input("Введите номер (1/2/3/4): ").strip()

    download_path = "/home/muhammadali/Видео"
    outtmpl = os.path.join(download_path, "temp_final.%(ext)s")

    if choice == "1":
        formats = list_formats(url, mode="audio")
        format_id = input("\nВведите format_id аудио (или Enter для авто): ").strip()
        ydl_opts = {
            "format": format_id if format_id else "bestaudio",
            "outtmpl": os.path.join("/home/muhammadali/Музыка", "temp_final.%(ext)s"),
            "postprocessors": [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                    "preferredquality": "192",
                }
            ],
        }

    elif choice == "2":
        formats = list_formats(url, mode="video")
        format_id = input("\nВведите format_id видео (только видео): ").strip()
        if format_id not in formats:
            print("❌ Неверный формат.")
            return
        ydl_opts = {
            "format": format_id,
            "outtmpl": outtmpl,
        }

    elif choice == "3":
        formats = list_formats(url, mode="video")
        video_id = input("\nВведите format_id видео: ").strip()
        formats = list_formats(url, mode="audio")
        audio_id = input("Введите format_id аудио (или Enter для лучшего): ").strip()

        fmt = f"{video_id}+{audio_id}" if audio_id else f"{video_id}+bestaudio"

        ydl_opts = {
            "format": fmt,
            "outtmpl": outtmpl,
            "merge_output_format": "mp4",
            "postprocessors": [{"key": "FFmpegMerger"}],
            "keepvideo": True,
        }

    elif choice == "4":
        ydl_opts = {
            "format": "bv*[ext=mp4]+ba[ext=m4a]/best",
            "outtmpl": outtmpl,
            "merge_output_format": "mp4",
            "postprocessors": [{"key": "FFmpegMerger"}],
            "keepvideo": True,
        }

    else:
        print("❌ Неверный выбор.")
        return

    print("\n⏬ Загрузка началась...\n")
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        title = info.get("title")
        ext = info.get("ext", "mp4")
        final_name = f"{title}.{ext}"
        temp_file = os.path.join(download_path, f"temp_final.{ext}")
        final_file = os.path.join(download_path, final_name)

        if os.path.exists(temp_file):
            os.rename(temp_file, final_file)
            print(f"\n✅ Файл сохранён как: {final_file}")
        else:
            print(f"\n⚠️ Не найден файл {temp_file}")

        cleanup_temp_files(download_path)

    print("\n🏁 Завершено.")


if __name__ == "__main__":
    main()

