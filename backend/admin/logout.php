<?php
/**
 * SAARTHI Admin Panel - Logout
 */

session_start();
session_destroy();
header('Location: login.php');
exit;
