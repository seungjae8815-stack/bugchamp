# Bug Champ 권위 서버 — Cloud Run 용 이미지.
# 워크스페이스 루트에서 빌드해야 core_* 패키지가 포함된다:
#   docker build -f packages/server/Dockerfile -t bugchamp-server .
FROM dart:3.9 AS build

WORKDIR /app

# 워크스페이스 전체를 넣어야 path 의존(core_models 등)이 해결된다.
COPY pubspec.yaml pubspec.lock ./
COPY packages/ ./packages/

RUN dart pub get
RUN dart compile exe packages/server/bin/server.dart -o /app/bin/server

# 런타임은 최소 이미지 — 컴파일된 실행파일만 담는다.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

# 밸런스 JSON — 앱과 **같은 파일**을 서버도 읽는다(§6: JSON 이 유일한 원본).
COPY --from=build /app/packages/app/assets/data /app/game_data
ENV GAME_DATA_DIR=/app/game_data

EXPOSE 8080
CMD ["/app/bin/server"]
