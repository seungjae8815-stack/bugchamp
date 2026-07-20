# ⚠️ 실제 빌드에 쓰이는 Dockerfile 은 **리포지토리 루트**에 있다.
#
# `gcloud run deploy --source .` 가 소스 루트의 Dockerfile 만 인식하기
# 때문이다. 여기 두면 조용히 Buildpack 으로 넘어가고, Buildpack 은
# 워크스페이스의 Flutter 앱까지 해석하려다 실패한다.
#
# → 루트의 `Dockerfile` 을 수정할 것.
