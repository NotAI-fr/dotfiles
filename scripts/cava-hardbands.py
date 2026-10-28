#!/usr/bin/env python3
"""Theme renderer matching the approved CAVA preview frames.

CAVA still owns capture, FFT, smoothing, sensitivity and raw bar levels.
Colour themes use the preview's smooth vertical stop interpolation. The
Monochrome A preview uses four discrete greys across each bar's own height.
"""

from __future__ import annotations

import configparser
import fcntl
import os
import re
import select
import signal
import subprocess
import sys
import tempfile
import termios
import tty
from pathlib import Path

NATIVE_CAVA = "/usr/bin/cava"
RAW_OPTIONS = (
    "raw_target",
    "data_format",
    "ascii_max_range",
    "bar_delimiter",
    "frame_delimiter",
)
STOP = False


def stop(_signum, _frame):
    global STOP
    STOP = True


def unquote(value: str) -> str:
    return value.strip().strip("\"'")


def read_config(path: Path) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str.lower
    with path.open(encoding="utf-8") as stream:
        parser.read_file(stream)
    return parser


def config_value(config: configparser.ConfigParser, section: str, key: str, default: str) -> str:
    return unquote(config.get(section, key, fallback=default))


def make_raw_config(source: Path, target: Path) -> None:
    """Clone the live config into a temporary raw-output variant."""
    lines = source.read_text(encoding="utf-8").splitlines()
    result: list[str] = []
    in_output = False
    found_output = False
    inserted = False
    method_written = False

    def append_raw_options() -> None:
        nonlocal inserted
        if not inserted:
            result.extend(
                [
                    "raw_target = /dev/stdout",
                    "data_format = ascii",
                    "ascii_max_range = 1000",
                    "bar_delimiter = 59",
                    "frame_delimiter = 10",
                ]
            )
            inserted = True

    for line in lines:
        section = re.match(r"^\s*\[([^]]+)\]\s*(?:[#;].*)?$", line)
        if section:
            if in_output:
                append_raw_options()
            in_output = section.group(1).strip().lower() == "output"
            found_output |= in_output
            inserted = False
            result.append(line)
            continue

        if in_output:
            key_match = re.match(r"^\s*([^#;=]+?)\s*=", line)
            if key_match:
                key = key_match.group(1).strip().lower()
                if key == "method":
                    result.append(re.sub(r"=\s*.*$", "= raw", line, count=1))
                    method_written = True
                    continue
                if key in RAW_OPTIONS:
                    continue
        result.append(line)

    if in_output:
        if not method_written:
            result.append("method = raw")
        append_raw_options()
    elif not found_output:
        result.extend(["", "[output]", "method = raw"])
        append_raw_options()

    temporary = target.with_name(target.name + ".tmp")
    temporary.write_text("\n".join(result) + "\n", encoding="utf-8")
    os.replace(temporary, target)


def theme_path(config: configparser.ConfigParser, config_file: Path) -> Path:
    xdg = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    theme = config_value(config, "color", "theme", "colors")
    theme_file = Path(theme).expanduser()
    if not theme_file.is_absolute():
        # CAVA theme names resolve from its themes directory.
        theme_file = xdg / "cava" / "themes" / theme_file
    return theme_file


def hex_rgb(value: str) -> tuple[int, int, int] | None:
    match = re.fullmatch(r"#?([0-9a-fA-F]{6})", unquote(value))
    if not match:
        return None
    number = match.group(1)
    return tuple(int(number[i : i + 2], 16) for i in (0, 2, 4))


def load_palette(config: configparser.ConfigParser, config_file: Path):
    path = theme_path(config, config_file)
    try:
        theme = read_config(path)
    except (OSError, configparser.Error):
        theme = config
        path = config_file

    stops = []
    if theme.has_section("color"):
        for index in range(1, 9):
            color = hex_rgb(theme.get("color", f"gradient_color_{index}", fallback=""))
            if color:
                stops.append(color)
        if not stops:
            color = hex_rgb(theme.get("color", "foreground", fallback=""))
            if color:
                stops.append(color)
    if not stops:
        stops = [(255, 255, 255)]

    # The approved prototype used smooth native gradients for the colour
    # themes. Monochrome A splits each bar's own height into four greys.
    grayscale = all(red == green == blue for red, green, blue in stops)
    if grayscale:
        return [(255, 255, 255), (208, 208, 208), (158, 158, 158), (85, 85, 85)], True, path
    return stops, False, path


