# Lessons Recap: the app plus everything a lecture needs — ffmpeg, Whisper, RapidOCR. The
# vendors' programs that write the report with a subscription (Claude Code, Codex, Antigravity
# CLI) are not in it: the setup installs the one chosen (recap/report/program.py). GitHub
# builds the published image on every release (.github/workflows/release.yml).
FROM python:3.12-slim-bookworm

# ffmpeg for audio and frames; libgl1 and libglib2.0-0 for OpenCV, which comes with
# RapidOCR; tzdata for local time (trash dates, logs); curl for the vendors' install scripts.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg libgl1 libglib2.0-0 tzdata curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# The libraries exactly as uv.lock pins them (--locked: a lock out of step with pyproject.toml
# stops the build), into /app/.venv, first in PATH: the "python" of CMD and docker-compose.yml
# is the one that has them. uv is only mounted for this step, not left in the image; pinned to
# its digest, like the release's actions, and to the version that writes uv.lock.
WORKDIR /app
COPY pyproject.toml uv.lock /app/
RUN --mount=from=ghcr.io/astral-sh/uv:0.12.23@sha256:61d393e44e249f2e4b526b6c7ddcecce245946826e608e11c93ad4f5bba55b21,source=/uv,target=/bin/uv \
    UV_PYTHON_DOWNLOADS=never UV_COMPILE_BYTECODE=1 UV_NO_CACHE=1 uv sync --locked --no-dev
ENV PATH=/app/.venv/bin:$PATH
COPY recap /app/recap
# The template the setup starts .env from (recap/setup.py).
COPY .env.example /app/

# The version, for the "new version available" notice (recap/updates.py): the release
# workflow passes the tag's number (1.2.3); a local build is "dev". The image labels
# (source, license) come from the release workflow.
ARG VERSION=dev
RUN echo "${VERSION}" > /app/VERSION

RUN useradd --uid 1000 --create-home app
USER app
# HF_HOME: the models folder: Whisper's weights (downloaded on the first lecture) and the OCR
# sizes other than small (downloaded on first use).
ENV HF_HOME=/models PYTHONUNBUFFERED=1 TZ=Europe/Rome
EXPOSE 8470
CMD ["python", "-m", "recap", "--courses", "/courses", "--listen", "0.0.0.0:8470"]
