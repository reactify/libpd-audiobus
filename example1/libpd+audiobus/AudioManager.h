//
//  AudioManager.h
//  libpd+audiobus
//
//  Created by Ragnar Hrafnkelsson on 31/10/2013.
//  Copyright (c) 2013 Reactify. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PdBase.h"

@interface AudioManager : NSObject <PdReceiverDelegate>

+ (AudioManager *)sharedInstance;

@property (nonatomic, readonly, getter = isActive) BOOL active;

- (void)start;
- (void)stop;

@end
