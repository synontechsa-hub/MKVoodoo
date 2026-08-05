import sys
from backend.cli.parser import build_parser
from backend.cli import handlers

# Force UTF-8 output and line buffering
if hasattr(sys.stdout, "reconfigure"):
    reconfig_out = getattr(sys.stdout, "reconfigure", None)
    if callable(reconfig_out):
        reconfig_out(encoding="utf-8", errors="replace", line_buffering=True)
if hasattr(sys.stderr, "reconfigure"):
    reconfig_err = getattr(sys.stderr, "reconfigure", None)
    if callable(reconfig_err):
        reconfig_err(encoding="utf-8", errors="replace", line_buffering=True)

def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    command_map = {
        "config":   handlers.handle_config,
        "encoders": handlers.handle_encoders,
        "scan":     handlers.handle_scan,
        "convert":  handlers.handle_convert,
        "status":   handlers.handle_status,
        "queue":    handlers.handle_queue,
        "presets":  handlers.handle_presets,
        "probe":    handlers.handle_probe,
        "debug":    handlers.handle_debug,
        "youtube":  handlers.handle_youtube,
        "check-update": handlers.handle_check_update,
        "update-downloader": handlers.handle_update_downloader,
        "metadata": handlers.handle_metadata,
    }

    handler = command_map.get(args.command)
    if not handler:
        parser.print_help()
        sys.exit(1)

    try:
        sys.exit(handler(args))
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
