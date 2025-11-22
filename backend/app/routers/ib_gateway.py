from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Any
import os
import subprocess
import time
import psutil
import socket
import random
import asyncio

try:
    from ib_insync import IB  # type: ignore
except Exception:
    IB = None  # ib_insync optional
from app.core.config import settings, Settings
import logging
from .auth import verify_credentials
from app.core.db import get_sql_model


router = APIRouter(prefix="/api/ib-gateway", tags=["ib-gateway"], dependencies=[Depends(verify_credentials)])
logger = logging.getLogger("app")


def _list_ibg_processes() -> list[psutil.Process]:
    procs = []
    try:
        for p in psutil.process_iter(["pid", "name", "exe", "cmdline"]):
            name = (p.info.get("name") or "").lower()
            cmdline = " ".join(p.info.get("cmdline") or []).lower()
            if "ibgateway" in name or "ibgateway" in cmdline or "ibc" in cmdline:
                procs.append(p)
    except Exception:
        pass
    return procs


def _list_tws_processes() -> list[psutil.Process]:
    procs = []
    try:
        for p in psutil.process_iter(["pid", "name", "exe", "cmdline"]):
            name = (p.info.get("name") or "").lower()
            exe = (p.info.get("exe") or "").lower()
            cmdline = " ".join(p.info.get("cmdline") or []).lower()
            # Match common signals for Trader Workstation
            if (
                name == "tws.exe"
                or exe.endswith("\\tws.exe")
                or exe.endswith("/tws.exe")
                or "tws.exe" in cmdline
            ):
                procs.append(p)
    except Exception:
        pass
    return procs


