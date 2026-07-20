# Bug Champ 권위 서버 — Cloud Run 용 이미지.
#
# ⚠️ **이 파일이 리포지토리 루트에 있어야 한다.**
# `gcloud run deploy --source .` 는 소스 루트의 Dockerfile 만 인식하고,
# 없으면 Buildpack 으로 넘어가 워크스페이스 전체(=Flutter 앱 포함)를
# 해석하려다 실패한다. 실제로 그렇게 한 번 실패했다.
#
# 배포:
#   gcloud run deploy bugchamp-server --source . --region asia-northeast3
#
# 워크스페이스에는 packages/app(Flutter)이 들어 있는데 Dart 전용 이미지에는
# Flutter SDK 가 없어 `dart pub get` 이 실패한다. 그래서 **서버가 실제로
# 필요로 하는 순수 패키지만** 복사하고, 워크스페이스 정의도 그에 맞춰
# 이미지 안에서 새로 쓴다. 앱의 밸런스 JSON 은 코드가 아니라 데이터이므로
# pub 해석 없이 파일만 가져온다.
FROM dart:3.11 AS build

WORKDIR /app

# 서버가 의존하는 순수 Dart 패키지만.
COPY packages/core_models/ ./packages/core_models/
COPY packages/core_run/    ./packages/core_run/
COPY packages/core_battle/ ./packages/core_battle/
COPY packages/core_save/   ./packages/core_save/
COPY packages/server/      ./packages/server/

# Flutter 멤버(app)를 뺀 워크스페이스 정의.
RUN printf '%s\n' \
    'name: bugchamp_server_workspace' \
    'publish_to: none' \
    'version: 0.1.0' \
    'environment:' \
    '  sdk: ^3.11.5' \
    'workspace:' \
    '  - packages/core_models' \
    '  - packages/core_battle' \
    '  - packages/core_run' \
    '  - packages/core_save' \
    '  - packages/server' \
    > pubspec.yaml

RUN dart pub get
# 출력 디렉터리를 미리 만든다 — compile 이 경로를 생성해 주지 않는다.
RUN mkdir -p /app/bin \
 && dart compile exe packages/server/bin/server.dart -o /app/bin/server

# 밸런스 JSON — 앱과 **같은 파일**이 유일한 원본이다(§6).
COPY packages/app/assets/data/ /app/game_data/

# 런타임은 최소 이미지 — 컴파일된 실행파일 + 데이터만.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/game_data/ /app/game_data/

ENV GAME_DATA_DIR=/app/game_data
EXPOSE 8080
CMD ["/app/bin/server"]
