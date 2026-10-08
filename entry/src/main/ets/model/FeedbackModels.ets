export enum FeedbackTone {
  Info = 'Info',
  Success = 'Success',
  Warning = 'Warning',
  Error = 'Error'
}

export enum SnackbarAction {
  None = 'None',
  Undo = 'Undo',
  Retry = 'Retry',
  Details = 'Details'
}

export enum DismissReason {
  Timeout = 'timeout',
  Action = 'action',
  Close = 'close',
  Cleared = 'cleared'
}

export class SnackbarRequest {
  id: number = 0;
  message: string;
  durationMs: number;
  tone: FeedbackTone;
  action: SnackbarAction;
  context: string;

  constructor(message: string, durationMs: number = 6000,
    tone: FeedbackTone = FeedbackTone.Info,
    action: SnackbarAction = SnackbarAction.None, context: string = '') {
    this.message = message;
    this.durationMs = durationMs;
    this.tone = tone;
    this.action = action;
    this.context = context;
  }
}

export class SnackbarViewState {
  visible: boolean = false;
  id: number = 0;
  message: string = '';
  tone: FeedbackTone = FeedbackTone.Info;
  action: SnackbarAction = SnackbarAction.None;
  remainingMs: number = 0;
  persistent: boolean = false;
  paused: boolean = false;
  queued: number = 0;
}

export class Workout {
  id: string;
  title: string;
  subtitle: string;
  constructor(id: string, title: string, subtitle: string) {
    this.id = id;
    this.title = title;
    this.subtitle = subtitle;
  }
}

export class DemoData {
  static workouts(): Workout[] {
    return [
      new Workout('walk', 'Morning walk', '28 min / 2.4 km'),
      new Workout('run', 'Evening run', '35 min / 5.0 km'),
      new Workout('cycle', 'City ride', '42 min / 9.2 km')
    ];
  }
}

export class FeedbackColors {
  static accent(tone: FeedbackTone): string {
    switch (tone) {
      case FeedbackTone.Success: return '#9DE8BE';
      case FeedbackTone.Warning: return '#FFD58A';
      case FeedbackTone.Error: return '#FFAEAE';
      default: return '#A4CCFF';
    }
  }
}
