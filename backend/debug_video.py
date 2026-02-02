import yt_dlp
import json

# Recent high-quality video
url = "https://www.youtube.com/watch?v=wbSwFU6tY1c" 
opts = {'format': 'best', 'quiet': True}

print("Extracting info...")
try:
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
        formats = info.get('formats', [])
        
        print(f"Total formats: {len(formats)}")
        
        hls_formats = [f for f in formats if 'm3u8' in f.get('protocol', '')]
        print(f"HLS formats (protocol match): {len(hls_formats)}")
        
        hls_url_match = [f for f in formats if '.m3u8' in f.get('url', '')]
        print(f"HLS formats (url match): {len(hls_url_match)}")

        # Print distinct heights for HLS
        heights = sorted(list(set(f.get('height') for f in hls_formats)))
        print(f"Available HLS Heights: {heights}")

        # Print top 3 HLS
        for f in hls_formats[:3]:
             print(f"HLS: {f['format_id']} {f.get('height')}p {f.get('protocol')}")

except Exception as e:
    print(f"Error: {e}")
