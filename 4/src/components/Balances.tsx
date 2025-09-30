"use client";

import { useBalances } from "@/hooks/useBalances";
import { formatUnits } from "ethers";

function formatAmount(value: bigint | null, decimals: number | null) {
  if (value === null || decimals === null) return "-";
  try {
    return formatUnits(value, decimals);
  } catch {
    return value.toString();
  }
}

export default function Balances() {
  const b = useBalances();

  return (
    <section className="border rounded-md p-4 space-y-2">
      <div className="font-semibold">Balances / Reserves</div>
      {b.error && (
        <div className="text-red-600 text-sm">{b.error}</div>
      )}
      <div className="grid grid-cols-2 gap-2 text-sm">
        <div className="opacity-70">xReserve</div>
        <div>{b.xReserve?.toString() ?? "-"}</div>
        <div className="opacity-70">yReserve</div>
        <div>{b.yReserve?.toString() ?? "-"}</div>
        <div className="opacity-70">k</div>
        <div>{b.k?.toString() ?? "-"}</div>
        <div className="opacity-70">tokenX (wallet)</div>
        <div>{formatAmount(b.tokenXWallet, b.tokenXDecimals)}</div>
        <div className="opacity-70">tokenY (wallet)</div>
        <div>{formatAmount(b.tokenYWallet, b.tokenYDecimals)}</div>
        <div className="opacity-70">tokenX (MiniAMM)</div>
        <div>{formatAmount(b.tokenXInMiniAmm, b.tokenXDecimals)}</div>
        <div className="opacity-70">tokenY (MiniAMM)</div>
        <div>{formatAmount(b.tokenYInMiniAmm, b.tokenYDecimals)}</div>
        <div className="opacity-70">allowance X → MiniAMM</div>
        <div>{b.tokenXAllowance ? formatAmount(b.tokenXAllowance, b.tokenXDecimals) : "-"}</div>
        <div className="opacity-70">allowance Y → MiniAMM</div>
        <div>{b.tokenYAllowance ? formatAmount(b.tokenYAllowance, b.tokenYDecimals) : "-"}</div>
      </div>
      <button
        className="border px-3 py-1 rounded-md text-sm"
        disabled={b.loading}
        onClick={b.refetch}
      >
        {b.loading ? "Loading..." : "Refresh"}
      </button>
    </section>
  );
}
