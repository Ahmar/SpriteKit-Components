//
//  SKComponentScene.m
//  ReEntry
//
//  Created by Andrew Eiche on 6/19/13.
//  Copyright (c) 2013 Andrew Eiche. All rights reserved.
//

#import "SKComponentScene.h"

@interface SKComponentScene() {
    NSHashTable* components;
    NSHashTable* componentsToRemove;
    NSHashTable* componentsToAdd;
    CFTimeInterval lastFrameTime;
}

@end


@implementation SKComponentScene

static Class skComponentNodeClass;

-(id)initWithSize:(CGSize)size {
    if ((self = [super initWithSize:size])) {
        if (!skComponentNodeClass)
            skComponentNodeClass = [SKComponentNode class];
        components = [NSHashTable weakObjectsHashTable];
        componentsToAdd = [NSHashTable weakObjectsHashTable];
        componentsToRemove = [NSHashTable weakObjectsHashTable];
        lastFrameTime = 0;
        
        self.physicsWorld.contactDelegate = self;
    }
    return self;
}

- (void)dealloc {
    components = Nil;
}

- (void)registerComponent:(id<SKComponent>)component {
    if (![components containsObject:component]) {
        [componentsToAdd addObject:component];
    } else {
        [componentsToRemove removeObject:component];
    }
}

- (void)unregisterComponent:(id<SKComponent>)component {
    if ([components containsObject:component]) {
        [componentsToRemove addObject:component];
    } else {
        [componentsToAdd removeObject:component];
    }
}

- (void)update:(NSTimeInterval)currentTime {
    // calculate delta time
    if (lastFrameTime == 0) {
        _deltaTime = 0;
    } else {
        _deltaTime = currentTime - lastFrameTime;
    }
    lastFrameTime = currentTime;

    
    // remove requested components
    [components minusHashTable:componentsToRemove];
    [componentsToRemove removeAllObjects];

    
    // look for new SKComponent nodes and make them enter the scene
    recursiveFindNewNodes(self);
    
    
    // add new componenets
    [components unionHashTable:componentsToAdd];
    [componentsToAdd removeAllObjects];
    
    
    // perform update on all regiseterd components
    for (id<SKComponent> component in components.objectEnumerator) {
        if (component.enabled && [component respondsToSelector:@selector(update:)])
            [component update:_deltaTime];
    }
    
    /** @todo: consider looping for as long as there are new components to add */
}

/** @todo:  this may cause problems if onEnter modifies the scene graph
 *          doesn't matter if we require all SKComponent nodes belong to other SKComponent nodes
 *          or we generate a list, then perform onEnter (also affects SKComponentNode onEnter)
 */
void recursiveFindNewNodes(SKNode* node) {
    for (SKNode *child in node.children) {
        if ([child isKindOfClass:skComponentNodeClass]) {
            SKComponentNode* componentNode = (SKComponentNode*)child;
            if (!componentNode.hasEnteredScene) {
                [componentNode onEnter];
            }
        }

        recursiveFindNewNodes(child);
    }
}

- (void)didEvaluateActions {
    [super didEvaluateActions];
    
    for (id<SKComponent> component in components.objectEnumerator) {
        SKComponentPerformSelector(component, didEvaluateActions);
    }
}

- (void)didSimulatePhysics{
    [super didSimulatePhysics];
    
    for (id<SKComponent> component in components.objectEnumerator) {
        SKComponentPerformSelector(component, didSimulatePhysics);
    }
}

- (void)didBeginContact:(SKPhysicsContact *)contact {
    for (id<SKComponent> component in components.objectEnumerator) {
        SKComponentPerformSelectorWithObject(component, didBeginContact, contact);
    }
}

- (void)didEndContact:(SKPhysicsContact *)contact {
    for (id<SKComponent> component in components.objectEnumerator) {
        SKComponentPerformSelectorWithObject(component, didEndContact, contact);
    }
}
@end