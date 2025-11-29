#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "[-] Please run as root (use sudo)."
  exit 1
fi

INSTALL_DIR="/opt/doclog"
BIN_PATH="/usr/local/bin/doclog"
IMAGE_NAME="doclog-target"

# Clear screen and show menu
clear
echo "========================================"
echo "      DocLog Environment Installer       "
echo "========================================"
echo "Which login page template do you want to use?"
echo ""
echo "  1) Generic Admin Login"
echo "      (Simple modern interface, fields: user_login/password_login)"
echo ""
echo "  2) Webcam 7 Login"
echo "      (Simulated webcam software, fields: username/password)"
echo ""
read -p "Select an option [1-2]: " CHOICE

# 1. Setup Directory
echo ""
echo "[*] Setting up directory..."
mkdir -p "$INSTALL_DIR"

# 2. Write router.php based on choice
if [ "$CHOICE" == "1" ]; then
    echo "[*] Selected: Generic Admin Login"
    H_PATH="/admin.html"
    H_FIELDS="user_login=^USER^&password_login=^PASS^"
    
    cat > "$INSTALL_DIR/router.php" << 'EOF'
<?php
$valid_user = getenv('TARGET_USER') ?: 'admin';
$valid_pass = getenv('TARGET_PASS') ?: 'password';
$path = parse_url($_SERVER["REQUEST_URI"], PHP_URL_PATH);

if ($path === '/admin.html') {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $user = $_POST['user_login'] ?? '';
        $pass = $_POST['password_login'] ?? '';
        if ($user === $valid_user && $pass === $valid_pass) {
            echo "<html><body style='background-color:#d4edda; color:#155724; font-family:sans-serif; text-align:center; padding:50px;'><h1>Login Successful!</h1><p>Welcome to the dashboard.</p></body></html>";
        } else {
            echo "<html><body style='background-color:#f8d7da; color:#721c24; font-family:sans-serif; text-align:center; padding:50px;'><h1>Access Denied</h1><p>Incorrect credentials.</p></body></html>";
        }
        exit;
    }
?>
    <html>
    <head><title>Admin Login</title></head>
    <body style="font-family: sans-serif; background-color: #f4f4f4; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0;">
        <div style="background: white; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); width: 300px; text-align: center;">
            <h2 style="margin-bottom: 20px; color: #333;">System Login</h2>
            <form method="POST" action="/admin.html">
                <input type="text" name="user_login" placeholder="Username" required style="width: 100%; padding: 10px; margin-bottom: 10px; border: 1px solid #ddd; border-radius: 4px; box-sizing: border-box;">
                <input type="password" name="password_login" placeholder="Password" required style="width: 100%; padding: 10px; margin-bottom: 20px; border: 1px solid #ddd; border-radius: 4px; box-sizing: border-box;">
                <input type="submit" value="Login" style="width: 100%; padding: 10px; background-color: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: bold;">
            </form>
        </div>
    </body>
    </html>
<?php
} else {
    http_response_code(404);
    echo "404 Not Found. Login is at /admin.html";
}
?>
EOF

elif [ "$CHOICE" == "2" ]; then
    echo "[*] Selected: Webcam 7 Login"
    H_PATH="/login.html"
    H_FIELDS="username=^USER^&password=^PASS^"

    cat > "$INSTALL_DIR/router.php" << 'EOF'
<?php
$valid_user = getenv('TARGET_USER') ?: 'admin';
$valid_pass = getenv('TARGET_PASS') ?: 'password';
$path = parse_url($_SERVER["REQUEST_URI"], PHP_URL_PATH);

