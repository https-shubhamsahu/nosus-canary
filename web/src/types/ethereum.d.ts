interface Window {
  ethereum?: {
    request: (request: { method: string; params?: unknown[] }) => Promise<unknown>;
  };
}
