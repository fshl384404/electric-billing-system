"""
启动 ChromaDB 服务 (本地持久化模式)

用法:
    python start_chroma.py

首次运行:
    pip install chromadb

ChromaDB 会在当前目录的 chroma_data/ 子目录下持久化数据。
服务默认运行在 http://localhost:8000
"""
import sys
import os
import subprocess


def main():
    persist_dir = os.path.join(os.path.dirname(__file__), "chroma_data")
    os.makedirs(persist_dir, exist_ok=True)

    print(f"[ChromaDB] Starting server...")
    print(f"[ChromaDB] Data directory: {persist_dir}")
    print(f"[ChromaDB] HTTP endpoint: http://localhost:8000")
    print(f"[ChromaDB] Press Ctrl+C to stop")

    try:
        # ChromaDB >= 0.6 uses `chroma run` CLI
        subprocess.run([
            "chroma", "run",
            "--path", persist_dir,
            "--host", "0.0.0.0",
            "--port", "8000"
        ], check=True)
    except KeyboardInterrupt:
        print("\n[ChromaDB] Server stopped.")
    except FileNotFoundError:
        # fallback: try python -m chromadb (older versions)
        try:
            subprocess.run([
                sys.executable, "-m", "chromadb",
                "--path", persist_dir,
                "--host", "0.0.0.0",
                "--port", "8000"
            ], check=True)
        except Exception as e2:
            print(f"[ChromaDB] Error: {e2}")
            print("[ChromaDB] Make sure ChromaDB is installed: pip install chromadb")
            sys.exit(1)
    except Exception as e:
        print(f"[ChromaDB] Error: {e}")
        print("[ChromaDB] Make sure ChromaDB is installed: pip install chromadb")
        sys.exit(1)


if __name__ == "__main__":
    main()
