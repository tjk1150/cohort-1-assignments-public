import WalletConnect from "@/components/WalletConnect";
import Balances from "@/components/Balances";
import Mint from "@/components/Mint";
import Approve from "@/components/Approve";
import Swap from "@/components/Swap";
import Liquidity from "@/components/Liquidity";

export default function Home() {
  return (
    <div className="max-w-3xl mx-auto w-full p-6 space-y-6">
      <WalletConnect />
      <main className="space-y-6">
        <h1 className="text-2xl font-semibold">MiniAMM DApp</h1>
        <p className="text-sm text-neutral-600">
          RainbowKit 지갑 연결이 설정되었습니다. 이후 민트/승인/스왑/유동성 UI를 추가합니다.
        </p>
        <Balances />
        <Mint />
        <Approve />
        <Swap />
        <Liquidity />
      </main>
    </div>
  );
}
