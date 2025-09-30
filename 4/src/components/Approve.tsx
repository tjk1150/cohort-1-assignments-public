"use client";

import { useMemo, useState } from "react";
import { useAccount } from "wagmi";
import { BrowserProvider } from "ethers";
import { MockERC20__factory } from "@/types/ethers-contracts";
import { contracts } from "@/lib/addresses";
import { useBalances } from "@/hooks/useBalances";
import { parseUnits } from "ethers";

export default function Approve() {
  const { status } = useAccount();
  const { refetch } = useBalances();

  const [amountX, setAmountX] = useState<string>("");
  const [amountY, setAmountY] = useState<string>("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | undefined>();

  const canApprove = useMemo(() => {
    const xOk = !!amountX && Number(amountX) > 0;
    const yOk = !!amountY && Number(amountY) > 0;
    return status === "connected" && (xOk || yOk) && !pending;
  }, [status, amountX, amountY, pending]);

  const onApprove = async () => {
    setError(undefined);
    if (status !== "connected") {
      setError("지갑이 연결되지 않았습니다.");
      return;
    }

    if (!amountX && !amountY) {
      setError("승인할 금액을 입력하세요 (X 또는 Y).");
      return;
    }

    try {
      setPending(true);
      const provider = new BrowserProvider((window as any).ethereum);
      const signer = await provider.getSigner();

      // Approve Token X
      if (amountX && Number(amountX) > 0) {
        const tokenX = MockERC20__factory.connect(contracts.tokenX, signer);
        const dx = await tokenX.decimals();
        const rawX = parseUnits(amountX, dx);
        const txX = await tokenX.approve(contracts.miniAmm, rawX);
        await txX.wait();
      }

      // Approve Token Y
      if (amountY && Number(amountY) > 0) {
        const tokenY = MockERC20__factory.connect(contracts.tokenY, signer);
        const dy = await tokenY.decimals();
        const rawY = parseUnits(amountY, dy);
        const txY = await tokenY.approve(contracts.miniAmm, rawY);
        await txY.wait();
      }

      await refetch();
      setAmountX("");
      setAmountY("");
    } catch (e: any) {
      setError(e?.message || "승인에 실패했습니다.");
    } finally {
      setPending(false);
    }
  };

  return (
    <section className="border rounded-md p-4 space-y-3">
      <div className="font-semibold">Approve MiniAMM</div>
      {error && <div className="text-sm text-red-600">{error}</div>}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
        <div className="flex items-center gap-2">
          <label className="w-16 text-sm opacity-70">Token X</label>
          <input
            className="border rounded px-2 py-1 text-sm flex-1"
            placeholder="Amount"
            value={amountX}
            onChange={(e) => setAmountX(e.target.value)}
            disabled={pending || status !== "connected"}
            inputMode="decimal"
          />
        </div>
        <div className="flex items-center gap-2">
          <label className="w-16 text-sm opacity-70">Token Y</label>
          <input
            className="border rounded px-2 py-1 text-sm flex-1"
            placeholder="Amount"
            value={amountY}
            onChange={(e) => setAmountY(e.target.value)}
            disabled={pending || status !== "connected"}
            inputMode="decimal"
          />
        </div>
      </div>
      <div className="flex gap-2">
        <button
          className="border px-3 py-1 rounded-md text-sm disabled:opacity-50"
          onClick={onApprove}
          disabled={!canApprove}
        >
          {pending ? "Approving..." : "Approve Both"}
        </button>
      </div>
    </section>
  );
}
