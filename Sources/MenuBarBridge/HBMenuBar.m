#import "HBMenuBar.h"
#import <objc/runtime.h>
#include <dlfcn.h>

@protocol HBConfiguration
- (instancetype)initWithAllowedSystemItems:(NSArray<NSNumber *> *)items allowedBundleIdentifiers:(NSArray<NSString *> *)identifiers;
@end
@protocol HBAssertion
- (void)activateWithConfiguration:(id)configuration completionHandler:(void (^)(NSError *))completion;
- (void)invalidate;
@end

static BOOL HBMethodMatches(Class cls, SEL selector, unsigned arguments, char result) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method || method_getNumberOfArguments(method) != arguments) return NO;
    char encoding[16] = {0};
    method_getReturnType(method, encoding, sizeof(encoding));
    return encoding[0] == result;
}

@implementation HBMenuBar {
    id<HBAssertion> _active;
    id<HBAssertion> _pending;
    NSUInteger _generation;
}

+ (BOOL)available {
    static BOOL available;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Resolve against the installed OS. Never link an undocumented framework at build time.
        void *handle = dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_NOW | RTLD_LOCAL);
        Class config = NSClassFromString(@"MBAssessmentModeConfiguration");
        Class assertion = NSClassFromString(@"MBAssessmentModeAssertion");
        available = handle && config && assertion &&
            HBMethodMatches(config, @selector(initWithAllowedSystemItems:allowedBundleIdentifiers:), 4, '@') &&
            HBMethodMatches(assertion, @selector(activateWithConfiguration:completionHandler:), 4, 'v') &&
            HBMethodMatches(assertion, @selector(invalidate), 2, 'v');
    });
    return available;
}

- (void)allowBundles:(NSArray<NSString *> *)bundleIDs completion:(void (^)(NSError *))completion {
    if (!HBMenuBar.available) {
        completion([NSError errorWithDomain:@"BooBar" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Native icon visibility is unavailable on this macOS version."}]);
        return;
    }
    [self cancelPending];
    NSUInteger generation = ++_generation;
    @try {
        id<HBConfiguration> allocated = [NSClassFromString(@"MBAssessmentModeConfiguration") alloc];
        // Preserve every system-item category. Restrict only the selected application bundles.
        id config = [allocated initWithAllowedSystemItems:@[@0,@1,@2,@3,@4,@5,@6,@7,@8] allowedBundleIdentifiers:bundleIDs];
        id<HBAssertion> candidate = [NSClassFromString(@"MBAssessmentModeAssertion") new];
        if (!config || !candidate) @throw [NSException exceptionWithName:@"Unavailable" reason:@"Menu bar configuration is unavailable." userInfo:nil];
        _pending = candidate;
        __weak HBMenuBar *weakSelf = self;
        [candidate activateWithConfiguration:config completionHandler:^(NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                HBMenuBar *owner = weakSelf;
                if (!owner || generation != owner->_generation) { [candidate invalidate]; return; }
                if (error) {
                    [owner restore];
                } else {
                    @try { [owner->_active invalidate]; } @catch (NSException *ignored) {}
                    owner->_active = candidate;
                    owner->_pending = nil;
                }
                completion(error);
            });
        }];
    } @catch (NSException *exception) {
        [self restore];
        completion([NSError errorWithDomain:@"BooBar" code:2 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"macOS rejected the operation."}]);
    }
}

- (void)cancelPending {
    @try { [_pending invalidate]; } @catch (NSException *ignored) {}
    _pending = nil;
}

- (void)restore {
    ++_generation;
    [self cancelPending];
    @try { [_active invalidate]; } @catch (NSException *ignored) {}
    _active = nil;
}

- (void)dealloc { [self restore]; }
@end
