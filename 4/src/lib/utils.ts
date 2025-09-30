import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"
import type { Eip1193Provider } from "ethers"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function getInjectedProvider(): Eip1193Provider {
  const w = window as unknown as { ethereum?: unknown }
  if (!w.ethereum) throw new Error("No injected provider (window.ethereum)")
  return w.ethereum as Eip1193Provider
}
