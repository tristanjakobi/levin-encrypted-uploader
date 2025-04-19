#import "LevinEncryptedUploader.h"

@implementation LevinEncryptedUploader

static NSString *BACKGROUND_SESSION_ID = @"levin-encrypted-uploader";
static LevinEncryptedUploader* staticEventEmitter = nil;

@synthesize downloadTasks = _downloadTasks;
@synthesize uploadTasks = _uploadTasks;
@synthesize uploadStreams = _uploadStreams;

- (instancetype)init {
    self = [super init];
    if (self) {
        staticEventEmitter = self;
        _responsesData = [NSMutableDictionary dictionary];
        _uploadTasks = [NSMutableDictionary dictionary];
        _uploadStreams = [NSMutableDictionary dictionary];
        _downloadTasks = [NSMutableDictionary dictionary];
        _uploadId = 0;
    }
    return self;
}

- (void)invalidate {
    [super invalidate];
    staticEventEmitter = nil;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
        @"levin-encrypted-uploader-progress",
        @"levin-encrypted-uploader-error",
        @"levin-encrypted-uploader-cancelled",
        @"levin-encrypted-uploader-completed",
        @"levin-encrypted-uploader-log"
    ];
}

- (void)_sendEventWithName:(NSString *)eventName body:(id)body {
    if (staticEventEmitter == nil) return;
    [staticEventEmitter sendEventWithName:eventName body:body];
}

- (void)sendLog:(NSString *)level 
         module:(NSString *)module 
        message:(NSString *)message 
          error:(NSError * _Nullable)error 
          params:(NSDictionary * _Nullable)params {
    NSMutableDictionary *logData = [NSMutableDictionary dictionary];
    logData[@"level"] = level;
    logData[@"module"] = module;
    logData[@"message"] = message;
    
    if (error) {
        logData[@"error"] = error.localizedDescription;
        if (error.userInfo) {
            logData[@"errorInfo"] = error.userInfo;
        }
        // Add more detailed error information
        logData[@"errorCode"] = @(error.code);
        logData[@"errorDomain"] = error.domain;
    }
    
    if (params) {
        logData[@"params"] = params;
    }
    
    // Log to console with clear formatting
    NSString *logMessage = [NSString stringWithFormat:@"[%@][%@] %@", level, module, message];
    if (error) {
        logMessage = [logMessage stringByAppendingFormat:@" - Error: %@ (Code: %ld)", error.localizedDescription, (long)error.code];
    }
    NSLog(@"%@", logMessage);
    
    [self _sendEventWithName:@"levin-encrypted-uploader-log" body:logData];
}

- (NSURL *)fileURLFromPath:(NSString *)path {
    if ([path hasPrefix:@"file://"]) {
        return [NSURL URLWithString:[path stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet]];
    } else {
        return [NSURL fileURLWithPath:path];
    }
}

- (NSString *)guessMIMETypeFromFileName:(NSString *)fileName {
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[fileName pathExtension], NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    
    if (UTI) {
        CFRelease(UTI);
    }
  
    if (!MIMEType) {
        return @"application/octet-stream";
    }
    return (__bridge NSString *)(MIMEType);
}

- (NSURLSession *)urlSession:(NSString *)groupId {
    if (_session == nil) {
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:BACKGROUND_SESSION_ID];
        if (groupId != nil && ![groupId isEqualToString:@""]) {
            sessionConfiguration.sharedContainerIdentifier = groupId;
        }
        _session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
    }
    return _session;
}

- (NSInputStream *)encryptedInputStreamFromFile:(NSString *)fileURI key:(NSData *)key nonce:(NSData *)nonce {
    NSURL *fileURL = [self fileURLFromPath:fileURI];
    NSInputStream *inputStream = [NSInputStream inputStreamWithURL:fileURL];
    return [[EncryptedInputStream alloc] initWithInputStream:inputStream key:key nonce:nonce];
}