def _is_port_open(host: str, port: int, timeout: float = 2.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except Exception:
        return False


def _current_settings() -> Settings:
    # Re-read .env each time to pick up latest calibration without restarting backend
    try:
        return Settings()
    except Exception:
        return settings  # fallback


@router.get("/status")
async def status() -> Dict[str, Any]:
    cfg = _current_settings()
    procs = _list_ibg_processes()
    is_running = len(procs) > 0
    pids = [p.pid for p in procs]
    # No socket probing to IBG — avoid any API/port touches here
    ib_connected = False
    ib_error: str | None = None

    # Optional: database heartbeat from StockDB.StockAPI.HeartBeat (if accessible)
    hb_success: int | None = None
    hb_updated: str | None = None
    hb_error: str | None = None
    try:
        sql = get_sql_model()
        # Query latest heartbeat within the configured database using standard helper
        rows = sql.execute_read_query(
            "SELECT TOP 1 GetDataSuccess, GetDataUpdateDateTime FROM [StockAPI].[HeartBeat] ORDER BY GetDataUpdateDateTime DESC",
            (),
        )
        if rows and len(rows) > 0:
            row = rows[0]
            try:
                hb_success = int(row.get("GetDataSuccess")) if row.get("GetDataSuccess") is not None else None
            except Exception:
                hb_success = None
            upd = row.get("GetDataUpdateDateTime")
            hb_updated = str(upd) if upd is not None else None
    except Exception as e:
        hb_error = str(e)
        logger.warning("IBG: failed to load DB heartbeat: %s", e)

    return {
        "running": is_running,
        "pids": pids,
        "ib_connected": ib_connected,
        "ib_error": ib_error,
        "calibrated": bool(cfg.ibg_username_x_pct and cfg.ibg_username_y_pct and cfg.ibg_password_x_pct and cfg.ibg_password_y_pct),
        "db_heartbeat_success": hb_success,
        "db_heartbeat_updated": hb_updated,
        "db_heartbeat_ok": (hb_success == 1) if hb_success is not None else None,
        "db_heartbeat_error": hb_error,
    }


@router.post("/calibration/start")
def calibration_start() -> Dict[str, Any]:
    # Bring IBKR Gateway to front if possible (by PID or title)
    try:
        from pywinauto import Application  # type: ignore
        app = None
        procs = _list_ibg_processes()
        if procs:
            try:
                app = Application(backend="uia").connect(process=procs[0].pid)
            except Exception:
                app = None
        if app is None:
            app = Application(backend="uia").connect(title_re=".*IBKR Gateway.*|.*IB Gateway.*|.*IBGateway.*|.*Interactive Brokers.*", timeout=5)
        dlg = app.top_window()
        dlg.set_focus()
        rect = dlg.rectangle()
        return {"ok": True, "window": {"width": rect.width(), "height": rect.height()}}
    except Exception as e:
        logger.warning("IBG: calibration_start failed: %s", e)
        raise HTTPException(status_code=500, detail=f"calibration_start failed: {e}")


@router.post("/calibration/save")
def calibration_save(data: Dict[str, float]) -> Dict[str, Any]:
    # Expect absolute pixel coords relative to the IBKR window client area; convert to pct and write to .env
    required = ["username_x", "username_y", "password_x", "password_y", "window_width", "window_height"]
    for k in required:
        if k not in data:
            raise HTTPException(status_code=400, detail=f"Missing field: {k}")
    ww = max(1.0, float(data["window_width"]))
    wh = max(1.0, float(data["window_height"]))
    ux_pct = max(0.0, min(1.0, float(data["username_x"]) / ww))
    uy_pct = max(0.0, min(1.0, float(data["username_y"]) / wh))
    px_pct = max(0.0, min(1.0, float(data["password_x"]) / ww))
    py_pct = max(0.0, min(1.0, float(data["password_y"]) / wh))

    # Persist to backend/.env (append or replace lines)
    env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "..", "..", "backend", ".env")
    env_path = os.path.normpath(env_path)
    try:
        lines: list[str] = []
        # Ensure directory exists
        os.makedirs(os.path.dirname(env_path), exist_ok=True)
        if os.path.exists(env_path):
            with open(env_path, "r", encoding="utf-8") as f:
                lines = f.read().splitlines()
        kv: Dict[str, str] = {
            "IBG_USERNAME_X_PCT": f"{ux_pct:.6f}",
            "IBG_USERNAME_Y_PCT": f"{uy_pct:.6f}",
            "IBG_PASSWORD_X_PCT": f"{px_pct:.6f}",
            "IBG_PASSWORD_Y_PCT": f"{py_pct:.6f}",
        }
        # Optional trading mode tab calibration
        live_x = data.get("live_tab_x")
        live_y = data.get("live_tab_y")
        paper_x = data.get("paper_tab_x")
        paper_y = data.get("paper_tab_y")
        if live_x is not None and live_y is not None:
            lx_pct = max(0.0, min(1.0, float(live_x) / ww))
            ly_pct = max(0.0, min(1.0, float(live_y) / wh))
            kv["IBG_LIVE_TAB_X_PCT"] = f"{lx_pct:.6f}"
            kv["IBG_LIVE_TAB_Y_PCT"] = f"{ly_pct:.6f}"
        if paper_x is not None and paper_y is not None:
            px2_pct = max(0.0, min(1.0, float(paper_x) / ww))
            py2_pct = max(0.0, min(1.0, float(paper_y) / wh))
            kv["IBG_PAPER_TAB_X_PCT"] = f"{px2_pct:.6f}"
            kv["IBG_PAPER_TAB_Y_PCT"] = f"{py2_pct:.6f}"
        # Replace or append
        saved_keys: list[str] = []
        for key, val in kv.items():
            replaced = False
            for i, line in enumerate(lines):
                if line.startswith(key + "="):
                    lines[i] = f"{key}={val}"
                    replaced = True
                    break
            if not replaced:
                lines.append(f"{key}={val}")
            saved_keys.append(key)
        with open(env_path, "w", encoding="utf-8", newline="\r\n") as f:
            f.write("\r\n".join(lines) + "\r\n")
            try:
                f.flush()
                os.fsync(f.fileno())
            except Exception:
                pass
        logger.info("IBG: calibration saved to %s", env_path)
        return {"ok": True, "env_path": env_path, "values": kv, "saved_keys": saved_keys}
    except Exception as e:
        logger.exception("IBG: calibration_save failed: %s", e)
        raise HTTPException(status_code=500, detail=f"calibration_save failed: {e}")


def _kill_ibg() -> None:
    logger.info("IBG: Killing existing IB Gateway processes if any")
    procs = _list_ibg_processes()
    for p in procs:
        try:
            parent = psutil.Process(p.pid)
            children = parent.children(recursive=True)
            for c in children:
                try:
                    c.kill()
                except Exception:
                    pass
            parent.kill()
        except Exception:
            pass