def setting_int(config, section: str, key: str, default: int) -> int:
    try:
        return int(float(config_value(config, section, key, str(default))))
    except ValueError:
        return default


def interpolate(stops, position):
    if len(stops) == 1:
        return stops[0]
    position = max(0.0, min(1.0, position)) * (len(stops) - 1)
    left = int(position)
    right = min(left + 1, len(stops) - 1)
    fraction = position - left
    return tuple(round(a + (b - a) * fraction) for a, b in zip(stops[left], stops[right]))


def render(values: list[int], config: configparser.ConfigParser, palette, hard_bands, terminal_size):
    columns, rows = terminal_size
    if columns < 1 or rows < 2 or not values:
        return ""

    bar_width = max(1, setting_int(config, "general", "bar_width", 1))
    spacing = max(0, setting_int(config, "general", "bar_spacing", 1))
    configured_max = max(1, setting_int(config, "general", "max_height", rows - 1))
    plot_height = max(1, min(configured_max, rows - 1))
    center = setting_int(config, "general", "center_align", 0)
    orientation = config_value(config, "output", "orientation", "bottom").lower()

    width = len(values) * bar_width + max(0, len(values) - 1) * spacing
    left_pad = max(0, (columns - width) // 2) if center and width <= columns else 0
    scale = plot_height * 8
    heights = [round(max(0, min(1000, value)) * scale / 1000) for value in values]
    blocks = (" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█")

    output = ["\x1b[H"]
    for row in range(plot_height):
        level = (plot_height - row - 1) * 8 if orientation == "bottom" else row * 8
        row_color = interpolate(palette, level / max(1, scale - 1)) if not hard_bands else None
        cells = []
        for index, height in enumerate(heights):
            filled = height - level
            glyph = blocks[min(8, filled)] if filled > 0 else " "
            if hard_bands:
                # Equal horizontal bands relative to this bar's active height.
                band = min(3, level * 4 // max(1, height)) if filled > 0 else 0
                red, green, blue = palette[band]
                cells.append(f"\x1b[38;2;{red};{green};{blue}m" + glyph * bar_width)
            else:
                cells.append(glyph * bar_width)
            if index != len(heights) - 1:
                cells.append(" " * spacing)
        if row_color is None:
            color_prefix = ""
        else:
            red, green, blue = row_color
            color_prefix = f"\x1b[38;2;{red};{green};{blue}m"
        output.append(
            " " * left_pad
            + color_prefix
            + "".join(cells)
            + "\x1b[0m\x1b[K\r\n"
        )
    output.append("\x1b[0m\x1b[K")
    return "".join(output)


def write_terminal(text: str, input_fd: int, output_fd: int) -> bool:
    """Write without trapping shutdown or keyboard input behind a full TTY."""
    data = text.encode("utf-8")
    offset = 0
    while offset < len(data) and not STOP:
        try:
            offset += os.write(output_fd, data[offset:])
        except BlockingIOError:
            readable, writable, _ = select.select([input_fd], [output_fd], [], 0.05)
            if input_fd in readable:
                try:
                    if b"q" in os.read(input_fd, 32).lower():
                        return False
                except BlockingIOError:
                    pass
        if STOP:
            return False
    return offset == len(data)


def main(argv: list[str]) -> int:
    if any(arg in ("-h", "--help", "-v", "--version") for arg in argv):
        os.execv(NATIVE_CAVA, [NATIVE_CAVA, *argv])

    config_file = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "cava" / "config"
    index = 0
    while index < len(argv):
        if argv[index] in ("-p", "--config") and index + 1 < len(argv):
            config_file = Path(argv[index + 1]).expanduser()
            index += 2
        else:
            print(f"cava-hardbands: unsupported argument: {argv[index]}", file=sys.stderr)
            return 2
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        os.execv(NATIVE_CAVA, [NATIVE_CAVA, "-p", str(config_file)])

    input_fd, output_fd = sys.stdin.fileno(), sys.stdout.fileno()
    original_termios = termios.tcgetattr(input_fd)
    original_flags = fcntl.fcntl(output_fd, fcntl.F_GETFL)
    child = None
    try:
        config = read_config(config_file)
        if config_value(config, "output", "method", "noncurses") != "noncurses":
            os.execv(NATIVE_CAVA, [NATIVE_CAVA, "-p", str(config_file)])
        with tempfile.TemporaryDirectory(prefix="cava-hardbands-") as temp_name:
            temp = Path(temp_name)
            raw_config = temp / "config"
            make_raw_config(config_file, raw_config)
            child = subprocess.Popen([NATIVE_CAVA, "-p", str(raw_config)], stdout=subprocess.PIPE)
            tty.setcbreak(input_fd)
            fcntl.fcntl(output_fd, fcntl.F_SETFL, original_flags | os.O_NONBLOCK)
            signal.signal(signal.SIGINT, stop)
            signal.signal(signal.SIGTERM, stop)
            write_terminal("\x1b[?25l\x1b[?7l\x1b[2J\x1b[H", input_fd, output_fd)

            pending = bytearray()
            current_config_mtime = config_file.stat().st_mtime_ns
            current_theme_stamp = None
            palette, hard_bands, _ = load_palette(config, config_file)
            last_terminal_size = None
            while not STOP:
                if child.poll() is not None:
                    return child.returncode or 0

                try:
                    input_ready, _, _ = select.select([child.stdout.fileno(), input_fd], [], [], 0.05)
                except (OSError, ValueError):
                    break
                if input_fd in input_ready:
                    try:
                        if os.read(input_fd, 32).lower().find(b"q") >= 0:
                            break
                    except BlockingIOError:
                        pass
                if child.stdout.fileno() in input_ready:
                    try:
                        pending.extend(os.read(child.stdout.fileno(), 65536))
                    except BlockingIOError:
                        pass
                    while b"\n" in pending:
                        line, _, rest = pending.partition(b"\n")
                        pending = bytearray(rest)
                        fields = line.strip().strip(b";").split(b";")
                        try:
                            values = [int(field) for field in fields if field]
                        except ValueError:
                            continue
                        if not values:
                            continue
                        try:
                            live_config = read_config(config_file)
                            config_mtime = config_file.stat().st_mtime_ns
                            if config_mtime != current_config_mtime:
                                make_raw_config(config_file, raw_config)
                                current_config_mtime = config_mtime
                                config = live_config
                            palette_file = theme_path(config, config_file)
                            try:
                                stat = palette_file.stat()
                                theme_stamp = (stat.st_mtime_ns, stat.st_size)
                            except OSError:
                                theme_stamp = None
                            if theme_stamp != current_theme_stamp:
                                palette, hard_bands, _ = load_palette(config, config_file)
                                current_theme_stamp = theme_stamp
                        except (OSError, configparser.Error):
                            pass
                        try:
                            size = os.get_terminal_size(output_fd)
                            terminal_size = (size.columns, size.lines)
                        except OSError:
                            terminal_size = (80, 24)
                        if terminal_size != last_terminal_size:
                            write_terminal("\x1b[2J", input_fd, output_fd)
                            last_terminal_size = terminal_size
                        frame = render(values, config, palette, hard_bands, terminal_size)
                        if frame:
                            if not write_terminal(frame, input_fd, output_fd):
                                break
            return 0
    except (OSError, configparser.Error) as error:
        print(f"cava-hardbands: {error}", file=sys.stderr)
        return 1
    finally:
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        if child is not None and child.stdout is not None:
            child.stdout.close()
        try:
            termios.tcsetattr(input_fd, termios.TCSADRAIN, original_termios)
        except (OSError, termios.error):
            pass
        try:
            os.write(output_fd, b"\x1b[0m\x1b[?25h\x1b[?7h\x1b[H\x1b[2J")
        except OSError:
            pass
        try:
            fcntl.fcntl(output_fd, fcntl.F_SETFL, original_flags)
        except OSError:
            pass


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
