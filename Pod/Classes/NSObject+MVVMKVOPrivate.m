//
//  NSObject+MVVMKVOPrivate.m
//  KVO-MVVM
//
//  Created by Andrew Podkovyrin on 16/03/16.
//
//

#import <objc/message.h>
#import <objc/runtime.h>

#import "NSObject+MVVMKVOPrivate.h"

static void *MVVMKVOContext = &MVVMKVOContext;

#pragma mark -

typedef void (^ObserveBlock)(id, id);
typedef NSMutableArray<void (^)(id, id)> ObserveBlocksArray;
typedef NSMutableDictionary<NSString *, ObserveBlocksArray *> ObserveBlocksDictionary;

@interface NSObject (MVVMKVOPrivate_Properties)

@property (strong, nonatomic) ObserveBlocksDictionary *mvvm_blocks;

@end

@implementation NSObject (MVVMKVOPrivate_Properties)

- (ObserveBlocksDictionary *)mvvm_blocks {
    NSMutableDictionary *blocks = objc_getAssociatedObject(self, @selector(mvvm_blocks));
    if (blocks == nil) {
        blocks = [NSMutableDictionary dictionary];
        self.mvvm_blocks = blocks;
    }
    return blocks;
}

- (void)setMvvm_blocks:(NSMutableDictionary<NSString *, void (^)(id, id)> *)mvvm_blocks {
    objc_setAssociatedObject(self, @selector(mvvm_blocks), mvvm_blocks, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark -

@implementation NSObject (MVVMKVOPrivate)

- (void)mvvm_observe:(NSString *)keyPath with:(void (^)(id self, id value))block {
    if (!self.mvvm_blocks[keyPath]) {
        self.mvvm_blocks[keyPath] = [NSMutableArray array];
    }
    [self.mvvm_blocks[keyPath] addObject:[block copy]];

    if (self.mvvm_blocks[keyPath].count == 1) {
        [self addObserver:self forKeyPath:keyPath options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:MVVMKVOContext];
    }
    else {
        self.mvvm_blocks[keyPath].lastObject(self, nil);
    }
}

- (void)mvvm_unobserve:(NSString *)keyPath {
    if (self.mvvm_blocks[keyPath]) {
        [self.mvvm_blocks removeObjectForKey:keyPath];
        [self removeObserver:self forKeyPath:keyPath];
    }
}

- (void)mvvm_unobserveAll {
    for (NSString *keyPath in self.mvvm_blocks) {
        [self removeObserver:self forKeyPath:keyPath];
    }
    self.mvvm_blocks = nil;
}

- (void)mvvm_observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context superClass:(Class)superClass {
    if (context != MVVMKVOContext) {
        SEL sel = @selector(observeValueForKeyPath:ofObject:change:context:);
        if ([superClass instancesRespondToSelector:sel]) {
            struct objc_super mySuper = {
                .receiver = self,
                .super_class = superClass,
            };

            id (*objc_superClassKVOMethod)(struct objc_super *, SEL, id, id, id, void *) = (void *)&objc_msgSendSuper;
            objc_superClassKVOMethod(&mySuper, sel, keyPath, object, change, context);
            // [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        }
        return;
    }

    id newValue = change[NSKeyValueChangeNewKey];
    id oldValue = change[NSKeyValueChangeOldKey];
    if ([newValue isEqual:oldValue]) {
        return;
    }

    for (ObserveBlock block in self.mvvm_blocks[keyPath]) {
        block(self, (newValue != [NSNull null]) ? newValue : nil);
    }
}

@end
