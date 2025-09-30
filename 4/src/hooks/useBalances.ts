"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useAccount } from "wagmi";
import { BrowserProvider, ContractRunner } from "ethers";
import { MiniAMM__factory, MockERC20__factory } from "@/types/ethers-contracts";
import { contracts } from "@/lib/addresses";

export type BalancesState = {
  loading: boolean;
  error?: string;
  tokenXDecimals: number | null;
  tokenYDecimals: number | null;
  xReserve: bigint | null;
  yReserve: bigint | null;
  k: bigint | null;
  tokenXWallet: bigint | null;
  tokenYWallet: bigint | null;
  tokenXInMiniAmm: bigint | null;
  tokenYInMiniAmm: bigint | null;
  tokenXAllowance: bigint | null;
  tokenYAllowance: bigint | null;
};

const ZERO_ADDR = "0x0000000000000000000000000000000000000000" as const;

export function useBalances() {
  const { address, status } = useAccount();
  const [state, setState] = useState<BalancesState>({
    loading: false,
    tokenXDecimals: null,
    tokenYDecimals: null,
    xReserve: null,
    yReserve: null,
    k: null,
    tokenXWallet: null,
    tokenYWallet: null,
    tokenXInMiniAmm: null,
    tokenYInMiniAmm: null,
    tokenXAllowance: null,
    tokenYAllowance: null,
  });

  const isReady = useMemo(() => {
    return (
      typeof window !== "undefined" &&
      status === "connected" &&
      !!address &&
      contracts.miniAmm !== ZERO_ADDR &&
      contracts.tokenX !== ZERO_ADDR &&
      contracts.tokenY !== ZERO_ADDR
    );
  }, [status, address]);

  const readAll = useCallback(async () => {
    if (!isReady) return;

    setState((s) => ({ ...s, loading: true, error: undefined }));
    try {
      const provider = new BrowserProvider((window as any).ethereum);
      const runner: ContractRunner = provider; // read-only

      const mini = MiniAMM__factory.connect(contracts.miniAmm, runner);
      const tokenX = MockERC20__factory.connect(contracts.tokenX, runner);
      const tokenY = MockERC20__factory.connect(contracts.tokenY, runner);

      const [xRes, yRes, kVal, xDec, yDec, xBalUser, yBalUser, xBalAmm, yBalAmm, xAllow, yAllow] = await Promise.all([
        mini.xReserve(),
        mini.yReserve(),
        mini.k(),
        tokenX.decimals(),
        tokenY.decimals(),
        address ? tokenX.balanceOf(address) : Promise.resolve(0n),
        address ? tokenY.balanceOf(address) : Promise.resolve(0n),
        tokenX.balanceOf(contracts.miniAmm),
        tokenY.balanceOf(contracts.miniAmm),
        address ? tokenX.allowance(address, contracts.miniAmm) : Promise.resolve(0n),
        address ? tokenY.allowance(address, contracts.miniAmm) : Promise.resolve(0n),
      ]);

      setState({
        loading: false,
        tokenXDecimals: Number(xDec),
        tokenYDecimals: Number(yDec),
        xReserve: xRes,
        yReserve: yRes,
        k: kVal,
        tokenXWallet: xBalUser,
        tokenYWallet: yBalUser,
        tokenXInMiniAmm: xBalAmm,
        tokenYInMiniAmm: yBalAmm,
        tokenXAllowance: xAllow,
        tokenYAllowance: yAllow,
      });
    } catch (e: any) {
      setState((s) => ({ ...s, loading: false, error: e?.message || "Failed to load balances" }));
    }
  }, [isReady, address]);

  useEffect(() => {
    if (!isReady) return;
    readAll();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isReady, address]);

  return {
    ...state,
    refetch: readAll,
    connected: status === "connected",
    address,
  };
}
