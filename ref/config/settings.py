import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Directory paths
INPUT_DIR = os.getenv("INPUT_DIR", "data/input")
ARCHIVE_DIR = os.getenv("ARCHIVE_DIR", "data/archive")
# Project uploads directory (for user-uploaded files attached to research projects)
PROJECT_UPLOAD_DIR = os.getenv("PROJECT_UPLOAD_DIR", "data/project_uploads")

# OpenAI settings
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# OpenRouter settings  
OPENROUTER_STANDARD_API_KEY = os.getenv("OPENROUTER_STANDARD_API_KEY")
# Gemini settings (complete model names for OpenRouter)
LLM_REASONING_MODEL = os.getenv("LLM_REASONING_MODEL", "google/gemini-2.5-flash")
LLM_CHAT_MODEL = os.getenv("LLM_CHAT_MODEL", "google/gemini-2.5-flash")


EMBEDDING_LLM_PROVIDER = os.getenv("EMBEDDING_LLM_PROVIDER", "openai")
OPENAI_EMBEDDING_MODEL = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")

# Chunking settings
CHUNK_SIZE = int(os.getenv("CHUNK_SIZE", 2000))
CHUNK_OVERLAP = int(os.getenv("CHUNK_OVERLAP", 400))

# PostgreSQL/pgvector settings
# Default to localhost for local development, override with environment variable for Cloud Run
DEFAULT_POSTGRES_HOST = os.getenv("POSTGRES_HOST", "localhost")
DEFAULT_POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", 6024))

# PostgreSQL connection components
POSTGRES_HOST = os.getenv("POSTGRES_HOST", DEFAULT_POSTGRES_HOST)
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", DEFAULT_POSTGRES_PORT))
POSTGRES_USER = os.getenv("POSTGRES_USER", "langchain")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "langchain")
POSTGRES_DATABASE = os.getenv("POSTGRES_DATABASE", "langchain")
POSTGRES_SSL_MODE = os.getenv("POSTGRES_SSL_MODE", "prefer")

def _build_postgres_connection_string(
    host: str,
    port: int,
    user: str,
    password: str,
    database: str,
    ssl_mode: str | None = None,
) -> str:
    auth = f"{user}:{password}@" if password else f"{user}@"
    base = f"postgresql://{auth}{host}:{port}/{database}"
    return f"{base}?sslmode={ssl_mode}" if ssl_mode else base

_env_conn = os.getenv("POSTGRES_CONNECTION_STRING", "").strip()
POSTGRES_CONNECTION_STRING = (
    _env_conn
    if _env_conn
    else _build_postgres_connection_string(
        POSTGRES_HOST,
        POSTGRES_PORT,
        POSTGRES_USER,
        POSTGRES_PASSWORD,
        POSTGRES_DATABASE,
        POSTGRES_SSL_MODE,
    )
)
POSTGRES_COLLECTION_NAME = os.getenv("POSTGRES_COLLECTION_NAME", "stock_announcements")

# Native pgvector collection id (UUID) for stock announcements
# Default to the provided constant if not set in environment
STOCK_ANN_EMBEDDING_COLLECTION_ID = os.getenv(
    "STOCK_ANN_EMBEDDING_COLLECTION_ID",
    "a96daa90-6fdb-4847-8e77-0faea5314122",
)

# Schema for stock announcement embeddings table
STOCK_ANN_SCHEMA = os.getenv("STOCK_ANN_SCHEMA", "public")

# Search configuration
USE_HYBRID_SEARCH = os.getenv("USE_HYBRID_SEARCH", "false").lower() == "true"

# History tracking configuration
ENABLE_QUERY_HISTORY = os.getenv("ENABLE_QUERY_HISTORY", "true").lower() == "true"
ENABLE_LOGIN_HISTORY = os.getenv("ENABLE_LOGIN_HISTORY", "true").lower() == "true"
QUERY_HISTORY_RETENTION_DAYS = int(os.getenv("QUERY_HISTORY_RETENTION_DAYS", 365))
LOGIN_HISTORY_RETENTION_DAYS = int(os.getenv("LOGIN_HISTORY_RETENTION_DAYS", 180))

# User limits configuration
DEFAULT_FREE_SEARCHES = int(os.getenv("DEFAULT_FREE_SEARCHES", 50))
DEFAULT_SILVER_SEARCHES = int(os.getenv("DEFAULT_SILVER_SEARCHES", 100))
DEFAULT_GOLD_SEARCHES = int(os.getenv("DEFAULT_GOLD_SEARCHES", 500))
DEFAULT_ULTIMATE_SEARCHES = int(os.getenv("DEFAULT_ULTIMATE_SEARCHES", 2000))

# Enable/disable user limits
ENABLE_USER_LIMITS = os.getenv("ENABLE_USER_LIMITS", "true").lower() == "true"

# LLM cost optimization settings
MIN_RELEVANCE_THRESHOLD = float(os.getenv("MIN_RELEVANCE_THRESHOLD", "75.0"))
MAX_CONTEXT_SIZE = int(os.getenv("MAX_CONTEXT_SIZE", "100000"))
MAX_DOCS_PER_STOCK = int(os.getenv("MAX_DOCS_PER_STOCK", "2"))

# Use NEXTAUTH_URL for NextAuth authentication
NEXTAUTH_URL = os.getenv("NEXTAUTH_URL", "http://localhost:3000")

# Use DOMAIN_URL for composing share links
DOMAIN_URL = os.getenv("DOMAIN_URL", "http://localhost:3000")