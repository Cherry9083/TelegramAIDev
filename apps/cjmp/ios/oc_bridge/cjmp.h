# ifndef CJMP_H
# define CJMP_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface cjmp : NSObject

+ (NSString *)logicTest;
+ (BOOL)saveDemoSessionPhone:(NSString *)phoneNumber;
+ (NSString *)loadDemoSessionPhone;
+ (void)clearDemoSessionPhone;
+ (BOOL)saveTelegramRuntimeConfig:(NSString *)configJson;
+ (NSString *)loadTelegramRuntimeConfig;
+ (void)clearTelegramRuntimeConfig;
+ (BOOL)saveTelegramSessionKey:(NSString *)sessionKey;
+ (NSString *)loadTelegramSessionKey;
+ (void)clearTelegramSessionKey;

@end

NS_ASSUME_NONNULL_END

#endif
