# =============================================================================
# CRC-Template Codex Finder Module
# =============================================================================
# RUN phase: Analyzes source code and crafts POV inputs using Codex.
#
# Uses pre-built ASAN harness from the build phase — no builder sidecar needed.
# =============================================================================

# These ARGs are required by the oss-crs framework template
ARG target_base_image
ARG crs_version

FROM crs-finder-codex-base

# Install libCRS (CLI + Python package)
COPY --from=libcrs . /libCRS
RUN pip3 install /libCRS \
    && python3 -c "from libCRS.base import DataType; print('libCRS OK')"

# Install the Finder package and agents.
COPY pyproject.toml /opt/crs-finder-codex/pyproject.toml
COPY finder.py /opt/crs-finder-codex/finder.py
COPY agents/ /opt/crs-finder-codex/agents/
RUN pip3 install /opt/crs-finder-codex

CMD ["run_finder"]
