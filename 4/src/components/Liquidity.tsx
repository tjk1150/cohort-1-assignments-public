"use client";

import { useMemo, useState } from "react";
import { useAccount } from "wagmi";
import { BrowserProvider } from "ethers";
import { MiniAMM__factory } from "@/types/ethers-contracts";
import { contracts } from "@/lib/addresses";
import { useBalances } from "@/hooks/useBalances";
import { parseUnits } from "ethers";

export default function Liquidity() {
  const { status } = useAccount();
  const b = useBalances();

  const [xIn, setXIn] = useState("");
  const [yIn, setYIn] = useState("");
  const [lpBurn, setLpBurn] = useState("");
  const [pendingAdd, setPendingAdd] = useState(false);
  const [pendingRemove, setPendingRemove] = useState(false);
  const [errorAdd, setErrorAdd] = useState<string | undefined>();
  const [errorRemove, setErrorRemove] = useState<string | undefined>();

  const canAdd = useMemo(() => {
    const ok = !!xIn && !!yIn && Number(xIn) > 0 && Number(yIn) > 0;
    return status === "connected" && ok && !pendingAdd && b.tokenXDecimals !== null && b.tokenYDecimals !== null;
  }, [status, xIn, yIn, pendingAdd, b.tokenXDecimals, b.tokenYDecimals]);

  const canRemove = useMemo(() => {
    return status === "connected" && !!lpBurn && Number(lpBurn) > 0 && !pendingRemove;
  }, [status, lpBurn, pendingRemove]);

  const onAdd = async () => {
    setErrorAdd(undefined);
    if (status !== "connected") {
      setErrorAdd("지갑이 연결되지 않았습니다.");
      return;
    }
    if (!xIn || !yIn || Number(xIn) <= 0 || Number(yIn) <= 0) {
      setErrorAdd("두 토큰의 수량을 모두 입력하세요.");
      return;
    }
    if (b.tokenXDecimals === null || b.tokenYDecimals === null) {
      setErrorAdd("토큰 정보를 불러오는 중입니다.");
      return;
    }

    try {
      setPendingAdd(true);
      const provider = new BrowserProvider((window as any).ethereum);
      const signer = await provider.getSigner();
      const mini = MiniAMM__factory.connect(contracts.miniAmm, signer);

      const xRaw = parseUnits(xIn, b.tokenXDecimals);
      const yRaw = parseUnits(yIn, b.tokenYDecimals);
      const tx = await mini.addLiquidity(xRaw, yRaw);
      await tx.wait();
      await b.refetch();
      setXIn("");
      setYIn("");
    } catch (e: any) {
      setErrorAdd(e?.message || "유동성 추가에 실패했습니다.");
    } finally {
      setPendingAdd(false);
    }
  };

  const onRemove = async () => {
    setErrorRemove(undefined);
    if (status !== "connected") {
      setErrorRemove("지갑이 연결되지 않았습니다.");
      return;
    }
    if (!lpBurn || Number(lpBurn) <= 0) {
      setErrorRemove("제거할 LP 수량을 입력하세요.");
      return;
    }

    try {
      setPendingRemove(true);
      const provider = new BrowserProvider((window as any).ethereum);
      const signer = await provider.getSigner();
      const mini = MiniAMM__factory.connect(contracts.miniAmm, signer);

      const lpDecimals = await mini.decimals();
      const lpRaw = parseUnits(lpBurn, lpDecimals);
      const tx = await mini.removeLiquidity(lpRaw);
      await tx.wait();
      await b.refetch();
      setLpBurn("");
    } catch (e: any) {
      setErrorRemove(e?.message || "유동성 제거에 실패했습니다.");
    } finally {
      setPendingRemove(false);
    }
  };

  return (
    <section className="border rounded-md p-4 space-y-4">
      <div className="font-semibold">Liquidity</div>

      <div className="space-y-2">
        <div className="font-medium text-sm">Add Liquidity</div>
        {errorAdd && <div className="text-sm text-red-600">{errorAdd}</div>}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
          <input
            className="border rounded px-2 py-1 text-sm"
            placeholder="Token X amount"
            value={xIn}
            onChange={(e) => setXIn(e.target.value)}
            disabled={pendingAdd || status !== "connected"}
            inputMode="decimal"
          />
          <input
            className="border rounded px-2 py-1 text-sm"
            placeholder="Token Y amount"
            value={yIn}
            onChange={(e) => setYIn(e.target.value)}
            disabled={pendingAdd || status !== "connected"}
            inputMode="decimal"
          />
        </div>
        <button
          className="border px-3 py-1 rounded-md text-sm disabled:opacity-50"
          onClick={onAdd}
          disabled={!canAdd}
        >
          {pendingAdd ? "Adding..." : "Add Liquidity"}
        </button>
      </div>

      <hr className="opacity-20" />

      <div className="space-y-2">
        <div className="font-medium text-sm">Remove Liquidity</div>
        {errorRemove && <div className="text-sm text-red-600">{errorRemove}</div>}
        <div className="flex items-center gap-2">
          <input
            className="border rounded px-2 py-1 text-sm flex-1"
            placeholder="LP amount"
            value={lpBurn}
            onChange={(e) => setLpBurn(e.target.value)}
            disabled={pendingRemove || status !== "connected"}
            inputMode="decimal"
          />
          <button
            className="border px-3 py-1 rounded-md text-sm disabled:opacity-50"
            onClick={onRemove}
            disabled={!canRemove}
          >
            {pendingRemove ? "Removing..." : "Remove"}
          </button>
        </div>
      </div>
    </section>
  );
}
