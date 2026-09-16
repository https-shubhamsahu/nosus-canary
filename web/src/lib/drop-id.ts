import { isHex, type Hex } from "viem";

export function isDropId(value: string): value is Hex {
  return isHex(value) && /^0x[0-9a-fA-F]{64}$/.test(value);
}
