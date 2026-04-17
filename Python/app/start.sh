#!/bin/bash
source /var/www/modernissues/Python/venv/bin/activate
exec uvicorn app.main:app --host 0.0.0.0 --port 8000