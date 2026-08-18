import argparse
import json
import os
import shutil
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict
from pathlib import Path
from typing import Any

from backend.core.container import container
from backend.core.engine import FFmpegEngine
from backend.models.job import JobStatus
from backend.presets import get_preset, list_presets
from backend.services.converter_service import ConverterService
from backend.utils.debug import get_debug_info


def handle_presets(_args: argparse.Namespace) -> int:
    print("\nAvailable presets:\n")
    for p in list_presets():
        print(f"  {p.name:<16}  {p.label}")
    return 0


def handle_config(args: argparse.Namespace) -> int:
    svc = container.get_config_service()
    if args.get:
        print(json.dumps(asdict(svc.load()), indent=2))
    elif args.set:
        svc.update_from_json(args.set)
        print("Configuration updated.")
    return 0


def handle_encoders(_args: argparse.Namespace) -> int:
    svc = container.get_hardware_service()
    backends = svc.get_available_backends()
    output = []
    for b in backends:
        d = asdict(b)
        d["backend"] = b.backend.name
        output.append(d)
    print(json.dumps(output, indent=2))
    return 0


def handle_scan(args: argparse.Namespace) -> int:
    cfg = container.get_config_service().load()
    output_dir = args.output or cfg.output_dir

    scanner = container.get_scanner_service()
    naming = container.get_naming_service()

    results = scanner.scan_multiple(args.input, output_dir=output_dir)
    proposals = naming.build_proposals(results, Path(output_dir))

    if args.json:
        out = [{
            "source": str(p.scan_result.source_path),
            "relative": str(p.scan_result.relative_path),
            "output_filename": p.output_filename,
            "original_filename": str(p.scan_result.source_path.with_suffix(".mkv").name),
            "season": p.season,
            "episode": p.episode,
            "title": p.title,
            "tracks": p.scan_result.tracks
        } for p in proposals]
        print(json.dumps(out, indent=2))
    else:
        print(f"Found {len(results)} files.")
    return 0


def handle_status(args: argparse.Namespace) -> int:
    cfg = container.get_config_service().load()
    svc = container.get_queue_service()
    hw_svc = container.get_hardware_service()

    if args.json:
        all_jobs = svc.get_all()
        jobs = [asdict(j) for j in all_jobs]

        active_jobs = 0
        done_jobs = 0
        failed_jobs = 0
        processed_bytes = 0

        for j in jobs:
            status_str = j["status"]
            if status_str in ("pending", "in_progress"):
                active_jobs += 1
            elif status_str == "done":
                done_jobs += 1
                try:
                    out_path = Path(j["output"])
                    if out_path.exists():
                        processed_bytes += out_path.stat().st_size
                except Exception:
                    pass
            elif status_str == "failed":
                failed_jobs += 1

        # Disk Space info
        output_path = Path(cfg.output_dir)
        storage: dict[str, float] = {"total_gb": 0.0, "free_gb": 0.0, "used_percent": 0.0}
        if output_path.exists() or output_path.parent.exists():
            check_path = output_path if output_path.exists() else output_path.parent
            try:
                usage = shutil.disk_usage(check_path)
                storage["total_gb"] = round(usage.total / (1024 ** 3), 1)
                storage["free_gb"] = round(usage.free / (1024 ** 3), 1)
                storage["used_percent"] = round((usage.used / usage.total) * 100, 1)
            except Exception:
                pass

        hw_dict = asdict(hw_svc.detect_best_encoder(force=cfg.force_encoder))
        hw_dict["backend"] = hw_dict["backend"].name

        payload = {
            "jobs": jobs,
            "stats": {
                "active_jobs": active_jobs,
                "done_jobs": done_jobs,
                "failed_jobs": failed_jobs,
                "processed_gb": round(processed_bytes / (1024 ** 3), 2)
            },
            "storage": storage,
            "hardware": hw_dict
        }
        print(json.dumps(payload, indent=2))
    else:
        summary = svc.get_summary()
        print(f"Queue Status ({cfg.queue_file}):")
        for k, v in summary.items():
            print(f"  {k:12}: {v}")
    return 0


