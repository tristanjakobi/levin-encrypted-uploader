#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>
#import "EncryptedInputStream.h"
#import "EncryptedOutputStream.h"
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import "generated/RNLevinEncryptedUploaderSpec/RNLevinEncryptedUploaderSpec.h"

@interface LevinEncryptedUploader : RCTEventEmitter <NativeLevinEncryptedUploaderSpec, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
{
  NSMutableDictionary *_responsesData;
  NSMutableDictionary *_uploadTasks;
  NSMutableDictionary *_uploadStreams;
  NSMutableDictionary *_downloadTasks;
  int _uploadId;
}
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary *downloadTasks;
@property (nonatomic, strong) NSMutableDictionary *uploadStreams;
@property (nonatomic, strong) NSMutableDictionary *uploadTasks;
@end

