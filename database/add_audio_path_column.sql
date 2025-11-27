-- Add audio_path column to sensor_events table
-- Note: Run this only if the column doesn't exist
-- If column already exists, you'll get an error - ignore it

ALTER TABLE sensor_events 
ADD COLUMN audio_path VARCHAR(500) COMMENT 'Path to audio recording file' AFTER image_path;

