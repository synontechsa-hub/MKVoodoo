@echo off
echo 🔍 MKVoodoo Quality Check
echo ━" * 30

echo 🛠 1. Python Static Analysis (Mypy)
python -m mypy backend/
if %errorlevel% neq 0 (
    echo ❌ Mypy failed.
    exit /b %errorlevel%
)
echo ✅ Mypy passed.

echo 🛠 2. Python Linting (Flake8)
python -m flake8 backend/ --max-line-length=120 --exclude=__pycache__
if %errorlevel% neq 0 (
    echo ❌ Flake8 failed.
    exit /b %errorlevel%
)
echo ✅ Flake8 passed.

echo 🛠 3. Python Tests (Pytest + BDD)
python -m pytest
if %errorlevel% neq 0 (
    echo ❌ Pytest failed.
    exit /b %errorlevel%
)
echo ✅ Pytest passed.

echo 🛠 4. Flutter Analysis
cd frontend
call flutter analyze
if %errorlevel% neq 0 (
    echo ❌ Flutter analysis failed.
    exit /b %errorlevel%
)
echo ✅ Flutter analysis passed.

echo 🚀 ALL QUALITY CHECKS PASSED!
