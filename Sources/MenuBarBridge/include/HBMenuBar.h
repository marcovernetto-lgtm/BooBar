#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface HBMenuBar : NSObject
@property(class, nonatomic, readonly) BOOL available;
- (void)allowBundles:(NSArray<NSString *> *)bundleIDs completion:(void (^)(NSError * _Nullable))completion __attribute__((swift_async(none)));
- (void)restore;
@end
NS_ASSUME_NONNULL_END
