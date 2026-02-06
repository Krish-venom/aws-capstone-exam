<?php
// app/v2/index.php
$server_ip = $_SERVER['SERVER_ADDR'] ?? gethostbyname(gethostname());
$hostname  = gethostname();
$ts        = date('Y-m-d H:i:s');
?>
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>StreamLine - v2 [New Feature]</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    :root { color-scheme: dark; }
    body { font-family: Arial, Helvetica, sans-serif; background: #0f1115; color: #e2e8f0; margin: 40px; }
    .wrap { max-width: 720px; margin: auto; }
    .card {
      background: #1a1f2b; border: 1px solid #2d3748; border-radius: 12px; padding: 24px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.25);
    }
    .badge {
      display: inline-block; background: #2b6cb0; color: #e6f1ff;
      border-radius: 999px; padding: 4px 10px; font-size: 12px; letter-spacing: .3px;
    }
    h1 { margin: 10px 0 10px; }
    .kv { margin: 6px 0; }
    .kv code { background: #2d3748; padding: 2px 6px; border-radius: 6px; }
    .links a { color: #90cdf4; text-decoration: none; }
    .links a:hover { text-decoration: underline; }
    .footer { margin-top: 14px; color: #a0aec0; font-size: 13px; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <span class="badge">New Feature</span>
      <h1>Welcome to StreamLine - v2 [New Feature]</h1>
      <p class="kv">Server IP: <code><?php echo htmlspecialchars($server_ip); ?></code></p>
      <p class="kv">Hostname: <code><?php echo htmlspecialchars($hostname); ?></code></p>
      <p class="kv">Build Time: <code><?php echo htmlspecialchars($ts); ?></code></p>
      <p class="links">
        ✅ App v2 deployed. Run the
        <a href="/db_check.php">Database Connectivity Check</a>.
      </p>
      <div class="footer">Zero-downtime via ALB across 2 AZs • Configured by Ansible</div>
    </div>
  </div>
</body>
</html>
