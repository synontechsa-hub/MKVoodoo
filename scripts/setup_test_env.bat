@echo off
echo 📦 MKVoodoo Test Environment Setup
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo 🛠 1. Installing Python Dev Dependencies...
pip install -e ".[dev]"

echo 🛠 2. Installing Flutter Dev Dependencies...
cd frontend
call flutter pub get

echo ✅ Setup Complete! You can now run scripts\check_quality.bat
pause
