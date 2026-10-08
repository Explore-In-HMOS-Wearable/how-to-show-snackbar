import {
  DemoData, DismissReason, FeedbackTone, SnackbarAction, SnackbarRequest,
  SnackbarViewState, Workout
} from '../model/FeedbackModels';
import { SnackbarController, CallbackSnackbarObserver } from '../services/SnackbarController';
import { NativeToastService } from '../services/NativeToastService';
import { SnackbarCard } from '../components/SnackbarCard';

@Entry
@Component
struct Index {
  @State private screen: string = 'Home';
  @State private message: string = 'Workout saved';
  @State private nativeDuration: number = 2000;
  @State private customDuration: number = 6000;
  @State private tone: FeedbackTone = FeedbackTone.Success;
  @State private keepVisible: boolean = false;
  @State private feedback: SnackbarViewState = new SnackbarViewState();
  @State private status: string = 'Choose an example';
  @State private workouts: Workout[] = DemoData.workouts();
  @State private online: boolean = false;
  @State private syncing: boolean = false;
  @State private attempts: number = 0;
  @State private syncStatus: string = 'Not synced';
  @State private details: string = '';
  @State private events: string[] = [];
  private controller: SnackbarController = new SnackbarController();
  private toastService: NativeToastService = new NativeToastService();
  private syncTimer: number = -1;
  private toastTimers: number[] = [];
  private pageActive: boolean = true;
  private deleted: Map<string, Workout> = new Map<string, Workout>();

  aboutToAppear(): void {
    const observer = new CallbackSnackbarObserver(
      (state: SnackbarViewState): void => { this.feedback = state; },
      (request: SnackbarRequest): void => { this.handleAction(request); },
      (request: SnackbarRequest, reason: DismissReason): void => {
        this.log(`#${request.id}: ${reason}`);
        if (request.action === SnackbarAction.Undo && reason !== DismissReason.Action) {
          this.deleted.delete(request.context);
        }
      }
    );
    this.controller.subscribe(observer);
  }

  onPageShow(): void { this.pageActive = true; }
  onPageHide(): void { this.pageActive = false; this.cancelPending(); }
  aboutToDisappear(): void {
    this.pageActive = false;
    this.cancelPending();
    this.controller.dispose();
  }

  private cancelPending(): void {
    this.controller.clear();
    this.toastTimers.forEach((id: number) => clearTimeout(id));
    this.toastTimers = [];
    if (this.syncTimer !== -1) {
      clearTimeout(this.syncTimer);
      this.syncTimer = -1;
      this.syncStatus = 'Sync cancelled';
    }
    this.syncing = false;
    this.deleted.clear();
  }

  private navigate(target: string): void {
    this.cancelPending();
    this.screen = target;
    this.status = 'Ready';
  }

  private log(text: string): void {
    this.events = [`${new Date().toLocaleTimeString()} ${text}`].concat(this.events).slice(0, 25);
  }

  private nativeToast(message: string, duration: number): void {
    if (!this.pageActive) { return; }
    // UIContext is acquired at call time, while the page is active.
    const result = this.toastService.show(this.getUIContext().getPromptAction(), message, duration);
    this.status = result.text;
    this.log(`${result.ok ? 'Toast' : 'Error'}: ${result.text}`);
  }

  private nativeSequence(): void {
    this.toastTimers.forEach((id: number) => clearTimeout(id));
    this.toastTimers = [];
    this.nativeToast('Starting workout', 1500);
    // This is app-scheduled feedback, not a native queue/completion callback.
    this.toastTimers.push(setTimeout(() => this.nativeToast('Goal reached', 2000), 4000));
    this.toastTimers.push(setTimeout(() => this.nativeToast('Workout saved', 3000), 8000));
  }

  private enqueue(request: SnackbarRequest): boolean {
    const id = this.controller.enqueue(request);
    if (id < 0) {
      this.status = 'Queue full or message empty';
      this.log(this.status);
      return false;
    }
    this.status = `Snackbar #${id} accepted`;
    this.log(`#${id} queued: ${request.message}`);
    return true;
  }

