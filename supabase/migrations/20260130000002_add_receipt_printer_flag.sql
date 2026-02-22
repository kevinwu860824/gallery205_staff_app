-- Add is_receipt_printer column to printer_settings table
ALTER TABLE printer_settings 
ADD COLUMN is_receipt_printer BOOLEAN NOT NULL DEFAULT FALSE;