def handle_probe(args: argparse.Namespace) -> int:
    svc = container.get_probe_service()
    if args.clip_info:
        print(json.dumps(svc.get_clip_media_info(args.input).to_dict(), indent=2))
        return 0
    if args.around_us is not None:
        frames = svc.get_nearby_frames(args.input, args.around_us, args.before, args.after)
        print(json.dumps([frame.to_dict() for frame in frames], indent=2))
        return 0
    tracks = svc.get_tracks(args.input)
    print(json.dumps(tracks, indent=2))
    return 0


def handle_clip(args: argparse.Namespace) -> int:
    service = container.get_clip_service()
    encoder = container.get_hardware_service().detect_best_encoder()
    result = service.export(args.input, args.output, args.in_us, args.out_us, args.container, encoder)
    print(json.dumps(result.to_dict(), indent=2))
    return 0


def handle_thumbnail(args: argparse.Namespace) -> int:
    service = container.get_thumbnail_service()
    if args.timestamp_us is not None:
        if not args.output:
            raise ValueError("--output is required with --timestamp-us.")
        output = service.extract_frame(args.input, args.timestamp_us, args.output, args.format)
        print(json.dumps({"path": str(output), "timestamp_us": args.timestamp_us}, indent=2))
        return 0
    if args.in_us is None or args.end_us is None or not args.cache_dir:
        raise ValueError("Candidate generation requires --in-us, --end-us, and --cache-dir.")
    candidates = service.generate_candidates(args.input, args.in_us, args.end_us, args.cache_dir, args.count)
    print(json.dumps([candidate.to_dict() for candidate in candidates], indent=2))
    return 0


def handle_debug(_args: argparse.Namespace) -> int:
    print(get_debug_info())
    return 0


def handle_youtube(args: argparse.Namespace) -> int:
    svc = container.get_download_service()
    if args.info:
        data = svc.fetch_metadata(args.info)
        out = {
            "title": data.get("title"),
            "thumbnail": data.get("thumbnail"),
            "duration": data.get("duration"),
            "uploader": data.get("uploader"),
            "description": data.get("description", "")[:200] + "...",
            "url": args.info
        }
        print(json.dumps(out, indent=2))
    elif args.download:
        def on_progress(pct: float) -> None:
            print(f"⏱ Progress: {pct:.1f}%", flush=True)

        path = svc.download_video(
            args.download,
            on_progress=on_progress,
            audio_only=args.audio_only,
            audio_format=args.format
        )
        print(f"✓ Downloaded to: {path}")
    return 0


def handle_metadata(args: argparse.Namespace) -> int:
    svc = container.get_metadata_service()
    if args.search:
        results = svc.search_content(args.search, is_tv=args.tv)
        out = []
        for r in results[:5]:
            poster_path = r.get("poster_path")
            out.append({
                "id": r.get("id"),
                "title": r.get("title") or r.get("name"),
                "date": r.get("release_date") or r.get("first_air_date"),
                "poster_url": svc.get_poster_url(poster_path) if poster_path else None,
                "overview": r.get("overview")
            })
        print(json.dumps(out, indent=2))
    return 0


def handle_check_update(_args: argparse.Namespace) -> int:
    svc = container.get_update_service()
    res = svc.check_for_update()
    print(json.dumps(res, indent=2))
    return 0


def handle_update_downloader(_args: argparse.Namespace) -> int:
    svc = container.get_download_service()
    res = svc.update_downloader()
    print(res)
    return 0


