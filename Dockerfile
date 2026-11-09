
# Use fix Node-red docker release
FROM nodered/node-red:5.0

# Switch to root user
USER root

# Set environment variables
ENV DKNR_USERNAME=admin \
      DKNR_PASSWORD=admin \
      DKNR_SECRET=dkmatter \
      DKNR_REPOSITORY=https://github.com/dknr-domotic/dknr-matter \
      NODE_RED_ENABLE_PROJECTS=true \
      TZ=Europe/Paris

# Image label
LABEL org.opencontainers.image.authors="Jean-Christian Paul Denis" \
      org.opencontainers.image.source="https://github.com/dknr-domotic/dknr-matter" \
      org.opencontainers.image.title="DKNR Matter" \
      org.opencontainers.image.description="DKNR MQTT entities as Matter devices (Matter bridge) with web UI" \
      org.opencontainers.image.licenses="AGPL-3.0"

# Set system timezone
RUN echo "$TZ" > /etc/timezone

# Prepare Node-Red structure
RUN mkdir -p /data/projects/dknr-matter

# Clone repository
RUN git clone ${DKNR_REPOSITORY} /data/projects/dknr-matter

# Fix ownership
RUN chown -R node-red:node-red /data

# Switch to node-red user
USER node-red

# Set working diretory for container starting script
WORKDIR /data

# Add container starting script
ADD docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
