-- Migration: 備援印表機
-- printer_settings 加 fallback_printer_id（自我參照 FK）
-- 主印表機失敗 3 次後自動切換備援
ALTER TABLE printer_settings
  ADD COLUMN IF NOT EXISTS fallback_printer_id UUID
    REFERENCES printer_settings(id) ON DELETE SET NULL;

-- 注意：set_hub 權限不需要 migration
-- shop_role_permissions 是 key-value 架構（permission_key TEXT），
-- 透過 App 職位管理介面設定即可
