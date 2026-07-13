# =============================================================================
# crs-bug-finding-codex Finder Module
# =============================================================================
# RUN phase: Analyzes source code and crafts POV inputs using Codex.
#
# Uses pre-built ASAN harness from the build phase — no builder sidecar needed.
# =============================================================================

# These ARGs are required by the oss-crs framework template
ARG target_base_image
ARG crs_version

FROM codex-bug-finding-base

# Install libCRS (CLI + Python package)
COPY --from=libcrs . /libCRS
RUN pip3 install /libCRS \
    && python3 -c "from libCRS.base import DataType; print('libCRS OK')"

# Install crs-bug-finding-codex package (finder + agents)
COPY pyproject.toml /opt/crs-bug-finding-codex/pyproject.toml
COPY finder.py /opt/crs-bug-finding-codex/finder.py
COPY agents/ /opt/crs-bug-finding-codex/agents/
RUN pip3 install /opt/crs-bug-finding-codex

CMD ["run_finder"]
