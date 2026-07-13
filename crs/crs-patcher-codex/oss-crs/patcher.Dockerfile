# =============================================================================
# CRC-Template Codex Patcher Module
# =============================================================================
# RUN phase: Receives POVs, generates patches using Codex,
# tests them using the snapshot image for incremental rebuilds.
#
# Uses host Docker socket (mounted by framework) to access snapshot images.
# =============================================================================

# These ARGs are required by the oss-crs framework template
ARG target_base_image
ARG crs_version

FROM crs-patcher-codex-base

# Install libCRS (CLI + Python package)
COPY --from=libcrs . /libCRS
RUN pip3 install /libCRS \
    && python3 -c "from libCRS.base import DataType; print('libCRS OK')"

# Install the Patcher package and agents.
COPY pyproject.toml /opt/crs-patcher-codex/pyproject.toml
COPY patcher.py /opt/crs-patcher-codex/patcher.py
COPY agents/ /opt/crs-patcher-codex/agents/
RUN pip3 install /opt/crs-patcher-codex

CMD ["run_patcher"]
