CREATE TABLE IF NOT EXISTS items (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(255) NOT NULL,
    value TEXT         NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_items_name ON items(name);
