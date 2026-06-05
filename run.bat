@echo off
TITLE MKVoodoo v1.0.0 Launcher
echo Checking environment...
if exist .venv\Scripts\python.exe (
    .venv\Scripts\python.exe launch.py
) else (
    echo [ERROR] Virtual environment not found. 
    echo Please ensure .venv exists in this directory.
)
pause
