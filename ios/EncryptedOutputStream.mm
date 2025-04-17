#import "EncryptedOutputStream.h"
#import <CommonCrypto/CommonCryptor.h>

@interface EncryptedOutputStream () {
    CCCryptorRef _cryptor;
    NSOutputStream *_outputStream;
    NSString *_filePath;
}
@end

@implementation EncryptedOutputStream

- (instancetype)initWithFilePath:(NSString *)filePath
                             key:(NSData *)key
                           nonce:(NSData *)nonce {
    self = [super init];
    if (self) {
        // 🔐 Normalize file path
        NSString *resolvedPath = filePath;
        if ([filePath hasPrefix:@"file://"]) {
            resolvedPath = [[NSURL URLWithString:filePath] path];
        }
        _filePath = resolvedPath;


        NSLog(@"[EncryptedOutputStream] initWithFilePath:");
        NSLog(@"  ➤ original path: %@", filePath);
        NSLog(@"  ➤ resolved path: %@", resolvedPath);


        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:resolvedPath]) {
            NSLog(@"[EncryptedOutputStream] File already exists, will be overwritten: %@", resolvedPath);
        }

        _outputStream = [NSOutputStream outputStreamToFileAtPath:_filePath append:NO];
        NSLog(@"[EncryptedOutputStream] Created output stream");

        [_outputStream open];
        NSLog(@"[EncryptedOutputStream] Stream status after open: %ld", (long)_outputStream.streamStatus);

        if (_outputStream.streamStatus == NSStreamStatusError) {
            NSLog(@"[EncryptedOutputStream] Failed to open stream for path: %@, error: %@", _filePath, _outputStream.streamError);
            return nil;
        }

        CCCryptorStatus status = CCCryptorCreateWithMode(kCCDecrypt,
                                                        kCCModeCTR,
                                                        kCCAlgorithmAES,
                                                        ccNoPadding,
                                                        nonce.bytes,
                                                        key.bytes,
                                                        key.length,
                                                        NULL, 0, 0,
                                                        kCCModeOptionCTR_BE,
                                                        &_cryptor);

        if (status != kCCSuccess) {
            NSLog(@"[EncryptedOutputStream] Failed to create cryptor with status: %d", status);
            return nil;
        }

        NSLog(@"[EncryptedOutputStream] Successfully initialized");
    }
    return self;
}

- (BOOL)writeData:(NSData *)data error:(NSError **)error {
    NSLog(@"[EncryptedOutputStream] Writing data of size: %lu", (unsigned long)data.length);

    if (!_cryptor || !_outputStream) {
        NSLog(@"[EncryptedOutputStream] Missing cryptor or output stream");
        if (error) {
            *error = [NSError errorWithDomain:@"EncryptedOutputStream"
                                         code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Missing cryptor or output stream" }];
        }
        return NO;
    }

    NSMutableData *outBuffer = [NSMutableData dataWithLength:data.length];
    size_t outMoved = 0;

    CCCryptorStatus status = CCCryptorUpdate(_cryptor,
                                             data.bytes,
                                             data.length,
                                             outBuffer.mutableBytes,
                                             outBuffer.length,
                                             &outMoved);

    if (status != kCCSuccess) {
        NSLog(@"[EncryptedOutputStream] Decryption failed with status: %d", status);
        if (error) {
            *error = [NSError errorWithDomain:@"EncryptedOutputStream"
                                         code:status
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Decryption failed" }];
        }
        return NO;
    }

    NSLog(@"[EncryptedOutputStream] Successfully decrypted data, size: %zu", outMoved);

    if (![_outputStream hasSpaceAvailable]) {
        NSLog(@"[EncryptedOutputStream] Output stream has no space available");
    }

    NSInteger written = [_outputStream write:(uint8_t *)outBuffer.bytes maxLength:outMoved];
    NSLog(@"[EncryptedOutputStream] Write returned %ld", (long)written);

    if (written <= 0) {
        NSLog(@"[EncryptedOutputStream] Write failed — streamError: %@", _outputStream.streamError);
        if (error) {
            *error = _outputStream.streamError ?: [NSError errorWithDomain:@"EncryptedOutputStream"
                                                                      code:-2
                                                                  userInfo:@{ NSLocalizedDescriptionKey: @"Write returned zero or failed" }];
        }
        return NO;
    }

    NSString *verifyPath = _filePath;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:verifyPath];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:verifyPath error:nil];

    NSLog(@"[EncryptedOutputStream] File written:");
    NSLog(@"  ➤ path: %@", verifyPath);
    NSLog(@"  ➤ exists: %@", exists ? @"YES" : @"NO");
    NSLog(@"  ➤ size: %@ bytes", attrs[NSFileSize]);

    NSLog(@"[EncryptedOutputStream] File exists at path? %@ | Size: %@", exists ? @"YES" : @"NO", attrs[NSFileSize]);

    return YES;
}


- (void)close {
    NSLog(@"[EncryptedOutputStream] Closing stream and cryptor");
    if (_cryptor) {
        CCCryptorRelease(_cryptor);
        _cryptor = NULL;
    }
    if (_outputStream) {
        [_outputStream close];
        _outputStream = nil;
    }
    NSLog(@"[EncryptedOutputStream] Closed successfully");
}

@end
