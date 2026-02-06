<?php
// app/v1/index.php
$server_ip = $_SERVER['SERVER_ADDR'] ?? gethostbyname(gethostname());
$hostname  = gethostname();
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>StreamLine - v1</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    :root { color-scheme: light; }
    body { font-family: Arial, Helvetica, sans-serif; background: #f6f9fc; color: #1a202c; margin: 40px; }
    .wrap { max-width: 720px; margin: auto; }
    .card {
      background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 24px;
      box-shadow: 0 1px 2px rgba(0,0,0,0.04);
    }
    h1 { margin: 0 0 10px; }
    .kv { margin: 6px 0; }
    .kv code { background: #edf2f7; padding: 2px 6px; border-radius: 6px; }
    .links a { color: #2b6cb0; text-decoration: none; }
    .links a:hover { text-decoration: underline; }
    .footer { margin-top: 14px; color: #4a5568; font-size: 13px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>Welcome to Streamline - v1</h1>
      <p class="kv">Server IP: <code><?php echo htmlspecialchars($server_ip); ?></code></p>
      <p class="kv">Hostname: <code><?php echo htmlspecialchars($hostname); ?></code></p>
      <p class="links">
        ✅ App is up. Try the
        <a href="/db_check.php">Database Connectivity Check</a>.
      </p>
      <div class="footer">Deployed via Terraform → Ansible → ALB</div>
    </div>
  </div>
</body>
</html>
