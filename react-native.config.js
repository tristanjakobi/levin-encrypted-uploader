/**
 * @type {import('@react-native-community/cli-types').UserDependencyConfig}
 */
module.exports = {
  dependency: {
    platforms: {
      ios: {
        project: './ios/LevinEncryptedUploader.xcodeproj',
      },
      android: {
        sourceDir: './android',
      },
    },
  },
};
