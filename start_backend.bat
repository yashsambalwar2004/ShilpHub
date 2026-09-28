@echo off
title MurtiTrack Backend Server
echo ========================================================
echo Starting MurtiTrack FastAPI Backend Server on port 8000
echo ========================================================
cd /d "%~dp0backend"
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
pause
