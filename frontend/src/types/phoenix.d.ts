declare module 'phoenix' {
  export class Socket {
    constructor(endPoint: string, opts?: object);
    connect(): void;
    disconnect(callback?: () => void, code?: number, reason?: string): void;
    onOpen(callback: () => void): void;
    onClose(callback: (event: CloseEvent) => void): void;
    onError(callback: (error: Event) => void): void;
    channel(topic: string, chanParams?: object): Channel;
  }

  export class Channel {
    join(timeout?: number): Push;
    leave(timeout?: number): Push;
    push(event: string, payload: object, timeout?: number): Push;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    on(event: string, callback: (payload: any) => void): number;
    off(event: string, ref?: number): void;
  }

  export class Push {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    receive(status: string, callback: (response: any) => void): Push;
  }
}
