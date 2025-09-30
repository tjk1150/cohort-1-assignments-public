export type Contracts = {
  miniAmm: `0x${string}`;
  tokenX: `0x${string}`;
  tokenY: `0x${string}`;
};

// 배포 주소를 여기서 관리합니다. 필요 시 환경변수/JSON 로딩으로 대체 가능
// 주의: Ethers v6는 혼합 대소문자(EIP-55) 체커를 엄격히 검증합니다.
// 체인별 체크섬(EIP-1191)과의 차이를 피하기 위해 모두 소문자로 표기합니다.
export const contracts: Contracts = {
  miniAmm: '0xead53d72c8964911f0036f4ae46a9542145588c7',
  tokenX: '0x63f76fcb27cfa1e675e9a14bc8ab778ac0515536',
  tokenY: '0xfdf91c00f3df313914ae9bc27085289da955a737',
};
