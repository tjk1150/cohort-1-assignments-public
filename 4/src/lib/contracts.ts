import { contracts } from '@/lib/addresses';
import { config } from '@/lib/wagmiConfig';
import {
  MiniAMM__factory,
  MockERC20__factory,
  type MiniAMM,
  type MockERC20,
} from '@/types/ethers-contracts';
import type { ContractRunner } from 'ethers';
import type { Address } from 'viem';
import { http } from 'wagmi';
import { getPublicClient, getWalletClient } from 'wagmi/actions';

export async function getSigner(): Promise<ContractRunner | null> {
  const wallet = await getWalletClient(config);
  if (!wallet) return null;
  return wallet as unknown as ContractRunner;
}

export function getProvider() {
  // wagmi가 관리하는 현재 체인의 public client를 활용
  const client = getPublicClient(config);
  return client?.transport?.url ? http(client.transport.url) : http();
}

export async function getMiniAmmContract(): Promise<MiniAMM | null> {
  const signer = await getSigner();
  if (!signer) return null;
  return MiniAMM__factory.connect(contracts.miniAmm as Address, signer);
}

export async function getTokenX(): Promise<MockERC20 | null> {
  const signer = await getSigner();
  if (!signer) return null;
  return MockERC20__factory.connect(contracts.tokenX as Address, signer);
}

export async function getTokenY(): Promise<MockERC20 | null> {
  const signer = await getSigner();
  if (!signer) return null;
  return MockERC20__factory.connect(contracts.tokenY as Address, signer);
}