  private showCustom(): void {
    this.enqueue(new SnackbarRequest(this.message, this.keepVisible ? 0 : this.customDuration,
      this.tone, SnackbarAction.Details, 'custom'));
  }

  private removeWorkout(workout: Workout): void {
    // Only mutate the model when an Undo notification has been accepted.
    if (this.enqueue(new SnackbarRequest(`${workout.title} removed`, 10000,
      FeedbackTone.Warning, SnackbarAction.Undo, workout.id))) {
      this.deleted.set(workout.id, workout);
      this.workouts = this.workouts.filter((item: Workout) => item.id !== workout.id);
    }
  }

  private handleAction(request: SnackbarRequest): void {
    this.log(`#${request.id}: clicked ${request.action}`);
    switch (request.action) {
      case SnackbarAction.Undo:
        const workout = this.deleted.get(request.context);
        if (workout !== undefined) {
          // Restore original order, even if several workouts were removed.
          const restored = this.workouts.concat([workout]);
          this.workouts = DemoData.workouts().filter((item: Workout) =>
          restored.some((saved: Workout) => saved.id === item.id));
          this.deleted.delete(request.context);
          this.status = `${workout.title} restored`;
        }
        break;
      case SnackbarAction.Retry:
        this.startSync();
        break;
      case SnackbarAction.Details:
        this.details = request.context === 'goal'
          ? 'Daily goal: 8,000 steps. Completed: 8,450 steps. This is simulated demo data.'
          : `Message: ${request.message}. Tone: ${request.tone}. This view was opened by the snackbar action.`;
        this.navigate('Details');
        break;
      default: break;
    }
  }

  private startSync(): void {
    if (this.syncing) { return; }
    this.syncing = true;
    this.attempts++;
    this.syncStatus = 'Syncing demo data...';
    // Deliberately simulated; no server or actual connectivity check is used.
    this.syncTimer = setTimeout(() => {
      this.syncTimer = -1;
      this.syncing = false;
      if (!this.pageActive) { return; }
      if (this.online) {
        this.syncStatus = 'Sync completed';
        this.enqueue(new SnackbarRequest('Workout synced', 4000, FeedbackTone.Success));
      } else {
        this.syncStatus = 'Offline: sync failed';
        this.enqueue(new SnackbarRequest('Sync failed. Retry?', 0,
          FeedbackTone.Error, SnackbarAction.Retry, 'sync'));
      }
    }, 1200);
  }

  private queueExamples(): void {
    this.enqueue(new SnackbarRequest('Workout saved', 4000, FeedbackTone.Success));
    this.enqueue(new SnackbarRequest('Battery is low', 4000, FeedbackTone.Warning));
    this.enqueue(new SnackbarRequest('Daily goal reached', 8000,
      FeedbackTone.Info, SnackbarAction.Details, 'goal'));
  }

  @Builder
  private heading(title: string, subtitle: string) {
    Text(title).fontSize(21).fontWeight(FontWeight.Bold)
      .fontColor(Color.White).textAlign(TextAlign.Center)
    Text(subtitle).fontSize(12).fontColor('#B5C3D5').textAlign(TextAlign.Center)
  }

  @Builder
  private menuButton(label: string, target: string) {
    Button(label).width('100%').height(48).fontSize(14)
      .backgroundColor('#253C57').onClick(() => this.navigate(target))
  }

  @Builder
  private home() {
    this.heading('Feedback lab', 'HarmonyOS wearable examples')
    this.menuButton('1. Native toast', 'Toast')
    this.menuButton('2. Custom snackbar', 'Custom')
    this.menuButton('3. Delete + Undo', 'Undo')
    this.menuButton('4. Sync + Retry', 'Retry')
    this.menuButton('5. Queue + Details', 'Queue')
    this.menuButton('6. Event history', 'History')
  }

