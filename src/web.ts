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
} from './definitions';

export class CapgoLiveActivitiesWeb extends WebPlugin implements CapgoLiveActivitiesPlugin {
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
}
