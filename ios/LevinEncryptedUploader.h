#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <Photos/Photos.h>
#import "EncryptedInputStream.h"
#import "EncryptedOutputStream.h"
#import <React/RCTLog.h>
#import <React/RCTUtils.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <LevinEncryptedUploader/RNLevinEncryptedUploaderSpec.h>

@interface LevinEncryptedUploader : RCTEventEmitter <NativeLevinEncryptedUploaderSpec, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
{
  NSMutableDictionary *_responsesData;
}
@property (nonatomic, strong) NSURLSession *session;
- (NSMutableDictionary *)uploadTasks;
- (NSMutableDictionary *)uploadStreams;
- (NSMutableDictionary *)downloadTasks;
@end