  @Builder
  private toastScreen() {
    this.heading('Native toast', 'PromptAction.showToast')
    TextInput({ text: this.message, placeholder: 'Enter message' })
      .width('100%').height(48).maxLength(80).fontSize(14)
      .onChange((value: string) => { this.message = value; })
    Text(`Requested: ${this.nativeDuration} ms`).fontColor(Color.White).fontSize(13)
    Slider({ value: this.nativeDuration, min: 1500, max: 3000, step: 500 })
      .width('100%')
      .onChange((value: number) => { this.nativeDuration = value; })
    Button('Show my message').width('100%').height(48).fontSize(14)
      .onClick(() => this.nativeToast(this.message, this.nativeDuration))
    Button('Success example').width('100%').height(44).fontSize(13)
      .onClick(() => this.nativeToast('Workout saved successfully', 2000))
    Button('Error example').width('100%').height(44).fontSize(13)
      .onClick(() => this.nativeToast('Unable to save workout', 3000))
    Button('Empty input check').width('100%').height(44).fontSize(13)
      .onClick(() => this.nativeToast('   ', 2000))
    Button('3-message sequence').width('100%').height(44).fontSize(13)
      .onClick(() => this.nativeSequence())
    Text('Native toast has no action in this demo. Platform controls its appearance and effective duration.')
      .fontSize(12).fontColor('#B5C3D5').textAlign(TextAlign.Center)
  }

  @Builder
  private customScreen() {
    this.heading('Custom snackbar', 'Message, tone, duration and action')
    TextInput({ text: this.message, placeholder: 'Snackbar message' })
      .width('100%').height(48).maxLength(80).fontSize(14)
      .onChange((value: string) => { this.message = value; })
    Button(`Tone: ${this.tone}`).width('100%').height(44).fontSize(13)
      .onClick(() => {
        switch (this.tone) {
          case FeedbackTone.Info: this.tone = FeedbackTone.Success; break;
          case FeedbackTone.Success: this.tone = FeedbackTone.Warning; break;
          case FeedbackTone.Warning: this.tone = FeedbackTone.Error; break;
          default: this.tone = FeedbackTone.Info;
        }
      })
    Text(`${this.customDuration / 1000} seconds`).fontColor(Color.White).fontSize(13)
    Slider({ value: this.customDuration, min: 2000, max: 15000, step: 1000 })
      .width('100%').enabled(!this.keepVisible)
      .onChange((value: number) => { this.customDuration = value; })
    Button(this.keepVisible ? 'Mode: until dismissed' : 'Mode: auto dismiss')
      .width('100%').height(44).fontSize(12)
      .onClick(() => { this.keepVisible = !this.keepVisible; })
    Button('Show + Details action').width('100%').height(48).fontSize(13)
      .onClick(() => this.showCustom())
    Text('Tap Details to open the message details. Pause stops the countdown.')
      .fontSize(12).fontColor('#B5C3D5').textAlign(TextAlign.Center)
  }

  @Builder
  private undoScreen() {
    this.heading('Workout list', 'Delete, then tap Undo within 10 seconds')
    ForEach(this.workouts, (workout: Workout) => {
      Column({ space: 5 }) {
        Text(workout.title).fontColor(Color.White).fontSize(15)
        Text(workout.subtitle).fontColor('#B5C3D5').fontSize(12)
        Button('Delete').width('100%').height(44).fontSize(13)
          .backgroundColor('#793C49').onClick(() => this.removeWorkout(workout))
      }.width('100%').padding(10).backgroundColor('#1C2938').borderRadius(16)
    }, (workout: Workout) => workout.id)
    if (this.workouts.length === 0) {
      Text('No workouts').fontSize(15).fontColor(Color.White)
    }
    Button('Reset workouts').width('100%').height(44).fontSize(13)
      .onClick(() => {
        this.controller.clear();
        this.deleted.clear();
        this.workouts = DemoData.workouts();
        this.status = 'Demo workouts restored';
      })
  }