- (void)startUpload:(JS::NativeLevinEncryptedUploader::UploadOptions &)options
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject {
    @try {
        int thisUploadId;
        @synchronized(self.class) {
            thisUploadId = _uploadId++;
        }

        // Extract values from the typed options
        NSString *uploadUrl = options.url();
        NSString *fileURI = options.path();
        NSString *method = options.method() ?: @"POST";
        NSString *customTransferId = options.customTransferId();
        NSString *appGroup = options.appGroup();
        NSDictionary *headers = (NSDictionary *)options.headers();
        
        // Get encryption parameters
        NSString *base64Key = options.encryptionKey();
        NSString *base64Nonce = options.encryptionNonce();

        NSLog(@"[LevinEncryptedUploader] Starting upload:");
        NSLog(@"  ➤ URL: %@", uploadUrl);
        NSLog(@"  ➤ File: %@", fileURI);
        NSLog(@"  ➤ Method: %@", method);
        NSLog(@"  ➤ Has key: %@", base64Key ? @"YES" : @"NO");
        NSLog(@"  ➤ Has nonce: %@", base64Nonce ? @"YES" : @"NO");

        // Validate all required parameters
        if (!uploadUrl || !fileURI) {
            reject(@"E_INVALID_ARGUMENT", @"Missing required URL or file path", nil);
            return;
        }
        
        if (!base64Key || !base64Nonce) {
            reject(@"E_INVALID_ARGUMENT", @"Missing encryption key or nonce", nil);
            return;
        }

        NSData *keyData = [[NSData alloc] initWithBase64EncodedString:base64Key options:0];
        NSData *nonceData = [[NSData alloc] initWithBase64EncodedString:base64Nonce options:0];
        
        if (!keyData || !nonceData) {
            reject(@"E_INVALID_ARGUMENT", @"Invalid encryption key or nonce format", nil);
            return;
        }

        NSURL *requestUrl = [NSURL URLWithString:uploadUrl];
        if (requestUrl == nil) {
            reject(@"E_INVALID_ARGUMENT", @"URL not compliant with RFC 2396", nil);
            return;
        }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestUrl];
        [request setHTTPMethod:method];
        [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];

        if (headers && [headers isKindOfClass:[NSDictionary class]]) {
            [headers enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
                if (![key isKindOfClass:[NSString class]]) return;
                if ([val respondsToSelector:@selector(stringValue)]) {
                    val = [val stringValue];
                }
                if ([val isKindOfClass:[NSString class]]) {
                    [request setValue:val forHTTPHeaderField:key];
                }
            }];
        }

        if (fileURI && [fileURI hasPrefix:@"assets-library"]) {
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);
            __block NSString *tempFileURI = nil;
            __block NSError *copyError = nil;
            
            [self copyAssetToFile:fileURI completionHandler:^(NSString *tempFileUrl, NSError *error) {
                if (error) {
                    copyError = error;
                } else {
                    tempFileURI = tempFileUrl;
                }
                dispatch_group_leave(group);
            }];
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
            
            if (copyError) {
                reject(@"E_ASSET_COPY_ERROR", @"Asset could not be copied to temp file.", copyError);
                return;
            }
            
            if (tempFileURI) {
                fileURI = tempFileURI;
            }
        }

        // Create encrypted stream
        NSInputStream *encryptedStream = [self encryptedInputStreamFromFile:fileURI key:keyData nonce:nonceData];
        if (!encryptedStream) {
            reject(@"E_STREAM_ERROR", @"Failed to create encrypted input stream", nil);
            return;
        }
        
        [request setHTTPBodyStream:encryptedStream];

        // Use NSURLSessionDataTask with uploadTaskWithStreamedRequest instead of NSURLSessionUploadTask
        NSURLSessionDataTask *uploadTask = [[self urlSession:appGroup] uploadTaskWithStreamedRequest:request];
        NSString *taskId = customTransferId ? customTransferId : [NSString stringWithFormat:@"%i", thisUploadId];
        uploadTask.taskDescription = taskId;
        
        [[self uploadTasks] setObject:uploadTask forKey:taskId];
        [[self uploadStreams] setObject:encryptedStream forKey:taskId];

        NSLog(@"[LevinEncryptedUploader] Starting upload task with ID: %@", taskId);
        [uploadTask resume];
        resolve(taskId);
    }
    @catch (NSException *exception) {
        NSLog(@"[LevinEncryptedUploader] Exception during upload: %@", exception);
        reject(@"E_UPLOAD_EXCEPTION", [NSString stringWithFormat:@"Exception: %@", exception.description], nil);
    }
}

- (void)cancelUpload:(NSString *)uploadId
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject {
    NSURLSessionUploadTask *task = self.uploadTasks[uploadId];
    if (task) {
        [task cancel];
        [self.uploadTasks removeObjectForKey:uploadId];
        resolve(@YES);
    } else {
        reject(@"E_INVALID_ARGUMENT", @"Invalid upload ID", nil);
    }
}

