"use client";

import { useMemo, useState } from "react";
import { useAccount } from "wagmi";
import { BrowserProvider } from "ethers";
import { MiniAMM__factory } from "@/types/ethers-contracts";
import { contracts } from "@/lib/addresses";
import { useBalances } from "@/hooks/useBalances";
import { parseUnits, formatUnits } from "ethers";

const FEE_MUL = 997n;
const FEE_DEN = 1000n;

export default function Swap() {
  const { status } = useAccount();
  const b = useBalances();

  const [dir, setDir] = useState<"XtoY" | "YtoX">("XtoY");
  const [sellAmount, setSellAmount] = useState<string>("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | undefined>();

  const estimate = useMemo(() => {
    try {
      if (!sellAmount) return "-";
      if (b.xReserve === null || b.yReserve === null) return "-";
      if (b.tokenXDecimals === null || b.tokenYDecimals === null) return "-";

      if (dir === "XtoY") {
        const xInRaw = parseUnits(sellAmount, b.tokenXDecimals);
        const xInAfter = (xInRaw * FEE_MUL) / FEE_DEN;
        const yOut = (xInAfter * b.yReserve) / (b.xReserve + xInAfter);
        return formatUnits(yOut, b.tokenYDecimals);
      } else {
        const yInRaw = parseUnits(sellAmount, b.tokenYDecimals);
        const yInAfter = (yInRaw * FEE_MUL) / FEE_DEN;
        const xOut = (yInAfter * b.xReserve) / (b.yReserve + yInAfter);
        return formatUnits(xOut, b.tokenXDecimals);
      }
    } catch {
      return "-";
    }
  }, [sellAmount, dir, b.xReserve, b.yReserve, b.tokenXDecimals, b.tokenYDecimals]);

  const canSwap = useMemo(() => {
    return status === "connected" && !!sellAmount && Number(sellAmount) > 0 && !pending;
  }, [status, sellAmount, pending]);

  const onSwap = async () => {
    setError(undefined);
    if (status !== "connected") {
      setError("지갑이 연결되지 않았습니다.");
      return;
    }
    if (!sellAmount || Number(sellAmount) <= 0) {
      setError("0보다 큰 판매 수량을 입력하세요.");
      return;
    }
    if (
      b.tokenXDecimals === null ||
      b.tokenYDecimals === null ||
      b.xReserve === null ||
      b.yReserve === null
    ) {
      setError("풀 상태를 불러오는 중입니다. 잠시 후 다시 시도하세요.");
      return;
    }

    try {
      setPending(true);
      const provider = new BrowserProvider((window as any).ethereum);
      const signer = await provider.getSigner();
      const mini = MiniAMM__factory.connect(contracts.miniAmm, signer);

      if (dir === "XtoY") {
        const xInRaw = parseUnits(sellAmount, b.tokenXDecimals);
        const tx = await mini.swap(xInRaw, 0n);
        await tx.wait();
      } else {
        const yInRaw = parseUnits(sellAmount, b.tokenYDecimals);
        const tx = await mini.swap(0n, yInRaw);
        await tx.wait();
      }

      await b.refetch();
      setSellAmount("");
    } catch (e: any) {
      setError(e?.message || "스왑에 실패했습니다.");
    } finally {
      setPending(false);
    }
  };

  return (
    <section className="border rounded-md p-4 space-y-3">
      <div className="font-semibold">Swap</div>
      {error && <div className="text-sm text-red-600">{error}</div>}
      <div className="flex flex-col sm:flex-row gap-2 items-start sm:items-center">
        <select
          className="border rounded px-2 py-1 text-sm"
          value={dir}
          onChange={(e) => setDir(e.target.value as any)}
          disabled={pending || status !== "connected"}
        >
          <option value="XtoY">Sell X → Buy Y</option>
          <option value="YtoX">Sell Y → Buy X</option>
        </select>
        <input
          className="border rounded px-2 py-1 text-sm flex-1"
          placeholder="Amount to sell"
          value={sellAmount}
          onChange={(e) => setSellAmount(e.target.value)}
          disabled={pending || status !== "connected"}
          inputMode="decimal"
        />
        <button
          className="border px-3 py-1 rounded-md text-sm disabled:opacity-50"
          onClick={onSwap}
          disabled={!canSwap}
        >
          {pending ? "Swapping..." : "Swap"}
        </button>
      </div>
      <div className="text-sm opacity-80">
        예상 수령량: <span className="font-mono">{estimate}</span>
      </div>
    </section>
  );
}
