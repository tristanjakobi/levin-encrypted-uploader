# React Native Levin Encrypted Uploader

A React Native module for encrypted file uploads and downloads with background task support.

## Features

- Encrypted file uploads and downloads
- Background task support
- Progress tracking
- Event-based notifications
- Support for both iOS and Android
- TypeScript support

## Installation

```bash
yarn add react-native-levin-encrypted-uploader
```

### iOS

Add the following to your `Podfile`:

```ruby
pod 'LevinEncryptedUploader', :path => '../node_modules/react-native-levin-encrypted-uploader'
```

Then run:

```bash
cd ios && pod install
```

### Android

No additional setup required for Android.

## Usage

```typescript
import LevinEncryptedUploader from 'react-native-levin-encrypted-uploader';

// Get file info
const fileInfo = await LevinEncryptedUploader.getFileInfo('file://path/to/file');

// Start an upload
const uploadId = await LevinEncryptedUploader.startUpload({
  url: 'https://example.com/upload',
  path: 'file://path/to/file',
  method: 'POST',
  headers: {
    'Authorization': 'Bearer token'
  },
  encryption: {
    key: 'base64-encoded-key',
    nonce: 'base64-encoded-nonce'
  }
});

// Start a download
const downloadId = await LevinEncryptedUploader.startDownload({
  url: 'https://example.com/file',
  path: 'file://path/to/save',
  method: 'GET',
  headers: {
    'Authorization': 'Bearer token'
  }
});

// Download and decrypt a file
const result = await LevinEncryptedUploader.downloadAndDecrypt({
  url: 'https://example.com/encrypted-file',
  destination: 'file://path/to/save',
  headers: {
    'Authorization': 'Bearer token'
  },
  encryption: {
    key: 'base64-encoded-key',
    nonce: 'base64-encoded-nonce'
  }
});

// Cancel an upload
await LevinEncryptedUploader.cancelUpload(uploadId);

// Cancel a download
await LevinEncryptedUploader.cancelDownload(downloadId);
```

## Events

The module emits the following events:

- `levin-encrypted-uploader-progress`: Upload/download progress
- `levin-encrypted-uploader-error`: Error occurred
- `levin-encrypted-uploader-cancelled`: Upload/download cancelled
- `levin-encrypted-uploader-completed`: Upload/download completed
- `levin-encrypted-uploader-log`: Debug logs

Example:

```typescript
import { NativeEventEmitter, NativeModules } from 'react-native';

const eventEmitter = new NativeEventEmitter(NativeModules.LevinEncryptedUploader);

eventEmitter.addListener('levin-encrypted-uploader-progress', (data) => {
  console.log('Progress:', data.progress);
});

eventEmitter.addListener('levin-encrypted-uploader-completed', (data) => {
  console.log('Completed:', data);
});

eventEmitter.addListener('levin-encrypted-uploader-error', (data) => {
  console.error('Error:', data.error);
});
```

## API Reference

### Methods

#### getFileInfo(path: string): Promise<FileInfo>

Get information about a file.

```typescript
interface FileInfo {
  mimeType: string;
  size: number;
  exists: boolean;
  name: string;
  extension: string;
}
```

#### startUpload(options: UploadOptions): Promise<string>

Start a file upload.

```typescript
interface UploadOptions {
  url: string;
  path: string;
  method?: string;
  headers?: Record<string, string>;
  encryption: {
    key: string;
    nonce: string;
  };
  customTransferId?: string;
  appGroup?: string;
}
```

#### cancelUpload(uploadId: string): Promise<boolean>

Cancel an ongoing upload.

#### startDownload(options: DownloadOptions): Promise<string>

Start a file download.

```typescript
interface DownloadOptions {
  url: string;
  path: string;
  method?: string;
  headers?: Record<string, string>;
  customTransferId?: string;
  appGroup?: string;
}
```

#### cancelDownload(downloadId: string): Promise<boolean>

Cancel an ongoing download.

#### downloadAndDecrypt(options: DownloadAndDecryptOptions): Promise<{ path: string }>

Download and decrypt a file.

```typescript
interface DownloadAndDecryptOptions {
  url: string;
  destination: string;
  headers?: Record<string, string>;
  encryption: {
    key: string;
    nonce: string;
  };
}
```

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