- (void)startDownload:(JS::NativeLevinEncryptedUploader::DownloadOptions &)options
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject {
    NSString *url = options.url();
    NSString *path = options.path();
    NSString *method = options.method() ?: @"GET";
    NSString *customTransferId = options.customTransferId();
    NSString *appGroup = options.appGroup();
    NSDictionary *headers = (NSDictionary *)options.headers();
    
    if (!url || !path) {
        reject(@"E_INVALID_ARGUMENT", @"URL and path are required", nil);
        return;
    }
    
    NSURL *downloadURL = [NSURL URLWithString:url];
    if (!downloadURL) {
        reject(@"E_INVALID_ARGUMENT", @"Invalid URL", nil);
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:downloadURL];
    [request setHTTPMethod:method];
    
    if (headers) {
        [headers enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            if ([value respondsToSelector:@selector(stringValue)]) {
                value = [value stringValue];
            }
            if ([value isKindOfClass:[NSString class]]) {
                [request setValue:value forHTTPHeaderField:key];
            }
        }];
    }
    
    NSURLSessionDownloadTask *task = [[self urlSession:appGroup] downloadTaskWithRequest:request];
    NSString *taskId = customTransferId ? customTransferId : [[NSUUID UUID] UUIDString];
    task.taskDescription = taskId;
    self.downloadTasks[taskId] = task;
    
    [task resume];
    resolve(taskId);
}

- (void)cancelDownload:(NSString *)downloadId
             resolve:(RCTPromiseResolveBlock)resolve
              reject:(RCTPromiseRejectBlock)reject {
    NSURLSessionDownloadTask *task = self.downloadTasks[downloadId];
    if (task) {
        [task cancel];
        [self.downloadTasks removeObjectForKey:downloadId];
        resolve(@YES);
    } else {
        reject(@"E_INVALID_ARGUMENT", @"Invalid download ID", nil);
    }
}

- (void)downloadAndDecrypt:(JS::NativeLevinEncryptedUploader::DownloadAndDecryptOptions &)options
                  resolve:(RCTPromiseResolveBlock)resolve
                   reject:(RCTPromiseRejectBlock)reject {
    NSString *urlStr = options.url();
    NSString *destination = options.destination();
    
    // Get encryption parameters
    NSString *base64Key = options.encryptionKey();
    NSString *base64Nonce = options.encryptionNonce();
    NSDictionary *headers = (NSDictionary *)options.headers();

    if (!urlStr || !destination) {
        reject(@"E_INVALID_ARGUMENT", @"Missing required URL or destination path", nil);
        return;
    }

    if (!base64Key || !base64Nonce) {
        reject(@"E_INVALID_ARGUMENT", @"Missing encryption key or nonce", nil);
        return;
    }

    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:base64Key options:0];
    NSData *nonceData = [[NSData alloc] initWithBase64EncodedString:base64Nonce options:0];
    
    if (!keyData || !nonceData) {
        reject(@"E_INVALID_ARGUMENT", @"Invalid encryption key or nonce format", nil);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:urlStr];
    
    if (!url) {
        reject(@"E_INVALID_ARGUMENT", @"Invalid URL", nil);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    if (headers && [headers isKindOfClass:[NSDictionary class]]) {
        [headers enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
            if ([val respondsToSelector:@selector(stringValue)]) {
                val = [val stringValue];
            }
            if ([val isKindOfClass:[NSString class]]) {
                [request setValue:val forHTTPHeaderField:key];
            }
        }];
    }

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
      dataTaskWithRequest:request
      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            reject(@"download_failed", error.localizedDescription, error);
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode >= 400) {
            NSString *errorMsg = [NSString stringWithFormat:@"HTTP error %ld", (long)httpResponse.statusCode];
            reject(@"http_error", errorMsg, nil);
            return;
        }

        NSURL *destinationURL;
        if ([destination hasPrefix:@"file://"]) {
            destinationURL = [NSURL URLWithString:destination];
        } else {
            destinationURL = [NSURL fileURLWithPath:destination];
        }
        
        if (!destinationURL) {
            reject(@"invalid_path", @"Invalid destination path", nil);
            return;
        }
        
        NSString *cleanedPath = [destinationURL path];
        cleanedPath = [cleanedPath stringByRemovingPercentEncoding];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *directory = [cleanedPath stringByDeletingLastPathComponent];
        
        NSError *dirError = nil;
        [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&dirError];
        if (dirError) {
            reject(@"directory_creation_failed", dirError.localizedDescription, dirError);
            return;
        }

        EncryptedOutputStream *stream = [[EncryptedOutputStream alloc] initWithFilePath:cleanedPath
                                                                                     key:keyData
                                                                                   nonce:nonceData];
        
        if (!stream) {
            reject(@"stream_creation_failed", @"Failed to create output stream", nil);
            return;
        }

        NSError *writeErr = nil;
        BOOL ok = [stream writeData:data error:&writeErr];
        [stream close];

        if (!ok) {
            reject(@"decryption_failed", writeErr.localizedDescription, writeErr);
        } else {
            resolve(@{ @"path": destination });
        }
    }];

    [task resume];
}

