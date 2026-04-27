"""
Сборка приложения для macOS, Windows и Linux с помощью PyInstaller.
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path


def build_macos():
    """Сборка .app для macOS с помощью PyInstaller"""
    print("Building macOS application...")
    
    subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
    
    bin_dir = Path("bin")
    bin_dir.mkdir(exist_ok=True)
    
    # Для macOS используем --onedir для создания .app бандла
    subprocess.run([
        "pyinstaller",
        "--onefile",
        "--windowed",
        "--name=AI Chat",
        "--icon=assets/icon.icns" if os.path.exists("assets/icon.icns") else "--icon=assets/icon.ico",
        "--clean",
        "--noupx",
        "src/main.py"
    ])
    
    try:
        if os.path.exists("dist/AI Chat.app"):
            shutil.move("dist/AI Chat.app", "bin/AI Chat.app")
            print("macOS build completed! App location: bin/AI Chat.app")
        elif os.path.exists("dist/AI Chat"):
            shutil.move("dist/AI Chat", "bin/AI Chat")
            print("macOS build completed! Executable location: bin/AI Chat")
    except Exception as e:
        print(f"macOS build completed! Executable location: dist/")
        print(f"Note: {e}")


def build_windows():
    """Сборка исполняемого файла для Windows с помощью PyInstaller"""
    print("Building Windows executable...")
    
    subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
    
    bin_dir = Path("bin")
    bin_dir.mkdir(exist_ok=True)
    
    subprocess.run([
        "pyinstaller",
        "--onefile",
        "--windowed",
        "--name=AI Chat",
        "--clean",
        "--noupx",
        "--uac-admin",
        "src/main.py"
    ])
    
    try:
        shutil.move("dist/AI Chat.exe", "bin/AIChat.exe")
        print("Windows build completed! Executable location: bin/AIChat.exe")
    except:
        print("Windows build completed! Executable location: dist/AI Chat.exe")


def build_linux():
    """Сборка исполняемого файла для Linux с помощью PyInstaller"""
    print("Building Linux executable...")
    
    subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
    
    bin_dir = Path("bin")
    bin_dir.mkdir(exist_ok=True)
    
    subprocess.run([
        "pyinstaller",
        "--onefile",
        "--windowed",
        "--icon=assets/icon.ico",
        "--name=aichat",
        "src/main.py"
    ])
    
    try:
        shutil.move("dist/aichat", "bin/aichat")
        print("Linux build completed! Executable location: bin/aichat")
    except:
        print("Linux build completed! Executable location: dist/aichat")


def main():
    """Основная функция сборки"""
    if sys.platform == 'darwin':  # macOS
        build_macos()
    elif sys.platform.startswith('win'):  # Windows
        build_windows()
    elif sys.platform.startswith('linux'):  # Linux
        build_linux()
    else:
        print("Unsupported platform")


if __name__ == "__main__":
    main()