if ($path === '/login.html' || $path === '/') {
    
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $user = $_POST['username'] ?? '';
        $pass = $_POST['password'] ?? '';
        
        if ($user === $valid_user && $pass === $valid_pass) {
            echo "<html><body style='background-color:#d4edda; color:#155724; font-family:sans-serif; text-align:center; padding:50px;'><h1>Login Successful!</h1><p>Welcome to the Webcam 7 dashboard.</p></body></html>";
        } else {
            echo "<html><body style='background-color:#f8d7da; color:#721c24; font-family:sans-serif; text-align:center; padding:50px;'><h1>Access Denied</h1><p>Incorrect credentials.</p><p><a href='/login.html'>Try Again</a></p></body></html>";
        }
        exit;
    }
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <meta http-equiv="content-type" content="text/html; charset=UTF-8">
    <title>webcam 7</title>
    <style>
        body { font-family: Verdana, Arial, sans-serif; font-size: 11px; background-color: #F0F0F0; }
        #container { width: 800px; margin: 0 auto; background: white; border: 1px solid #999; padding: 10px; }
        .wxpmenu a { text-decoration: none; color: #333; padding: 5px; }
        .wxpmenu a:hover { text-decoration: underline; }
        h1 span { font-size: 16px; font-weight: bold; color: #000; }
        h2 span { font-size: 11px; color: #666; font-weight: normal; }
    </style>
</head>
<body id="webcamXP-body">
<div id="container">
    <div id="intro">
        <div id="pageHeader">
            <h1><span>webcam 7</span></h1>
            <h2><span>webcams and ip cameras server for windows</span></h2>
        </div>
        <div class="wxptopnav">
          <div class="wxpmenu">
            <a class="btn-arrow" href="/home.html"><span>Home</span></a>
            <a class="btn-arrow" href="/adminSettings.html"><span>Administration</span></a>
            <a class="btn-arrow" href="/adminUsers.html"><span>Users manager</span></a>
            <a class="btn-arrow" href="/adminStats.html"><span>Statistics</span></a>
          </div>
          <div class="wxplogin">Not logged in</div>
        </div>
        <div class="wxpcontainer">
            Please provide a valid username/password to access this server.<br><br>
            <form method="POST" action="/login.html">
                Username:<br><input type="text" name="username" size="15"><br>
                Password:<br><input type="password" name="password" size="15"><br>
                <input type="hidden" name="Redir" value="/admin.html"><br>
                <p><input type="submit" value="Login"></p>
            </form>
        </div><br>
        <div class="wxpdark">
            <div class="internal_content">powered by <a href="#">webcam 7</a> v1.5.3.0</div>
        </div>
    </div>
</div>
</body></html>
<?php
} else {
    echo "Simulated page: " . htmlspecialchars($path);
}
?>
EOF

else
    echo "[-] Invalid selection. Exiting."
    exit 1
fi
echo "[+] Created router.php"

# 3. Create Dockerfile
cat > "$INSTALL_DIR/Dockerfile" << 'EOF'
FROM php:alpine
WORKDIR /app
COPY router.php /app/router.php
EXPOSE 8080
CMD ["php", "-S", "0.0.0.0:8080", "router.php"]
EOF
echo "[+] Created Dockerfile"

# 4. Build Docker Image
echo "[*] Building Docker Image (this may take a moment)..."
# Use /dev/null to hide noisy output
docker build -t "$IMAGE_NAME" "$INSTALL_DIR" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "[+] Docker Image '$IMAGE_NAME' built successfully."
else
    echo "[-] Docker build failed. Is Docker running?"
    exit 1
fi

# 5. Create the System Shortcut (The 'doclog' command)
# Note: We use the H_ variables defined above to customize the output message
cat > "$BIN_PATH" << EOF
#!/bin/bash
clear
echo "========================================"
echo "      DocLog - Login Target Active       "
echo "========================================"

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH."
    exit 1
fi

# Input Credentials
echo ""
read -p "Set Target Username: " U_SET
read -sp "Set Target Password: " P_SET
echo ""
echo ""

# Cleanup old container if exists
docker rm -f doclog-container > /dev/null 2>&1

# Run Container
echo "[*] Starting container..."
docker run -d -p 85:8080 \\
    -e TARGET_USER="\$U_SET" \\
    -e TARGET_PASS="\$P_SET" \\
    --name doclog-container \\
    $IMAGE_NAME > /dev/null

if [ \$? -eq 0 ]; then
    echo "[+] Server is UP!"
    echo "----------------------------------------"
    echo "URL:       http://localhost:85$H_PATH"
    echo "User:      \$U_SET"
    echo "Pass:      (hidden)"
    echo "----------------------------------------"
    echo "Hydra Info:"
    echo "  Method: http-post-form"
    echo "  Path:    $H_PATH"
    echo "  Fields: $H_FIELDS"
    echo "  Fail:    Access Denied"
    echo "----------------------------------------"
else
    echo "[-] Failed to start container."
fi
EOF

# Make the shortcut executable
chmod +x "$BIN_PATH"
echo "[+] Shortcut created at $BIN_PATH"

echo ""
echo "SUCCESS! Installation complete."
echo "Type 'doclog' to run the server."