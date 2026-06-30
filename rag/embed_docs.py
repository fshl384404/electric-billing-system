"""
文档嵌入脚本 — 读取 rag/docs/ 下的 markdown 文件, 分块 → 嵌入 → 写入 ChromaDB

用法:
    # 先确保 ChromaDB 正在运行
    chroma run --path ./chroma_data --host 0.0.0.0 --port 8000   # (另开终端)

    # 然后运行嵌入脚本
    python embed_docs.py

依赖:
    pip install chromadb ollama

前置条件:
    - ChromaDB 运行在 localhost:8000
    - Ollama 运行在 localhost:11434
    - 已拉取嵌入模型: ollama pull nomic-embed-text
"""
import os
import re
import sys

# 用 chromadb Python 客户端 (自动适配 API 版本)
import chromadb
# 确保 Ollama embedding function 可用
from chromadb.utils.embedding_functions import OllamaEmbeddingFunction

# ============================================================================
# 配置
# ============================================================================
DOCS_DIR = os.path.join(os.path.dirname(__file__), "docs")
COLLECTION_NAME = "elec_knowledge"
CHUNK_SIZE = 512       # 每块最大字符数
CHROMA_HOST = "localhost"
CHROMA_PORT = 8000

# ============================================================================
# 文档分块
# ============================================================================
def chunk_text(text: str, source: str) -> list[dict]:
    """将文本按段落切分，在 CHUNK_SIZE 附近切出语义完整的块。"""
    paragraphs = re.split(r'\n\n+', text.strip())
    if not paragraphs:
        return []

    chunks = []
    current = ""
    for para in paragraphs:
        para = para.strip()
        if not para:
            continue
        if len(current) + len(para) + 2 <= CHUNK_SIZE:
            current = (current + "\n\n" + para).strip() if current else para
        else:
            if current:
                chunks.append(current)
            if len(para) > CHUNK_SIZE:
                # 超大段落按句子切
                sentences = re.split(r'(?<=[。！？.!?])\s*', para)
                for sent in sentences:
                    sent = sent.strip()
                    if sent:
                        chunks.append(sent)
            else:
                current = para
    if current.strip():
        chunks.append(current.strip())

    result = []
    for chunk in chunks:
        title = ""
        first_line = chunk.split("\n")[0]
        if first_line.startswith("#"):
            title = first_line.lstrip("#").strip()

        result.append({
            "text": chunk,
            "source": source,
            "title": title
        })
    return result


def load_documents(docs_dir: str) -> list[dict]:
    """加载 docs/ 下所有 .md/.txt 文件并分块"""
    all_chunks = []
    for fname in sorted(os.listdir(docs_dir)):
        if fname.endswith((".md", ".txt")):
            fpath = os.path.join(docs_dir, fname)
            with open(fpath, "r", encoding="utf-8") as f:
                content = f.read()
            chunks = chunk_text(content, fname)
            all_chunks.extend(chunks)
            print(f"  [{fname}] {len(content)} chars → {len(chunks)} chunks")
    return all_chunks


# ============================================================================
# 主流程
# ============================================================================
def main():
    print("=" * 60)
    print("  文档嵌入工具 — 民用电缴费系统 RAG 知识库")
    print("=" * 60)

    # 1. 加载文档
    print("\n[1/4] Loading documents...")
    chunks = load_documents(DOCS_DIR)
    print(f"       Total: {len(chunks)} chunks")

    if not chunks:
        print("[ERROR] No documents found in:", DOCS_DIR)
        sys.exit(1)

    # 2. 连接 ChromaDB (HTTP 客户端)
    print(f"\n[2/4] Connecting to ChromaDB at {CHROMA_HOST}:{CHROMA_PORT}...")
    try:
        client = chromadb.HttpClient(host=CHROMA_HOST, port=CHROMA_PORT)
        # 测试连接
        client.list_collections()
        print("       Connected OK")
    except Exception as e:
        print(f"[ERROR] Cannot connect to ChromaDB: {e}")
        print("       Make sure: chroma run --path ./chroma_data --host 0.0.0.0 --port 8000")
        sys.exit(1)

    # 3. 创建/覆盖 Collection (使用 Ollama 嵌入)
    print(f"\n[3/4] Creating collection '{COLLECTION_NAME}'...")
    print("       Embedding model: nomic-embed-text (via Ollama)")

    ollama_ef = OllamaEmbeddingFunction(
        model_name="nomic-embed-text",
        url="http://localhost:11434/api/embeddings"
    )

    # 删除同名 collection (如果存在)
    try:
        client.delete_collection(COLLECTION_NAME)
        print("       Deleted existing collection")
    except Exception:
        pass

    collection = client.create_collection(
        name=COLLECTION_NAME,
        embedding_function=ollama_ef,
        metadata={"description": "民用电缴费系统知识库"}
    )

    # 4. 批量嵌入和写入
    print(f"\n[4/4] Embedding and writing {len(chunks)} chunks...")
    batch_size = 20
    for i in range(0, len(chunks), batch_size):
        batch = chunks[i:i+batch_size]
        ids = [f"chunk_{j}" for j in range(i, i + len(batch))]
        documents = [c["text"] for c in batch]
        metadatas = [{"source": c["source"], "title": c["title"]} for c in batch]

        collection.add(ids=ids, documents=documents, metadatas=metadatas)
        print(f"       [{i+len(batch)}/{len(chunks)}] embedded and stored")

    print("\n" + "=" * 60)
    print("  [OK] 知识库构建完成!")
    print(f"  Collection: {COLLECTION_NAME}")
    print(f"  Chunks:     {len(chunks)}")
    print("=" * 60)


if __name__ == "__main__":
    main()
