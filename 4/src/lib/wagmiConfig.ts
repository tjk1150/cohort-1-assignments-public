import { defineChain } from "viem";
import { WagmiProvider, cookieStorage, createConfig, createStorage, http } from "wagmi";

export const coston2 = defineChain({
  id: 114,
  name: "Flare Coston2",
  nativeCurrency: { name: "Coston2 FLR", symbol: "C2FLR", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://coston2-api.flare.network/ext/C/rpc"] },
    public: { http: ["https://coston2-api.flare.network/ext/C/rpc"] },
  },
  blockExplorers: {
    default: { name: "Coston2 Explorer", url: "https://coston2-explorer.flare.network" },
  },
  testnet: true,
});

export const config = createConfig({
  chains: [coston2],
  transports: {
    [coston2.id]: http("https://coston2-api.flare.network/ext/C/rpc"),
  },
  storage: createStorage({ storage: cookieStorage }),
  ssr: true,
});
