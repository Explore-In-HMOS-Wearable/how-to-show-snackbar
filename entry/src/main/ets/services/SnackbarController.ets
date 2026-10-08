import {
  DismissReason, FeedbackTone, SnackbarAction, SnackbarRequest, SnackbarViewState
} from '../model/FeedbackModels';

// Framework-independent timing/queue logic. The UI subscribes to fresh snapshots.
export interface SnackbarObserver {
  onState(state: SnackbarViewState): void;
  onAction(request: SnackbarRequest): void;
  onDismiss(request: SnackbarRequest, reason: DismissReason): void;
}

// Explicit implementation avoids object literals implementing method signatures.
export class CallbackSnackbarObserver implements SnackbarObserver {
  private stateHandler: (state: SnackbarViewState) => void;
  private actionHandler: (request: SnackbarRequest) => void;
  private dismissHandler: (request: SnackbarRequest, reason: DismissReason) => void;

  constructor(
    stateHandler: (state: SnackbarViewState) => void,
    actionHandler: (request: SnackbarRequest) => void,
    dismissHandler: (request: SnackbarRequest, reason: DismissReason) => void
  ) {
    this.stateHandler = stateHandler;
    this.actionHandler = actionHandler;
    this.dismissHandler = dismissHandler;
  }

  onState(state: SnackbarViewState): void {
    this.stateHandler(state);
  }

  onAction(request: SnackbarRequest): void {
    this.actionHandler(request);
  }

  onDismiss(request: SnackbarRequest, reason: DismissReason): void {
    this.dismissHandler(request, reason);
  }
}

export class SnackbarController {
  private observer: SnackbarObserver | undefined = undefined;
  private active: SnackbarRequest | undefined = undefined;
  private waiting: SnackbarRequest[] = [];
  private nextId: number = 1;
  private timer: number = -1;
  private deadline: number = 0;
  private remaining: number = 0;
  private paused: boolean = false;
  private disposed: boolean = false;

  subscribe(observer: SnackbarObserver): void {
    this.observer = observer;
    this.disposed = false;
    this.publish();
  }

  enqueue(request: SnackbarRequest): number {
    if (this.disposed || request.message.trim().length === 0) {
      return -1;
    }
    // At most one visible and five waiting. Reject without changing caller data.
    if (this.active !== undefined && this.waiting.length >= 5) {
      return -1;
    }
    const copy = new SnackbarRequest(request.message.trim().slice(0, 100),
      this.normalizeDuration(request.durationMs), request.tone, request.action, request.context);
    copy.id = this.nextId++;
    if (this.active === undefined) {
      this.activate(copy);
    } else {
      this.waiting.push(copy);
      this.publish();
    }
    return copy.id;
  }

  private normalizeDuration(value: number): number {
    if (value === 0) { return 0; }
    if (!Number.isFinite(value)) { return 6000; }
    return Math.max(2000, Math.min(15000, Math.round(value)));
  }

  private activate(request: SnackbarRequest): void {
    this.active = request;
    this.remaining = request.durationMs;
    this.paused = false;
    this.deadline = Date.now() + this.remaining;
    if (request.durationMs > 0) {
      this.timer = setInterval(() => this.tick(), 200);
    }
    this.publish();
  }

  private tick(): void {
    if (this.active === undefined || this.paused) { return; }
    this.remaining = Math.max(0, this.deadline - Date.now());
    if (this.remaining === 0) {
      this.finish(DismissReason.Timeout);
    } else {
      this.publish();
    }
  }

  performAction(id: number): void {
    // Snapshot ID protects against a click delivered after the next item appears.
    if (this.active === undefined || this.active.id !== id ||
      this.active.action === SnackbarAction.None) { return; }
    if (!this.paused && this.active.durationMs > 0 && Date.now() >= this.deadline) {
      this.finish(DismissReason.Timeout);
      return;
    }
    this.finish(DismissReason.Action);
  }

  dismiss(id: number): void {
    if (this.active !== undefined && this.active.id === id) {
      this.finish(DismissReason.Close);
    }
  }

  togglePause(id: number): void {
    if (this.active === undefined || this.active.id !== id || this.active.durationMs === 0) {
      return;
    }
    if (!this.paused) {
      this.remaining = Math.max(0, this.deadline - Date.now());
      if (this.remaining === 0) { this.finish(DismissReason.Timeout); return; }
      this.paused = true;
    } else {
      this.paused = false;
      this.deadline = Date.now() + this.remaining;
    }
    this.publish();
  }

  private finish(reason: DismissReason): void {
    const completed = this.active;
    if (completed === undefined) { return; }
    this.stopTimer();
    this.active = undefined;
    this.paused = false;
    // Invalidate the completed item before invoking application callbacks.
    // Promote queued work first so callback-enqueued items preserve FIFO order.
    const next = this.waiting.shift();
    if (next !== undefined) { this.activate(next); } else { this.publish(); }
    if (this.observer !== undefined) {
      this.observer.onDismiss(completed, reason);
      if (reason === DismissReason.Action) { this.observer.onAction(completed); }
    }
  }

  clear(): void {
    this.stopTimer();
    const removed: SnackbarRequest[] = this.waiting.slice();
    if (this.active !== undefined) { removed.unshift(this.active); }
    this.active = undefined;
    this.waiting = [];
    this.paused = false;
    this.publish();
    const observer = this.observer;
    if (observer !== undefined) {
      removed.forEach((item: SnackbarRequest) => observer.onDismiss(item, DismissReason.Cleared));
    }
  }

  dispose(): void {
    this.disposed = true;
    this.clear();
    this.observer = undefined;
  }

  private stopTimer(): void {
    if (this.timer !== -1) { clearInterval(this.timer); this.timer = -1; }
  }

  private publish(): void {
    const state = new SnackbarViewState();
    state.queued = this.waiting.length;
    if (this.active !== undefined) {
      state.visible = true;
      state.id = this.active.id;
      state.message = this.active.message;
      state.tone = this.active.tone;
      state.action = this.active.action;
      state.persistent = this.active.durationMs === 0;
      state.remainingMs = this.remaining;
      state.paused = this.paused;
    }
    if (this.observer !== undefined) { this.observer.onState(state); }
  }
}