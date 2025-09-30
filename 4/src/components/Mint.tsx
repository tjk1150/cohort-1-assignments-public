"use client";

import { useState, useMemo } from "react";
import { useAccount } from "wagmi";
import { BrowserProvider } from "ethers";
import { MockERC20__factory } from "@/types/ethers-contracts";
import { contracts } from "@/lib/addresses";
import { useBalances } from "@/hooks/useBalances";
import { parseUnits } from "ethers";

export default function Mint() {
  const { status } = useAccount();
  const { refetch } = useBalances();

  const [which, setWhich] = useState<"X" | "Y">("X");
  const [amount, setAmount] = useState<string>("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | undefined>();

  const canMint = useMemo(() => {
    return status === "connected" && !!amount && Number(amount) > 0 && !pending;
  }, [status, amount, pending]);

  const onMint = async () => {
    setError(undefined);
    if (status !== "connected") {
      setError("지갑이 연결되지 않았습니다.");
      return;
    }
    if (!amount || Number(amount) <= 0) {
      setError("0보다 큰 민트 수량을 입력하세요.");
      return;
    }

    const tokenAddr = which === "X" ? contracts.tokenX : contracts.tokenY;
    if (tokenAddr === "0x0000000000000000000000000000000000000000") {
      setError("토큰 주소가 설정되지 않았습니다.");
      return;
    }

    try {
      setPending(true);
      const provider = new BrowserProvider((window as any).ethereum);
      const signer = await provider.getSigner();
      const token = MockERC20__factory.connect(tokenAddr, signer);

      const decimals = await token.decimals();
      const raw = parseUnits(amount, decimals);
      const tx = await token.freeMintToSender(raw);
      await tx.wait();
      await refetch();
      setAmount("");
    } catch (e: any) {
      setError(e?.message || "민트에 실패했습니다.");
    } finally {
      setPending(false);
    }
  };

  return (
    <section className="border rounded-md p-4 space-y-3">
      <div className="font-semibold">Mint MockERC20</div>
      {error && <div className="text-sm text-red-600">{error}</div>}
      <div className="flex items-center gap-2">
        <select
          className="border rounded px-2 py-1 text-sm"
          value={which}
          onChange={(e) => setWhich(e.target.value as "X" | "Y")}
          disabled={pending || status !== "connected"}
        >
          <option value="X">Token X</option>
          <option value="Y">Token Y</option>
        </select>
        <input
          className="border rounded px-2 py-1 text-sm flex-1"
          placeholder="Amount"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          disabled={pending || status !== "connected"}
          inputMode="decimal"
        />
        <button
          className="border px-3 py-1 rounded-md text-sm disabled:opacity-50"
          onClick={onMint}
          disabled={!canMint}
        >
          {pending ? "Minting..." : "Mint"}
        </button>
      </div>
    </section>
  );
}
