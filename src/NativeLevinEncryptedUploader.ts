import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface FileInfo {
  mimeType: string;
  size: number;
  exists: boolean;
  name: string;
  extension: string;
}

export interface UploadOptions {
  url: string;
  path: string;
  method?: string;
  headers?: { [key: string]: string };
  encryptionKey: string;
  encryptionNonce: string;
  customTransferId?: string;
  appGroup?: string;
}

export interface DownloadOptions {
  url: string;
  path: string;
  method?: string;
  headers?: { [key: string]: string };
  customTransferId?: string;
  appGroup?: string;
}

export interface DownloadAndDecryptOptions {
  url: string;
  destination: string;
  headers?: { [key: string]: string };
  encryptionKey: string;
  encryptionNonce: string;
}

export interface Spec extends TurboModule {
  // File info methods
  getFileInfo(path: string): Promise<FileInfo>;

  // Upload methods
  startUpload(options: UploadOptions): Promise<string>;
  cancelUpload(uploadId: string): Promise<boolean>;

  // Download methods
  startDownload(options: DownloadOptions): Promise<string>;
  cancelDownload(downloadId: string): Promise<boolean>;

  // Direct download and decrypt
  downloadAndDecrypt(
    options: DownloadAndDecryptOptions
  ): Promise<{ path: string }>;

  // Event emitter methods
  addListener(eventName: string): void;
  removeListeners(count: number): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('LevinEncryptedUploader');