def _kill_tws() -> None:
    logger.info("IBG: Killing existing Trader Workstation (tws.exe) if any")
    procs = _list_tws_processes()
    for p in procs:
        try:
            parent = psutil.Process(p.pid)
            children = parent.children(recursive=True)
            for c in children:
                try:
                    c.kill()
                except Exception:
                    pass
            parent.kill()
        except Exception:
            pass


def _start_ibg_via_ibc() -> None:
    """Start IB Gateway using IBC script (recommended for unattended operation)."""
    cfg = _current_settings()
    ibc_script = cfg.ibg_ibc_script_path
    if not ibc_script:
        logger.error("IBG: IBC script path not configured")
        raise HTTPException(status_code=500, detail="IBC script path (ibg_ibc_script_path) is not configured")
    if not os.path.exists(ibc_script):
        logger.error("IBG: IBC script not found at %s", ibc_script)
        raise HTTPException(status_code=500, detail=f"IBC script not found: {ibc_script}")

    logger.info("IBG: Launching via IBC script: %s", ibc_script)
    try:
        # Launch IBC with /INLINE argument for proper operation with Task Scheduler
        # This runs IBC in the current console instead of opening a new window
        ps_cmd = [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            f"Start-Process -FilePath '{ibc_script}' -ArgumentList '/INLINE' -WindowStyle Hidden -PassThru | Select-Object -ExpandProperty Id"
        ]
        result = subprocess.run(ps_cmd, capture_output=True, text=True, check=True)
        out = (result.stdout or "").strip()
        started_pid = None
        if out:
            try:
                started_pid = int(out.splitlines()[-1].strip())
                logger.info("IBG: IBC script launched with PID=%s", started_pid)
            except Exception:
                pass

        # Wait for IBG process to appear (IBC starts the actual gateway)
        for i in range(30):
            procs = _list_ibg_processes()
            if procs:
                logger.info("IBG: IB Gateway process detected: %s", [p.pid for p in procs])
                break
            time.sleep(1)
        else:
            logger.warning("IBG: No IB Gateway process detected after 30 seconds, but IBC may still be starting it")

        logger.info("IBG: IBC will handle login automatically (credentials from IBC config)")

    except subprocess.CalledProcessError as e:
        logger.exception("IBG: Failed to launch IBC script: %s", e)
        raise HTTPException(status_code=500, detail=f"Failed to launch IBC script: {e}")
    except Exception as e:
        logger.exception("IBG: Unexpected error launching IBC: %s", e)
        raise HTTPException(status_code=500, detail=f"Unexpected error launching IBC: {e}")


