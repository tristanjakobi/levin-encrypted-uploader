#import "EncryptedInputStream.h"
#import <CommonCrypto/CommonCryptor.h>

@interface EncryptedInputStream () {
    CCCryptorRef _cryptor;
    NSInputStream *_sourceStream;
    NSMutableData *_readBuffer;
    uint8_t *_internalBuffer;
    NSUInteger _bufferPos;
    NSUInteger _bufferLen;
}
@end

@implementation EncryptedInputStream

- (NSStreamStatus)streamStatus {
    return [_sourceStream streamStatus];
}

- (NSError *)streamError {
    return [_sourceStream streamError];
}

- (BOOL)hasBytesAvailable {
    return YES;
}

- (instancetype)initWithInputStream:(NSInputStream *)stream key:(NSData *)key nonce:(NSData *)nonce {
    self = [super init];
    if (self) {
        _sourceStream = stream;
        _readBuffer = [NSMutableData dataWithLength:4096];
        _internalBuffer = static_cast<uint8_t *>(malloc(4096));
        _bufferPos = 0;
        _bufferLen = 0;

        CCCryptorStatus status = CCCryptorCreateWithMode(kCCEncrypt,
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
            NSLog(@"[EncryptedInputStream] Failed to create cryptor with status: %d", status);
            return nil;
        }
        
        NSLog(@"[EncryptedInputStream] Successfully initialized with key length: %lu, nonce length: %lu", (unsigned long)key.length, (unsigned long)nonce.length);
    }
    return self;
}

- (void)dealloc {
    if (_cryptor) {
        CCCryptorRelease(_cryptor);
    }
    if (_internalBuffer) {
        free(_internalBuffer);
    }
}

- (void)open {
    [_sourceStream open];
    NSLog(@"[EncryptedInputStream] Stream opened, status: %ld", (long)[_sourceStream streamStatus]);
}

- (void)close {
    [_sourceStream close];
    NSLog(@"[EncryptedInputStream] Stream closed");
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if (_bufferPos >= _bufferLen) {
        NSInteger bytesRead = [_sourceStream read:_internalBuffer maxLength:4096];
        NSLog(@"[EncryptedInputStream] Read %ld bytes from source stream", (long)bytesRead);
        
        if (bytesRead <= 0) {
            NSLog(@"[EncryptedInputStream] No more data to read or error occurred");
            return bytesRead;
        }

        size_t outMoved = 0;
        CCCryptorStatus status = CCCryptorUpdate(_cryptor,
                                                 _internalBuffer, bytesRead,
                                                 _readBuffer.mutableBytes, _readBuffer.length,
                                                 &outMoved);
                                                 
        if (status != kCCSuccess) {
            NSLog(@"[EncryptedInputStream] Encryption failed with status: %d", status);
            return -1;
        }

        NSLog(@"[EncryptedInputStream] Encrypted %zu bytes", outMoved);
        _bufferLen = outMoved;
        _bufferPos = 0;
    }

    NSUInteger available = _bufferLen - _bufferPos;
    NSUInteger toCopy = MIN(len, available);
    memcpy(buffer, static_cast<const uint8_t *>(_readBuffer.bytes) + _bufferPos, toCopy);
    _bufferPos += toCopy;

    NSLog(@"[EncryptedInputStream] Returning %lu bytes to caller", (unsigned long)toCopy);
    return toCopy;
}

- (id)propertyForKey:(NSStreamPropertyKey)key {
    return [_sourceStream propertyForKey:key];
}

- (BOOL)setProperty:(id)property forKey:(NSStreamPropertyKey)key {
    return [_sourceStream setProperty:property forKey:key];
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode {
    [_sourceStream scheduleInRunLoop:aRunLoop forMode:mode];
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode {
    [_sourceStream removeFromRunLoop:aRunLoop forMode:mode];
}

- (id)delegate {
    return [_sourceStream delegate];
}

- (void)setDelegate:(id<NSStreamDelegate>)delegate {
    [_sourceStream setDelegate:delegate];
}

- (NSData *)decryptAESCTRData:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv {
    size_t dataOutAvailable = data.length;
    void *dataOut = malloc(dataOutAvailable);
    size_t dataOutMoved = 0;

    CCCryptorRef cryptor = NULL;
    CCCryptorCreateWithMode(kCCDecrypt,
                            kCCModeCTR,
                            kCCAlgorithmAES,
                            ccNoPadding,
                            iv.bytes,
                            key.bytes,
                            key.length,
                            NULL, 0, 0,
                            kCCModeOptionCTR_BE,
                            &cryptor);

    CCCryptorUpdate(cryptor, data.bytes, data.length, dataOut, dataOutAvailable, &dataOutMoved);
    CCCryptorRelease(cryptor);

    NSData *decrypted = [NSData dataWithBytesNoCopy:dataOut length:dataOutMoved];
    return decrypted;
}

@end
