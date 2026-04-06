-- Hub iPad 的 LAN IP 儲存
-- Hub 啟動時自動寫入，Client 啟動時讀取（外網可用時）
ALTER TABLE shops
  ADD COLUMN IF NOT EXISTS hub_ip TEXT,
  ADD COLUMN IF NOT EXISTS hub_ip_updated_at TIMESTAMPTZ;
