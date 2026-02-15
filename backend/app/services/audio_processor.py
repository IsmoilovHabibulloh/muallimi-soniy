"""Audio processing service: FFmpeg conversion, waveform, segmentation."""

import json
import logging
import os
import subprocess
import re
from typing import List, Optional, Tuple

from app.config import get_settings

logger = logging.getLogger("muallimus")
settings = get_settings()


def get_audio_duration_ms(file_path: str) -> int:
    """Get audio duration in milliseconds using FFprobe."""
    try:
        result = subprocess.run(
            [
                "ffprobe", "-v", "quiet",
                "-show_entries", "format=duration",
                "-of", "json", file_path,
            ],
            capture_output=True, text=True, timeout=30,
        )
        data = json.loads(result.stdout)
        duration = float(data["format"]["duration"])
        return int(duration * 1000)
    except Exception as e:
        logger.error(f"FFprobe error: {e}")
        return 0


def normalize_audio(input_path: str, output_path: str) -> bool:
    """Normalize audio to consistent format: 44.1kHz, mono, 128kbps MP3."""
    try:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        result = subprocess.run(
            [
                "ffmpeg", "-y", "-i", input_path,
                "-ar", "44100", "-ac", "1", "-b:a", "128k",
                "-f", "mp3", output_path,
            ],
            capture_output=True, text=True, timeout=300,
        )
        if result.returncode != 0:
            logger.error(f"FFmpeg normalize error: {result.stderr}")
            return False
        return True
    except Exception as e:
        logger.error(f"Normalize error: {e}")
        return False


def generate_waveform_peaks(file_path: str, num_samples: int = 1000) -> List[float]:
    """Generate waveform peak data for visualization using FFmpeg."""
    try:
        # Get raw audio samples
        result = subprocess.run(
            [
                "ffmpeg", "-i", file_path,
                "-f", "s16le", "-ac", "1", "-ar", "8000",
                "-",
            ],
            capture_output=True, timeout=120,
        )
        if result.returncode != 0:
            logger.error("Waveform generation failed")
            return []

        raw_data = result.stdout
        if not raw_data:
            return []

        # Convert raw bytes to samples
        import struct
        sample_count = len(raw_data) // 2
        samples = struct.unpack(f"<{sample_count}h", raw_data[:sample_count * 2])

        # Downsample to num_samples peaks
        chunk_size = max(1, sample_count // num_samples)
        peaks = []
        for i in range(0, sample_count, chunk_size):
            chunk = samples[i:i + chunk_size]
            if chunk:
                peak = max(abs(s) for s in chunk) / 32768.0
                peaks.append(round(peak, 4))

        return peaks[:num_samples]

    except Exception as e:
        logger.error(f"Waveform error: {e}")
        return []


def detect_silence_boundaries(
    file_path: str,
    silence_threshold: str = "-30dB",
    min_silence_duration: float = 0.3,
) -> List[Tuple[float, float]]:
    """
    Use FFmpeg silencedetect to find silence regions.
    Returns list of (start_ms, end_ms) silence boundaries.
    """
    try:
        result = subprocess.run(
            [
                "ffmpeg", "-i", file_path,
                "-af", f"silencedetect=noise={silence_threshold}:d={min_silence_duration}",
                "-f", "null", "-",
            ],
            capture_output=True, text=True, timeout=120,
        )

        silences = []
        start_pattern = re.compile(r"silence_start: ([\d.]+)")
        end_pattern = re.compile(r"silence_end: ([\d.]+)")

        starts = start_pattern.findall(result.stderr)
        ends = end_pattern.findall(result.stderr)

        for s, e in zip(starts, ends):
            silences.append((float(s) * 1000, float(e) * 1000))

        return silences

    except Exception as e:
        logger.error(f"Silence detect error: {e}")
        return []


def auto_segment(
    file_path: str,
    duration_ms: int,
    silence_threshold: str = "-30dB",
    min_silence_duration: float = 0.3,
) -> List[dict]:
    """
    Auto-segment audio based on silence detection.
    Returns list of segment dicts with start_ms, end_ms, is_silence.
    """
    silences = detect_silence_boundaries(file_path, silence_threshold, min_silence_duration)

    segments = []
    current_pos = 0
    seg_index = 0

    for silence_start, silence_end in silences:
        silence_start = int(silence_start)
        silence_end = int(silence_end)

        # Content segment before this silence
        if current_pos < silence_start:
            segments.append({
                "segment_index": seg_index,
                "start_ms": current_pos,
                "end_ms": silence_start,
                "duration_ms": silence_start - current_pos,
                "is_silence": False,
            })
            seg_index += 1

        # Silence segment
        segments.append({
            "segment_index": seg_index,
            "start_ms": silence_start,
            "end_ms": silence_end,
            "duration_ms": silence_end - silence_start,
            "is_silence": True,
        })
        seg_index += 1
        current_pos = silence_end

    # Final content segment after last silence
    if current_pos < duration_ms:
        segments.append({
            "segment_index": seg_index,
            "start_ms": current_pos,
            "end_ms": duration_ms,
            "duration_ms": duration_ms - current_pos,
            "is_silence": False,
        })

    return segments


def cut_segment_file(
    source_path: str,
    output_path: str,
    start_ms: int,
    end_ms: int,
) -> bool:
    """Cut a single segment from the source audio using FFmpeg."""
    try:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        start_s = start_ms / 1000.0
        duration_s = (end_ms - start_ms) / 1000.0

        result = subprocess.run(
            [
                "ffmpeg", "-y",
                "-ss", str(start_s),
                "-t", str(duration_s),
                "-i", source_path,
                "-c", "copy",
                output_path,
            ],
            capture_output=True, text=True, timeout=60,
        )
        return result.returncode == 0

    except Exception as e:
        logger.error(f"Cut segment error: {e}")
        return False
