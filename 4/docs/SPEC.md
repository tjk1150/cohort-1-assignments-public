### Frontend SPEC (MiniAMM DApp)

본 문서는 `FE-Stack-and-Requirements.md`를 바탕으로 실제 구현 전에 합의할 상세 사양입니다. 코드 작성 전에 이 문서의 항목을 하나씩 완료 처리합니다.

---

### 1) 전제 및 스택
- Next.js + React + TypeScript (Ethers v6)
- RainbowKit로 지갑 연결/해제
- TypeChain 생성 타입 사용 경로: `src/types/ethers-contracts`
  - 예: `import { MiniAMM, MockERC20, MiniAMM__factory, MockERC20__factory } from "@/types/ethers-contracts"`
- Netlify 호스팅 (레포에 `netlify.toml` 존재)

---

### 2) 컨트랙트 인터페이스 및 시그니처
- IMiniAMM (`2/src/IMiniAMM.sol`)
  - `function addLiquidity(uint256 xAmountIn, uint256 yAmountIn) external returns (uint256 lpMinted)`
  - `function removeLiquidity(uint256 lpAmount) external returns (uint256 xAmount, uint256 yAmount)`
  - `function swap(uint256 xAmountIn, uint256 yAmountIn) external`
- MockERC20 (`2/src/MockERC20.sol`)
  - 표준 ERC20 + `freeMintTo(uint256 amount, address to)` / `freeMintToSender(uint256 amount)`
- MiniAMM 상태
  - `xReserve()`, `yReserve()`, `k()` 공개 변수 (자동 getter)
  - MiniAMM는 LP 토큰 컨트랙트를 상속(동일 주소). `balanceOf(address)`로 LP 발행량 조회 가능

---

### 3) 구성/설정
- 주소/ABI
  - 주소는 배포 산출물에서 주입: `4/abi/*.json` 또는 환경변수
  - 타입 세이프 연결: `MiniAMM__factory.connect(address, signerOrProvider)`, `MockERC20__factory.connect(address, signerOrProvider)`
- 체인/지갑
  - RainbowKit + Wagmi(Ethers v6 provider) 구성
  - 잘못된 네트워크 시 경고/스위치 유도
- 유닛/정밀도
  - Ethers v6 기본 bigint 사용
  - `decimals()`로 토큰 단위 파악 후 `parseUnits/formatUnits` 헬퍼 사용

---

### 4) 페이지/컴포넌트 구조(제안)
- `src/lib/addresses.ts`: 컨트랙트 주소 상수/로드
- `src/lib/contracts.ts`: 팩토리 기반 인스턴스 생성 헬퍼(typed)
- `src/hooks/useBalances.ts`: 토큰/LP/리저브 조회 훅(signerOrProvider 의존, refetch 포함)
- `src/components/WalletConnect.tsx`: RainbowKit 연결/해제 UI
- `src/components/Mint.tsx`: MockERC20 민트 폼
- `src/components/Approve.tsx`: 두 토큰 approve UI (spender=MiniAMM)
- `src/components/Swap.tsx`: 스왑 폼/견적/실행/상태
- `src/components/Liquidity.tsx`: add/remove 폼/실행/상태
- `src/app/page.tsx`: 위 컴포넌트 배치 및 데이터 갱신 orchestration

---

### 5) 데이터 모델/표시 요건
- 잔액 표시
  - 연결된 지갑의 `tokenX`, `tokenY`, `LP(MiniAMM as ERC20)` 잔액
  - MiniAMM 컨트랙트 보유 `tokenX`, `tokenY` 잔액(= `xReserve`, `yReserve`) 및 k
- 스왑 인터페이스
  - 판매 토큰 선택(X→Y 또는 Y→X)
  - 판매 수량 입력(지갑 잔액/decimals 반영)
  - 예상 수령량 계산(상수곱 공식, 수수료 반영)
  - 실행 버튼 + 대기/완료 후 리프레시

---

### 6) 연산/공식(견적)
- 수수료: 계약 로직 기준 `fee = 0.3%` (997/1000)
- X→Y 견적: `yOut = (xInAfterFee * yRes) / (xRes + xInAfterFee)` where `xInAfterFee = xIn * 997n / 1000n`
- Y→X 견적: `xOut = (yInAfterFee * xRes) / (yRes + yInAfterFee)` where `yInAfterFee = yIn * 997n / 1000n`
- 입력/출력 모두 bigint, 소수처리는 `decimals`로 변환

---

### 7) 기능 플로우
- 지갑 연결/해제
  - RainbowKit 버튼 제공
- 민트(MockERC20)
  - 입력 금액 → `freeMintToSender(amountRaw)` 호출
  - 컨펌 대기 중 버튼 비활성화/로딩 표시 → 컨펌 후 잔액/리저브 갱신
- 승인(Approve)
  - 두 토큰 각각에 대해 `approve(miniAmmAddress, amount)`
  - addLiquidity 전: 두 토큰 모두 충분 승인 필요
  - swap 전: 판매 토큰만 충분 승인 필요
- 스왑(Swap)
  - 방향 선택 후 금액 입력 → 견적 표시
  - `swap(xIn, 0)` 또는 `swap(0, yIn)` 실행(한 방향만 > 0)
  - 컨펌까지 버튼 비활성화/로딩 → 컨펌 후 잔액/리저브 갱신
- 유동성 추가(Add Liquidity)
  - 두 토큰 금액 입력(비율 가이드 표시: `xIn/xRes ≈ yIn/yRes`)
  - `addLiquidity(xIn, yIn)` 실행 → 컨펌 후 잔액/리저브/LP 갱신
- 유동성 제거(Remove Liquidity)
  - 보유 LP 중 일부 입력 → `removeLiquidity(lpAmount)` 실행
  - 컨펌 후 잔액/리저브/LP 갱신

---

### 8) 상태관리/리프레시 규칙
- 트랜잭션 라이프사이클
  - 제출 시: 실행 버튼 비활성화 + 로딩 표시
  - 1확인(또는 N확인) 후: 관련 데이터 일괄 refetch
- refetch 대상
  - `balanceOf(user)` for tokenX, tokenY, LP
  - `xReserve`, `yReserve`, `k`
- 에러 처리
  - 사용자 거절, 잔액/승인 부족, 잘못된 입력(0 또는 음수), 네트워크 불일치

---

### 9) 타입/안전 규칙
- 컨트랙트 상호작용은 반드시 TypeChain 타입 사용(`src/types/ethers-contracts`)
- `bigint` 기반 금액 처리, UI 경계에서만 문자열 변환
- `decimals` 캐시/동시 호출 방지(필요 시 메모이제이션)

---

### 10) 테스트/검증 체크리스트(수동)
- 지갑 연결/해제 동작
- 민트 후 토큰 잔액 증가
- approve 후 allowance 반영
- swap 실행 및 예상치 근사 일치(수수료 고려)
- add/remove 후 리저브/LP 변화 일관성 및 k 증가/변화 검증
- 트랜잭션 대기 중 버튼 비활성/로딩, 컨펌 후 데이터 최신화

---

### 11) 성능/UX 메모
- 입력 디바운스 후 견적 계산
- 버튼 상태: disabled 조건(미연결, 0입력, 잔액부족, 승인부족, pending)
- 네트워크 경고/스위치 유도 메시지

---

### 12) 보안/안전 노트
- 하드코딩 민감정보 금지(주소는 환경/설정으로)
- 실패 시 재시도/명확한 에러 문구
- 승인 금액은 필요한 만큼만(무제한 승인 지양)
