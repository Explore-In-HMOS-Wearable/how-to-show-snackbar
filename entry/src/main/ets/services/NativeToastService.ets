import { PromptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

export class NativeToastResult {
  ok: boolean;
  text: string;
  constructor(ok: boolean, text: string) { this.ok = ok; this.text = text; }
}

export class NativeToastService {
  show(prompt: PromptAction, message: string, durationMs: number): NativeToastResult {
    const clean = message.trim();
    if (clean.length === 0) { return new NativeToastResult(false, 'Enter a message first'); }
    if (clean.length > 80) { return new NativeToastResult(false, 'Use at most 80 characters'); }
    if (!Number.isFinite(durationMs)) { return new NativeToastResult(false, 'Invalid duration'); }
    // Conservative demo range, not a guarantee of exact native display timing.
    const duration = Math.max(1500, Math.min(3000, Math.round(durationMs)));
    try {
      prompt.showToast({ message: clean, duration: duration });
      return new NativeToastResult(true, `Requested: ${duration} ms / ${clean}`);
    } catch (error) {
      const detail = error as BusinessError;
      console.error(`showToast: ${detail.code}, ${detail.message}`);
      return new NativeToastResult(false, `Toast failed (${detail.code})`);
    }
  }
}
