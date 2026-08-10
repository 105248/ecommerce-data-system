# -*- coding: utf-8 -*-
"""日志模块。"""
import logging
import sys
from datetime import datetime
from pathlib import Path

import config


def get_logger(name: str = "importer") -> logging.Logger:
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger
    logger.setLevel(logging.INFO)

    # 控制台
    console = logging.StreamHandler(sys.stdout)
    console.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s", "%H:%M:%S"))
    logger.addHandler(console)

    # 文件
    log_file = config.LOG_DIR / f"importer_{datetime.now():%Y%m%d_%H%M%S}.log"
    fh = logging.FileHandler(log_file, encoding="utf-8")
    fh.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
    logger.addHandler(fh)
    return logger
