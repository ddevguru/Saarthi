-- Add device_token columns to devices table
ALTER TABLE devices 
ADD COLUMN device_token VARCHAR(128) NULL COMMENT 'Secure token for ESP32 authentication',
ADD COLUMN token_generated_at TIMESTAMP NULL COMMENT 'When token was generated';

CREATE INDEX idx_device_token ON devices(device_token);

