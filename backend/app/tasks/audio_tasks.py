"""Async audio processing tasks."""

import logging
import os

from app.tasks.celery_app import celery_app
from app.config import get_settings

logger = logging.getLogger("muallimus")
settings = get_settings()


@celery_app.task(bind=True, max_retries=2, default_retry_delay=30)
def process_audio_task(self, audio_file_id: int):
    """Process uploaded audio: normalize, generate waveform, auto-segment."""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session
    from app.models.audio import AudioFile, AudioSegment, AudioStatus
    from app.services.audio_processor import (
        normalize_audio, generate_waveform_peaks,
        get_audio_duration_ms, auto_segment,
    )

    engine = create_engine(settings.sync_database_url)

    try:
        with Session(engine) as db:
            audio = db.query(AudioFile).get(audio_file_id)
            if not audio:
                logger.error(f"Audio file {audio_file_id} not found")
                return {"status": "error", "message": "Audio file not found"}

            audio.status = AudioStatus.PROCESSING
            db.commit()

            source_path = os.path.join(settings.MEDIA_DIR, audio.file_path)

            # 1. Normalize
            normalized_path = os.path.join(
                settings.MEDIA_DIR, "uploads",
                f"normalized_{audio_file_id}.mp3"
            )
            if not normalize_audio(source_path, normalized_path):
                audio.status = AudioStatus.ERROR
                audio.error_message = "Audio normalization failed"
                db.commit()
                return {"status": "error"}

            audio.normalized_path = f"uploads/normalized_{audio_file_id}.mp3"

            # 2. Get duration
            duration = get_audio_duration_ms(normalized_path)
            audio.duration_ms = duration

            # 3. Generate waveform
            peaks = generate_waveform_peaks(normalized_path)
            audio.waveform_peaks = peaks

            # 4. Auto-segment
            segments = auto_segment(normalized_path, duration)

            # Save segments to DB
            for seg_info in segments:
                segment = AudioSegment(
                    audio_file_id=audio.id,
                    segment_index=seg_info["segment_index"],
                    start_ms=seg_info["start_ms"],
                    end_ms=seg_info["end_ms"],
                    duration_ms=seg_info["duration_ms"],
                    is_silence=seg_info["is_silence"],
                )
                db.add(segment)

            audio.status = AudioStatus.SEGMENTED
            audio.processing_metadata = {
                "segment_count": len(segments),
                "duration_ms": duration,
                "peaks_count": len(peaks),
            }
            db.commit()

            logger.info(
                f"Audio processing complete: {len(segments)} segments, "
                f"duration {duration}ms"
            )

        return {"status": "success", "segments": len(segments)}

    except Exception as e:
        logger.error(f"Audio processing failed: {e}")
        with Session(engine) as db:
            audio = db.query(AudioFile).get(audio_file_id)
            if audio:
                audio.status = AudioStatus.ERROR
                audio.error_message = str(e)[:500]
                db.commit()
        self.retry(exc=e)


@celery_app.task(bind=True, max_retries=2, default_retry_delay=15)
def cut_segments_task(self, audio_file_id: int):
    """Cut individual segment files from the source audio."""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session
    from app.models.audio import AudioFile, AudioSegment, AudioStatus
    from app.services.audio_processor import cut_segment_file

    engine = create_engine(settings.sync_database_url)

    try:
        with Session(engine) as db:
            audio = db.query(AudioFile).get(audio_file_id)
            if not audio:
                return {"status": "error", "message": "Not found"}

            source_path = os.path.join(settings.MEDIA_DIR, audio.normalized_path or audio.file_path)
            segments_dir = os.path.join(settings.MEDIA_DIR, "segments")
            os.makedirs(segments_dir, exist_ok=True)

            segments = (
                db.query(AudioSegment)
                .filter(
                    AudioSegment.audio_file_id == audio_file_id,
                    AudioSegment.is_silence == False,
                )
                .order_by(AudioSegment.segment_index)
                .all()
            )

            cut_count = 0
            for seg in segments:
                filename = f"seg_{audio_file_id}_{seg.segment_index:04d}_v{seg.version}.mp3"
                output_path = os.path.join(segments_dir, filename)

                if cut_segment_file(source_path, output_path, seg.start_ms, seg.end_ms):
                    seg.file_path = f"segments/{filename}"
                    cut_count += 1
                else:
                    logger.error(f"Failed to cut segment {seg.segment_index}")

            audio.status = AudioStatus.READY
            db.commit()

            logger.info(f"Cut {cut_count} segments for audio file {audio_file_id}")

        return {"status": "success", "cut_count": cut_count}

    except Exception as e:
        logger.error(f"Segment cutting failed: {e}")
        self.retry(exc=e)
