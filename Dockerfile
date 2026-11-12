# Starter image only. Production deployments should pin the base image by digest
# and add the verified registryAIQ Megatron CLI distribution/install step.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ACTION_HOME=/opt/megatron-action

WORKDIR ${ACTION_HOME}
COPY src/ ${ACTION_HOME}/src/
COPY entrypoint.sh ${ACTION_HOME}/entrypoint.sh

RUN chmod 0755 ${ACTION_HOME}/entrypoint.sh \
    && python -m compileall -q ${ACTION_HOME}/src

ENTRYPOINT ["/opt/megatron-action/entrypoint.sh"]
