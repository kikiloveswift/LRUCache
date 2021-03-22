//
//  LRUCache.m
//  LRUCache
//
//  Created by Alexey Patosin on 26/02/15.
//  Copyright (c) 2015 TestOrg. All rights reserved.
//

#import "LRUCache.h"
#import "LRUCacheNode.h"

static const char *kLRUCacheQueue = "kLRUCacheQueue";

@interface LRUCache ()
@property (nonatomic, strong) NSMutableDictionary *dictionary;
@property (nonatomic, strong) LRUCacheNode *headNode;
@property (nonatomic, strong) LRUCacheNode *tailNode;
@property (nonatomic) NSUInteger size;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation LRUCache

- (instancetype)initWithCapacity:(NSUInteger)capacity {
    self = [super init];
    if (self) {
        [self commonSetup];
        _capacity = capacity;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        [self commonSetup];
        _capacity = [aDecoder decodeIntegerForKey:@"kLRUCacheCapacityCoderKey"];
        _headNode = [aDecoder decodeObjectForKey:@"kLRUCacheRootNodeCoderKey"];
        _tailNode = [aDecoder decodeObjectForKey:@"kLRUCacheTailNodeCoderKey"];
        _dictionary = [aDecoder decodeObjectForKey:@"kLRUCacheDictionaryCoderKey"];
        _size = [aDecoder decodeIntegerForKey:@"kLRUCacheSizeCoderKey"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInteger:self.capacity forKey:@"kLRUCacheCapacityCoderKey"];
    [aCoder encodeObject:self.headNode forKey:@"kLRUCacheRootNodeCoderKey"];
    [aCoder encodeObject:self.headNode forKey:@"kLRUCacheTailNodeCoderKey"];
    [aCoder encodeObject:self.dictionary forKey:@"kLRUCacheDictionaryCoderKey"];
    [aCoder encodeInteger:self.size forKey:@"kLRUCacheSizeCoderKey"];
}

- (void)commonSetup {
    _dictionary = [NSMutableDictionary dictionary];
    _queue = dispatch_queue_create(kLRUCacheQueue, 0);
    _headNode = [LRUCacheNode new];
    _tailNode = [LRUCacheNode new];
    _headNode.next = _tailNode;
    _tailNode.prev = _headNode;
}

#pragma mark - set object / get object methods

- (void)setObject:(id)object forKey:(id<NSCopying>)key {
    
    NSAssert(object != nil, @"LRUCache cannot store nil object!");
    
    dispatch_barrier_async(self.queue, ^{
        LRUCacheNode *node = self.dictionary[key];
        if (node == nil) {
            node = [LRUCacheNode nodeWithValue:object key:key];
            self.dictionary[key] = node;
            [self addToHead:node];
            self.size++;
            [self checkSpace];
        } else {
            node.value = object;
            [self moveToHead:node];
        }
    });
}


- (id)objectForKey:(id<NSCopying>)key {
    __block id value = nil;
    
    dispatch_sync(self.queue, ^{
        LRUCacheNode *node = self.dictionary[key];
        if (node) {
            [self moveToHead:node];
            value = node.value;
        }
    });
    
    return value;
}

#pragma mark - helper methods

- (void)addToHead:(LRUCacheNode *)node {
    node.prev = self.headNode;
    node.next = self.headNode.next;
    self.headNode.next.prev = node;
    self.headNode.next = node;
}

- (void)moveToHead:(LRUCacheNode *)node {
    [self removeNode:node];
    [self addToHead:node];
}

- (void)removeNode:(LRUCacheNode *)node {
    node.prev.next = node.next;
    node.next.prev = node.prev;
}

- (LRUCacheNode *)removeTail {
    LRUCacheNode *node = self.tailNode.prev;
    [self removeNode:node];
    return node;
}

- (void)checkSpace {
    if (self.size > self.capacity) {
        LRUCacheNode *removeNode = [self removeTail];
        [self.dictionary removeObjectForKey:removeNode.key];
        self.size--;
    }
}

@end
