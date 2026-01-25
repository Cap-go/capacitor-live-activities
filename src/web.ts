import type { PluginListenerHandle } from '@capacitor/core';
import { WebPlugin } from '@capacitor/core';

import type {
  CapgoLiveActivitiesPlugin,
  StartActivityOptions,
  StartActivityResult,
  UpdateActivityOptions,
  EndActivityOptions,
  GetAllActivitiesResult,
  SaveImageOptions,
  SaveImageResult,
  RemoveImageOptions,
  RemoveImageResult,
  ListImagesResult,
  AreActivitiesSupportedResult,
  TimerSequenceOptions,
  TimerSequenceResult,
  TimerSequenceState,
  TimerSequenceCallback,
  GetTimerStateOptions,
} from './definitions';

export class CapgoLiveActivitiesWeb extends WebPlugin implements CapgoLiveActivitiesPlugin {
  private timerSequences: Map<
    string,
    {
      options: TimerSequenceOptions;
      state: TimerSequenceState;
      intervalId: number | null;
      callbacks: TimerSequenceCallback[];
    }
  > = new Map();

  async areActivitiesSupported(): Promise<AreActivitiesSupportedResult> {
    return {
      supported: false,
      reason: 'Live Activities are only available on iOS 16.1+',
    };
  }

  async startActivity(_options: StartActivityOptions): Promise<StartActivityResult> {
    throw this.unavailable('Live Activities are only available on iOS');
  }

  async updateActivity(_options: UpdateActivityOptions): Promise<void> {
    throw this.unavailable('Live Activities are only available on iOS');
  }

  async endActivity(_options: EndActivityOptions): Promise<void> {
    throw this.unavailable('Live Activities are only available on iOS');
  }

  async getAllActivities(): Promise<GetAllActivitiesResult> {
    return { activities: [] };
  }

  async saveImage(_options: SaveImageOptions): Promise<SaveImageResult> {
    throw this.unavailable('Image saving for Live Activities is only available on iOS');
  }

  async removeImage(_options: RemoveImageOptions): Promise<RemoveImageResult> {
    throw this.unavailable('Image management for Live Activities is only available on iOS');
  }

  async listImages(): Promise<ListImagesResult> {
    return { images: [] };
  }

  async cleanupImages(): Promise<void> {
    // No-op on web
  }

  async getPluginVersion(): Promise<{ version: string }> {
    return { version: 'web' };
  }

