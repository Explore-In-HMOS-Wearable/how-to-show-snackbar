import { FeedbackColors, SnackbarAction, SnackbarViewState } from '../model/FeedbackModels';

@Component
export struct SnackbarCard {
  @Prop state: SnackbarViewState = new SnackbarViewState();
  onAction: (id: number) => void = (id: number): void => {};
  onClose: (id: number) => void = (id: number): void => {};
  onPause: (id: number) => void = (id: number): void => {};

  build() {
    // A compact, scrollable in-page overlay for constrained watch screens.
    Scroll() {
      Column({ space: 6 }) {
        Text(this.state.tone)
          .fontSize(12)
          .fontColor(FeedbackColors.accent(this.state.tone))
        Text(this.state.message)
          .fontSize(15)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
        if (this.state.action !== SnackbarAction.None) {
          Button(this.state.action)
            .width('100%').height(44).fontSize(15)
            .fontColor('#102019')
            .backgroundColor(FeedbackColors.accent(this.state.tone))
            .onClick(() => this.onAction(this.state.id))
        }
        if (!this.state.persistent) {
          Button(this.state.paused ? 'Resume timer' : `Pause (${Math.ceil(this.state.remainingMs / 1000)}s)`)
            .width('100%').height(44).fontSize(12)
            .backgroundColor('#354352')
            .onClick(() => this.onPause(this.state.id))
        }
        Button('Dismiss')
          .width('100%').height(44).fontSize(12)
          .backgroundColor('#354352')
          .onClick(() => this.onClose(this.state.id))
        if (this.state.queued > 0) {
          Text(`${this.state.queued} waiting`).fontSize(11).fontColor('#C4CDD8')
        }
      }
      .width('100%').padding(12)
    }
    .width('72%').height('66%')
    .backgroundColor('#202D38').borderRadius(22)
    .scrollBar(BarState.Off)
    .margin({ bottom: 28 })
  }
}