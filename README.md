# react-native-levin-encrypted-uploader 🚧

A DIY React Native file uploader with mandatory encryption, inspired by the VydiaRNFileUploader. This is very much a work in progress - use at your own risk!

> ⚠️ **Warning**: This package is still in active development. Things might break, change, or not work as expected. You've been warned!

## Features

- 🔒 Mandatory encryption for all uploads (no way around it!)
- 📱 Background uploads on iOS and Android
- 🚀 Streaming encryption (no temporary files needed)
- 📊 Progress tracking
- 🎯 Simple API

## Usage

```typescript
import { startUpload } from 'react-native-levin-encrypted-uploader';

// You MUST provide encryption parameters - no way around it!
const uploadId = await startUpload({
  url: 'https://your-upload-endpoint.com/upload',
  path: '/path/to/your/file.mp4',
  method: 'POST',
  headers: {
    Authorization: 'Bearer your-token',
  },
  encryption: {
    key: 'your-base64-encoded-key', // Required!
    nonce: 'your-base64-encoded-nonce', // Required!
  },
});

// Listen for upload events
const subscription = addEventListener(
  'levin-encrypted-uploader-progress',
  ({ progress }) => {
    console.log(`Upload progress: ${progress}%`);
  }
);

// Don't forget to clean up!
subscription.remove();
```

## Events

- `levin-encrypted-uploader-progress`: Fired during upload with progress percentage
- `levin-encrypted-uploader-completed`: Fired when upload completes successfully
- `levin-encrypted-uploader-error`: Fired when an error occurs
- `levin-encrypted-uploader-cancelled`: Fired when upload is cancelled
- `levin-encrypted-uploader-log`: Fired for debug logs

## Contributing

Feel free to open issues and pull requests! Just remember this is a DIY project, so be patient with us. 😅

## License

MIT

## Acknowledgments

- HEAVILY inspired by [VydiaRNFileUploader](https://github.com/Vydia/react-native-background-upload)
- Built with ❤️ and a lot of trial and error