def _start_ibg_and_type_credentials() -> None:
    cfg = _current_settings()

    # Check if IBC integration is enabled
    if cfg.ibg_use_ibc_script:
        _start_ibg_via_ibc()
        return

    # Original direct launch method
    exe = cfg.ibg_exe_path
    if not exe:
        logger.error("IBG: Missing ibg_exe_path config")
        raise HTTPException(status_code=500, detail="IB Gateway executable path (ibg_exe_path) is not configured")
    if not os.path.exists(exe):
        logger.error("IBG: Executable not found at %s", exe)
        raise HTTPException(status_code=500, detail=f"IB Gateway executable not found: {exe}")

    username = cfg.ibg_username
    password = cfg.ibg_password
    if not username or not password:
        logger.error("IBG: Missing ibg_username or ibg_password config")
        raise HTTPException(status_code=500, detail="IB Gateway credentials are not configured")

    # Start the GUI app and capture PID for reliable AppActivate
    started_pid: int | None = None
    try:
        exe_dir = os.path.dirname(exe) or "."
        ps_cmd = [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            (
                f"$p = Start-Process -FilePath '{exe}' -WorkingDirectory '{exe_dir}' -WindowStyle Normal -PassThru;"
                f"$p.Id"
            ),
        ]
        logger.info("IBG: Launching via Start-Process -PassThru: %s", exe)
        result = subprocess.run(ps_cmd, capture_output=True, text=True, check=True)
        out = (result.stdout or "").strip()
        if out:
            try:
                started_pid = int(out.splitlines()[-1].strip())
            except Exception:
                started_pid = None
        if started_pid:
            logger.info("IBG: Started PID=%s", started_pid)
    except Exception as e:
        logger.exception("IBG: Failed Start-Process -PassThru, attempting direct launch: %s", e)
        try:
            proc = subprocess.Popen([exe], cwd=os.path.dirname(exe) or None, close_fds=False)
            started_pid = proc.pid
            logger.info("IBG: Direct launch PID=%s", started_pid)
        except Exception as e2:
            logger.exception("IBG: Failed to start IB Gateway directly: %s", e2)
            raise HTTPException(status_code=500, detail=f"Failed to start IB Gateway: {e2}")

    # Wait for process to appear
    for i in range(20):
        if _list_ibg_processes():
            break
        time.sleep(0.5)
    else:
        logger.warning("IBG: No IB Gateway process detected after launch")

    # Prefer pywinauto automation (does not require foreground focus)
    try:
        from pywinauto import Application  # type: ignore
        time.sleep(5)

        # Helper: type text with human-like per-keystroke delays
        def _escape_key(ch: str) -> str:
            # Escape characters that have special meaning in type_keys
            return '{' + ch + '}' if ch in '{}^%+~()' else ch

        def _type_human(ctrl, text: str) -> None:
            import random as _r
            for i, ch in enumerate(text):
                try:
                    ctrl.type_keys(_escape_key(ch), with_spaces=True, set_foreground=False)
                except Exception:
                    # fallback: try on dlg if control rejected
                    try:
                        dlg.type_keys(_escape_key(ch), with_spaces=True, set_foreground=False)
                    except Exception:
                        pass
                # base jitter 50-120ms
                time.sleep(_r.uniform(0.05, 0.12))
                # occasional longer pause
                if i > 0 and (i % _r.randint(4, 7) == 0):
                    time.sleep(_r.uniform(0.18, 0.35))
        # Helper connect with selected backend
        def _connect_dialog(backend_name: str):
            app_local = None
            if started_pid:
                try:
                    app_local = Application(backend=backend_name).connect(process=started_pid, timeout=10)
                except Exception:
                    app_local = None
            if app_local is None:
                app_local = Application(backend=backend_name).connect(title_re=".*IBKR Gateway.*|.*IB Gateway.*|.*IBGateway.*|.*Interactive Brokers.*", timeout=10)
            dlg_local = app_local.top_window()
            return app_local, dlg_local

        # Attempt with UIA first, then win32 as fallback
        backends_order = ["uia", "win32"]
        last_error: Exception | None = None
        for backend_name in backends_order:
            try:
                app, dlg = _connect_dialog(backend_name)
                title_txt = ""
                try:
                    title_txt = dlg.window_text()
                except Exception:
                    title_txt = ""
                try:
                    rect0 = dlg.rectangle()
                    logger.info("IBG: connected (%s). title='%s' rect=(%s,%s,%s,%s)", backend_name, title_txt, rect0.left, rect0.top, rect0.right, rect0.bottom)
                except Exception:
                    logger.info("IBG: connected (%s). title='%s'", backend_name, title_txt)

                # Try to prepare focus a few times with bounded delay
                for _ in range(3):
                    try:
                        try:
                            dlg.set_window_visual_state("normal")
                        except Exception:
                            pass
                        try:
                            dlg.set_focus()
                        except Exception:
                            pass
                        try:
                            rect = dlg.rectangle()
                            x = min(max(10, rect.left + 10), rect.right - 10)
                            y = min(max(10, rect.top + 10), rect.bottom - 10)
                            dlg.click_input(coords=(x, y))
                        except Exception:
                            pass
                        time.sleep(0.3)
                    except Exception:
                        pass

                # Ensure correct trading mode (Live/Paper) before typing (reuse existing logic)
                try:
                    desired = (cfg.ibg_trading_mode or "Live").strip().lower()
                    if desired.startswith("live") and cfg.ibg_live_tab_x_pct is not None and cfg.ibg_live_tab_y_pct is not None:
                        rect = dlg.rectangle(); w = rect.width(); h = rect.height()
                        lx = int(max(0, min(w - 1, w * float(cfg.ibg_live_tab_x_pct))))
                        ly = int(max(0, min(h - 1, h * float(cfg.ibg_live_tab_y_pct))))
                        dlg.click_input(coords=(lx, ly)); logger.info("IBG: (%s) clicked Live tab at (%.3f,%.3f)", backend_name, float(cfg.ibg_live_tab_x_pct), float(cfg.ibg_live_tab_y_pct)); time.sleep(0.5)
                    elif desired.startswith("paper") and cfg.ibg_paper_tab_x_pct is not None and cfg.ibg_paper_tab_y_pct is not None:
                        rect = dlg.rectangle(); w = rect.width(); h = rect.height()
                        px2 = int(max(0, min(w - 1, w * float(cfg.ibg_paper_tab_x_pct))))
                        py2 = int(max(0, min(h - 1, h * float(cfg.ibg_paper_tab_y_pct))))
                        dlg.click_input(coords=(px2, py2)); logger.info("IBG: (%s) clicked Paper tab at (%.3f,%.3f)", backend_name, float(cfg.ibg_paper_tab_x_pct), float(cfg.ibg_paper_tab_y_pct)); time.sleep(0.5)
                except Exception:
                    pass

                # Try calibrated typing first if available
                if (
                    cfg.ibg_username_x_pct is not None and
                    cfg.ibg_username_y_pct is not None and
                    cfg.ibg_password_x_pct is not None and
                    cfg.ibg_password_y_pct is not None
                ):
                    try:
                        rect = dlg.rectangle(); w = rect.width(); h = rect.height()
                        ux = int(max(0, min(w - 1, w * float(cfg.ibg_username_x_pct))))
                        uy = int(max(0, min(h - 1, h * float(cfg.ibg_username_y_pct))))
                        px = int(max(0, min(w - 1, w * float(cfg.ibg_password_x_pct))))
                        py = int(max(0, min(h - 1, h * float(cfg.ibg_password_y_pct))))
                        logger.info("IBG: (%s) coords ux=%s,uy=%s px=%s,py=%s (w=%s,h=%s)", backend_name, ux, uy, px, py, w, h)
                        dlg.click_input(coords=(ux, uy)); dlg.type_keys("^a{BACKSPACE}"); time.sleep(1.0)
                        _type_human(dlg, username)
                        dlg.click_input(coords=(px, py)); dlg.type_keys("^a{BACKSPACE}"); time.sleep(2.0)
                        _type_human(dlg, password)
                        logger.info("IBG: (%s) filled credentials using calibrated coords", backend_name)
                        try:
                            dlg.type_keys("{ENTER}", set_foreground=False)
                        except Exception:
                            pass
                        return
                    except Exception as e_inner:
                        logger.warning("IBG: (%s) calibrated typing failed: %s", backend_name, e_inner)

                # Locate fields generically
                try:
                    containers = [dlg]
                    try:
                        containers += dlg.descendants(control_type="Pane")
                        containers += dlg.descendants(control_type="Window")
                    except Exception:
                        pass
                    for container in containers:
                        try:
                            edits = container.descendants(control_type="Edit")
                        except Exception:
                            try:
                                edits = container.descendants(class_name="Edit")  # win32
                            except Exception:
                                edits = []
                        if len(edits) >= 2:
                            try:
                                user_edit = edits[0]; pass_edit = edits[1]
                                user_edit.set_edit_text(""); time.sleep(1.0); _type_human(user_edit, username)
                                pass_edit.set_edit_text(""); time.sleep(2.0); _type_human(pass_edit, password)
                                logger.info("IBG: (%s) filled credentials using container with %s edit controls", backend_name, len(edits))
                                try:
                                    dlg.type_keys("{ENTER}", set_foreground=False)
                                except Exception:
                                    pass
                                return
                            except Exception:
                                continue
                except Exception as e_inner2:
                    logger.warning("IBG: (%s) scanning for edits failed: %s", backend_name, e_inner2)

                last_error = RuntimeError(f"{backend_name} backend could not locate input fields")
            except Exception as e_backend:
                last_error = e_backend
                logger.warning("IBG: %s backend connect/automation failed: %s", backend_name, e_backend)

        # Optional final fallback: foreground typing with calibrated coords
        if (
            _current_settings().ibg_allow_fallback_typing and
            cfg.ibg_username_x_pct is not None and cfg.ibg_username_y_pct is not None and
            cfg.ibg_password_x_pct is not None and cfg.ibg_password_y_pct is not None
        ):
            try:
                app_fg, dlg_fg = _connect_dialog("win32")
                try:
                    dlg_fg.set_focus()
                except Exception:
                    pass
                rect = dlg_fg.rectangle(); w = rect.width(); h = rect.height()
                ux = int(max(0, min(w - 1, w * float(cfg.ibg_username_x_pct))))
                uy = int(max(0, min(h - 1, h * float(cfg.ibg_username_y_pct))))
                px = int(max(0, min(w - 1, w * float(cfg.ibg_password_x_pct))))
                py = int(max(0, min(h - 1, h * float(cfg.ibg_password_y_pct))))
                dlg_fg.click_input(coords=(ux, uy)); time.sleep(0.5)
                try:
                    from pywinauto.keyboard import send_keys  # type: ignore
                    send_keys("^a{BACKSPACE}")
                    for ch in username:
                        send_keys(ch)
                    dlg_fg.click_input(coords=(px, py)); time.sleep(0.5)
                    send_keys("^a{BACKSPACE}")
                    for ch in password:
                        send_keys(ch)
                    send_keys("{ENTER}")
                    logger.info("IBG: foreground typing fallback succeeded")
                    return
                except Exception as e_send:
                    logger.warning("IBG: foreground typing fallback failed: %s", e_send)
            except Exception as e_fg:
                last_error = e_fg
                logger.warning("IBG: win32 foreground fallback failed to connect: %s", e_fg)

        # If we reached here, all strategies failed
        if last_error is not None:
            raise last_error
        raise RuntimeError("Unable to locate IB Gateway input fields for safe automation")
        # Try hard to bring window to foreground and ready for input
        try:
            try:
                dlg.set_window_visual_state("normal")
            except Exception:
                pass
            for _ in range(3):
                try:
                    dlg.set_focus()
                except Exception:
                    pass
                try:
                    # Click near top-left inside client area to activate
                    rect = dlg.rectangle()
                    x = min(max(10, rect.left + 10), rect.right - 10)
                    y = min(max(10, rect.top + 10), rect.bottom - 10)
                    dlg.click_input(coords=(x, y))
                except Exception:
                    pass
                time.sleep(0.3)
        except Exception:
            pass

        # Ensure correct trading mode (Live/Paper) before typing
        try:
            desired = (cfg.ibg_trading_mode or "Live").strip().lower()
            # Preferred: calibrated click locations for Trading Mode tabs
            if desired.startswith("live") and cfg.ibg_live_tab_x_pct is not None and cfg.ibg_live_tab_y_pct is not None:
                rect = dlg.rectangle()
                w = rect.width(); h = rect.height()
                lx = int(max(0, min(w - 1, w * float(cfg.ibg_live_tab_x_pct))))
                ly = int(max(0, min(h - 1, h * float(cfg.ibg_live_tab_y_pct))))
                dlg.click_input(coords=(lx, ly))
                logger.info("IBG: Clicked calibrated Live tab at (%.3f,%.3f)", float(cfg.ibg_live_tab_x_pct), float(cfg.ibg_live_tab_y_pct))
                time.sleep(0.5)
            elif desired.startswith("paper") and cfg.ibg_paper_tab_x_pct is not None and cfg.ibg_paper_tab_y_pct is not None:
                rect = dlg.rectangle()
                w = rect.width(); h = rect.height()
                px = int(max(0, min(w - 1, w * float(cfg.ibg_paper_tab_x_pct))))
                py = int(max(0, min(h - 1, h * float(cfg.ibg_paper_tab_y_pct))))
                dlg.click_input(coords=(px, py))
                logger.info("IBG: Clicked calibrated Paper tab at (%.3f,%.3f)", float(cfg.ibg_paper_tab_x_pct), float(cfg.ibg_paper_tab_y_pct))
                time.sleep(0.5)
            else:
                # Fallback: try to find elements by text in generic containers
                candidates = []
                try:
                    candidates += dlg.descendants()
                except Exception:
                    pass
                for c in candidates:
                    try:
                        title = (getattr(c, 'window_text', lambda: '')() or '').strip().lower()
                    except Exception:
                        continue
                    if desired.startswith('live') and ('live trading' in title or title == 'live'):
                        try:
                            c.click_input(); logger.info("IBG: Selected trading mode via '%s'", title); time.sleep(0.5)
                        except Exception:
                            pass
                        break
                    if desired.startswith('paper') and ('paper trading' in title or title == 'paper'):
                        try:
                            c.click_input(); logger.info("IBG: Selected trading mode via '%s'", title); time.sleep(0.5)
                        except Exception:
                            pass
                        break
        except Exception:
            # Non-fatal if we cannot identify the control; rely on last-used mode
            pass
        # If calibrated positions are available, use them first
        if (
            cfg.ibg_username_x_pct is not None and
            cfg.ibg_username_y_pct is not None and
            cfg.ibg_password_x_pct is not None and
            cfg.ibg_password_y_pct is not None
        ):
            try:
                rect = dlg.rectangle()
                w = rect.width()
                h = rect.height()
                ux = int(max(0, min(w - 1, w * float(cfg.ibg_username_x_pct))))
                uy = int(max(0, min(h - 1, h * float(cfg.ibg_username_y_pct))))
                px = int(max(0, min(w - 1, w * float(cfg.ibg_password_x_pct))))
                py = int(max(0, min(h - 1, h * float(cfg.ibg_password_y_pct))))
                dlg.click_input(coords=(ux, uy))
                dlg.type_keys("^a{BACKSPACE}")
                time.sleep(1.0)
                _type_human(dlg, username)
                dlg.click_input(coords=(px, py))
                dlg.type_keys("^a{BACKSPACE}")
                time.sleep(2.0)
                _type_human(dlg, password)
                logger.info("IBG: pywinauto filled credentials using calibrated coords (ux=%.3f,uy=%.3f,px=%.3f,py=%.3f)",
                            float(cfg.ibg_username_x_pct), float(cfg.ibg_username_y_pct),
                            float(cfg.ibg_password_x_pct), float(cfg.ibg_password_y_pct))
                # Submit
                try:
                    dlg.type_keys("{ENTER}", set_foreground=False)
                except Exception:
                    pass
                return
            except Exception as e:
                logger.warning("IBG: Calibrated click typing failed: %s", e)
        # Skip toggling tabs/modes; assume defaults are correct

        # Locate fields in nested containers
        containers = [dlg]
        try:
            containers += dlg.descendants(control_type="Pane")
            containers += dlg.descendants(control_type="Window")
        except Exception:
            pass
        filled = False
        last_edit_count = 0
        for container in containers:
            try:
                edits = container.descendants(control_type="Edit")
                last_edit_count = max(last_edit_count, len(edits))
                if len(edits) >= 2:
                    user_edit = edits[0]
                    pass_edit = edits[1]
                    user_edit.set_edit_text("")
                    time.sleep(1.0)
                    _type_human(user_edit, username)
                    pass_edit.set_edit_text("")
                    time.sleep(2.0)
                    _type_human(pass_edit, password)
                    filled = True
                    logger.info("IBG: pywinauto filled credentials using container with %s edit controls", len(edits))
                    break
            except Exception:
                continue
        if not filled:
            # Safety: do NOT send any keystrokes globally. Abort with clear error.
            logger.warning("IBG: No standard Edit controls found; refusing to send keystrokes for safety")
            raise RuntimeError("Unable to locate IB Gateway input fields for safe automation")
        # Press Enter (or click Login)
        try:
            dlg.type_keys("{ENTER}", set_foreground=False)
        except Exception:
            try:
                login_btn = dlg.child_window(title_re=".*Login.*|.*Sign in.*", control_type="Button")
                login_btn.click_input()
            except Exception:
                logger.warning("IBG: pywinauto could not submit the form, continuing")
        return
    except Exception as e:
        logger.warning("IBG: pywinauto automation failed: %s", e)
        raise HTTPException(status_code=500, detail=f"IB Gateway automation failed: {e}")


@router.post("/restart")
def restart() -> Dict[str, Any]:
    cfg = _current_settings()
    logger.info("IBG: Restart requested. SESSIONNAME=%s", os.getenv('SESSIONNAME', ''))
    # Kill existing
    _kill_tws()
    _kill_ibg()
    wait_s = max(1, int(cfg.ibg_wait_after_kill_seconds))
    logger.info("IBG: Waiting %ss after kill", wait_s)
    time.sleep(wait_s)

    # Start and type
    _start_ibg_and_type_credentials()

    # Final check
    procs = _list_ibg_processes()
    started = len(procs) > 0
    logger.info("IBG: Restart completed. Detected processes: %s", [p.pid for p in procs])

    return {"ok": True, "started": started, "pids": [p.pid for p in procs]}