  // Timer Sequence methods - work on web for testing purposes
  async startTimerSequence(options: TimerSequenceOptions): Promise<TimerSequenceResult> {
    const sequenceId = `web-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    const totalDuration = options.steps.reduce((sum, step) => sum + step.duration, 0);

    const state: TimerSequenceState = {
      sequenceId,
      isRunning: true,
      isPaused: false,
      isComplete: false,
      currentStepIndex: 0,
      totalSteps: options.steps.length,
      currentStep: options.steps[0],
      remainingSeconds: options.steps[0].duration,
      totalRemainingSeconds: totalDuration,
      elapsedSeconds: 0,
      currentLoop: 1,
      totalLoops: options.loopCount ?? 0,
    };

    const sequence = {
      options,
      state,
      intervalId: null as number | null,
      callbacks: [] as TimerSequenceCallback[],
    };

    this.timerSequences.set(sequenceId, sequence);
    this.startTimerInterval(sequenceId);

    console.log(`[Web] Timer sequence started: ${options.title ?? 'Untitled'}`);
    console.log(`[Web] Steps: ${options.steps.map((s) => `${s.title} (${s.duration}s)`).join(' -> ')}`);

    return { sequenceId };
  }

  private startTimerInterval(sequenceId: string): void {
    const sequence = this.timerSequences.get(sequenceId);
    if (!sequence) return;

    sequence.intervalId = window.setInterval(() => {
      this.tickTimer(sequenceId);
    }, 1000);
  }

  private tickTimer(sequenceId: string): void {
    const sequence = this.timerSequences.get(sequenceId);
    if (!sequence || sequence.state.isPaused || sequence.state.isComplete) return;

    const state = sequence.state;
    state.remainingSeconds--;
    state.totalRemainingSeconds--;
    state.elapsedSeconds++;

    // Emit tick event
    this.emitEvent(sequenceId, 'tick');

    // Check if current step is complete
    if (state.remainingSeconds <= 0) {
      // Move to next step
      if (state.currentStepIndex < state.totalSteps - 1) {
        state.currentStepIndex++;
        state.currentStep = sequence.options.steps[state.currentStepIndex];
        state.remainingSeconds = state.currentStep.duration;
        this.emitEvent(sequenceId, 'stepChange');
      } else {
        // End of sequence
        if (
          sequence.options.loop &&
          (sequence.options.loopCount === 0 || state.currentLoop < (sequence.options.loopCount ?? 0))
        ) {
          // Loop back
          state.currentLoop++;
          state.currentStepIndex = 0;
          state.currentStep = sequence.options.steps[0];
          state.remainingSeconds = state.currentStep.duration;
          state.totalRemainingSeconds = sequence.options.steps.reduce((sum, step) => sum + step.duration, 0);
          this.emitEvent(sequenceId, 'loopComplete');
          this.emitEvent(sequenceId, 'stepChange');
        } else {
          // Complete
          state.isComplete = true;
          state.isRunning = false;
          if (sequence.intervalId) {
            clearInterval(sequence.intervalId);
            sequence.intervalId = null;
          }
          this.emitEvent(sequenceId, 'complete');
        }
      }
    }
  }

  private emitEvent(
    sequenceId: string,
    type: 'stepChange' | 'complete' | 'tick' | 'paused' | 'resumed' | 'stopped' | 'loopComplete',
  ): void {
    const sequence = this.timerSequences.get(sequenceId);
    if (!sequence) return;

    const event = {
      type,
      sequenceId,
      state: { ...sequence.state },
    };

    sequence.callbacks.forEach((callback) => callback(event));
    this.notifyListeners('timerSequenceEvent', event);
  }

  async pauseTimerSequence(options: { sequenceId: string }): Promise<void> {
    const sequence = this.timerSequences.get(options.sequenceId);
    if (!sequence) throw new Error('Timer sequence not found');

    sequence.state.isPaused = true;
    this.emitEvent(options.sequenceId, 'paused');
  }

  async resumeTimerSequence(options: { sequenceId: string }): Promise<void> {
    const sequence = this.timerSequences.get(options.sequenceId);
    if (!sequence) throw new Error('Timer sequence not found');

    sequence.state.isPaused = false;
    this.emitEvent(options.sequenceId, 'resumed');
  }

  async stopTimerSequence(options: { sequenceId: string }): Promise<void> {
    const sequence = this.timerSequences.get(options.sequenceId);
    if (!sequence) throw new Error('Timer sequence not found');

    if (sequence.intervalId) {
      clearInterval(sequence.intervalId);
    }

    sequence.state.isRunning = false;
    this.emitEvent(options.sequenceId, 'stopped');
    this.timerSequences.delete(options.sequenceId);
  }

  async skipTimerStep(options: { sequenceId: string }): Promise<void> {
    const sequence = this.timerSequences.get(options.sequenceId);
    if (!sequence) throw new Error('Timer sequence not found');

    const state = sequence.state;
    if (state.currentStepIndex < state.totalSteps - 1) {
      state.totalRemainingSeconds -= state.remainingSeconds;
      state.elapsedSeconds += state.remainingSeconds;
      state.currentStepIndex++;
      state.currentStep = sequence.options.steps[state.currentStepIndex];
      state.remainingSeconds = state.currentStep.duration;
      this.emitEvent(options.sequenceId, 'stepChange');
    }
  }

  async previousTimerStep(options: { sequenceId: string }): Promise<void> {
    const sequence = this.timerSequences.get(options.sequenceId);
    if (!sequence) throw new Error('Timer sequence not found');

    const state = sequence.state;
    if (state.currentStepIndex > 0) {
      state.totalRemainingSeconds += state.currentStep.duration - state.remainingSeconds;
      state.elapsedSeconds -= state.currentStep.duration - state.remainingSeconds;
      state.currentStepIndex--;
      state.currentStep = sequence.options.steps[state.currentStepIndex];
      state.totalRemainingSeconds += state.currentStep.duration;
      state.elapsedSeconds -= state.currentStep.duration;
      state.remainingSeconds = state.currentStep.duration;
      this.emitEvent(options.sequenceId, 'stepChange');
    }
  }

  async getTimerState(options: GetTimerStateOptions): Promise<TimerSequenceState> {
    const sequence = this.timerSequences.get(options.sequenceId);
    if (!sequence) throw new Error('Timer sequence not found');
    return { ...sequence.state };
  }

  async addListener(eventName: 'timerSequenceEvent', callback: TimerSequenceCallback): Promise<PluginListenerHandle> {
    // Use parent class listener mechanism
    return super.addListener(eventName, callback as any);
  }
}