- (void)getFileInfo:(NSString *)path
           resolve:(RCTPromiseResolveBlock)resolve
            reject:(RCTPromiseRejectBlock)reject {
    @try {
        NSString *escapedPath = [path stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
        NSURL *fileUri = [NSURL URLWithString:escapedPath];
        NSString *pathWithoutProtocol = [fileUri path];
        NSString *name = [fileUri lastPathComponent];
        NSString *extension = [name pathExtension];
        bool exists = [[NSFileManager defaultManager] fileExistsAtPath:pathWithoutProtocol];
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:name, @"name", nil];
        [params setObject:extension forKey:@"extension"];
        [params setObject:[NSNumber numberWithBool:exists] forKey:@"exists"];

        if (exists) {
            [params setObject:[self guessMIMETypeFromFileName:name] forKey:@"mimeType"];
            NSError* error;
            NSDictionary<NSFileAttributeKey, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:pathWithoutProtocol error:&error];
            if (error == nil) {
                unsigned long long fileSize = [attributes fileSize];
                [params setObject:[NSNumber numberWithLong:fileSize] forKey:@"size"];
            }
        }
        resolve(params);
    }
    @catch (NSException *exception) {
        reject(@"RN Uploader", exception.name, nil);
    }
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    NSString *taskId = task.taskDescription;
    [self sendLog:@"INFO" 
           module:@"Uploader" 
          message:[NSString stringWithFormat:@"Task completed - ID: %@", taskId] 
            error:error 
            params:nil];
    
    if (!taskId) {
        [self sendLog:@"ERROR" 
               module:@"Uploader" 
              message:@"Task completed without ID" 
                error:nil 
                params:nil];
        return;
    }
    
    // Handle upload stream cleanup
    NSInputStream *stream = self.uploadStreams[taskId];
    if (stream) {
        [self sendLog:@"DEBUG" 
               module:@"Uploader" 
              message:[NSString stringWithFormat:@"Closing upload stream for task: %@", taskId] 
                error:nil 
                params:nil];
        [stream close];
        [self.uploadStreams removeObjectForKey:taskId];
    }
    
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:taskId, @"id", nil];
    
    // Handle response data for upload tasks
    if ([task isKindOfClass:[NSURLSessionDataTask class]]) {
        NSURLSessionDataTask *uploadTask = (NSURLSessionDataTask *)task;
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)uploadTask.response;
        
        if (response != nil) {
            [self sendLog:@"INFO" 
                   module:@"Uploader" 
                  message:[NSString stringWithFormat:@"Response status code: %ld", (long)response.statusCode] 
                    error:nil 
                    params:@{@"headers": [response allHeaderFields]}];
            [data setObject:[NSNumber numberWithInteger:response.statusCode] forKey:@"responseCode"];
        }
        
        NSMutableData *responseData = _responsesData[@(task.taskIdentifier)];
        if (responseData) {
            [_responsesData removeObjectForKey:@(task.taskIdentifier)];
            NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            if (response) {
                [self sendLog:@"DEBUG" 
                       module:@"Uploader" 
                      message:[NSString stringWithFormat:@"Response body: %@", response] 
                        error:nil 
                        params:nil];
                [data setObject:response forKey:@"responseBody"];
            } else {
                [self sendLog:@"ERROR" 
                       module:@"Uploader" 
                      message:@"Failed to decode response data" 
                        error:nil 
                        params:@{@"dataLength": @(responseData.length)}];
                [data setObject:[NSNull null] forKey:@"responseBody"];
            }
        } else {
            [self sendLog:@"WARN" 
                   module:@"Uploader" 
                  message:@"No response data received" 
                    error:nil 
                    params:nil];
            [data setObject:[NSNull null] forKey:@"responseBody"];
        }
    }
    
    // Handle response code for download tasks
    if ([task isKindOfClass:[NSURLSessionDownloadTask class]]) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        if (response != nil) {
            [self sendLog:@"INFO" 
                   module:@"Uploader" 
                  message:[NSString stringWithFormat:@"Download response status code: %ld", (long)response.statusCode] 
                    error:nil 
                    params:nil];
            [data setObject:[NSNumber numberWithInteger:response.statusCode] forKey:@"responseCode"];
        }
    }

    if (error == nil) {
        [self sendLog:@"INFO" 
               module:@"Uploader" 
              message:@"Upload completed successfully" 
                error:nil 
                params:data];
        [self _sendEventWithName:@"levin-encrypted-uploader-completed" body:data];
    } else {
        [self sendLog:@"ERROR" 
               module:@"Uploader" 
              message:@"Upload failed" 
                error:error 
                params:data];
        [data setObject:error.localizedDescription forKey:@"error"];
        if (error.code == NSURLErrorCancelled) {
            [self sendLog:@"INFO" 
                   module:@"Uploader" 
                  message:@"Upload was cancelled" 
                    error:nil 
                    params:data];
            [self _sendEventWithName:@"levin-encrypted-uploader-cancelled" body:data];
        } else {
            [self _sendEventWithName:@"levin-encrypted-uploader-error" body:data];
        }
    }
    
    // Clean up task references
    if ([task isKindOfClass:[NSURLSessionUploadTask class]]) {
        [self.uploadTasks removeObjectForKey:taskId];
    } else if ([task isKindOfClass:[NSURLSessionDownloadTask class]]) {
        [self.downloadTasks removeObjectForKey:taskId];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    float progress = -1;
    if (totalBytesExpectedToSend > 0) {
        progress = 100.0 * (float)totalBytesSent / (float)totalBytesExpectedToSend;
    }
    
    NSLog(@"[LevinEncryptedUploader] Upload progress - ID: %@, sent: %lld, total: %lld, expected: %lld, progress: %.2f%%",
          task.taskDescription, bytesSent, totalBytesSent, totalBytesExpectedToSend, progress);
    
    [self _sendEventWithName:@"levin-encrypted-uploader-progress" 
                       body:@{ @"id": task.taskDescription, @"progress": [NSNumber numberWithFloat:progress] }];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (!data.length) {
        NSLog(@"[LevinEncryptedUploader] Received empty data");
        return;
    }
    NSLog(@"[LevinEncryptedUploader] Received %lu bytes of response data", (unsigned long)data.length);
    
    NSMutableData *responseData = _responsesData[@(dataTask.taskIdentifier)];
    if (!responseData) {
        responseData = [NSMutableData dataWithData:data];
        _responsesData[@(dataTask.taskIdentifier)] = responseData;
    } else {
        [responseData appendData:data];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
 needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler {
    NSLog(@"[LevinEncryptedUploader] Need new body stream for task: %@", task.taskDescription);
    
    NSInputStream *inputStream = task.originalRequest.HTTPBodyStream;
    if (completionHandler) {
        NSLog(@"[LevinEncryptedUploader] Providing new body stream");
        completionHandler(inputStream);
    }
}

- (void)copyAssetToFile:(NSString *)assetUrl completionHandler:(void(^)(NSString *__nullable tempFileUrl, NSError *__nullable error))completionHandler {
    NSURL *url = [NSURL URLWithString:assetUrl];
    PHAsset *asset = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil].lastObject;
    if (!asset) {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"Asset could not be fetched.  Are you missing permissions?" forKey:NSLocalizedDescriptionKey];
        completionHandler(nil, [NSError errorWithDomain:@"RNUploader" code:5 userInfo:details]);
        return;
    }
    PHAssetResource *assetResource = [[PHAssetResource assetResourcesForAsset:asset] firstObject];
    NSString *pathToWrite = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSURL *pathUrl = [NSURL fileURLWithPath:pathToWrite];
    NSString *fileURI = pathUrl.absoluteString;

    PHAssetResourceRequestOptions *options = [PHAssetResourceRequestOptions new];
    options.networkAccessAllowed = YES;

    [[PHAssetResourceManager defaultManager] writeDataForAssetResource:assetResource toFile:pathUrl options:options completionHandler:^(NSError * _Nullable e) {
        if (e == nil) {
            completionHandler(fileURI, nil);
        }
        else {
            completionHandler(nil, e);
        }
    }];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    NSString *taskId = downloadTask.taskDescription;
    if (!taskId) return;
    
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:taskId, @"id", nil];
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)downloadTask.response;
    
    if (response != nil) {
        [data setObject:[NSNumber numberWithInteger:response.statusCode] forKey:@"responseCode"];
    }
    
    [self _sendEventWithName:@"levin-encrypted-uploader-completed" body:data];
    [self.downloadTasks removeObjectForKey:taskId];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    float progress = -1;
    if (totalBytesExpectedToWrite > 0) {
        progress = 100.0 * (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    }
    
    [self _sendEventWithName:@"levin-encrypted-uploader-progress" 
                       body:@{ @"id": downloadTask.taskDescription, @"progress": [NSNumber numberWithFloat:progress] }];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeLevinEncryptedUploaderSpecJSI>(params);
}

@end
