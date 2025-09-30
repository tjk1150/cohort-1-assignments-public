import { getPublicClient, getWalletClient } from "wagmi/actions";
import { http } from "wagmi";
import { sepolia, localhost } from "wagmi/chains";
import { contracts } from "@/lib/addresses";
import { MiniAMM__factory, MockERC20__factory, MiniAMM, MockERC20 } from "@/types/ethers-contracts";
import { Address } from "viem";

export async function getSigner() {
  const wallet = await getWalletClient();
  if (!wallet) return null;
  return wallet;
}

export function getProvider() {
  // wagmi가 관리하는 현재 체인의 public client를 활용
  const client = getPublicClient();
  return client?.transport?.url ? http(client.transport.url) : http();
}

export async function getMiniAmmContract(): Promise<MiniAMM | null> {
  const signer = await getSigner();
  if (!signer) return null;
  return MiniAMM__factory.connect(contracts.miniAmm as Address, signer as any);
}

export async function getTokenX(): Promise<MockERC20 | null> {
  const signer = await getSigner();
  if (!signer) return null;
  return MockERC20__factory.connect(contracts.tokenX as Address, signer as any);
}

export async function getTokenY(): Promise<MockERC20 | null> {
  const signer = await getSigner();
  if (!signer) return null;
  return MockERC20__factory.connect(contracts.tokenY as Address, signer as any);
}
