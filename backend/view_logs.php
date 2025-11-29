<?php
/**
 * SAARTHI Backend - View Error Logs
 * Simple script to view error logs in browser
 * 
 * SECURITY: Remove or protect this file in production!
 */

$logFile = __DIR__ . '/logs/error.log';
$maxLines = 500; // Show last 500 lines

header('Content-Type: text/plain; charset=utf-8');

if (!file_exists($logFile)) {
    echo "Error log file not found: $logFile\n";
    echo "Make sure the logs directory exists and is writable.\n";
    exit;
}

if (!is_readable($logFile)) {
    echo "Error log file is not readable: $logFile\n";
    exit;
}

$lines = file($logFile);
if ($lines === false) {
    echo "Failed to read error log file.\n";
    exit;
}

// Show last N lines
$totalLines = count($lines);
$startLine = max(0, $totalLines - $maxLines);

echo "=== SAARTHI Error Log ===\n";
echo "Total lines: $totalLines\n";
echo "Showing last " . min($maxLines, $totalLines) . " lines\n";
echo "Last updated: " . date('Y-m-d H:i:s', filemtime($logFile)) . "\n";
echo "========================\n\n";

for ($i = $startLine; $i < $totalLines; $i++) {
    echo $lines[$i];
}

