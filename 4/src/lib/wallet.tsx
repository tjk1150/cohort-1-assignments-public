'use client';
import { RainbowKitProvider } from '@rainbow-me/rainbowkit';
import '@rainbow-me/rainbowkit/styles.css';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { PropsWithChildren, useMemo } from 'react';
import { defineChain } from 'viem';
import {
  WagmiProvider,
  cookieStorage,
  createConfig,
  createStorage,
  http,
} from 'wagmi';

const coston2 = defineChain({
  id: 114,
  name: 'Flare Coston2',
  nativeCurrency: { name: 'Coston2 FLR', symbol: 'C2FLR', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://coston2-api.flare.network/ext/C/rpc'] },
    public: { http: ['https://coston2-api.flare.network/ext/C/rpc'] },
  },
  blockExplorers: {
    default: {
      name: 'Coston2 Explorer',
      url: 'https://coston2-explorer.flare.network',
    },
  },
  testnet: true,
});

const queryClient = new QueryClient();

export function WalletProviders({ children }: PropsWithChildren) {
  const config = useMemo(() => {
    return createConfig({
      chains: [coston2],
      transports: {
        [coston2.id]: http('https://coston2-api.flare.network/ext/C/rpc'),
      },
      storage: createStorage({ storage: cookieStorage }),
      ssr: true,
    });
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <WagmiProvider config={config}>
        <RainbowKitProvider>{children}</RainbowKitProvider>
      </WagmiProvider>
    </QueryClientProvider>
  );
}