  @Builder
  private retryScreen() {
    this.heading('Sync + Retry', 'Simulated network operation')
    Text(`Attempts: ${this.attempts}`).fontColor(Color.White).fontSize(14)
    Text(this.syncStatus).fontColor('#B5C3D5').fontSize(14).textAlign(TextAlign.Center)
    Button(this.online ? 'Network: online' : 'Network: offline')
      .width('100%').height(48).fontSize(13)
      .onClick(() => { this.online = !this.online; })
    Button(this.syncing ? 'Syncing...' : 'Start sync')
      .width('100%').height(48).enabled(!this.syncing).fontSize(14)
      .onClick(() => this.startSync())
    Text('First try offline. On the error card, use Go online below, then tap Retry. Retry while offline fails again.')
      .fontColor('#B5C3D5').fontSize(12).textAlign(TextAlign.Center)
  }

  @Builder
  private queueScreen() {
    this.heading('Queue + Details', 'FIFO: one snackbar at a time')
    Text(`${this.feedback.queued} waiting`).fontColor(Color.White).fontSize(14)
    Button('Queue three examples').width('100%').height(48).fontSize(13)
      .onClick(() => this.queueExamples())
    Button('Queue limit example').width('100%').height(48).fontSize(13)
      .onClick(() => {
        for (let i: number = 1; i <= 8; i++) {
          this.enqueue(new SnackbarRequest(`Message ${i}`, 3000, FeedbackTone.Info));
        }
      })
    Button('Clear queue').width('100%').height(44).fontSize(13)
      .onClick(() => this.controller.clear())
    Text('Maximum: 1 visible + 5 waiting. Excess requests are rejected and logged. Each countdown starts when shown.')
      .fontColor('#B5C3D5').fontSize(12).textAlign(TextAlign.Center)
  }

  @Builder
  private historyScreen() {
    this.heading('Event history', 'Last 25 events, newest first')
    if (this.events.length === 0) {
      Text('No events yet').fontColor(Color.White).fontSize(14)
    }
    ForEach(this.events, (event: string) => {
      Text(event).fontColor('#D4DDEA').fontSize(12)
        .width('100%').padding(8).backgroundColor('#1C2938').borderRadius(10)
    }, (event: string, index: number) => `${index}:${event}`)
    Button('Clear history').width('100%').height(44)
      .onClick(() => { this.events = []; })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: 10 }) {
          if (this.screen === 'Home') { this.home() }
          else if (this.screen === 'Toast') { this.toastScreen() }
          else if (this.screen === 'Custom') { this.customScreen() }
          else if (this.screen === 'Undo') { this.undoScreen() }
          else if (this.screen === 'Retry') { this.retryScreen() }
          else if (this.screen === 'Queue') { this.queueScreen() }
          else if (this.screen === 'History') { this.historyScreen() }
          else {
            this.heading('Details', 'Opened from snackbar click')
            Text(this.details).fontColor(Color.White).fontSize(15).textAlign(TextAlign.Center)
          }
          if (this.screen !== 'Home') { this.menuButton('Home', 'Home') }
          Text(this.status).fontColor('#A6B7CA').fontSize(11).textAlign(TextAlign.Center)
        }.width('72%').padding({ top: 36, bottom: 48 })
      }.width('100%').height('100%').scrollBar(BarState.Off)
      // Disable covered content; notification actions remain enabled above it.
      .enabled(!this.feedback.visible)
      if (this.feedback.visible) {
        SnackbarCard({
          state: this.feedback,
          onAction: (id: number): void => this.controller.performAction(id),
          onClose: (id: number): void => this.controller.dismiss(id),
          onPause: (id: number): void => this.controller.togglePause(id)
        })
        if (this.screen === 'Retry' && !this.online) {
          Button('Go online').width('55%').height(40).fontSize(12)
            .backgroundColor('#315077').position({ x: '22.5%', y: '10%' })
            .onClick(() => { this.online = true; this.log('Simulated network online'); })
        }
      }
    }.width('100%').height('100%').backgroundColor('#0D1521')
  }
}