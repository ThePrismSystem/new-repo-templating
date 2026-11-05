# A static page served by BusyBox httpd, as a starting point. Whatever image
# replaces it keeps the three rules this one follows: a base image pinned by
# digest, a non-root user and a health check.
FROM busybox:1.38.0-musl@sha256:80e38f9a1b39188b8bdb28879178edb322a4402b081a9aedda1924609decd6f6

RUN adduser -D -H -u 10001 app

COPY --chown=app:app site/ /srv/

USER app
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD ["wget", "-q", "--spider", "http://127.0.0.1:8080/"]

CMD ["httpd", "-f", "-v", "-p", "8080", "-h", "/srv"]
