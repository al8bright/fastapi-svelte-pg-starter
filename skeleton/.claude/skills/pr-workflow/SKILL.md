---
name: pr-workflow
description: __PROJECT_NAME__ 에서 커밋·브랜치·PR을 만들 때 사용. 브랜치 명명, 커밋 메시지 형식([Structural]/[Behavioral]), Structural·Behavioral 분리, gh pr create → squash 머지 흐름을 architecture.md §19·§20 기준으로 안내한다.
---

# 커밋 · 브랜치 · PR

> 변경은 **브랜치 → PR → CI 통과 → 머지** 흐름으로 반영한다. ⛔ `main` 직접 푸시 금지. (architecture.md §20)

## 커밋 메시지 (§19)
- **형식**: `[Category] <type>: <요약(한글, 50자 이내, 현재형)>`
- **Category**: `[Structural]`(구조 변경, 로직 불변) / `[Behavioral]`(기능·버그·로직 변경)
- **type**: `feat` `fix` `refactor` `docs` `style` `test` `chore`
- 예: `[Behavioral] feat: 주문 생성 API 추가`, `[Structural] refactor: 의존성 dependencies.py로 이동`
- ⛔ 모든 테스트 통과 + 린트 경고 0일 때만 커밋.
- **Tidy First**: 구조 변경과 동작 변경을 **한 커밋에 섞지 않는다.**

## 브랜치 명명 (kebab-case)
- `feat/<요약>`, `fix/<요약>`, `refactor/<요약>`, `docs/<요약>`
- 예: `feat/order-create`, `refactor/move-deps`

## PR (§20)
- **제목**: 커밋과 동일 형식 `[Category] <type>: <요약>`.
- **하나의 PR은 Structural·Behavioral 중 하나만** 담는다(섞지 않음).
- **작게 유지** — 리뷰 가능한 크기로 쪼갠다.
- 본문은 `.github/pull_request_template.md` 템플릿 사용. 체크리스트:
  - [ ] 모든 테스트 통과 + 린트 경고 0
  - [ ] Structural/Behavioral 를 섞지 않음
  - [ ] DB 변경 시 Alembic 마이그레이션 포함(§11) → [db-migration]
  - [ ] 설정 변경 시 `.env.example` 갱신(§5·§17)

## gh CLI 흐름 (PowerShell)
```powershell
git switch -c feat/order-create
# ... 작업 + 커밋 ...
git push -u origin feat/order-create
gh pr create --fill --base main
gh pr view --web          # 상태/CI 확인
gh pr merge --squash --delete-branch
```
- `gh`가 없으면: `winget install GitHub.cli` 후 `gh auth login`.
- 원격(remote)이 아직 없으면 먼저 저장소를 연결해야 한다(`git remote add origin <url>`).

## 머지 게이트
- **CI(테스트·린트) 통과**를 머지 조건으로 한다. ⛔ 실패 상태 머지 금지.
- 셀프 머지 허용하되 머지 전 **본인 diff 셀프 리뷰**. 머지 후 브랜치 삭제.
