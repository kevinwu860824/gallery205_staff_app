-- Add paper_width_mm column to printer_settings table
ALTER TABLE printer_settings 
ADD COLUMN paper_width_mm INTEGER NOT NULL DEFAULT 80 UI_HINT 'Paper Width in mm (58 or 80)';