def handle_queue(args: argparse.Namespace) -> int:
    cfg = container.get_config_service().load()
    svc = container.get_queue_service()

    if args.clear_done:
        n = svc.clear_completed()
        print(f"Cleared {n} jobs.")
    elif args.clear_all:
        n = svc.clear_all_history()
        print(f"Cleared {n} jobs from history.")
    elif args.reset_failed:
        n = svc.reset_failed()
        print(f"Reset {n} jobs.")
    elif args.remove:
        ids = [i.strip() for i in args.remove.split(",") if i.strip()]
        n = svc.remove_by_ids(ids)
        print(f"Removed {n} job(s).")
    elif args.add:
        out_dir = Path(args.to or cfg.output_dir)
        preset_name = cfg.default_preset
        count = 0
        scanner = container.get_scanner_service()

        for path_str in args.add:
            p = Path(path_str)
            if not p.exists():
                print(f"Warning: Path does not exist: {p}")
                continue

            if p.is_file():
                out_dir.mkdir(parents=True, exist_ok=True)
                out_path = out_dir / f"{p.stem}_converted.mkv"
                svc.add(source=str(p.absolute()), output=str(out_path.absolute()), preset=preset_name)
                count += 1
            elif p.is_dir():
                scan_results = scanner.scan(p, output_dir=out_dir)
                for res in scan_results:
                    out_path = out_dir / res.relative_path.parent / f"{res.source_path.stem}_converted.mkv"
                    svc.add(source=str(res.source_path.absolute()), output=str(out_path.absolute()), preset=preset_name)
                    count += 1

        print(f"Added {count} item(s) to queue.")
    elif args.jobs:
        jobs_data = json.loads(args.jobs)
        count = 0
        for j in jobs_data:
            svc.add(
                source=j['source'],
                output=j['output'],
                preset=j.get('preset', cfg.default_preset),
                audio_tracks=j.get('audio_tracks'),
                subtitle_tracks=j.get('subtitle_tracks'),
                audio_bitrate=j.get('audio_bitrate'),
                keep_all_audio=j.get('keep_all_audio', True),
                keep_all_subtitles=j.get('keep_all_subtitles', True),
                delete_source_after_done=j.get('delete_source_after_done', False),
            )
            count += 1
        print(f"Added {count} job(s) from JSON.")
    elif args.resume:
        return _process_queue(svc, cfg)
    return 0


def handle_convert(args: argparse.Namespace) -> int:
    cfg = container.get_config_service().load()
    output_dir = Path(args.output or cfg.output_dir)
    preset_name = args.preset or cfg.default_preset

    # 1. Scan & Name
    scanner = container.get_scanner_service()
    naming = container.get_naming_service()

    results = scanner.scan(args.input, output_dir=output_dir)
    proposals = naming.build_proposals(results, output_dir)

    # 2. Filter active
    active = [p for p in proposals if not p.skipped]
    if not active:
        print("Nothing to convert.")
        return 0

    # 3. Queue
    q_svc = container.get_queue_service()
    for p in active:
        q_svc.add(
            source=str(p.scan_result.source_path),
            output=str(p.output_path),
            preset=preset_name
        )

    # 4. Process
    return _process_queue(q_svc, cfg)


def _process_queue(q_svc: Any, cfg: Any) -> int:
    hw_svc = container.get_hardware_service()
    encoder = hw_svc.detect_best_encoder(force=cfg.force_encoder)

    logger = container.get_logger()

    active_engines: list[Any] = []
    engines_lock = threading.Lock()

    def _watchdog() -> None:
        try:
            sys.stdin.read()
        except Exception:
            pass

        logger.error("Parent process disconnected! Emergency termination of FFmpeg...")
        with engines_lock:
            for eng in active_engines:
                try:
                    eng.stop()
                except Exception:
                    pass
        os._exit(1)

    if not sys.stdin.isatty():
        threading.Thread(target=_watchdog, name="SynWatchdog", daemon=True).start()

    pending = q_svc.get_pending()
    if not pending:
        print("No pending jobs.")
        return 0

    logger.session_start(len(pending), encoder.label)

    max_workers = max(1, min(cfg.parallel_jobs, 8))

    def worker(job_tuple: tuple[int, Any]) -> None:
        index, job = job_tuple
        job_id = job.id
        logger.file_start(index, len(pending), job.source, job_id=job_id)
        q_svc.update_status(job_id, JobStatus.IN_PROGRESS)

        try:
            preset = get_preset(job.preset)
            thread_engine = FFmpegEngine(hw_svc._ffmpeg)
            with engines_lock:
                active_engines.append(thread_engine)

            thread_converter = ConverterService(thread_engine, logger)

            try:
                success = thread_converter.process_job(
                    job, preset, encoder,
                    skip_existing=cfg.skip_existing,
                    max_retries=cfg.max_retries
                )
            finally:
                with engines_lock:
                    if thread_engine in active_engines:
                        active_engines.remove(thread_engine)

            if success:
                q_svc.update_status(job_id, JobStatus.DONE)
            else:
                last_err = "FFmpeg failed (check logs for details)"
                q_svc.update_status(job_id, JobStatus.FAILED, error=last_err)
        except Exception as exc:
            q_svc.update_status(job_id, JobStatus.FAILED, error=str(exc))
            logger.error(f"Worker failed: {exc}", job_id=job_id)

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        list(executor.map(worker, enumerate(pending, start=1)))

    logger.session_end(show_notification=cfg.show_notifications)
    return 0
