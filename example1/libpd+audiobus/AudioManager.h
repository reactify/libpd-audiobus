//
//  AudioManager.h
//  libpd+audiobus
//
//  Created by Ragnar Hrafnkelsson on 31/10/2013.
//  Copyright (c) 2013 Reactify. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioManager : NSObject

@property (nonatomic, getter = isActive) BOOL active;

+ (instancetype)sharedInstance;

@end
