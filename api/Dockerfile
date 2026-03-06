# --- Build stage ---
FROM dart:3.3 AS build

WORKDIR /app
COPY pubspec.yaml .
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# --- Runtime stage ---
FROM dart:3.3-slim

RUN groupadd -r appuser && useradd -r -g appuser appuser
WORKDIR /app

COPY --from=build /app/bin/server /app/bin/server

USER appuser

EXPOSE 8080
ENV PORT=8080

CMD ["/app/bin/server"]
